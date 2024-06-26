#include <Adafruit_BMP280.h>
#include <LiquidCrystal.h>
#include <Wire.h>
#include "DFRobot_RainfallSensor.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>
#include "Arduino.h"
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <TimeLib.h>
#include <driver/adc.h>
#include <esp_adc_cal.h>
#include <time.h>

#define AHT10_ADDRESS 0x38
#define AHT10_CMD_CALIBRATE 0xE1
#define AHT10_CMD_TRIGGER 0xAC
#define AHT10_CMD_SOFTRESET 0xBA
#define rxPin 16
#define txPin 17
#define BAUD_RATE 9600
#define WIND_SENSOR_PIN ADC1_CHANNEL_4
#define ADC_VREF 1100       // ADC reference voltage in mV (use a multimeter to measure it)
#define SENSOR_POWER_PIN 5  // Pin to control power to the rainfall sensor


esp_adc_cal_characteristics_t *adc_chars;
// Replace with your Firebase Realtime Database URL
const char *firebaseURL = "https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/SensorData.json";

DFRobot_RainfallSensor_I2C Sensor(&Wire);

// Create An LCD Object. Signals: [ RS, EN, D4, D5, D6, D7 ]
LiquidCrystal My_LCD(15, 14, 27, 26, 25, 33);
Adafruit_BMP280 bmp;  // I2C Interface
String phoneNumber;
bool messageSentAt6AM = false;
bool messageSentAt6PM = false;
bool resetRainfallFlag = false;
bool resetTempFlag = false;
bool hourRainFlag = false;
bool rainhourUpdate = false;
bool rainmonthUpdate = false;

float user_humidity;
float user_temperature;
float calibrated_humidity;
float calibrated_temperature;
float scale_humidity = 1;
float scale_temp = 1;
float min_temp = 100;
float max_temp = -31;
float getRainfall=0;

// Define NTP Client to get time
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 19800, 60000);

void clearSerialBuffer(void);
bool readAHT10(float &temperature, float &humidity);
void connectToNetwork(void);
void send_SMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt);
void updateSerial(void);
void checkForIncomingSMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt);
void sendConfirmationSMS(String phoneNumber, String message);
float mapVoltageToWindSpeed(uint32_t voltage);
void resetRainfall(void);
void parseJson(String jsonString, float &user_humidity, float &user_temperature);
void setCalibrateHumidity(float user_humidity, float humidity);
void setCalibrateTemperature(float user_temperature, float temperature);
float calibrateHumidity(float humidity);
float calibrateTemperature(float temperature);
void checkMaxMinTemp(float temperature);
void sendHourRainData(float rainfall);

