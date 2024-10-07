#include <TinyGPSPlus.h>
#include <SoftwareSerial.h>

SoftwareSerial ss(4, 3); // RX, TX for GPS
TinyGPSPlus gps;

// The serial connection to the Bluetooth HC-06 module
SoftwareSerial btSerial(7, 8); // RX, TX for Bluetooth

double prevLat = 0.0, prevLng = 0.0; // Previous location coordinates
double totalDistance = 0.0; // Total distance traveled

void setup() {
  Serial.begin(9600);       // Start the serial monitor
  ss.begin(9600);           // Start the GPS module
  btSerial.begin(9600);     // Start the Bluetooth module
  
  Serial.println("GPS Module Initialized");
  Serial.println("Bluetooth Module Initialized");
}

void loop() {
  // Parse the GPS data
  while (ss.available() > 0) {
    gps.encode(ss.read());
    
    if (gps.location.isUpdated()) {
      // Display Latitude and Longitude on the Serial Monitor
      Serial.print("Latitude: ");
      Serial.println(gps.location.lat(), 6);
      Serial.print("Longitude: ");
      Serial.println(gps.location.lng(), 6);
      
      // Send Latitude and Longitude to the Bluetooth App
      btSerial.print("Lat: ");
      btSerial.println(gps.location.lat(), 6);
      btSerial.print("Lng: ");
      btSerial.println(gps.location.lng(), 6);
      
      // Display Date on the Serial Monitor
      Serial.print("Date: ");
      Serial.print(gps.date.month());
      Serial.print("/");
      Serial.print(gps.date.day());
      Serial.print("/");
      Serial.println(gps.date.year());
      
      // Send Date to the Bluetooth App
      btSerial.print("Date: ");
      btSerial.print(gps.date.month());
      btSerial.print("/");
      btSerial.print(gps.date.day());
      btSerial.print("/");
      btSerial.println(gps.date.year());

      // Display Time in UTC on the Serial Monitor
      Serial.print("Time (UTC): ");
      if (gps.time.hour() < 10) Serial.print(F("0"));
      Serial.print(gps.time.hour());
      Serial.print(":");
      if (gps.time.minute() < 10) Serial.print(F("0"));
      Serial.print(gps.time.minute());
      Serial.print(":");
      if (gps.time.second() < 10) Serial.print(F("0"));
      Serial.println(gps.time.second());

      // Send Time to the Bluetooth App
      btSerial.print("Time (UTC): ");
      if (gps.time.hour() < 10) btSerial.print(F("0"));
      btSerial.print(gps.time.hour());
      btSerial.print(":");
      if (gps.time.minute() < 10) btSerial.print(F("0"));
      btSerial.print(gps.time.minute());
      btSerial.print(":");
      if (gps.time.second() < 10) btSerial.print(F("0"));
      btSerial.println(gps.time.second());

      // Display Speed (km/h) on the Serial Monitor
      Serial.print("Speed (km/h): ");
      Serial.println(gps.speed.kmph());

      // Send Speed to the Bluetooth App
      btSerial.print("Speed (km/h): ");
      btSerial.println(gps.speed.kmph());

      // Calculate distance traveled since last update
      if (prevLat != 0.0 && prevLng != 0.0) {
        double distance = TinyGPSPlus::distanceBetween(
          prevLat, prevLng,
          gps.location.lat(), gps.location.lng()
        );
        totalDistance += distance;
        
        Serial.print("Distance from last point (m): ");
        Serial.println(distance);

        // Send Distance to the Bluetooth App
        btSerial.print("Distance from last point (m): ");
        btSerial.println(distance);
      }

      // Update previous coordinates
      prevLat = gps.location.lat();
      prevLng = gps.location.lng();
      
      // Display total distance on the Serial Monitor
      Serial.print("Total Distance Traveled (m): ");
      Serial.println(totalDistance);

      // Send total distance to the Bluetooth App
      btSerial.print("Total Distance Traveled (m): ");
      btSerial.println(totalDistance);
      
      Serial.println(); // Blank line for readability
      btSerial.println(); // Blank line for readability in the app
    }
  }
}
