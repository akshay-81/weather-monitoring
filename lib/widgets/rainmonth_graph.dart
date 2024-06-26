import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MonthlyRainfallChart extends StatefulWidget {
  final String base;

  const MonthlyRainfallChart({required this.base, super.key});

  @override
  State<MonthlyRainfallChart> createState() => _MonthlyRainfallChartState();
}
  DateTime now = DateTime.now();

class _MonthlyRainfallChartState extends State<MonthlyRainfallChart> {
 List<Color> gradientColors = [
    Colors.green, // Default color
    Colors.yellow,
    Colors.orange,
    Colors.red,
  ];
  List<double> rainfallData = [];
  List<DateTime> dates = [];

  @override
  void initState() {
    super.initState();
    fetchRainfallData();
  }

  Future<void> fetchRainfallData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}/rainmonth.json'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is List) {
          setState(() {
            // Assuming responseData is a list of rainfall values with an index representing days
            rainfallData = responseData.map((e) => double.parse(e)).toList();
            // Generate dates for every day in the month
            dates = List.generate(
              DateTime(now.year, now.month + 1, 0).day,
              (index) => DateTime(now.year, now.month, index + 1),
            );
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
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM').format(now);
    return Column(
      children: [
         Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            '$monthName Rainfall (mm)',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        Expanded(
          child: rainfallData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : LineChart(mainData()),
        ),
      ],
    );
  }

 Widget bottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 10,
    color: Colors.white,
  );

  // Ensure value is within the range of dates index
  int index = value.toInt();
  if (index < 0 || index >= dates.length) {
    return const SizedBox(); // Return an empty widget if index is out of bounds
  }
  if ((index+1)%5!=0) {
    return const SizedBox(width:5); // Return an empty widget if index is out of bounds
  }
  Widget text = Text('${dates[index].day}', style: style);

  return SideTitleWidget(
    axisSide: meta.axisSide,
    child: text,
  );
}

LineChartData mainData() {

    int today = now.day;
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    List<double> limitedRainfallData = rainfallData.sublist(0, today - 1);
  return LineChartData(
     gridData: FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: true,
      horizontalInterval: 0.1,
      verticalInterval: 1,
      getDrawingHorizontalLine: (value) {
        if ([64.5,115.5,204.4].contains(num.parse(value.toStringAsFixed(1)))) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 0.25,
          );
        } else {
          return const FlLine(
            color: Colors.transparent,
          );
        }
      },
      getDrawingVerticalLine: (value) {
        // Adjust the condition to draw vertical lines at every 5 units
        if ((value % 5) == 4) {
          return FlLine(
            color: Colors.grey[300]!,
            strokeWidth: 0.25,
          );
        } else {
          return const FlLine(
            color: Colors.transparent,
          );
        }
      },
    ),
     borderData: FlBorderData(
      show: true,
      border: Border.all(color:  Colors.grey[300]!),
    ),
    titlesData: FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: DateTime(now.year, now.month + 1, 0).day.toDouble(),
          interval: 1,
          getTitlesWidget: bottomTitleWidgets,
        ),
      ),
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false), // Remove Y-axis labels
      ),
    ),
    minX: 0,
    maxX: daysInMonth.toDouble()-1, 
    minY: 0,
    maxY: limitedRainfallData.isNotEmpty ? (limitedRainfallData.reduce((a, b) => a > b ? a : b) + 10) : 10,
    lineBarsData: [
      LineChartBarData(
        spots: limitedRainfallData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
        isCurved: false,
        gradient: LinearGradient(
          colors: limitedRainfallData
              .map<Color>((value) {
                if (value > 204.4) {
                  return gradientColors[3]; // Red
                } else if (value > 115.5) {
                  return gradientColors[2]; // Orange
                } else if (value > 64.5) {
                  return gradientColors[1]; // Yellow
                } else {
                  return gradientColors[0]; // Green
                }
              })
              .toList(),
        ),
        barWidth: 5,
        isStrokeCapRound: true,
        dotData: const FlDotData(
          show: false,
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient:const LinearGradient(
            colors: [Colors.transparent,Color.fromARGB(104, 0, 0, 0)],
          ),
        ),
      ),
    ],
  );
}


}