void setup() {
  Serial.begin(9600);
  Serial2.begin(BAUD_RATE, SERIAL_8N1, rxPin, txPin);  // Serial2 for SIM800L
  delay(3000);
  // test_sim800_module();
  connectToNetwork();
  // send_SMS();
  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten(WIND_SENSOR_PIN, ADC_ATTEN_DB_11);  // Attenuation for 0 - 3.6V

  // Allocate memory for the ADC characteristics structure
  adc_chars = (esp_adc_cal_characteristics_t *)calloc(1, sizeof(esp_adc_cal_characteristics_t));
  esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12, ADC_VREF, adc_chars);
  Wire.begin();
  delay(1000);

  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_CALIBRATE);
  Wire.write(0x08);
  Wire.write(0x00);
  Wire.endTransmission();
  delay(500);  // Wait for sensor to calibrate

  // Soft reset
  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_SOFTRESET);
  Wire.endTransmission();
  delay(20);  // Wait for reset
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  Sensor.setRainAccumulatedValue(0.2794);

  while (!Sensor.begin()) {
    Serial.println("Rain Sensor init err!!!");
    delay(1000);
  }

  Serial.print("vid:\t");
  Serial.println(Sensor.vid, HEX);
  Serial.print("pid:\t");
  Serial.println(Sensor.pid, HEX);
  Serial.print("Version:\t");
  Serial.println(Sensor.getFirmwareVersion());


  // Initialize The LCD. Parameters: [ Columns, Rows ]
  My_LCD.begin(16, 2);
  // Clears The LCD Display
  My_LCD.clear();

  if (!bmp.begin()) {
    Serial.println(F("Could not find a valid BMP280 sensor, check wiring!"));
    My_LCD.print("BMP failed");
    while (1)
      ;
  }

  My_LCD.clear();

  My_LCD.print("Connecting...");
  My_LCD.setCursor(0, 1);
  My_LCD.print("Please Wait...");

  Serial.println(F("BMP280 test"));


  /* Default settings from datasheet. */
  bmp.setSampling(Adafruit_BMP280::MODE_NORMAL,     /* Operating Mode. */
                  Adafruit_BMP280::SAMPLING_X2,     /* Temp. oversampling */
                  Adafruit_BMP280::SAMPLING_X16,    /* Pressure oversampling */
                  Adafruit_BMP280::FILTER_X16,      /* Filtering. */
                  Adafruit_BMP280::STANDBY_MS_500); /* Standby time. */
  WiFiManager wifiManager;

  // Uncomment to reset saved WiFi credentials
  // wifiManager.resetSettings();7

  // Set custom WiFi SSID and Password for the configuration portal
  wifiManager.autoConnect("ESP32_ConfigPortal", "password");
  // If you get here, you have connected to the WiFi
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
  float temperature, humidity;
  // float temp = bmp.readTemperature();
  float rainfall = Sensor.getRainfall();
  float val1, val2, sum = 0;
  for (int i = 0; i < 10; i++) {
    uint32_t adc_reading = adc1_get_raw(WIND_SENSOR_PIN);
    uint32_t val3 = esp_adc_cal_raw_to_voltage(adc_reading, adc_chars);
    sum = sum + val3;
  }
  val2 = sum / 10;
  Serial.println(val2);
  float wind = (mapVoltageToWindSpeed(val2)) * 3.6;
  sum = 0;
  for (int i = 0; i < 10; i++) {
    val1 = bmp.readPressure() / 100;
    sum = sum + val1;
  }
  float pressure = sum / 10;
  sum = 0;
  for (int i = 0; i < 10; i++) {
    val1 = bmp.readAltitude(1013.25);
    sum = sum + val1;
  }
  float alt = (sum / 10);
  readAHT10(temperature, humidity);
  calibrated_temperature = calibrateTemperature(temperature);
  calibrated_humidity = calibrateHumidity(humidity);
  My_LCD.clear();
  // Get current time
  unsigned long epochTime = timeClient.getEpochTime();
  setTime(epochTime);
  Serial.print(hour());
  Serial.print(":");
  Serial.println(minute());

  char timeString[6];
  sprintf(timeString, "%02d:%02d", hour(), minute());
  My_LCD.print("Time: ");
  My_LCD.print(timeString);


  Serial.print(F("Temperature = "));
  Serial.print(temperature);
  Serial.println(" *C");
  Serial.print(F("Pressure = "));
  Serial.print(pressure);  //displaying the Pressure in hPa, you can change the unit
  Serial.println(" hPa");
  Serial.print(F("Approx altitude = "));
  Serial.print(alt);     //The "1019.66" is the pressure(hPa) at sea level in day in your region
  Serial.println(" m");  //If you don't know it, modify it until you get your current altitude
  Serial.print("Rainfall:\t");
  Serial.println(rainfall);
  Serial.println(" mm");
  Serial.print("Wind speed:\t");
  Serial.println(wind);
  Serial.println(" km/hr");
  Serial.print("Humidity:\t");
  Serial.println(humidity);
  Serial.println(" %");
  if (WiFi.status() == WL_CONNECTED) {
    // WiFiClient Client;
    HTTPClient http;

    Serial.print("Making get request to: ");
    Serial.println(firebaseURL);

    http.begin(firebaseURL);
    int httpResponseCode2 = http.GET();
    if (httpResponseCode2 > 0) {
      String response = http.getString();
      Serial.println("HTTP Response Code: " + String(httpResponseCode2));
      Serial.println("Response: " + response);

      // Parse the JSON response
      // parseJson(response, user_humidity, user_temperature);

      DynamicJsonDocument doc(2048);
      DeserializationError error = deserializeJson(doc, response);
      if (error) {
        Serial.print("deserializeJson() failed: ");
        Serial.println(error.c_str());
        return;
      }
      String passwordField = doc["password"];
      phoneNumber = doc["phoneNumber"].as<String>();
      user_temperature = doc["user_temperature"].as<float>();
      user_humidity = doc["user_humidity"].as<float>();
      max_temp = doc["max_temperature"].as<float>();
      min_temp = doc["min_temperature"].as<float>();
      scale_temp = doc["scale"].as<float>();


      if(rainfall==0 && !resetRainfallFlag){
         getRainfall = doc["Rainfall"].as<float>();
      }   
      rainfall=rainfall+getRainfall;

      Serial.print("Rainfall: ");
      Serial.print(rainfall);

      Serial.print("user_temperature: ");
      Serial.println(user_temperature);
      Serial.print("user_humidity: ");
      Serial.println(user_humidity);

      if (user_humidity != 255) {
        if (user_humidity == 254) {
          Serial.print("Reset Calibrate humidity");
          setCalibrateHumidity(humidity, humidity);
          user_humidity = 255.0;
        } else {
          Serial.print("Calibrate humidity");
          setCalibrateHumidity(user_humidity, humidity);
          user_humidity = 255.0;
        }
        // Calibrate the values (example calibration)
      } else if (user_temperature != 255) {
        if (user_temperature == 254) {
          Serial.print("Reset Calibrate temperature");
          setCalibrateTemperature(temperature, temperature);
          user_temperature = 255.0;
        } else {
          Serial.print("Calibrate temperature");
          setCalibrateTemperature(user_temperature, temperature);
          user_temperature = 255.0;
        }
      } else {
        Serial.print("No need to Calibrate Temperature or humidity");
      }

      checkMaxMinTemp(temperature);


      // Access the rainhour array and update the value at the specific index (hour)
      // JsonArray rainhour = doc["rainhour"];
      doc["temperature"] = String(temperature, 2);
      doc["humidity"] = String(humidity, 2);
      doc["pressure"] = String(pressure, 2);
      doc["wind"] = String(wind, 2);
      doc["altitude"] = String(alt, 2);
      doc["Rainfall"] = String(rainfall, 2);
      doc["user_temperature"] = String(user_temperature, 2);
      doc["user_humidity"] = String(user_humidity, 2);
      doc["calibrated_humidity"] = String(calibrated_humidity, 2);
      doc["calibrated_temperature"] = String(calibrated_temperature, 2);
      doc["max_temperature"] = String(max_temp, 2);
      doc["min_temperature"] = String(min_temp, 2);
      doc["phoneNumber"] = phoneNumber;
      doc["updated_time"] = timeString;
      doc["scale"] = String(scale_temp, 4);


      JsonArray rainhour;
      if (doc.containsKey("rainhour")) {
        rainhour = doc["rainhour"].as<JsonArray>();
      } else {
        rainhour = doc.createNestedArray("rainhour");
        // Initialize the array with zeros for 24 hours
        for (int i = 0; i < 24; i++) {
          rainhour.add(0);
        }
      }

        if (!rainhour.isNull() && rainhour.size() > hour()) {
          if((hour() == 05 && minute() >= 30) && (hour() == 05 && minute() <= 37))) {
            Serial.print("pass(reset time)");   //Don't upload rainfall during this time since time initializes at 5:30 and takes some time to get the actual time during reset
          }else{
            rainhour[hour()] = String(rainfall, 2);
          }
        } else {
          Serial.println("Invalid rainhour array or hour out of range");
          return;
    
      }

      JsonArray rainmonth;
      if (doc.containsKey("rainmonth")) {
        rainmonth = doc["rainmonth"].as<JsonArray>();
      } else {
        rainmonth = doc.createNestedArray("rainmonth");
        // Initialize the array with zeros for 24 hours
        for (int i = 0; i < 31; i++) {
          rainmonth.add(0);
        }
      }

      if (hour() < 23 ||(hour() == 23 && minute() <= 25 )) {
        if (!rainmonth.isNull()) {
          rainmonth[day()] = String(rainfall, 2);
        } else {
          Serial.println("Invalid rainmonth array or day out of range");
          return;
        }
      }
      // // Serialize the updated JSON object to a string
      String jsonString;
      serializeJson(doc, jsonString);

      // Serial.print(jsonString);

      // Send the updated JSON string via PUT request
      http.begin(firebaseURL);
      http.addHeader("Content-Type", "application/json");
      int httpResponseCode = http.PUT(jsonString);

      // Check the response code
      if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.println("PUT Response Code: " + String(httpResponseCode));
        Serial.println("PUT Response: " + response);
      } else {
        Serial.println("Error on PUT request");
      }

      http.end();  // Free the resources
    }
  } else {
    My_LCD.setCursor(0, 1);
    My_LCD.print("No Network");
  }
  timeClient.update();


  // Send SMS at 6 AM
  if (hour() == 06 && minute() == 00 && !messageSentAt6AM) {
    send_SMS(calibrated_temperature, calibrated_humidity, wind, rainfall, pressure, alt);
    messageSentAt6AM = true;
  }

  // Reset flag at 6:01 AM
  if (hour() == 06 && minute() == 01) {
    messageSentAt6AM = false;
  }

  // Send SMS at 6 PM
  if (hour() == 18 && minute() == 00 && !messageSentAt6PM) {
    send_SMS(calibrated_temperature, calibrated_humidity, wind, rainfall, pressure, alt);
    messageSentAt6PM = true;
  }

  // Reset flag at 6:01 PM
  if (hour() == 18 && minute() == 01) {
    messageSentAt6PM = false;
  }
  // reset rainfall at 11 30pm
  if (hour() == 23 && minute() == 30 && !resetRainfallFlag) {
    resetRainfall();
    resetRainfallFlag = true;
  }
  if (hour() == 23 && minute() == 31 && resetRainfallFlag) {
    digitalWrite(SENSOR_POWER_PIN, HIGH);
    resetRainfallFlag = false;
  }
  if (hour() == 00 && minute() == 00 && !resetTempFlag) {
    max_temp = -31;
    min_temp = 100;
    resetTempFlag = true;
  }
  if (hour() == 00 && minute() == 01) {
    resetTempFlag = false;
  }
  // Check for incoming SMS messages
  checkForIncomingSMS(calibrated_temperature, calibrated_humidity, wind, rainfall, pressure, alt);
  My_LCD.clear();

  My_LCD.print("Temp = ");
  My_LCD.print(temperature);
  My_LCD.print("*C");
  My_LCD.setCursor(0, 1);
  My_LCD.print("Cal.Temp=");
  My_LCD.print(calibrated_temperature);
  My_LCD.print("*C");
  delay(3000);

  My_LCD.clear();
  My_LCD.print("Pre= ");
  My_LCD.print(pressure);
  My_LCD.print("hPa");
  My_LCD.setCursor(0, 1);
  My_LCD.print("Wind= ");
  My_LCD.print(wind);
  My_LCD.print("km/hr");
  delay(3000);

  My_LCD.clear();
  My_LCD.print("alt= ");
  My_LCD.print(alt);
  My_LCD.print(" m");
  My_LCD.setCursor(0, 1);
  My_LCD.print("Rainfall=");
  My_LCD.print(rainfall);
  My_LCD.print("mm");
  Serial.println();
  delay(3000);

  My_LCD.clear();
  My_LCD.print("Humidity= ");
  My_LCD.print(humidity);
  My_LCD.print("%");
  My_LCD.setCursor(0, 1);
  My_LCD.print("Cal. Hum= ");
  My_LCD.print(calibrated_humidity);
  My_LCD.print("%");
  delay(3000);
}

