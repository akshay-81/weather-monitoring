// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weatherapp/screens/calibrate.dart';
import 'package:weatherapp/screens/phonechange.dart';
import 'login.dart';
import 'passchange.dart';
import '../models/category.dart';
import '../widgets/category_grid_item.dart';
import 'details.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share/share.dart';

class DashboardScreen extends StatefulWidget {
  final String base;

  const DashboardScreen({required this.base, super.key});

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
    int _currentIndex = 0;
  List<double> rainfallData = [];
  List<double> hourlyRainfall = [];
  Map<String, dynamic> weatherData = {};
  bool isWeatherDataLoaded = false;
  DateTime now = DateTime.now();

  List<Category> categories = [
    Category(title: 'Temperature', icon: Icons.thermostat, color: Colors.red),
    Category(title: 'Wind Speed', icon: Icons.wind_power, color: Colors.blue),
    Category(title: 'Altitude', icon: Icons.landscape, color: Colors.green),
    Category(title: 'Rainfall', icon: Icons.cloudy_snowing, color: Colors.blueGrey),
    Category(title: 'Humidity', icon: Icons.water_drop, color: Colors.cyan),
    Category(title: 'Atm Pressure', icon: Icons.air, color: Colors.orange),
  ];

  List<String> values = ['-', '-', '-', '-', '-', '-','-'];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchWeatherData();
    startFetchingData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startFetchingData() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final fetchedValues = await fetchData();
      if (mounted) {
        setState(() {
          values = fetchedValues;
        });
      }
    });
  }
  Future<void> fetchWeatherData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          weatherData = responseData;
          if (responseData['rainmonth'] is List) {
            int today=now.day;
            List<double> lRainfallData = responseData['rainmonth']
                .map<double>((e) => double.parse(e))
                .toList();
            rainfallData = lRainfallData.sublist(0, today - 1);
          }
          if (responseData['rainhour'] is List) {
                            List<double> rainHourData = [];
            rainHourData = responseData['rainhour']
                .map<double>((e) => double.parse(e))
                .toList();
                double previousValue = 0;
                int currentHour = now.hour;

                for (int hour = 0; hour < currentHour; hour++) {
                  num cur =rainHourData[hour];
                  double currentValue=cur.toDouble();
                  hourlyRainfall.add(currentValue - previousValue);
                  previousValue = currentValue;
                }
          }

          // Remove specific fields from weatherData map
          weatherData.remove('user_humidity');
          weatherData.remove('user_temperature');
          weatherData.remove('password');

        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> exportToCSV() async {
    if (await Permission.storage.request().isGranted) {
      // Fetch weather data if not already loaded
        await fetchWeatherData();

      List<List<dynamic>> rows = [
        ["Key", "Value"]
      ];

      weatherData.forEach((key, value) {
        if (key != 'rainmonth' &&
            key != 'rainhour' &&
            key != 'user_humidity' &&
            key != 'user_temperature' &&
            key != 'max_temperature' &&
            key != 'min_temperature' &&
            key != 'password') {
          rows.add([key, value]);
        }
      });
 // Add max_temperature and min_temperature with scaling
    if (weatherData.containsKey('max_temperature') && weatherData.containsKey('min_temperature') && weatherData.containsKey('scale')) {
      double scale = double.parse(weatherData['scale']);
      double maxTemperature = double.parse(weatherData['max_temperature']) * scale;
      double minTemperature = double.parse(weatherData['min_temperature']) * scale;
      rows.add(["Max Temperature", maxTemperature.toStringAsFixed(2)]);
      rows.add(["Min Temperature", minTemperature.toStringAsFixed(2)]);
    }
      rows.add([]);
      rows.add(["Day", "Rainfall (mm)"]);
      for (int i = 0; i < rainfallData.length; i++) {
        rows.add([i + 1, rainfallData[i]]);
      }

      rows.add([]);
      rows.add(["Hour", "Rainfall (mm)"]);
      for (int i = 0; i < hourlyRainfall.length; i++) {
        rows.add([i, hourlyRainfall[i]]);
      }

      String csv = const ListToCsvConverter().convert(rows);

      Directory directory;
      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory())!;
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String path = "${directory.path}/weather_data.csv";
      File file = File(path);

      await file.writeAsString(csv);

      Share.shareFiles([path], text: 'Weather data for the month');
    } else {
      print("Permission denied");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
    }
  }
  void _showExportConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Export', style: TextStyle(color: Colors.white),),
        content: const Text('Do you want to export the weather data to CSV?', style: TextStyle(color: Colors.white),),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
           onPressed: () {              
            Navigator.of(context).pop();
            exportToCSV();
            },
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
}

  Future<List<String>> fetchData() async {
    try {
      final response = await http.get(Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return [
          double.parse(data['calibrated_temperature'])<-30?"error":"${data['calibrated_temperature']} °C",
          "${data['wind']} km/hr",
          (data['altitude']=='nan')?"error":(double.parse(data['altitude'])<0||double.parse(data['altitude'])>8000)?"error":"${data['altitude']} m",
          "${data['Rainfall']} mm",
          double.parse(data['calibrated_temperature'])<-30?"error":"${data['calibrated_humidity']} %",
          double.parse(data['pressure'])<0?"error":"${data['pressure']} hPa",
          "${data['updated_time']}"
        ];
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('username');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(500, 85, 1, 0),
      items: [
        const PopupMenuItem<String>(value: 'calibrate', child: Text('Calibrate Temp/Humidity')),
        const PopupMenuItem<String>(value: 'change_password', child: Text('Change Password')),
        const PopupMenuItem<String>(value: 'change_phone', child: Text('Change Phone No')),
        const PopupMenuItem<String>(value: 'export_csv', child: Text('Export CSV')),
        const PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
      ],
    );

    if (selected == 'logout') {
      _logout();
    } else if (selected == 'change_password') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PasswordChangeScreen(base: widget.base)),
      );
    }
    else if (selected == 'calibrate') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CalibrateScreen(base: widget.base)),
      );
    }
    else if (selected == 'change_phone') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PhoneChangeScreen(base: widget.base)),
      );
    }
    else if (selected == 'export_csv') {
    _showExportConfirmationDialog(context);
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo.png', fit: BoxFit.contain, height: 38),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: _currentIndex == 0 ? buildDashboard(context) : DetailsScreen(base: widget.base),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.details),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget buildDashboard(BuildContext context) {
    return FutureBuilder<List<String>?>(
      future: fetchData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        } else {
          return SingleChildScrollView(
              child: Column(
                children:[ 
                  Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10.0),
              padding: const EdgeInsets.all(10.0),
              child: Text('Last updated at ${values[6]}',style: const TextStyle(color: Colors.white,fontSize: 18),),
            ),
            GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return GridItem(
                      category: categories[index],
                      value: values[index],
                    );
                  },
                ),],
            ),
            );
        }
      },
    );
  }
}
