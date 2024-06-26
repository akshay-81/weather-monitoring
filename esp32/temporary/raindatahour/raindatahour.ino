#include <WiFi.h>
#include <WiFiManager.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 3600;  // Adjust as per your timezone
const int daylightOffset_sec = 3600;  // Adjust as per your timezone
bool timeSynchronized = false;

// Function to get today's date
void getTodaysDate(int &day, int &month, int &year) {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    day = 0;
    month = 0;
    year = 0;
    return;
  }
  day = timeinfo.tm_mday;
  month = timeinfo.tm_mon + 1; // tm_mon is 0-based
  year = timeinfo.tm_year + 1900; // tm_year is the number of years since 1900
}

// Function to get today's day
int getTodayDay() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return 0; // Return 0 if time is not available
  }
  return timeinfo.tm_mday;
}

// Function to get the current hour
int getCurrentHour() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return -1; // Return -1 if time is not available
  }
  return timeinfo.tm_hour;
}

// Function to get the current minute
int getCurrentMinute() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return -1; // Return -1 if time is not available
  }
  return timeinfo.tm_min;
}

void setup() {
  Serial.begin(115200);
  WiFiManager wifiManager;
  wifiManager.autoConnect("ESP32_ConfigPortal", "password");
  Serial.println("Connected to WiFi!");

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  // Wait for time to be set
  struct tm timeinfo;
  while (!getLocalTime(&timeinfo)) {
    Serial.println("Waiting for NTP time sync...");
    delay(1000);
  }
  Serial.println("Time synchronized successfully");

  // Print today's date
  int day, month, year;
  getTodaysDate(day, month, year);
  Serial.print("Today's date is: ");
  Serial.print(day);
  Serial.print("/");
  Serial.print(month);
  Serial.print("/");
  Serial.println(year);
}

void loop() {
  // Your main loop code here

  delay(60000); // Wait for a minute before the next loop
}
