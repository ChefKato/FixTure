import 'dart:async';
import 'dart:convert';
import 'package:fixture/Image_load.dart';
import 'package:fixture/tuning_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<int> timerOptions = [];
  int selectedTime = 15;
  List<int> percentOptions = [];
  int selectedPercent = 60;
  bool isSwitchOn = false;
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> devicesList = [];
  BluetoothConnection? bluetoothConnection;
  BluetoothDevice? connectedDevice;
  bool isScanning = false;
  late AnimationController controller;
  Uint8List? logoBytes;
  int backDegree = 100;
  Timer? timer;

  final String serviceUuid = "your-service-uuid";
  final String txCharacteristicUuid = "your-tx-characteristic-uuid";
  final String rxCharacteristicUuid = "your-rx-characteristic-uuid";
  double currentAngle = 0.0; // Variable to hold the angle value


  @override 
  void initState() {
    super.initState();
    timerOptions = List.generate(20, (index) => (index + 1) * 15);
    percentOptions = List.generate(10, (index) => (index + 1) * 10);
    logoBytes = ImageManager().logoImage;
    controller = AnimationController(
      duration: const Duration(seconds: 2), // Duration of rotation
      vsync: this,
    )..repeat();
  }

Future<void> startBluetoothScan() async {
  // Request necessary permissions (Not required for classic Bluetooth, but useful for Android 12+)
  await Permission.bluetooth.request();
  await Permission.bluetoothConnect.request();
  await Permission.locationWhenInUse.request();

  setState(() {
    isScanning = true;
  });

  // Clear devices list to avoid duplicates
  devicesList.clear();

  // Get paired devices (HC-06 must be paired first in phone settings)
  List<BluetoothDevice> pairedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
  setState(() {
    devicesList.addAll(pairedDevices);
  });

  // Start scanning for nearby devices
  FlutterBluetoothSerial.instance.startDiscovery().listen((BluetoothDiscoveryResult result) {
    setState(() {
      if (!devicesList.any((device) => device.address == result.device.address)) {
        devicesList.add(result.device);
      }
    });
  });

  // Stop scan after a delay and show the modal
  Timer(const Duration(seconds: 4), () {
    FlutterBluetoothSerial.instance.cancelDiscovery();
    setState(() {
      isScanning = false;
    });
    _showDeviceSelectionModal();
  });
}



