#include <SoftwareSerial.h>
#include <TinyGPS++.h>

// The serial connection to the GPS module
SoftwareSerial ss(3, 4); // RX, TX
TinyGPSPlus gps;

double prevLat = 0.0, prevLng = 0.0; // Previous location coordinates
double totalDistance = 0.0; // Total distance traveled

void setup() {
  Serial.begin(9600);
  ss.begin(9600);
  Serial.println("GPS Module Initialized");
}

void loop() {
  // Parse the GPS data
  while (ss.available() > 0) {
    gps.encode(ss.read());
    
    if (gps.location.isUpdated()) {
      // Display Latitude and Longitude
      Serial.print("Latitude: ");
      Serial.println(gps.location.lat(), 6);
      Serial.print("Longitude: ");
      Serial.println(gps.location.lng(), 6);
      
      // Display Date
      Serial.print("Date: ");
      Serial.print(gps.date.month());
      Serial.print("/");
      Serial.print(gps.date.day());
      Serial.print("/");
      Serial.println(gps.date.year());

      // Display Time in UTC
      Serial.print("Time (UTC): ");
      if (gps.time.hour() < 10) Serial.print(F("0"));
      Serial.print(gps.time.hour());
      Serial.print(":");
      if (gps.time.minute() < 10) Serial.print(F("0"));
      Serial.print(gps.time.minute());
      Serial.print(":");
      if (gps.time.second() < 10) Serial.print(F("0"));
      Serial.println(gps.time.second());

      // Calculate speed (km/h)
      Serial.print("Speed (km/h): ");
      Serial.println(gps.speed.kmph());

      // Calculate distance traveled since last update
      if (prevLat != 0.0 && prevLng != 0.0) {
        double distance = TinyGPSPlus::distanceBetween(
          prevLat, prevLng,
          gps.location.lat(), gps.location.lng()
        );
        totalDistance += distance;
        
        Serial.print("Distance from last point (m): ");
        Serial.println(distance);
      }

      // Update previous coordinates
      prevLat = gps.location.lat();
      prevLng = gps.location.lng();
      
      // Display total distance
      Serial.print("Total Distance Traveled (m): ");
      Serial.println(totalDistance);
      
      Serial.println(); // Blank line for readability
    }
  }
}
