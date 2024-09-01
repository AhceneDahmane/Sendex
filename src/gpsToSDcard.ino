#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include <SD.h>

// The serial connection to the GPS module
SoftwareSerial ss(3, 4); // RX, TX
TinyGPSPlus gps;

const int CS_PIN = 10; // Chip Select pin for SD card module

double prevLat = 0.0, prevLng = 0.0; // Previous location coordinates
double totalDistance = 0.0; // Total distance traveled
File dataFile;

void setup() {
  Serial.begin(9600);
  ss.begin(9600);
  Serial.println("GPS Module Initialized");

  // Initialize SD card
  if (!SD.begin(CS_PIN)) {
    Serial.println("SD Card initialization failed!");
    return;
  }
  Serial.println("SD Card initialized.");

  // Open file to log data
  dataFile = SD.open("gps_data.txt", FILE_WRITE);
  if (dataFile) {
    dataFile.println("GPS Log: Latitude, Longitude, Date, Time (UTC), Speed (km/h), Distance (m), Total Distance (m)");
    dataFile.close();
  } else {
    Serial.println("Error opening file!");
  }
}

void loop() {
  // Parse the GPS data
  while (ss.available() > 0) {
    gps.encode(ss.read());
    
    if (gps.location.isUpdated()) {
      // Calculate distance traveled since last update
      double distance = 0.0;
      if (prevLat != 0.0 && prevLng != 0.0) {
        distance = TinyGPSPlus::distanceBetween(
          prevLat, prevLng,
          gps.location.lat(), gps.location.lng()
        );
        totalDistance += distance;
      }

      // Open file for appending data
      dataFile = SD.open("gps_data.txt", FILE_WRITE);
      if (dataFile) {
        // Write data to file
        dataFile.print(gps.location.lat(), 6);
        dataFile.print(", ");
        dataFile.print(gps.location.lng(), 6);
        dataFile.print(", ");
        dataFile.print(gps.date.month());
        dataFile.print("/");
        dataFile.print(gps.date.day());
        dataFile.print("/");
        dataFile.print(gps.date.year());
        dataFile.print(", ");
        if (gps.time.hour() < 10) dataFile.print(F("0"));
        dataFile.print(gps.time.hour());
        dataFile.print(":");
        if (gps.time.minute() < 10) dataFile.print(F("0"));
        dataFile.print(gps.time.minute());
        dataFile.print(":");
        if (gps.time.second() < 10) dataFile.print(F("0"));
        dataFile.print(gps.time.second());
        dataFile.print(", ");
        dataFile.print(gps.speed.kmph());
        dataFile.print(", ");
        dataFile.print(distance);
        dataFile.print(", ");
        dataFile.println(totalDistance);

        dataFile.close(); // Close the file
      } else {
        Serial.println("Error writing to file!");
      }

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

      // Display speed (km/h)
      Serial.print("Speed (km/h): ");
      Serial.println(gps.speed.kmph());

      // Display distance from last point and total distance
      Serial.print("Distance from last point (m): ");
      Serial.println(distance);
      Serial.print("Total Distance Traveled (m): ");
      Serial.println(totalDistance);
      
      Serial.println(); // Blank line for readability

      // Update previous coordinates
      prevLat = gps.location.lat();
      prevLng = gps.location.lng();
    }
  }
}
