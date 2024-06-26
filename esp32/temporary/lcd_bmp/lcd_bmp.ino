#include <Adafruit_BMP280.h>
#include <LiquidCrystal.h>
#include <Wire.h>
#include "DFRobot_RainfallSensor.h"

DFRobot_RainfallSensor_I2C Sensor(&Wire);
 
// Create An LCD Object. Signals: [ RS, EN, D4, D5, D6, D7 ]
LiquidCrystal My_LCD(13, 12, 14, 27, 26, 25);
Adafruit_BMP280 bmp; // I2C Interface

void setup() {
Serial.begin(9600);
Serial.println(F("BMP280 test"));
Wire.begin();
  // Serial.begin(115200);
  delay(1000);

  while (!Sensor.begin()) {
    Serial.println("Sensor init err!!!");
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
while (1);
}

/* Default settings from datasheet. */
bmp.setSampling(Adafruit_BMP280::MODE_NORMAL, /* Operating Mode. */
Adafruit_BMP280::SAMPLING_X2, /* Temp. oversampling */
Adafruit_BMP280::SAMPLING_X16, /* Pressure oversampling */
Adafruit_BMP280::FILTER_X16, /* Filtering. */
Adafruit_BMP280::STANDBY_MS_500); /* Standby time. */
}

void loop() {
    My_LCD.clear();
Serial.print(F("Temperature = "));
Serial.print(bmp.readTemperature());
Serial.println(" *C");
 // Display The First Message In Home Position (0, 0)
  My_LCD.print("Temp = ");
  My_LCD.print(bmp.readTemperature());
 My_LCD.print(" *C");

Serial.print(F("Pressure = "));
Serial.print(bmp.readPressure()/100); //displaying the Pressure in hPa, you can change the unit
Serial.println(" hPa");
My_LCD.setCursor(0, 1);
 My_LCD.print("Pressure= ");
  My_LCD.print(bmp.readPressure()/100);
 My_LCD.print(" hPa");

delay(5000);
Serial.print(F("Approx altitude = "));
Serial.print(bmp.readAltitude(1019.66)); //The "1019.66" is the pressure(hPa) at sea level in day in your region
Serial.println(" m"); //If you don't know it, modify it until you get your current altitude

  My_LCD.clear();

 My_LCD.print("alt= ");
  My_LCD.print(bmp.readAltitude(1019.66));
 My_LCD.print(" m");

 Serial.print("Sensor WorkingTime:\t");
  Serial.print(Sensor.getSensorWorkingTime());
  Serial.println(" H");
  // Get the accumulated rainfall during the sensor working time
  Serial.print("Rainfall:\t");
  Serial.println(Sensor.getRainfall());
  // Get the accumulated rainfall within 1 hour of the system (function parameter optional 1-24)
  Serial.print("1 Hour Rainfall:\t");
  Serial.print(Sensor.getRainfall(1));
  Serial.println(" mm");
  // Get the raw data, the number of tipping buckets for rainfall, unit: times
  Serial.print("rainfall raw:\t");
  Serial.println(Sensor.getRawData());
  // delay(1000);
My_LCD.setCursor(0, 1);

  My_LCD.print("Rainfall= ");
  My_LCD.print(Sensor.getRainfall());
Serial.println();
delay(5000);
}