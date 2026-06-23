#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID        "FFF0"
#define CHARACTERISTIC_UUID "FFF1"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
unsigned long lastUpdate = 0;

double lat = 48.856600;
double lng = 2.352200;
double speed = 0.0;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer* pServer) { deviceConnected = false; }
};

void setup() {
  Serial.begin(115200);

  BLEDevice::init("Sendex-ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );

  pService->start();
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->start();
  Serial.println("BLE ready. Connect with Sendex app.");
}

void loop() {
  if (!deviceConnected) return;
  if (millis() - lastUpdate < 1000) return;
  lastUpdate = millis();

  speed = random(0, 30) / 10.0;
  lat += (random(-100, 100) / 1000000.0);
  lng += (random(-100, 100) / 1000000.0);

  char json[128];
  snprintf(json, sizeof(json),
    "{\"lat\":%.6f,\"lng\":%.6f,\"speed\":%.1f}", lat, lng, speed);

  pCharacteristic->setValue(json);
  pCharacteristic->notify();
  Serial.println(json);
}
