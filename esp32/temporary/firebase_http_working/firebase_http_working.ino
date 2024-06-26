#include <WiFi.h>
#include <WiFiClientSecure.h>

// Replace with your network credentials
const char* ssid = "HUAWEI Y5 Prime 2018";
const char* password = "12344321";

// Replace with your Firebase Realtime Database URL and Host
const char* host = "weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app";
const int httpsPort = 443;

void setup() {
  Serial.begin(115200);

  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("Connected to WiFi");

  // Use WiFiClientSecure to establish a connection
  WiFiClientSecure client;
  client.setInsecure(); // Use setInsecure for testing purposes only, not for production

  Serial.print("Connecting to ");
  Serial.println(host);

  if (!client.connect(host, httpsPort)) {
    Serial.println("Connection failed");
    return;
  }

  // Create JSON data
  String jsonData = "{\"temperature\": 29, \"humidity\": 50}";

  // Create HTTP PUT request
  String url = "/sensorData.json";
  String request = String("PUT ") + url + " HTTP/1.1\r\n" +
                   "Host: " + host + "\r\n" +
                   "Content-Type: application/json\r\n" +
                   "Content-Length: " + jsonData.length() + "\r\n" +
                   "Connection: close\r\n\r\n" +
                   jsonData;

  // Send the request
  client.print(request);

  // Read the response
  while (client.connected()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") {
      Serial.println("Headers received");
      break;
    }
  }

  // Print the response
  String response = client.readString();
  Serial.println("Response: ");
  Serial.println(response);

  // Close the connection
  client.stop();
}

void loop() {
  // Add your repeated code here
}
