#include <SoftwareSerial.h>
#include <TinyGPS++.h>

SoftwareSerial sim800(2, 3); // RX, TX for SIM800L
SoftwareSerial gpsSerial(4, 5); // RX, TX for Neo-6M GPS
TinyGPSPlus gps;

void setup() {
  Serial.begin(9600);       // Debugging serial
  sim800.begin(9600);       // SIM800L baud rate
  gpsSerial.begin(9600);    // Neo-6M GPS baud rate

  Serial.println("Initializing...");
  delay(2000);

  // Test SIM800L communication
  sim800.println("AT");
  delay(1000);
  showSIM800Response();
}

void loop() {
  String location = "";

  // Attempt to get GPS data
  bool gpsAvailable = false;
  for (unsigned long start = millis(); millis() - start < 10000;) {
    while (gpsSerial.available() > 0) {
      gps.encode(gpsSerial.read());
      if (gps.location.isUpdated()) {
        gpsAvailable = true;
        location = "GPS Location: " + String(gps.location.lat(), 6) + "," + String(gps.location.lng(), 6);
        break;
      }
    }
    if (gpsAvailable) break;
  }

  if (!gpsAvailable) {
    // GPS not available, fallback to SIM800L location
    sim800.println("AT+CIPGSMLOC=1,1");
    delay(5000);
    location = getSIM800Location();
  }

  if (location.length() > 0) {
    sendSMS("1234567890", location); // Replace with your phone number
  }

  delay(60000); // Wait 1 minute before trying again
}

void sendSMS(String number, String text) {
  sim800.println("AT+CMGF=1"); // Set SMS to text mode
  delay(1000);

  sim800.print("AT+CMGS=\"");
  sim800.print(number);
  sim800.println("\"");
  delay(100
