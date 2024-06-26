#include <Wire.h>
#include <WiFiManager.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <TimeLib.h>

#define SIM800L_TX 17
#define SIM800L_RX 16

String storedPhoneNumber = "+918075608422";
bool messageSentAt6AM = false;
bool messageSentAt6PM = false;

// Define NTP Client to get time
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 0, 60000);

void setup() {
  Serial.begin(9600); // Serial for debugging
  Serial2.begin(9600, SERIAL_8N1, SIM800L_RX, SIM800L_TX); // Serial for SIM800L
  delay(2000);
  
  WiFiManager wifiManager;
  wifiManager.autoConnect("ESP32_ConfigPortal", "password");
  
  Serial.println("Connected to WiFi!");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");
  delay(1000);

  timeClient.begin();

  // Ensure we start with a clean buffer
  clearSerialBuffer();
}

void loop() {
  float temperature = 30;
  float humidity = 50;
  float pressure = 1008;
  float alt = 108;
  float rainfall = 0;
  float wind = 5.6;

  timeClient.update();

  // Get current time
  unsigned long epochTime = timeClient.getEpochTime();
  setTime(epochTime);
  Serial.print(hour());
  Serial.print(":");
  Serial.println(minute());

  // Send SMS at 6 AM
  if (hour() == 10 && minute() == 44 && !messageSentAt6AM) {
    send_SMS(temperature, humidity, wind, rainfall, pressure, alt);
    messageSentAt6AM = true;
  }
  
  // Reset flag at 6:01 AM
  if (hour() == 10 && minute() == 45) {
    messageSentAt6AM = false;
  }

  // Send SMS at 6 PM
  if (hour() == 10 && minute() == 46 && !messageSentAt6PM) {
    send_SMS(temperature, humidity, wind, rainfall, pressure, alt);
    messageSentAt6PM = true;
  }
  
  // Reset flag at 6:01 PM
  if (hour() == 10 && minute() == 47) {
    messageSentAt6PM = false;
  }

  // Check for incoming SMS messages
  checkForIncomingSMS( temperature,  humidity,  wind,  rainfall,  pressure,  alt);
  
  delay(1000); // Delay to prevent spamming the loop
}

void send_SMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt) {
  String message = "Humidity: " + String(humidity) + " %\n";
  message += "Rainfall: " + String(rainfall) + " mm\n";
  message += "Wind Speed: " + String(wind) + " m/s\n";
  message += "Temperature: " + String(temperature) + " *C\n";
  message += "Pressure: " + String(pressure) + " hPa\n";
  message += "Approx. Altitude: " + String(alt) + " m\n";

  Serial2.println("AT+CMGF=1"); // Configuring TEXT mode
  updateSerial();
  Serial2.println("AT+CMGS=\""+storedPhoneNumber+"\""); // Use the stored phone number
  updateSerial();
  Serial2.print(message); // SMS content
  updateSerial();
  Serial2.write(26); // ASCII code for Ctrl+Z to send the SMS
  updateSerial();
  Serial.println("Message Sent");
}

void checkForIncomingSMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt) {
  Serial2.println("AT+CMGF=1"); // Set the module to SMS mode
  delay(100);
  Serial2.println("AT+CNMI=1,2,0,0,0"); // Configure to send SMS data to serial port
  delay(100);
  
  if (Serial2.available()) {
    String response = Serial2.readString();
    Serial.println(response);

    // Extract the sender's phone number
    int senderIndex = response.indexOf("+CMT:");
    if (senderIndex != -1) {
      int quoteIndex = response.indexOf('"', senderIndex + 5);
      int nextQuoteIndex = response.indexOf('"', quoteIndex + 1);
      String senderNumber = response.substring(quoteIndex + 1, nextQuoteIndex);
      Serial.println(senderNumber);
      // Extract the SMS message content
      int contentIndex = response.indexOf("\n", nextQuoteIndex) + 1;
      String messageContent = response.substring(contentIndex);
      messageContent.trim();

      // Check if the message is from the stored phone number
      if (senderNumber == storedPhoneNumber) {
        if (messageContent.indexOf("Weather") != -1) {
          send_SMS(temperature,  humidity,  wind,  rainfall,  pressure,  alt); // Example values for SMS response
        }
      } else {
          sendConfirmationSMS(senderNumber, "No access.");
        }
      
    }
  }
}

void sendConfirmationSMS(String phoneNumber, String message) {
  Serial2.println("AT+CMGF=1"); // Configuring TEXT mode
  updateSerial();
  Serial2.println("AT+CMGS=\""+phoneNumber+"\""); // Send to the specified phone number
  updateSerial();
  Serial2.print(message); // SMS content
  updateSerial();
  Serial2.write(26); // ASCII code for Ctrl+Z to send the SMS
  updateSerial();
  Serial.println("Confirmation message sent");
}

void clearSerialBuffer() {
  while (Serial.available() > 0) {
    Serial.read();
  }
  while (Serial2.available() > 0) {
    Serial2.read();
  }
}

void updateSerial() {
  delay(500);
  while (Serial.available()) {
    Serial2.write(Serial.read()); // Forward what Serial received to Serial2
  }
  while (Serial2.available()) {
    Serial.write(Serial2.read()); // Forward what Serial2 received to Serial
  }
}
