#include <TinyGPSPlus.h>
#include <SD.h>
#include <SoftwareSerial.h>

const int chipSelect = 10;
const int buttonPin = 7; // Pin for the push button
const int ledPin = 8;    // Pin for the green LED
bool isLogging = false;  // Variable to keep track of logging state
File myFile;

SoftwareSerial ss(4, 3);
TinyGPSPlus gps;

void setup() {
  pinMode(buttonPin, INPUT_PULLUP); // Button setup with internal pull-up resistor
  pinMode(ledPin, OUTPUT);          // LED setup

  Serial.begin(9600);
  ss.begin(9600);
  Serial.println("GPS Module Initialized");

  while (!Serial);
  Serial.print("Initializing SD card...");
  if (!SD.begin(chipSelect)) {
    Serial.println("Initialization failed. Things to check:");
    Serial.println("1. Is a card inserted?");
    Serial.println("2. Is your wiring correct?");
    Serial.println("3. Did you change the chipSelect pin to match your shield or module?");
    Serial.println("Note: press reset button on the board and reopen this serial monitor after fixing your issue!");
    while (1);
  }
  Serial.println("Initialization done.");

  if (SD.exists("gps.txt")) {
    Serial.println("gps.txt exists.");
  } else {
    Serial.println("gps.txt doesn't exist. Creating gps.txt...");
    myFile = SD.open("gps.txt", FILE_WRITE);
    myFile.close();
  }
}

void loop() {
  static unsigned long lastButtonPress = 0;
  unsigned long currentTime = millis();

  // Check if the button is pressed (debouncing included)
  if (digitalRead(buttonPin) == LOW && currentTime - lastButtonPress > 200) {
    isLogging = !isLogging;  // Toggle logging state
    lastButtonPress = currentTime;
    Serial.print("Logging ");
    Serial.println(isLogging ? "started" : "stopped");
  }

  // If logging is enabled, check for GPS data
  if (isLogging && ss.available() > 0) {
    gps.encode(ss.read());
    if (gps.location.isUpdated()) {
      double latitude = gps.location.lat();
      double longitude = gps.location.lng();
      double speed = gps.speed.kmph(); // Speed in km/h

      Serial.print("Latitude: ");
      Serial.print(latitude, 6); // Print latitude with 6 decimal places
      Serial.print(" Longitude: ");
      Serial.print(longitude, 6); // Print longitude with 6 decimal places
      Serial.print(" Speed: ");
      Serial.print(speed); // Print speed in km/h
      Serial.println(" km/h");

      // Blink the LED when writing to file
      digitalWrite(ledPin, HIGH);  // Turn LED on
      delay(100);                  // Short blink
      digitalWrite(ledPin, LOW);   // Turn LED off

      // Write GPS data to the file
      myFile = SD.open("gps.txt", FILE_WRITE);
      if (myFile) {
        myFile.print("Latitude: ");
        myFile.print(latitude, 6);
        myFile.print(", Longitude: ");
        myFile.print(longitude, 6);
        myFile.print(", Speed: ");
        myFile.print(speed);
        myFile.println(" km/h");
        myFile.close();
      } else {
        Serial.println("Error opening gps.txt for writing.");
      }
    }
  } else if (!isLogging) {
    digitalWrite(ledPin, HIGH); // Keep LED steady on when not logging
  }
}
