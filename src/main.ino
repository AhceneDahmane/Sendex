 
#include <SoftwareSerial.h>
#include <TinyGPS++.h>
#include <SD.h>

// The serial connection to the GPS module
SoftwareSerial ss(3, 4); // RX, TX
TinyGPSPlus gps;

const int CS_PIN = 10;  // Chip Select pin for SD card module
const int BUTTON_PIN = 7;  // Pin for push button
const int BLUE_LED_PIN = 9;  // Pin for blue LED
const int GREEN_LED_PIN = 8;  // Pin for green LED

double prevLat = 0.0, prevLng = 0.0;  // Previous location coordinates
double totalDistance = 0.0;  // Total distance traveled
File dataFile;

bool isLogging = false;  // Flag to track logging status
unsigned long buttonPressTime = 0;  // Time when button was pressed

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

  // Setup button and LED pins
  pinMode(BUTTON_PIN, INPUT_PULLUP);  // Pull-up resistor to avoid floating state
  pinMode(BLUE_LED_PIN, OUTPUT);
  pinMode(GREEN_LED_PIN, OUTPUT);

  // Initially, the green LED is ON, indicating logging is not active
  digitalWrite(GREEN_LED_PIN, HIGH);
  digitalWrite(BLUE_LED_PIN, LOW);
}

void loop() {
  // Handle button press for start/stop logging
  handleButton();

  // If logging is active, continue logging GPS data
  if (isLogging) {
    logGPSData();
  }
}

void handleButton() {
  int buttonState = digitalRead(BUTTON_PIN);

  if (buttonState == LOW) {  // Button is pressed
    if (buttonPressTime == 0) {
      buttonPressTime = millis();  // Record the time when button was first pressed
    }

    // If button is held for more than 3 seconds
    if (millis() - buttonPressTime >= 3000) {
      if (isLogging) {
        stopLogging();
      } else {
        startLogging();
      }
      buttonPressTime = 0;  // Reset button press time
      delay(500);  // Debounce delay
    }
  } else {
    buttonPressTime = 0;  // Reset if button is released
  }
}

void startLogging() {
  isLogging = true;
  totalDistance = 0.0;  // Reset total distance for new session
  prevLat = 0.0;
  prevLng = 0.0;

  // Open file to log data
  dataFile = SD.open("gps_data.txt", FILE_WRITE);
  if (dataFile) {
    dataFile.println("GPS Log: Latitude, Longitude, Date, Time (UTC), Speed (km/h), Distance (m), Total Distance (m)");
    dataFile.close();
  } else {
    Serial.println("Error opening file!");
  }

  Serial.println("Logging started...");

  // Set LED status: blue blinking to indicate logging
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(BLUE_LED_PIN, HIGH);
}

void stopLogging() {
  isLogging = false;

  Serial.println("Logging stopped.");

  // Set LED status: green solid to indicate logging is stopped
  digitalWrite(GREEN_LED_PIN, HIGH);
  digitalWrite(BLUE_LED_PIN, LOW);
}

void logGPSData() {
  // Blink blue LED when logging
  static unsigned long prevBlinkTime = 0;
  if (millis() - prevBlinkTime >= 500) {  // Blink every 500ms
    digitalWrite(BLUE_LED_PIN, !digitalRead(BLUE_LED_PIN));
    prevBlinkTime = millis();
  }

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

        dataFile.close();  // Close the file
      } else {
        Serial.println("Error writing to file!");
      }

      // Update previous coordinates
      prevLat = gps.location.lat();
      prevLng = gps.location.lng();
    }
  }
}
