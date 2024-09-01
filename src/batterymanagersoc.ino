#include <avr/sleep.h>
#include <avr/wdt.h>

// Pin Definitions
const int batteryPin = A0;  // Analog pin for battery voltage monitoring
const int tempPin = A1;     // Analog pin for temperature monitoring (thermistor)
const int redLedPin = 8;    // Red LED
const int orangeLedPin = 9; // Orange LED
const int greenLedPin = 10; // Green LED
const int chargerPin = 7;   // Pin to detect if charger is plugged in

// Voltage Divider Constants
const float R1 = 10000.0;   // Resistor R1 (ohms)
const float R2 = 10000.0;   // Resistor R2 (ohms)
const float referenceVoltage = 5.0; // Reference voltage for ADC (typically 5V or 3.3V)

// Battery Management Constants
const float shutdownVoltage = 3.0;  // Critical voltage for safe shutdown
const float maxChargeVoltage = 4.2; // Maximum charge voltage for LiPo
const float maxTemp = 60.0;         // Maximum safe temperature in Celsius

bool isCharging = false;    // Flag to indicate charging status

void setup() {
  pinMode(redLedPin, OUTPUT);
  pinMode(orangeLedPin, OUTPUT);
  pinMode(greenLedPin, OUTPUT);
  pinMode(chargerPin, INPUT);

  Serial.begin(9600);

  // Attach an interrupt to wake up when the charger is plugged in (rising edge)
  attachInterrupt(digitalPinToInterrupt(chargerPin), wakeUp, RISING);
}

void loop() {
  // Read the battery voltage
  int analogValue = analogRead(batteryPin);
  float batteryVoltage = (analogValue / 1023.0) * referenceVoltage * ((R1 + R2) / R2);
  
  // Estimate SoC (State of Charge) based on voltage
  int soc = estimateSoC(batteryVoltage);

  // Monitor temperature
  float batteryTemp = readTemperature();

  // Display battery status
  Serial.print("Battery Voltage: ");
  Serial.print(batteryVoltage);
  Serial.print("V, SoC: ");
  Serial.print(soc);
  Serial.print("%, Temperature: ");
  Serial.print(batteryTemp);
  Serial.println("°C");

  // Check if battery voltage is below the safe threshold
  if (batteryVoltage <= shutdownVoltage) {
    Serial.println("Battery voltage critical! Shutting down...");
    safeShutdown();
  }

  // Check if battery voltage is above the maximum charge voltage (overcharge protection)
  if (batteryVoltage >= maxChargeVoltage) {
    Serial.println("Battery voltage high! Stopping charge...");
    stopCharging();
  }

  // Check if battery temperature exceeds safe limit
  if (batteryTemp >= maxTemp) {
    Serial.println("Battery temperature high! Stopping charge...");
    stopCharging();
    safeShutdown();
  }

  // Manage LEDs based on SoC
  if (soc > 0 && soc <10) {
    setLEDs(HIGH, LOW, LOW); // Red LED on, others off
  } else if (soc > 10 && soc < 20) {
    setLEDs(LOW, HIGH, LOW); // Orange LED on, others off
  } else {
    setLEDs(LOW, LOW, HIGH); // Green LED on, others off
  }

  // Check if charger is plugged in
  if (digitalRead(chargerPin) == HIGH) {
    Serial.println("Charger plugged in.");
    isCharging = true;
    handleChargingStatus(soc);
  } else {
    Serial.println("Charger not plugged in.");
    isCharging = false;
  }

  delay(1000); // Delay for readability
}

// Function to estimate SoC based on voltage (simplified for example purposes)
int estimateSoC(float voltage) {
  // Assume 4.2V is 100% and 3.0V is 0%
  if (voltage >= 4.2) return 100;
  if (voltage <= 3.0) return 0;
  return (int)((voltage - 3.0) / (4.2 - 3.0) * 100);
}

// Function to set LEDs
void setLEDs(int redState, int orangeState, int greenState) {
  digitalWrite(redLedPin, redState);
  digitalWrite(orangeLedPin, orangeState);
  digitalWrite(greenLedPin, greenState);
}

// Function to handle charging status with LED indication
void handleChargingStatus(int soc) {
  if (soc < 100) {
    unsigned long currentMillis = millis();
    // Blink the green LED while charging
    static bool ledState = LOW;
    if (currentMillis % 500 == 0) {
      ledState = !ledState;
      digitalWrite(greenLedPin, ledState);
    }
  } else {
    // Solid green LED when fully charged
    digitalWrite(greenLedPin, HIGH);
  }
}

// Function to safely shut down the system
void safeShutdown() {
  // Turn off all LEDs
  setLEDs(LOW, LOW, LOW);

  // Put the microcontroller into sleep mode
  Serial.println("Entering sleep mode...");
  set_sleep_mode(SLEEP_MODE_PWR_DOWN);
  sleep_enable();
  sleep_mode();

  // After waking up, the code continues from here
  sleep_disable(); // Disable sleep
  Serial.println("Waking up from sleep mode.");
}

// Function to stop charging (disconnect charger or disable charging circuit)
void stopCharging() {
  // Implement this based on your charger circuit
  // Example: Disable a MOSFET that controls charging
}

// Function to read battery temperature using a thermistor
float readTemperature() {
  int analogValue = analogRead(tempPin);
  float voltage = analogValue * (referenceVoltage / 1023.0);
  // Convert voltage to temperature (simple thermistor calculation)
  float temperature = (voltage - 0.5) * 100.0; // Assuming a TMP36 sensor, adjust for your sensor
  return temperature;
}

// Interrupt service routine (ISR) to wake up from sleep mode
void wakeUp() {
  // This function will be called when the charger is plugged in, waking the MCU
  Serial.println("Wake-up triggered.");
}
