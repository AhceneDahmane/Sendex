#include <SoftwareSerial.h> 
SoftwareSerial bluetooth(1, 0); // RX, TX
void setup() {
  bluetooth.begin(9600); 
  delay(200);
  bluetooth.print("AT+sendex.com"); // configure the bluetooth name
  delay(3000);
}
void loop() {
  if (bluetooth.available()) { // check if anything in UART buffer
    bluetooth.write(bluetooth.read()); // if so, echo it back!
  }
}
