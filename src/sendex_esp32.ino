/*
  Sendex — ESP32 GPS + HR + Accelerometer + BLE Firmware
  Hardware:
    - GPS: NEO-6M (SoftwareSerial RX=16, TX=17)
    - HR: MAX30102 (I2C 0x57, SDA=21, SCL=22)
    - Accel: MPU6050 (I2C 0x68, same bus)
    - Button: GPIO 7 (INPUT_PULLUP, hold 3s toggle session)
    - LEDs: Green=8, Blue=9
    - Battery ADC: GPIO 35 (voltage divider 2:1)
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <TinyGPS++.h>
#include <SoftwareSerial.h>
#include <Wire.h>
#include <Preferences.h>

// ── Pins ───────────────────────────────────────────────
#define GPS_RX_PIN  16
#define GPS_TX_PIN  17
#define BTN_PIN     7
#define LED_GREEN   8
#define LED_BLUE    9
#define BAT_ADC     35
#define I2C_SDA     21
#define I2C_SCL     22

// ── Firmware info ──────────────────────────────────────
#define FIRMWARE_VERSION "v1.3.0"
#define DEVICE_NAME "Sendex-Vest"

// ── BLE UUIDs ──────────────────────────────────────────
#define SERVICE_UUID          "FFF0"
#define CHAR_DATA_UUID        "FFF1"
#define CHAR_CMD_UUID         "FFF2"
#define BATTERY_SERVICE_UUID  "180F"
#define BATTERY_CHAR_UUID     "2A19"

// ── Constants ──────────────────────────────────────────
#define NOTIFY_INTERVAL      1000
#define BATT_NOTIFY_INTERVAL 60000
#define HOLD_DURATION        3000
#define DEBOUNCE_DELAY       50
#define MAX_POINTS_CACHE     3600
#define JSON_BUF_SIZE        512
#define DEEP_SLEEP_TIMEOUT   60000
#define PPG_RING_SIZE        64

// ── GPS ────────────────────────────────────────────────
TinyGPSPlus gps;
SoftwareSerial gpsSerial(GPS_RX_PIN, GPS_TX_PIN);

// ── BLE ────────────────────────────────────────────────
BLECharacteristic *pDataChar = nullptr;
BLECharacteristic *pCmdChar = nullptr;
BLECharacteristic *pBattChar = nullptr;
bool deviceConnected = false;

// ── NVS cache ──────────────────────────────────────────
Preferences prefs;
int cacheIndex = 0;

// ── State ──────────────────────────────────────────────
bool sessionActive = false;
unsigned long lastNotifyTime = 0;
unsigned long lastBattNotify = 0;
unsigned long sessionStartMs = 0;
unsigned long lastGpsFixMs = 0;
unsigned long lastBtnPressMs = 0;
unsigned long sessionStopMs = 0;

// ── MAX30102 (0x57) ────────────────────────────────────
#define MAX30102_ADDR 0x57
#define REG_INTR_STATUS_1 0x00
#define REG_FIFO_DATA     0x07
#define REG_MODE_CONFIG   0x09
#define REG_SPO2_CONFIG   0x0A
#define REG_LED1_PA       0x0C
#define REG_LED2_PA       0x0D

bool hrSensorPresent = false;

// ── PPG ring buffer ────────────────────────────────────
uint32_t ppgRing[PPG_RING_SIZE];
int ppgIdx = 0;
int ppgCount = 0;

// ── MPU6050 (0x68) ─────────────────────────────────────
#define MPU6050_ADDR   0x68
#define REG_PWR_MGMT_1 0x6B
#define REG_ACCEL_XOUT 0x3B

bool mpuPresent = false;
float accelX = 0, accelY = 0, accelZ = 0;

// ═══════════════════════════════════════════════════════
//  Battery
// ═══════════════════════════════════════════════════════
float readBatteryVoltage() {
  int raw = 0;
  for (int i = 0; i < 10; i++) raw += analogRead(BAT_ADC);
  raw /= 10;
  return (raw / 4095.0) * 3.3 * 2;
}

uint8_t batteryPercent(float voltage) {
  if (voltage >= 4.2) return 100;
  if (voltage >= 4.0) return map((voltage - 4.0) * 100, 0, 20, 75, 100);
  if (voltage >= 3.8) return map((voltage - 3.8) * 100, 0, 20, 50, 75);
  if (voltage >= 3.6) return map((voltage - 3.6) * 100, 0, 20, 25, 50);
  if (voltage >= 3.4) return map((voltage - 3.4) * 100, 0, 20, 5, 25);
  return 0;
}

// ═══════════════════════════════════════════════════════
//  MPU6050
// ═══════════════════════════════════════════════════════
bool initMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  if (Wire.endTransmission() != 0) return false;
  // Wake up (clear sleep bit)
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(REG_PWR_MGMT_1);
  Wire.write(0x00);
  Wire.endTransmission();
  delay(50);
  return true;
}

void readMPU6050() {
  if (!mpuPresent) { accelX = 0; accelY = 0; accelZ = 0; return; }
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(REG_ACCEL_XOUT);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU6050_ADDR, 6);
  if (Wire.available() < 6) return;
  int16_t ax = Wire.read() << 8 | Wire.read();
  int16_t ay = Wire.read() << 8 | Wire.read();
  int16_t az = Wire.read() << 8 | Wire.read();
  // Convert to G (±2g range, 16384 LSB/g)
  accelX = ax / 16384.0;
  accelY = ay / 16384.0;
  accelZ = az / 16384.0;
}

float computeNetAccel() {
  float mag = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  return fabs(mag - 1.0);
}

// ═══════════════════════════════════════════════════════
//  MAX30102 — PPG with ring buffer + adaptive peak
// ═══════════════════════════════════════════════════════
bool initMAX30102() {
  Wire.beginTransmission(MAX30102_ADDR);
  if (Wire.endTransmission() != 0) return false;
  // Reset
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_MODE_CONFIG); Wire.write(0x40);
  Wire.endTransmission();
  delay(100);
  // Multi-LED mode
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_MODE_CONFIG); Wire.write(0x03);
  Wire.endTransmission();
  // SpO2: 200Hz, 411us, 18-bit
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_SPO2_CONFIG); Wire.write(0x27);
  Wire.endTransmission();
  // LEDs 25mA
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_LED1_PA); Wire.write(0x24);
  Wire.endTransmission();
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_LED2_PA); Wire.write(0x24);
  Wire.endTransmission();
  return true;
}

bool readPPGSample(uint32_t &ir) {
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_FIFO_DATA);
  Wire.endTransmission();
  Wire.requestFrom(MAX30102_ADDR, 6);
  if (Wire.available() < 6) return false;
  Wire.read(); Wire.read(); Wire.read(); // skip red
  ir = (uint32_t)(Wire.read() << 16 | Wire.read() << 8 | Wire.read());
  return true;
}

float ppgHeartRate() {
  if (!hrSensorPresent) return readSimulatedHR();
  uint32_t sample;
  if (!readPPGSample(sample)) return readSimulatedHR();
  // Ring buffer
  ppgRing[ppgIdx] = sample;
  ppgIdx = (ppgIdx + 1) % PPG_RING_SIZE;
  if (ppgCount < PPG_RING_SIZE) ppgCount++;
  if (ppgCount < 10) return readSimulatedHR(); // not enough samples
  // DC removal (mean subtract)
  uint64_t sum = 0;
  for (int i = 0; i < ppgCount; i++) sum += ppgRing[i];
  uint32_t mean = sum / ppgCount;
  // Find peaks above adaptive threshold
  static bool lastAbove = false;
  static unsigned long lastPeakMs = 0;
  static float hr = 72.0;
  int half = ppgCount / 2;
  uint32_t thresh = mean + (ppgRing[half] > mean ? (ppgRing[half] - mean) / 3 : 500);
  bool above = (sample > thresh);
  if (above && !lastAbove) {
    unsigned long now = millis();
    if (lastPeakMs > 0) {
      float interval = (now - lastPeakMs) / 1000.0;
      if (interval > 0.3 && interval < 2.0) {
        hr = 60.0 / interval;
        if (hr < 40) hr = 40;
        if (hr > 220) hr = 220;
      }
    }
    lastPeakMs = now;
  }
  lastAbove = above;
  return hr;
}

float readSimulatedHR() {
  static float hr = 72.0;
  hr += (random(-5, 6)) / 10.0;
  if (hr < 55) hr = 55;
  if (hr > 180) hr = 180;
  return hr;
}

// ═══════════════════════════════════════════════════════
//  NVS cache
// ═══════════════════════════════════════════════════════
void cachePoint(const char* json) {
  if (cacheIndex >= MAX_POINTS_CACHE) return;
  String key = "p" + String(cacheIndex);
  prefs.putString(key.c_str(), json);
  cacheIndex++;
  prefs.putInt("count", cacheIndex);
}

void flushCache() {
  int count = prefs.getInt("count", 0);
  if (count == 0 || !deviceConnected) return;
  for (int i = 0; i < count; i++) {
    String key = "p" + String(i);
    String val = prefs.getString(key.c_str(), "");
    if (val.length() > 0) {
      pDataChar->setValue(val.c_str());
      pDataChar->notify();
      delay(10);
      prefs.remove(key.c_str());
    }
  }
  cacheIndex = 0;
  prefs.putInt("count", 0);
  Serial.printf("Flushed %d cached points\n", count);
}

// ═══════════════════════════════════════════════════════
//  Button (debounced, hold 3s)
// ═══════════════════════════════════════════════════════
void handleButton() {
  static int lastState = HIGH;
  static unsigned long lastStableMs = 0;
  static bool holdActive = false;
  unsigned long now = millis();
  int raw = digitalRead(BTN_PIN);
  if (raw != lastState) lastStableMs = now;
  lastState = raw;
  bool stable = (now - lastStableMs) >= DEBOUNCE_DELAY;
  bool pressed = stable && raw == LOW;
  if (pressed && !holdActive && (now - lastBtnPressMs) >= HOLD_DURATION) {
    lastBtnPressMs = now;
    holdActive = true;
    sessionActive = !sessionActive;
    digitalWrite(LED_GREEN, sessionActive ? LOW : HIGH);
    digitalWrite(LED_BLUE, sessionActive ? HIGH : LOW);
    if (sessionActive) {
      sessionStartMs = now;
      sessionStopMs = 0;
      Serial.println("Session STARTED (button)");
    } else {
      sessionStopMs = now;
      Serial.println("Session STOPPED (button)");
    }
  }
  if (!pressed) holdActive = false;
}

// ═══════════════════════════════════════════════════════
//  BLE commands
// ═══════════════════════════════════════════════════════
class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    String cmd = c->getValue().c_str();
    cmd.toUpperCase();
    cmd.trim();
    Serial.printf("BLE cmd: %s\n", cmd.c_str());
    if (cmd == "START") {
      if (!sessionActive) {
        sessionActive = true;
        sessionStartMs = millis();
        sessionStopMs = 0;
        digitalWrite(LED_GREEN, LOW);
        digitalWrite(LED_BLUE, HIGH);
        c->setValue("OK:START");
      } else {
        c->setValue("ERR:ALREADY_STARTED");
      }
    } else if (cmd == "STOP") {
      if (sessionActive) {
        sessionActive = false;
        sessionStopMs = millis();
        digitalWrite(LED_GREEN, HIGH);
        digitalWrite(LED_BLUE, LOW);
        c->setValue("OK:STOP");
      } else {
        c->setValue("ERR:NOT_STARTED");
      }
    } else if (cmd == "STATUS") {
      char resp[128];
      readMPU6050();
      snprintf(resp, sizeof(resp),
        "{\"session\":%s,\"bat\":%d,\"hr\":%.0f,\"sat\":%d,\"v\":\"%s\",\"accel\":%.2f}",
        sessionActive ? "true" : "false",
        batteryPercent(readBatteryVoltage()),
        hrSensorPresent ? ppgHeartRate() : readSimulatedHR(),
        gps.satellites.isValid() ? gps.satellites.value() : 0,
        FIRMWARE_VERSION,
        computeNetAccel()
      );
      c->setValue(resp);
    } else if (cmd == "PING") {
      c->setValue("PONG " FIRMWARE_VERSION);
    } else if (cmd == "SLEEP") {
      c->setValue("OK:SLEEP");
      delay(100);
      enterDeepSleep();
    } else {
      c->setValue("ERR:UNKNOWN");
    }
    c->notify();
  }
};

// ═══════════════════════════════════════════════════════
//  BLE server callbacks
// ═══════════════════════════════════════════════════════
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) {
    deviceConnected = true;
    Serial.println("Client connected");
    flushCache();
  }
  void onDisconnect(BLEServer* s) {
    deviceConnected = false;
    Serial.println("Client disconnected");
    BLEDevice::getAdvertising()->start();
  }
};

// ═══════════════════════════════════════════════════════
//  Deep sleep
// ═══════════════════════════════════════════════════════
void enterDeepSleep() {
  Serial.println("Entering deep sleep...");
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);
  delay(100);
  // Save session state to NVS
  prefs.putBool("sessionActive", sessionActive);
  prefs.putULong("sessionStart", sessionStartMs);
  // Button GPIO 7 = RTC_GPIO_10, wake on LOW (pressed)
  esp_sleep_enable_ext0_wakeup(GPIO_NUM_7, LOW);
  esp_deep_sleep_start();
}

void checkDeepSleep() {
  if (!sessionActive && !deviceConnected && sessionStopMs > 0 &&
      (millis() - sessionStopMs) >= DEEP_SLEEP_TIMEOUT) {
    enterDeepSleep();
  }
}

// ═══════════════════════════════════════════════════════
//  Setup
// ═══════════════════════════════════════════════════════
void setup() {
  Serial.begin(115200);
  Serial.printf("\nSendex ESP32 %s booting...\n", FIRMWARE_VERSION);

  pinMode(BTN_PIN, INPUT_PULLUP);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, LOW);

  Wire.begin(I2C_SDA, I2C_SCL);

  // MAX30102
  hrSensorPresent = initMAX30102();
  Serial.printf("MAX30102: %s\n", hrSensorPresent ? "OK" : "missing (simulated)");

  // MPU6050
  mpuPresent = initMPU6050();
  Serial.printf("MPU6050:  %s\n", mpuPresent ? "OK" : "missing (no accel)");

  // GPS
  gpsSerial.begin(9600);
  Serial.println("GPS on pins 16/17");

  analogReadResolution(12);
  float vbat = readBatteryVoltage();
  Serial.printf("Battery: %.2fV (%d%%)\n", vbat, batteryPercent(vbat));

  // NVS
  prefs.begin("sendex", false);
  cacheIndex = prefs.getInt("count", 0);
  if (cacheIndex > 0) Serial.printf("NVS: %d cached points\n", cacheIndex);

  // Restore session from before deep sleep
  bool wasActive = prefs.getBool("sessionActive", false);
  if (wasActive) {
    sessionActive = true;
    sessionStartMs = millis() - (millis() - prefs.getULong("sessionStart", millis()));
    digitalWrite(LED_GREEN, LOW);
    digitalWrite(LED_BLUE, HIGH);
    Serial.println("Session restored from NVS");
  }

  // BLE
  BLEDevice::init(DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *dataService = server->createService(SERVICE_UUID);
  pDataChar = dataService->createCharacteristic(
    CHAR_DATA_UUID, BLECharacteristic::PROPERTY_NOTIFY
  );
  pDataChar->addDescriptor(new BLE2902());

  pCmdChar = dataService->createCharacteristic(
    CHAR_CMD_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCmdChar->addDescriptor(new BLE2902());
  pCmdChar->setCallbacks(new CmdCallbacks());
  dataService->start();

  BLEService *battService = server->createService(BATTERY_SERVICE_UUID);
  pBattChar = battService->createCharacteristic(
    BATTERY_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pBattChar->addDescriptor(new BLE2902());
  pBattChar->setValue((uint8_t)batteryPercent(vbat));
  battService->start();

  BLEAdvertising *adv = server->getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  adv->setMaxPreferred(0x12);
  adv->start();

  Serial.printf("Advertising as '%s'\n", DEVICE_NAME);
  Serial.println("Commands: START, STOP, STATUS, PING, SLEEP");
}

// ═══════════════════════════════════════════════════════
//  Loop
// ═══════════════════════════════════════════════════════
void loop() {
  handleButton();

  while (gpsSerial.available() > 0) gps.encode(gpsSerial.read());

  // GPS fix LED
  if (gps.location.isValid() && gps.satellites.value() >= 3) lastGpsFixMs = millis();
  bool hasFix = (millis() - lastGpsFixMs) < 10000;
  if (!sessionActive) {
    if (hasFix) digitalWrite(LED_GREEN, (millis() / 1000) % 2 == 0 ? LOW : HIGH);
    else digitalWrite(LED_GREEN, (millis() / 500) % 2 == 0 ? LOW : HIGH);
  }

  // 1s data notify
  if (sessionActive && millis() - lastNotifyTime >= NOTIFY_INTERVAL) {
    lastNotifyTime = millis();
    readMPU6050();

    float speed = gps.speed.isValid() ? gps.speed.kmph() : 0.0;
    double lat = gps.location.isValid() ? gps.location.lat() : 0.0;
    double lng = gps.location.isValid() ? gps.location.lng() : 0.0;
    float alt = gps.altitude.isValid() ? gps.altitude.meters() : 0.0;
    int sat = gps.satellites.isValid() ? gps.satellites.value() : 0;
    float hdop = gps.hdop.isValid() ? gps.hdop.hdop() : 99.9;
    float hr = hrSensorPresent ? ppgHeartRate() : readSimulatedHR();
    uint8_t bat = batteryPercent(readBatteryVoltage());
    float netAccel = computeNetAccel();

    // Sign from speed delta (positive = speeding up)
    static float prevSpeed = 0;
    float signedAccel = (speed >= prevSpeed) ? netAccel : -netAccel;
    prevSpeed = speed;

    char json[JSON_BUF_SIZE];
    snprintf(json, sizeof(json),
      "{"
      "\"v\":\"%s\","
      "\"lat\":%.6f,"
      "\"lng\":%.6f,"
      "\"speed\":%.1f,"
      "\"alt\":%.1f,"
      "\"hr\":%.0f,"
      "\"sat\":%d,"
      "\"hdop\":%.1f,"
      "\"bat\":%d,"
      "\"accel\":%.2f"
      "}",
      FIRMWARE_VERSION,
      lat, lng, speed, alt, hr, sat, hdop, bat, signedAccel
    );

    if (deviceConnected) {
      pDataChar->setValue(json);
      pDataChar->notify();
    } else {
      cachePoint(json);
    }
    Serial.println(json);
  }

  // Battery notify every 60s
  if (deviceConnected && millis() - lastBattNotify >= BATT_NOTIFY_INTERVAL) {
    lastBattNotify = millis();
    uint8_t pct = batteryPercent(readBatteryVoltage());
    pBattChar->setValue(&pct, 1);
    pBattChar->notify();
  }

  // Deep sleep check
  checkDeepSleep();

  // GPS watchdog
  if (sessionActive && millis() - lastGpsFixMs > 30000 && gps.location.isValid()) {
    gpsSerial.end();
    delay(100);
    gpsSerial.begin(9600);
    gps = TinyGPSPlus();
    lastGpsFixMs = millis();
    Serial.println("GPS watchdog reset");
  }
}
