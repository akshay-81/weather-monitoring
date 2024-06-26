#include <WiFi.h>
#include <HTTPClient.h>
#include <FirebaseESP32.h>

const char* ssid = "AK.";
const char* password = "abcdefgh";
const char* serverUrl = "http://103.140.16.30:5500/api/sensor";

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
    Serial.println("Connecting to WiFi...");

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }

  Serial.println("Connected to WiFi");
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;

    Serial.print("Connecting to server: ");
    Serial.println(serverUrl);

    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    float temperature = readTemperature();  // Replace with actual sensor reading
    float humidity = readHumidity();        // Replace with actual sensor reading

    String jsonPayload = "{\"temperature\":" + String(temperature) + ",\"humidity\":" + String(humidity) + "}";
    Serial.print("Sending payload: ");
    Serial.println(jsonPayload);

    int httpResponseCode = http.POST(jsonPayload);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println(httpResponseCode);
      Serial.println(response);
    } else {
      Serial.print("Error on sending POST: ");
      Serial.println(httpResponseCode);
      Serial.println(http.errorToString(httpResponseCode));
    }

    http.end();
  } else {
    Serial.println("WiFi Disconnected");
  }

  delay(15000); // Send data every 15 seconds
}

float readTemperature() {
  // Simulate reading temperature
  return random(20, 30) + random(0, 99) / 100.0;
}

float readHumidity() {
  // Simulate reading humidity
  return random(30, 70) + random(0, 99) / 100.0;
}