void clearSerialBuffer() {
  while (Serial.available() > 0) {
    Serial.read();
  }
  while (Serial2.available() > 0) {
    Serial2.read();
  }
}

bool readAHT10(float &temperature, float &humidity) {
  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_TRIGGER);
  Wire.write(0x33);
  Wire.write(0x00);
  Wire.endTransmission();
  delay(80);  // Wait for the measurement to complete

  Wire.requestFrom(AHT10_ADDRESS, 6);
  if (Wire.available() == 6) {
    uint8_t data[6];
    for (int i = 0; i < 6; i++) {
      data[i] = Wire.read();
    }

    uint32_t rawHumidity = ((uint32_t)data[1] << 12) | ((uint32_t)data[2] << 4) | ((data[3] & 0xF0) >> 4);
    humidity = (rawHumidity * 100.0) / 1048576.0;  // 2^20 = 1048576

    uint32_t rawTemperature = ((uint32_t)(data[3] & 0x0F) << 16) | ((uint32_t)data[4] << 8) | data[5];
    temperature = (rawTemperature * 200.0) / 1048576.0 - 50.0;  // 2^20 = 1048576

    return true;
  }
  return false;
}

void connectToNetwork() {
  Serial2.println("AT+COPS=0");  // Manually connect to "Bharat Kerala" network
  updateSerial();
  delay(5000);  // Wait for network registration
  Serial2.println("AT+CREG?");
  updateSerial();
}

