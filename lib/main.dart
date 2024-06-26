import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weatherapp/screens/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weatherapp/screens/dashboard.dart';
import 'package:permission_handler/permission_handler.dart';

final theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: const Color.fromARGB(255, 0, 120, 218),
  ),
  textTheme: GoogleFonts.latoTextTheme(),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String?> _getUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Monitor',
      theme: theme,
      home: FutureBuilder<void>(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return FutureBuilder<bool>(
              future: _checkLoginStatus(),
              builder: (context, loginSnapshot) {
                if (loginSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  if (loginSnapshot.data!) {
                    return FutureBuilder<String?>(
                      future: _getUsername(),
                      builder: (context, usernameSnapshot) {
                        if (usernameSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else {
                          return DashboardScreen(base: usernameSnapshot.data ?? '');
                        }
                      },
                    );
                  } else {
                    return const LoginScreen();
                  }
                }
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
  }
}