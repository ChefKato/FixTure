import 'package:flutter/material.dart';
import 'dart:async';

class TuningSettingsPage extends StatefulWidget {
  const TuningSettingsPage({super.key});

  @override
  _TuningSettingsPageState createState() => _TuningSettingsPageState();
}

class _TuningSettingsPageState extends State<TuningSettingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _step = 0;
  String _instructionText = "Press 'Start' to begin tuning";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStartPressed() {
    setState(() {
      _step = 1; // Start the tuning process
      _instructionText = "Stand straight and press 'Done'";
    });
  }

  void _onDonePressed() {
    if (_step == 1) {
      _sendData("GP_R"); // Stand straight
      setState(() {
        _step = 2;
        _instructionText = "Curve your posture and press 'Done'";
      });
    } else if (_step == 2) {
      _sendData("BP_R"); // Curve posture
      setState(() {
        _step = 3;
        _instructionText = "Sit straight and press 'Done'";
      });
    } else if (_step == 3) {
      _sendData("SGP_R"); // Sit straight
      setState(() {
        _step = 4;
        _instructionText = "Curve your posture while sitting and press 'Done'";
      });
    } else if (_step == 4) {
      _sendData("SBP_R"); // Curve posture while sitting
      setState(() {
        _instructionText = "Customization complete";
      });
      _controller.stop();
      Timer(const Duration(seconds: 2), () {
        _sendData("EXIT");
        Navigator.pop(context);
      });
    }
  }

  void _sendData(String command) {
    // Implement the actual data sending logic
    print("Sent command: $command");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuning Settings'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_step == 0) ...[
              ElevatedButton(
                onPressed: _onStartPressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20.0, horizontal: 40.0),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('Start tuning'),
              ),
            ] else ...[
              RotationTransition(
                turns: _controller,
                child: const Icon(
                  Icons.settings,
                  size: 80,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _instructionText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onDonePressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 30.0),
                ),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
