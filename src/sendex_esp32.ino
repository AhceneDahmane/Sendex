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

// ── Pins ───────────────────────────────────────────────
#define GPS_RX_PIN  16
#define GPS_TX_PIN  17
#define BTN_PIN     7
#define LED_GREEN   8
#define LED_BLUE    9
#define BAT_ADC     35

// ── BLE ────────────────────────────────────────────────
#define SERVICE_UUID        "FFF0"
#define CHAR_UUID           "FFF1"
#define BATTERY_SERVICE_UUID "180F"
#define BATTERY_CHAR_UUID    "2A19"

// ── GPS ────────────────────────────────────────────────
TinyGPSPlus gps;
SoftwareSerial gpsSerial(GPS_RX_PIN, GPS_TX_PIN);

// ── BLE objects ────────────────────────────────────────
BLECharacteristic *pDataChar = nullptr;
BLECharacteristic *pBattChar = nullptr;
bool deviceConnected = false;

// ── State ──────────────────────────────────────────────
bool sessionActive = false;
unsigned long lastNotifyTime = 0;
unsigned long lastBattNotify = 0;
unsigned long sessionStartMs = 0;

// ── Battery ────────────────────────────────────────────
float readBatteryVoltage() {
  int raw = analogRead(BAT_ADC);
  float voltage = (raw / 4095.0) * 3.3 * 2;  // voltage divider ~1/2
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

// ── Heart rate simulation (MAX30102 integration placeholder) ──
float readHeartRate() {
  // TODO: replace with actual MAX30102 library calls
  // For now returns a simulated realistic value
  static float hr = 72.0;
  hr += (random(-5, 6)) / 10.0;
  if (hr < 55) hr = 55;
  if (hr > 180) hr = 180;
  return hr;
}

// ── Button handler ─────────────────────────────────────
void handleButton() {
  static unsigned long pressStart = 0;
  static bool wasPressed = false;
  bool pressed = digitalRead(BTN_PIN) == LOW;

  if (pressed && !wasPressed) {
    pressStart = millis();
  }
  if (pressed && wasPressed && millis() - pressStart >= 3000) {
    sessionActive = !sessionActive;
    digitalWrite(LED_GREEN, sessionActive ? LOW : HIGH);
    digitalWrite(LED_BLUE, sessionActive ? HIGH : LOW);

    if (sessionActive) {
      sessionStartMs = millis();
      Serial.println("Session STARTED");
    } else {
      Serial.println("Session STOPPED");
    }
    pressStart = millis();  // prevent retrigger
  }
  wasPressed = pressed;
}

// ── BLE callbacks ──────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) {
    deviceConnected = true;
    Serial.println("Client connected");
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
  Serial.println("\nSendex ESP32 starting...");

  // Pins
  pinMode(BTN_PIN, INPUT_PULLUP);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_BLUE, LOW);

  // GPS
  gpsSerial.begin(9600);
  Serial.println("GPS serial started on pins 16/17");

  // Battery
  analogReadResolution(12);
  float vbat = readBatteryVoltage();
  Serial.printf("Battery: %.2fV (%d%%)\n", vbat, batteryPercent(vbat));

  // BLE
  BLEDevice::init("Sendex-Vest");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  // Data service
  BLEService *dataService = server->createService(SERVICE_UUID);
  pDataChar = dataService->createCharacteristic(
    CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pDataChar->addDescriptor(new BLE2902());
  dataService->start();

  // Battery service
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

  Serial.println("BLE advertising as 'Sendex-Vest'");
  Serial.println("Hold button 3s to start/stop session");
}

// ── Loop ───────────────────────────────────────────────
void loop() {
  handleButton();

  // Read GPS
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }

  // Notify data every 1s if connected and session active
  if (deviceConnected && sessionActive && millis() - lastNotifyTime >= 1000) {
    lastNotifyTime = millis();

    float speed = gps.speed.isValid() ? gps.speed.kmph() : 0.0;
    double lat = gps.location.isValid() ? gps.location.lat() : 0.0;
    double lng = gps.location.isValid() ? gps.location.lng() : 0.0;
    float altitude = gps.altitude.isValid() ? gps.altitude.meters() : 0.0;
    int satellites = gps.satellites.isValid() ? gps.satellites.value() : 0;
    float hdop = gps.hdop.isValid() ? gps.hdop.hdop() : 99.9;
    float heartRate = readHeartRate();
    float batteryVoltage = readBatteryVoltage();
    uint8_t batteryPct = batteryPercent(batteryVoltage);

    char json[256];
    snprintf(json, sizeof(json),
      "{"
      "\"lat\":%.6f,"
      "\"lng\":%.6f,"
      "\"speed\":%.1f,"
      "\"alt\":%.1f,"
      "\"hr\":%.0f,"
      "\"sat\":%d,"
      "\"hdop\":%.1f,"
      "\"bat\":%d"
      "}",
      lat, lng, speed, altitude, heartRate, satellites, hdop, batteryPct
    );

    pDataChar->setValue(json);
    pDataChar->notify();
    Serial.println(json);
  }

  // Battery notification every 60s
  if (deviceConnected && millis() - lastBattNotify >= 60000) {
    lastBattNotify = millis();
    uint8_t pct = batteryPercent(readBatteryVoltage());
    pBattChar->setValue(&pct, 1);
    pBattChar->notify();
  }
}
