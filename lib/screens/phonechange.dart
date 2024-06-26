import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PhoneChangeScreen extends StatefulWidget {
  final String base;

  const PhoneChangeScreen({required this.base, super.key});

  @override
  State<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends State<PhoneChangeScreen> {
  final TextEditingController _newPhoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _changePhone() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String newPhone = _newPhoneController.text.trim();

    if (!_validatePhoneNumber(newPhone)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid phone number. Please include the "+91" and local number.';
      });
      return;
    }

    try {
      final updateResponse = await http.patch(
        Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': newPhone}),
      );

      if (updateResponse.statusCode == 200) {
        // Delay for 2 seconds before re-checking
        await Future.delayed(const Duration(seconds: 2));

        // Re-fetch the phoneNumber from Firebase
        final recheckResponse = await http.get(Uri.parse('https://weather-monitor-trial-default-rtdb.asia-southeast1.firebasedatabase.app/${widget.base}.json'));

        if (recheckResponse.statusCode == 200) {
          final recheckData = json.decode(recheckResponse.body);
          if (recheckData != null && recheckData['phoneNumber'] == newPhone) {
            Navigator.pop(context);
          } else {
            setState(() {
              _errorMessage = 'Phone Number update failed. Please try again.';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Failed to re-check Phone Number. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to update Phone Number';
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

  bool _validatePhoneNumber(String phoneNumber) {
    final RegExp phoneRegExp = RegExp(r'^\+91\d{10}$');
    return phoneRegExp.hasMatch(phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Phone Number')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('New Phone Number', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              style: const TextStyle(color: Colors.black),
              controller: _newPhoneController,
              decoration: InputDecoration(
                hintText: '+91XXXXXXXXXX',
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
                  onPressed: _changePhone,
                  child: const Text('Change Phone Number'),
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
