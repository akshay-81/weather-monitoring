import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalibrateScreen extends StatefulWidget {
  final String base;

  const CalibrateScreen({required this.base, super.key});

  @override
  State<CalibrateScreen> createState() => _CalibrateScreenState();
}

class _CalibrateScreenState extends State<CalibrateScreen> {
  bool? _isTempSelected = false;
  bool? _isHumiditySelected = false;
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  double? currentTemp;
  double? currentHumidity;
  double? calibtemp;
  double? calibhumdidty;

  @override
  void initState() {
    super.initState();
    fetchCurrentData();
  }

  Future<void> fetchCurrentData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          currentTemp = double.parse(responseData['temperature']);
          currentHumidity = double.parse(responseData['humidity']);
          calibtemp = double.parse(responseData['calibrated_temperature']);
          calibhumdidty = double.parse(responseData['calibrated_humidity']);
        });
      } else {
        throw Exception('Failed to load current data');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _handleCalibrate() async {
    double? tempValue;
    double? humidityValue;

    if (_isTempSelected == true) {
      tempValue = double.tryParse(_tempController.text);
      if (tempValue == null || tempValue < -30 || tempValue > 85) {
        _showErrorDialog('Temperature must be between -30 and 85 degrees.');
        return;
      }
    }

    if (_isHumiditySelected == true) {
      humidityValue = double.tryParse(_humidityController.text);
      if (humidityValue == null || humidityValue < 0 || humidityValue > 100) {
        _showErrorDialog('Humidity must be between 0 and 100%.');
        return;
      }
    }

    try {
      Map<String, dynamic> updateData = {};
      if (tempValue != null) updateData['user_temperature'] = tempValue.toString();
      if (humidityValue != null) updateData['user_humidity'] = humidityValue.toString();

      final response = await http.patch(
        Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'),
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog('Calibration successful!');
      } else {
        _showErrorDialog('Failed to calibrate.');
      }
    } catch (e) {
      print('Error: $e');
      _showErrorDialog('An error occurred.');
    }
  }

  void _handleResetTemp() async {
    try {
      if (currentTemp != null) {
        final response = await http.patch(
          Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'),
          body: json.encode({'user_temperature': "254"}),
        );

        if (response.statusCode == 200) {
          setState(() {
            calibtemp = currentTemp;
          });
          _showSuccessDialog('Temperature reset successful!');
        } else {
          _showErrorDialog('Failed to reset temperature.');
        }
      }
    } catch (e) {
      print('Error: $e');
      _showErrorDialog('An error occurred.');
    }
  }

  void _handleResetHumidity() async {
    try {
      if (currentHumidity != null) {
        final response = await http.patch(
          Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'),
          body: json.encode({'user_humidity':"254"}),
        );

        if (response.statusCode == 200) {
          setState(() {
            calibhumdidty = currentHumidity;
          });
          _showSuccessDialog('Humidity reset successful!');
        } else {
          _showErrorDialog('Failed to reset humidity.');
        }
      }
    } catch (e) {
      print('Error: $e');
      _showErrorDialog('An error occurred.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Navigate back to the previous screen (Dashboard)
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibrate'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Calibrated Data',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Temperature: ${calibtemp?.toStringAsFixed(2) ?? '-'}°C',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              Text(
                'Humidity: ${calibhumdidty?.toStringAsFixed(2) ?? '-'}%',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              const Text(
                'Current Measured Data',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'Temperature: ${currentTemp?.toStringAsFixed(2) ?? '-'}°C',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              Text(
                'Humidity: ${currentHumidity?.toStringAsFixed(2) ?? '-'}%',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 20),
              const Text(
                'Calibrate',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              RadioListTile<bool>(
                title: const Text('Temperature', style: TextStyle(color: Colors.white)),
                value: true,
                groupValue: _isTempSelected,
                onChanged: (value) {
                  setState(() {
                    _isTempSelected = value == true ? !_isTempSelected! : null;
                    if (_isTempSelected!) {
                      _isHumiditySelected = false;
                    }
                  });
                },
                activeColor: Colors.white,
              ),
              if (_isTempSelected == true)
                TextField(
                  controller: _tempController,
                  decoration: const InputDecoration(
                    labelText: 'Temperature (°C)',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                ),
              RadioListTile<bool>(
                title: const Text('Humidity', style: TextStyle(color: Colors.white)),
                value: true,
                groupValue: _isHumiditySelected,
                onChanged: (value) {
                  setState(() {
                    _isHumiditySelected = value == true ? !_isHumiditySelected! : null;
                    if (_isHumiditySelected!) {
                      _isTempSelected = false;
                    }
                  });
                },
                activeColor: Colors.white,
              ),
              if (_isHumiditySelected == true)
                TextField(
                  controller: _humidityController,
                  decoration: const InputDecoration(
                    labelText: 'Humidity (%)',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _handleCalibrate,
                  child: const Text('Calibrate'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _handleResetTemp,
                  child: const Text('Reset Temperature'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _handleResetHumidity,
                  child: const Text('Reset Humidity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