void _showDeviceSelectionModal() {
  print('showModal here');
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Select a Bluetooth Device',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                final device = devicesList[index];
                return ListTile(
                  title: Text(device.name ?? 'Unknown Device'),  // HC-06 should show its name
                  subtitle: Text(device.address),  // Address is important for Classic Bluetooth
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}


void connectToDevice(BluetoothDevice device) async {
  try {
    BluetoothConnection connection = await BluetoothConnection.toAddress(device.address);
    print('Connected to ${device.name}');

    setState(() {
      connectedDevice = device;
      bluetoothConnection = connection;
    });

    if (mounted) { 
      Navigator.pop(context);
    }

    startReceivingData();
  } catch (e) {
    print('Error connecting to device: $e');
  }
}


  @override 
dispose() {
  FlutterBluetoothSerial.instance.cancelDiscovery();
  bluetoothConnection?.close();
  timer?.cancel();
  super.dispose();
}

void sendData(String data) async {
  if (bluetoothConnection != null && bluetoothConnection!.isConnected) {
    bluetoothConnection!.output.add(utf8.encode(data));
    await bluetoothConnection!.output.allSent; // Ensure data is sent
    print('Sent: $data');
  } else {
    print('Device not connected');
  }
}

void onTimerSelected(int value) async {
  selectedTime = value;

  if (bluetoothConnection != null && bluetoothConnection!.isConnected) {
    String command = "T_R($selectedTime)";
    
    bluetoothConnection!.output.add(utf8.encode(command));
    await bluetoothConnection!.output.allSent; // Ensure data is sent

    print("Sent command: $command");
  } else {
    print('Device not connected');
  }
}

void startReceivingData() {
  if (bluetoothConnection != null && bluetoothConnection!.isConnected) {
    bluetoothConnection!.input!.listen((Uint8List data) {
      String receivedData = utf8.decode(data).trim();
      
      try {
        currentAngle = double.parse(receivedData); // Assuming the received format is valid
        print("Received Angle: $currentAngle");
      } catch (e) {
        print("Error parsing angle data: $e");
      }

      setState(() {}); // Update the UI
    }).onDone(() {
      print("Disconnected from device.");
    });
  } else {
    print("Device not connected.");
  }
}


  void stopReceivingData() {
    timer?.cancel();
  }

@override
Widget build(BuildContext context) {
  double rotationAngle = (90 - (backDegree * 0.9)) * (3.14 / 180);
  return Scaffold(
    appBar: AppBar(
      backgroundColor: const Color.fromRGBO(185, 223, 254, 1),
      title: const Text('Fixture', style: TextStyle(fontSize: 23.0, color: Colors.black)),
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: [
  IconButton(
    onPressed: () {
      startBluetoothScan();
    },
    icon: const Icon(Icons.bluetooth),
  ),
],
    ),
    body: isScanning 
    ? Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      color: const Color.fromRGBO(185, 223, 254, 1),
      child: Center(
        child: RotationTransition(
            turns: controller,
            child: logoBytes != null ? Image.memory(logoBytes!) : Container(),
          ),
      ),
    )
    : SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height,
        color: const Color.fromRGBO(185, 223, 254, 1),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  color: const Color.fromRGBO(185, 223, 254, 1),
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/logo.svg',
                        width: 100,
                        height: 100,
                      ),
                      connectedDevice?.isConnected ?? false 
                        ? const Text('Connected', style: TextStyle(color: Colors.black)) 
                        : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.15,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${currentAngle.toStringAsFixed(1)}°", style: const TextStyle(fontSize: 25.0, color: Colors.indigo)),
                        Text('Your posture position', style: TextStyle(fontSize: 15.0, color: Colors.indigo.withOpacity(0.5)))
                      ],
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                            color: backDegree > 50 ? Colors.greenAccent : Colors.red
                          ),
                        ),
                        Transform.rotate(
                          angle: rotationAngle,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ),
              const SizedBox(height: 10.0),
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Position',
                          style: TextStyle(
                            fontSize: 25.0,
                            color: Colors.indigo,
                          )
                        )
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Sitting Button
                          ElevatedButton(
                            onPressed: () {
                              sendData('P_RO');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/sitting.png',
                                  width: 70, 
                                  height: 70,
                                ),
                                const SizedBox(height: 10.0),
                                const Text(
                                  'Sitting',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.black,
                                  )
                                )
                              ],
                            ),
                          ),
                          // Standing Button
                          ElevatedButton(
                            onPressed: () {
                              sendData('P_RT');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/standing.png',
                                  width: 70, 
                                  height: 70,
                                ),
                                const SizedBox(height: 10.0),
                                const Text(
                                  'Standing',
                                  style: TextStyle(
                                    fontSize: 15.0,
                                    color: Colors.black,
                                  )
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Timer:',
                            style: TextStyle(
                              fontSize: 20.0,
                              color: Colors.black,
                            )
                          ),
                          DropdownButton<int>(
                            value: selectedTime,
                            icon: const Icon(Icons.timer, color: Colors.indigo),
                            menuMaxHeight: 150.0,
                            borderRadius: BorderRadius.circular(10.0),
                            onChanged: (int? newValue) {
                              setState(() {
                                selectedTime = newValue!;
                                sendData('T_R($selectedTime)');
                              });
                            },
                            items: timerOptions.map<DropdownMenuItem<int>>((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(formatTime(value)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Customized tuning',
                            style: TextStyle(
                              fontSize: 20.0,
                              color: Colors.black,
                            )
                          ),
                          Switch(
                            value: isSwitchOn,
                            onChanged: (bool value) {
                              setState(() {
                                isSwitchOn = value;
                                if (isSwitchOn) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TuningSettingsPage()),
                                  );
                                }
                              });
                            },
                            activeColor: Colors.indigo, 
                            inactiveThumbColor: Colors.indigo,
                            inactiveTrackColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ),
              const SizedBox(height: 10.0),
              Container(
                height: MediaQuery.of(context).size.height * 0.25,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0)
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Tuning', style: TextStyle(fontSize: 25.0, color: Colors.indigo))
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  sendData('N_TN');
                                }, 
                                icon: const Icon(Icons.notifications_active_outlined),
                                iconSize: 35.0,
                              ),
                              const SizedBox(height: 5.0),
                              const Text('Notification', style: TextStyle(fontSize: 15.0, color: Colors.black))
                            ],
                          ),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () {
                                  sendData('N_TV');
                                }, 
                                icon: const Icon(Icons.vibration_outlined),
                                iconSize: 35.0,
                              ),
                              const SizedBox(height: 5.0),
                              const Text('Vibration', style: TextStyle(fontSize: 15.0, color: Colors.black))

                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Vibration Intensity:'),
                            DropdownButton<int>(
                              value: selectedPercent,
                              menuMaxHeight: 150.0,
                              borderRadius: BorderRadius.circular(10.0),
                              onChanged: (int? newValue) {
                                setState(() {
                                  selectedPercent = newValue!;
                                  sendData('V_R($selectedPercent)');
                                });
                              },
                              items: percentOptions.map<DropdownMenuItem<int>>((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(formatPercent(value)),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        )
      )
    );
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0 && remainingSeconds > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${remainingSeconds}s';
    }
  }

  String formatPercent(int percents) {
    return '$percents %';
  }
}