void send_SMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt) {
  String message = "Humidity: " + String(humidity) + " %\n";
  message += "Rainfall: " + String(rainfall) + " mm\n";
  message += "Wind Speed: " + String(wind) + " km/hr\n";
  message += "Temperature: " + String(temperature) + " *C\n";
  message += "Pressure: " + String(pressure) + " hPa\n";
  message += "Approx. Altitude: " + String(alt) + " m\n";

  Serial2.println("AT+CMGF=1");  // Configuring TEXT mode
  updateSerial();
  Serial2.println("AT+CMGS=\"" + phoneNumber + "\"");  // Use the stored phone number
  updateSerial();
  Serial2.print(message);  // SMS content
  updateSerial();
  Serial2.write(26);  // ASCII code for Ctrl+Z to send the SMS
  updateSerial();
  Serial.println("Message Sent");
}

void updateSerial() {
  delay(500);
  while (Serial.available()) {
    Serial2.write(Serial.read());  // Forward what Serial received to Serial2
  }
  while (Serial2.available()) {
    Serial.write(Serial2.read());  // Forward what Serial2 received to Serial
  }
}

void checkForIncomingSMS(float temperature, float humidity, float wind, float rainfall, float pressure, int alt) {
  Serial2.println("AT+CMGF=1");  // Set the module to SMS mode
  delay(100);
  Serial2.println("AT+CNMI=1,2,0,0,0");  // Configure to send SMS data to serial port
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
      if (senderNumber == phoneNumber) {
        if (messageContent.indexOf("Weather") != -1) {
          send_SMS(temperature, humidity, wind, rainfall, pressure, alt);  // Example values for SMS response
        }
      } else {
        sendConfirmationSMS(senderNumber, "No access.");
      }
    }
  }
}

