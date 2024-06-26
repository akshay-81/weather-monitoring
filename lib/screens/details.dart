import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:weatherapp/widgets/rainmonth_graph.dart'; // Adjust the import based on your file structure

class DetailsScreen extends StatefulWidget {
  final String base;
  const DetailsScreen({required this.base, super.key});

  @override
  State<DetailsScreen> createState() {
    return _DetailsScreenState();
  }
}

class _DetailsScreenState extends State<DetailsScreen> {
  Map<String, dynamic> rainData = {};
  String? maxTemperature;
  String? minTemperature;
  late Future<void> _dataFuture;
  String lastUpdatedAt = "";

 @override
  void initState() {
    super.initState();
    _dataFuture = fetchRainfallData();
  }

  bool showAvg = false;

  Future<void> fetchRainfallData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}/rainhour.json'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is Map<String, dynamic>) {
          setState(() {
            rainData = responseData;
          });
        } else if (responseData is List) {
          setState(() {
            rainData = { for (var e in responseData.asMap().entries) e.key.toString() : e.value };
          });
        } else {
          throw Exception('Unexpected data format');
        }
      } else {
        throw Exception('Failed to load rainfall data');
      }
    } catch (e) {
      print('Error: $e');
    }

    try { // Fetching max and min temperature
      final tempResponse = await http.get(Uri.parse(
          'https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

      if (tempResponse.statusCode == 200) {
        final tempResponseData = json.decode(tempResponse.body);
        setState(() {
          lastUpdatedAt = tempResponseData['updated_time'];
          maxTemperature = (double.parse(tempResponseData['max_temperature'])>80||double.parse(tempResponseData['max_temperature'])<-30)?"error":"${(double.parse(tempResponseData['max_temperature'])*double.parse(tempResponseData['scale'])).toStringAsFixed(2)}°C";
          minTemperature = (double.parse(tempResponseData['min_temperature'])>80||double.parse(tempResponseData['min_temperature'])<-30)?"error":"${(double.parse(tempResponseData['min_temperature'])*double.parse(tempResponseData['scale'])).toStringAsFixed(2)}°C";
        });
      } else {
        throw Exception('Failed to load temperature data');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  DateTime now = DateTime.now();

  List<double> calculateHourlyRainfall() {
    List<double> hourlyRainfall = [];
    double previousValue = 0;
    int currentHour = now.hour;

    for (int hour = 0; hour <= currentHour; hour++) {
      double currentValue=double.parse(rainData['$hour']);
      if(currentValue<previousValue){
      return [];}
      hourlyRainfall.add(currentValue - previousValue);
      previousValue = currentValue;
    }

    return hourlyRainfall;
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            List<double?> hourlyRainfall = calculateHourlyRainfall();
            int currentHour = now.hour;

            return SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10.0),
              padding: const EdgeInsets.all(10.0),
              child: Text('Last updated at $lastUpdatedAt',style: const TextStyle(color: Colors.white,fontSize: 18),),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(150, 70, 70, 70),
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.thermostat, color: Colors.red, size: 30),
                      const SizedBox(height: 10),
                      Text(
                        "$maxTemperature",
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Max Temp',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.ac_unit, color: Colors.blue, size: 30),
                      const SizedBox(height: 10),
                      Text(
                        "$minTemperature",
                        style: const TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Min Temp',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(150, 70, 70, 70),
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  const Text(
                    'Hourly Rainfall (mm)',
                    style: TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120.0,
                    child:  (hourlyRainfall.isNotEmpty)?
                    ListView(
  scrollDirection: Axis.horizontal,
  children: List.generate(23, (index) {
    // Create a list of indexes from 1 to 23, then add 0 at the end
    List<int> modifiedIndexes = List<int>.generate(23, (i) => i + 1);
    int displayIndex = modifiedIndexes[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: [
          Text(
            '${displayIndex.toString().padLeft(2, '0')}:00',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 4.0),
          Icon(
            Icons.water_drop,
            size: 30,
            color: getRainIconColor(displayIndex <= currentHour ? hourlyRainfall[displayIndex] : 0),
          ),
          const SizedBox(height: 4.0),
          Text(
            displayIndex <= currentHour ? '${hourlyRainfall[displayIndex]?.toStringAsFixed(2)}' : '-',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }),
):
                    const Center(
                      child: Text('Error in rainfall measurement. Will reset tomorrow', 
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 22,),),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color.fromARGB(150, 70, 70, 70),
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(10.0),
              child: MonthlyRainfallChart(base: widget.base),
            ),
          ],
        ),
      );
      }
      }
      ),
    );
  }

  Color getRainIconColor(double? rainAmount) {
    if (rainAmount == null || rainAmount == 0) {
      return Colors.grey;
    } else if (rainAmount > 0 && rainAmount <= 10) {
      return const Color.fromARGB(255, 131, 194, 245);
    } else if (rainAmount > 10 && rainAmount <= 20) {
      return const Color.fromARGB(255, 28, 102, 230);
    } else {
      return const Color.fromARGB(255, 7, 37, 82);
    }
  }
}
