#include <avr/sleep.h>
#include <avr/interrupt.h>

// Pin Definitions
const int buttonPin = 2;      // Push button pin (must be an interrupt-capable pin)
const int redLedPin = 8;      // Red LED (optional for sleep mode indication)

// Time Constants
const unsigned long sleepDelay = 3000; // 3 seconds (3000 milliseconds)
unsigned long buttonPressTime = 0;     // Stores the time when button is pressed
bool isSleeping = false;               // Flag to track if the system is in sleep mode

void setup() {
  pinMode(buttonPin, INPUT_PULLUP); // Configure button pin as input with internal pull-up
  pinMode(redLedPin, OUTPUT);       // Configure LED pin as output

  Serial.begin(9600);

  // Attach an interrupt to wake up when the button is pressed
  attachInterrupt(digitalPinToInterrupt(buttonPin), wakeUp, FALLING);
}

void loop() {
  if (!isSleeping) {
    // Check if the button is pressed (LOW state due to pull-up)
    if (digitalRead(buttonPin) == LOW) {
      if (buttonPressTime == 0) {
        // Start timing the button press
        buttonPressTime = millis();
      } else if (millis() - buttonPressTime >= sleepDelay) {
        // Button held for 3 seconds, enter sleep mode
        Serial.println("Entering sleep mode...");
        enterSleepMode();
      }
    } else {
      // Reset button press time if the button is released
      buttonPressTime = 0;
    }
  }

  delay(100); // Small delay to prevent bouncing issues
}

void enterSleepMode() {
  // Turn off any LEDs or peripherals if necessary
  digitalWrite(redLedPin, HIGH); // Optional: Turn on the red LED to indicate sleep mode

  // Set flag to indicate the system is sleeping
  isSleeping = true;

  // Put the microcontroller into sleep mode
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // Use the lowest power sleep mode
  sleep_enable();
  sleep_mode(); // The microcontroller will enter sleep here

  // After waking up, the code continues from here
  sleep_disable();  // Disable sleep mode after waking up
  digitalWrite(redLedPin, LOW); // Turn off the sleep mode indication LED

  Serial.println("Waking up from sleep mode.");
}

void wakeUp() {
  // This function is called when the interrupt is triggered (button press)
  // Wake up the microcontroller from sleep mode
  if (isSleeping) {
    // Reset the sleep flag
    isSleeping = false;

    // Additional wake-up logic can be added here
    Serial.println("System has exited sleep mode.");
  }
}