void sendConfirmationSMS(String phoneNumber, String message) {
  Serial2.println("AT+CMGF=1");  // Configuring TEXT mode
  updateSerial();
  Serial2.println("AT+CMGS=\"" + phoneNumber + "\"");  // Send to the specified phone number
  updateSerial();
  Serial2.print(message);  // SMS content
  updateSerial();
  Serial2.write(26);  // ASCII code for Ctrl+Z to send the SMS
  updateSerial();
  Serial.println("Confirmation message sent");
}

float mapVoltageToWindSpeed(uint32_t voltage) {
  // The voltage range is 660mV to 3300mV (0.66V to 3.3V)
  // Corresponding wind speed range is 0 m/s to 30 m/s
  const float minVoltage = 660.0;   // in mV
  const float maxVoltage = 3300.0;  // in mV
  const float minWindSpeed = 0.0;   // in m/s
  const float maxWindSpeed = 30.0;  // in m/s 

  // Map the voltage to the wind speed range
  float windSpeed = (voltage < 690) ? 0 : (((voltage - minVoltage) * (maxWindSpeed - minWindSpeed)) / (maxVoltage - minVoltage) + minWindSpeed);
  return windSpeed;
}

void resetRainfall() {
  digitalWrite(SENSOR_POWER_PIN, LOW);
  Serial.println("Rainfall reset to 0");
}

// Example calibration functions
void setCalibrateHumidity(float user_humidity, float humidity) {
  scale_humidity = (float)user_humidity / humidity;
  Serial.println("Scale humidity: ");
  Serial.println(scale_humidity);
  // return (humidity * scale_humidity);
}

void setCalibrateTemperature(float user_temperature, float temperature) {
  scale_temp = (float)user_temperature / temperature;
  Serial.println("Scale temperature: ");
  Serial.println(scale_temp);
  // return (temperature * scale_temp);
}

float calibrateHumidity(float humidity) {
  Serial.println("Scale humidity: ");
  Serial.println(scale_humidity);
  return (humidity * scale_humidity);
}

float calibrateTemperature(float temperature) {
  Serial.println("Scale temperature: ");
  Serial.println(scale_temp);
  return (temperature * scale_temp);
}

void checkMaxMinTemp(float temperature) {
  if (temperature > max_temp) {
    max_temp = temperature;
  }
  if ((temperature < min_temp) && (temperature > -31)) {
    min_temp = temperature;
  }
}
