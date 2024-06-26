#include <driver/adc.h>
#include <esp_adc_cal.h>
#define WIND_SENSOR_PIN ADC1_CHANNEL_4  
#define ADC_VREF 1100  // ADC reference voltage in mV (use a multimeter to measure it)

esp_adc_cal_characteristics_t *adc_chars;

void setup() {

  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten(WIND_SENSOR_PIN, ADC_ATTEN_DB_11);  // Attenuation for 0 - 3.6V

  // Allocate memory for the ADC characteristics structure
  adc_chars = (esp_adc_cal_characteristics_t *)calloc(1, sizeof(esp_adc_cal_characteristics_t));
  esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12, ADC_VREF, adc_chars);
}

void loop() {
  // Read the ADC value
  uint32_t adc_reading = adc1_get_raw(WIND_SENSOR_PIN);

  // Convert the ADC reading to a voltage in mV
  uint32_t voltage = esp_adc_cal_raw_to_voltage(adc_reading, adc_chars);
  
  // Convert the voltage to wind speed
  float windSpeed = mapVoltageToWindSpeed(voltage);

}

float mapVoltageToWindSpeed(uint32_t voltage) {
  // The voltage range is 660mV to 3300mV (0.66V to 3.3V)
  // Corresponding wind speed range is 0 m/s to 30 m/s
  const float minVoltage = 700.0;  // in mV
  const float maxVoltage = 3300.0;  // in mV
  const float minWindSpeed = 0.0;  // in m/s
  const float maxWindSpeed = 30.0;  // in m/s

  // Map the voltage to the wind speed range
  float windSpeed = ((voltage - minVoltage) * (maxWindSpeed - minWindSpeed)) / (maxVoltage - minVoltage) + minWindSpeed;
  return (windSpeed<0)?0:windSpeed;
}
