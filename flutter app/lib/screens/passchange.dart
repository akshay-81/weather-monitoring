// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class PasswordChangeScreen extends StatefulWidget {
  final String base;

  const PasswordChangeScreen({required this.base, super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String currentPassword = _currentPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();

    try {
      final response = await http.get(Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['password'] == currentPassword) {
          // Update the password
          final updateResponse = await http.patch(
            Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'password': newPassword}),
          );

          if (updateResponse.statusCode == 200) {
            // Delay for 2 seconds before re-checking
            await Future.delayed(const Duration(seconds: 2));

            // Re-fetch the password from Firebase
            final recheckResponse = await http.get(Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

            if (recheckResponse.statusCode == 200) {
              final recheckData = json.decode(recheckResponse.body);
              if (recheckData != null && recheckData['password'] == newPassword) {
                Navigator.pop(context);
              } else {
                setState(() {
                  _errorMessage = 'Password update failed. Please try again.';
                });
              }
            } else {
              setState(() {
                _errorMessage = 'Failed to re-check password. Please try again.';
              });
            }
          } else {
            setState(() {
              _errorMessage = 'Failed to update password';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Current password is incorrect';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Failed to connect to database';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              style: const TextStyle(color: Colors.black),
              controller: _currentPasswordController,
              decoration: InputDecoration(
                hintText: 'Current Password',
                hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              style: const TextStyle(color: Colors.black),
              controller: _newPasswordController,
              decoration: InputDecoration(
                hintText: 'New Password',
                hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _changePassword,
                  child: const Text('Change Password'),
                ),
              ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
