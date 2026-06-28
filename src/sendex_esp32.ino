/*
  Sendex — ESP32 GPS + Heart Rate + BLE Firmware
  Hardware:
    - GPS: NEO-6M (SoftwareSerial RX=16, TX=17)
    - Heart Rate: MAX30102 (I2C SDA=21, SCL=22)
    - Button: GPIO 7 (INPUT_PULLUP, hold 3s to toggle)
    - LEDs: Green=8, Blue=9
    - Battery ADC: GPIO 35 (voltage divider)
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
#define FIRMWARE_VERSION "v1.2.3"
#define DEVICE_NAME "Sendex-Vest"

// ── BLE UUIDs ──────────────────────────────────────────
#define SERVICE_UUID          "FFF0"
#define CHAR_DATA_UUID        "FFF1"
#define CHAR_CMD_UUID         "FFF2"
#define BATTERY_SERVICE_UUID  "180F"
#define BATTERY_CHAR_UUID     "2A19"

// ── Constants ──────────────────────────────────────────
#define NOTIFY_INTERVAL      1000  // 1s GPS data
#define BATT_NOTIFY_INTERVAL 60000 // 60s battery
#define HOLD_DURATION        3000  // 3s to toggle session
#define DEBOUNCE_DELAY       50
#define MAX_POINTS_CACHE     3600  // 1h at 1Hz
#define JSON_BUF_SIZE        512

// ── GPS ────────────────────────────────────────────────
TinyGPSPlus gps;
SoftwareSerial gpsSerial(GPS_RX_PIN, GPS_TX_PIN);

// ── BLE objects ────────────────────────────────────────
BLECharacteristic *pDataChar = nullptr;
BLECharacteristic *pCmdChar = nullptr;
BLECharacteristic *pBattChar = nullptr;
bool deviceConnected = false;

// ── NVS (data cache when BLE disconnected) ─────────────
Preferences prefs;
int cacheIndex = 0;

// ── State ──────────────────────────────────────────────
bool sessionActive = false;
unsigned long lastNotifyTime = 0;
unsigned long lastBattNotify = 0;
unsigned long sessionStartMs = 0;
unsigned long lastGpsFixMs = 0;
unsigned long lastBtnPressMs = 0;

// ── MAX30102 registers ─────────────────────────────────
#define MAX30102_ADDR 0x57
#define REG_INTR_STATUS_1 0x00
#define REG_FIFO_DATA     0x07
#define REG_MODE_CONFIG   0x09
#define REG_SPO2_CONFIG   0x0A
#define REG_LED1_PA       0x0C
#define REG_LED2_PA       0x0D

bool hrSensorPresent = false;

// ── Battery ────────────────────────────────────────────
float readBatteryVoltage() {
  int raw = 0;
  for (int i = 0; i < 10; i++) raw += analogRead(BAT_ADC);
  raw /= 10;
  float voltage = (raw / 4095.0) * 3.3 * 2;
  return voltage;
}

uint8_t batteryPercent(float voltage) {
  if (voltage >= 4.2) return 100;
  if (voltage >= 4.0) return map((voltage - 4.0) * 100, 0, 20, 75, 100);
  if (voltage >= 3.8) return map((voltage - 3.8) * 100, 0, 20, 50, 75);
  if (voltage >= 3.6) return map((voltage - 3.6) * 100, 0, 20, 25, 50);
  if (voltage >= 3.4) return map((voltage - 3.4) * 100, 0, 20, 5, 25);
  return 0;
}

// ── MAX30102 ───────────────────────────────────────────
bool initMAX30102() {
  Wire.beginTransmission(MAX30102_ADDR);
  if (Wire.endTransmission() != 0) return false;

  // Reset
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_MODE_CONFIG);
  Wire.write(0x40);
  Wire.endTransmission();
  delay(100);

  // Multi-LED mode, SpO2
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_MODE_CONFIG);
  Wire.write(0x03);
  Wire.endTransmission();

  // SpO2 config: 200Hz, 411us pulse, 18-bit
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_SPO2_CONFIG);
  Wire.write(0x27);
  Wire.endTransmission();

  // LED currents: 25mA
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_LED1_PA);
  Wire.write(0x24);
  Wire.endTransmission();

  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_LED2_PA);
  Wire.write(0x24);
  Wire.endTransmission();

  return true;
}

float readMAX30102HR() {
  if (!hrSensorPresent) return readSimulatedHR();

  // Read FIFO
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(REG_FIFO_DATA);
  Wire.endTransmission();
  Wire.requestFrom(MAX30102_ADDR, 6);
  if (Wire.available() < 6) return readSimulatedHR();

  uint32_t red = Wire.read() << 16 | Wire.read() << 8 | Wire.read();
  uint32_t ir = Wire.read() << 16 | Wire.read() << 8 | Wire.read();

  // Simple threshold-based peak detection
  static uint32_t lastIr = 0;
  static unsigned long lastPeakMs = 0;
  static float hr = 72.0;

  if (lastIr > 0 && ir > lastIr + 5000) {
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
  lastIr = ir;

  return hr;
}

float readSimulatedHR() {
  static float hr = 72.0;
  hr += (random(-5, 6)) / 10.0;
  if (hr < 55) hr = 55;
  if (hr > 180) hr = 180;
  return hr;
}

// ── NVS cache (prevent data loss on BLE disconnect) ────
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

// ── Button handler (with debounce) ─────────────────────
void handleButton() {
  static int lastState = HIGH;
  static unsigned long lastStableMs = 0;
  static boolHold = false;

  int raw = digitalRead(BTN_PIN);
  unsigned long now = millis();

  // Debounce
  if (raw != lastState) lastStableMs = now;
  lastState = raw;

  bool stable = (now - lastStableMs) >= DEBOUNCE_DELAY;
  bool pressed = stable && raw == LOW;

  if (pressed && !boolHold && (now - lastBtnPressMs) >= HOLD_DURATION) {
    lastBtnPressMs = now;
    boolHold = true;
    sessionActive = !sessionActive;
    digitalWrite(LED_GREEN, sessionActive ? LOW : HIGH);
    digitalWrite(LED_BLUE, sessionActive ? HIGH : LOW);

    if (sessionActive) {
      sessionStartMs = now;
      Serial.println("Session STARTED (button)");
    } else {
      Serial.println("Session STOPPED (button)");
    }
  }
  if (!pressed) boolHold = false;
}

// ── BLE command handler ────────────────────────────────
class CmdCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) {
    String cmd = c->getValue().c_str();
    cmd.toUpperCase();
    cmd.trim();
    Serial.printf("BLE command: %s\n", cmd.c_str());

    if (cmd == "START") {
      if (!sessionActive) {
        sessionActive = true;
        sessionStartMs = millis();
        digitalWrite(LED_GREEN, LOW);
        digitalWrite(LED_BLUE, HIGH);
        Serial.println("Session STARTED (BLE)");
        c->setValue("OK:START");
      } else {
        c->setValue("ERR:ALREADY_STARTED");
      }
    } else if (cmd == "STOP") {
      if (sessionActive) {
        sessionActive = false;
        digitalWrite(LED_GREEN, HIGH);
        digitalWrite(LED_BLUE, LOW);
        Serial.println("Session STOPPED (BLE)");
        c->setValue("OK:STOP");
      } else {
        c->setValue("ERR:NOT_STARTED");
      }
    } else if (cmd == "STATUS") {
      char resp[64];
      snprintf(resp, sizeof(resp),
        "{\"session\":%s,\"bat\":%d,\"hr\":%.0f,\"sat\":%d}",
        sessionActive ? "true" : "false",
        batteryPercent(readBatteryVoltage()),
        hrSensorPresent ? readMAX30102HR() : readSimulatedHR(),
        gps.satellites.isValid() ? gps.satellites.value() : 0
      );
      c->setValue(resp);
    } else if (cmd == "PING") {
      c->setValue("PONG v" FIRMWARE_VERSION);
    } else {
      c->setValue("ERR:UNKNOWN");
    }
    c->notify();
  }
};

// ── BLE server callbacks ───────────────────────────────
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

// ── Setup ──────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.printf("\nSendex ESP32 %s starting...\n", FIRMWARE_VERSION);

  // Pins
  pinMode(BTN_PIN, INPUT_PULLUP);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, LOW);

  // I2C for MAX30102
  Wire.begin(I2C_SDA, I2C_SCL);
  hrSensorPresent = initMAX30102();
  Serial.printf("MAX30102: %s\n", hrSensorPresent ? "detected" : "not found (simulated)");

  // GPS
  gpsSerial.begin(9600);
  Serial.println("GPS serial started on pins 16/17");

  // Battery
  analogReadResolution(12);
  float vbat = readBatteryVoltage();
  Serial.printf("Battery: %.2fV (%d%%)\n", vbat, batteryPercent(vbat));

  // NVS cache
  prefs.begin("sendex", false);
  cacheIndex = prefs.getInt("count", 0);
  if (cacheIndex > 0) Serial.printf("NVS cache: %d points pending\n", cacheIndex);

  // BLE
  BLEDevice::init(DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  // Data service (FFF0)
  BLEService *dataService = server->createService(SERVICE_UUID);

  pDataChar = dataService->createCharacteristic(
    CHAR_DATA_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pDataChar->addDescriptor(new BLE2902());

  pCmdChar = dataService->createCharacteristic(
    CHAR_CMD_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCmdChar->addDescriptor(new BLE2902());
  pCmdChar->setCallbacks(new CmdCallbacks());

  dataService->start();

  // Battery service (180F)
  BLEService *battService = server->createService(BATTERY_SERVICE_UUID);
  pBattChar = battService->createCharacteristic(
    BATTERY_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pBattChar->addDescriptor(new BLE2902());
  pBattChar->setValue((uint8_t)batteryPercent(vbat));
  battService->start();

  // Advertising
  BLEAdvertising *adv = server->getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  adv->setMaxPreferred(0x12);
  adv->start();

  Serial.printf("BLE advertising as '%s'\n", DEVICE_NAME);
  Serial.println("Hold button 3s or send BLE commands: START, STOP, STATUS, PING");
}

// ── Loop ───────────────────────────────────────────────
void loop() {
  handleButton();

  // Read GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // LED feedback for GPS fix
  if (gps.location.isValid() && gps.satellites.value() >= 3) {
    lastGpsFixMs = millis();
  }
  bool hasFix = (millis() - lastGpsFixMs) < 10000;
  if (hasFix && !sessionActive) {
    digitalWrite(LED_GREEN, (millis() / 1000) % 2 == 0 ? LOW : HIGH);
  }
  if (!hasFix && !sessionActive) {
    digitalWrite(LED_GREEN, (millis() / 500) % 2 == 0 ? LOW : HIGH);
  }

  // Notify data every 1s if session active
  if (sessionActive && millis() - lastNotifyTime >= NOTIFY_INTERVAL) {
    lastNotifyTime = millis();

    float speed = gps.speed.isValid() ? gps.speed.kmph() : 0.0;
    double lat = gps.location.isValid() ? gps.location.lat() : 0.0;
    double lng = gps.location.isValid() ? gps.location.lng() : 0.0;
    float altitude = gps.altitude.isValid() ? gps.altitude.meters() : 0.0;
    int satellites = gps.satellites.isValid() ? gps.satellites.value() : 0;
    float hdop = gps.hdop.isValid() ? gps.hdop.hdop() : 99.9;
    float heartRate = hrSensorPresent ? readMAX30102HR() : readSimulatedHR();
    float batteryVoltage = readBatteryVoltage();
    uint8_t batteryPct = batteryPercent(batteryVoltage);

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
      "\"bat\":%d"
      "}",
      FIRMWARE_VERSION,
      lat, lng, speed, altitude, heartRate, satellites, hdop, batteryPct
    );

    if (deviceConnected) {
      pDataChar->setValue(json);
      pDataChar->notify();
    } else {
      cachePoint(json);
    }
    Serial.println(json);
  }

  // Battery notification every 60s
  if (deviceConnected && millis() - lastBattNotify >= BATT_NOTIFY_INTERVAL) {
    lastBattNotify = millis();
    uint8_t pct = batteryPercent(readBatteryVoltage());
    pBattChar->setValue(&pct, 1);
    pBattChar->notify();
  }

  // Watchdog: if GPS stuck > 30s and session active, reset
  if (sessionActive && millis() - lastGpsFixMs > 30000 && gps.location.isValid()) {
    // GPS was valid but now stuck — soft reset GPS
    gpsSerial.end();
    delay(100);
    gpsSerial.begin(9600);
    gps = TinyGPSPlus();
    lastGpsFixMs = millis();
    Serial.println("GPS watchdog: reset GPS");
  }
}
