#include <Wire.h>

#define AHT10_ADDRESS 0x38
#define AHT10_CMD_CALIBRATE 0xE1
#define AHT10_CMD_TRIGGER 0xAC
#define AHT10_CMD_SOFTRESET 0xBA

void setup() {
  Serial.begin(115200);
  Wire.begin();

  // Initialize AHT10
  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_CALIBRATE);
  Wire.write(0x08);
  Wire.write(0x00);
  Wire.endTransmission();
  delay(500); // Wait for sensor to calibrate

  // Soft reset
  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_SOFTRESET);
  Wire.endTransmission();
  delay(20); // Wait for reset
}

void loop() {
  float temperature, humidity;
  if (readAHT10(temperature, humidity)) {
    Serial.print("Temperature: ");
    Serial.print(temperature);
    Serial.println(" °C");

    Serial.print("Humidity: ");
    Serial.print(humidity);
    Serial.println(" %");

  } else {
    Serial.println("Failed to read from AHT10 sensor!");
  }
  delay(2000); // Wait for 2 seconds before taking another reading
}

bool readAHT10(float &temperature, float &humidity) {
  Wire.beginTransmission(AHT10_ADDRESS);
  Wire.write(AHT10_CMD_TRIGGER);
  Wire.write(0x33);
  Wire.write(0x00);
  Wire.endTransmission();
  delay(80); // Wait for the measurement to complete

   Wire.requestFrom(AHT10_ADDRESS, 6);
  if (Wire.available() == 6) {
    uint8_t data[6];
    for (int i = 0; i < 6; i++) {
      data[i] = Wire.read();
    }

    uint32_t rawHumidity = ((uint32_t)data[1] << 12) | ((uint32_t)data[2] << 4) | ((data[3] & 0xF0) >> 4);
    humidity = (rawHumidity * 100.0) / 1048576.0; // 2^20 = 1048576

    uint32_t rawTemperature = ((uint32_t)(data[3] & 0x0F) << 16) | ((uint32_t)data[4] << 8) | data[5];
    temperature = (rawTemperature * 200.0) / 1048576.0 - 50.0; // 2^20 = 1048576

    return true;
  }
  return false;
}
