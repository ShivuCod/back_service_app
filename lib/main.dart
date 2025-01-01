import 'dart:async';
import 'dart:ui';

import 'package:back_service_app/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

final notificationChannelId = "MY_CHANNEL";
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ActivityRecognitionApp(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String text = "start";
  String location = "Unknown";
  final StreamController<String> _locationStreamController =
      StreamController<String>();

  @override
  void initState() {
    _checkAndRequestPermissions();
    _listenToLocationUpdates();
    super.initState();
  }

  Future<void> _checkAndRequestPermissions() async {
    LocationPermission locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      locationPermission = await Geolocator.requestPermission();
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  void _listenToLocationUpdates() {
    FlutterBackgroundService().on('update').listen((data) {
      if (data != null) {
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        
        _locationStreamController.add("$latitude, $longitude");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            StreamBuilder<String>(
              stream: _locationStreamController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  location = snapshot.data!;
                }
                return Text("Location: $location");
              },
            ),
            ElevatedButton(
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsForeground");
                },
                child: Text("set foreground")),
            ElevatedButton(
                onPressed: () {
                  FlutterBackgroundService().invoke("setAsBackground");
                },
                child: Text("setForeground")),
            ElevatedButton(
                onPressed: () async {
                  final service = FlutterBackgroundService();
                  if (await service.isRunning()) {
                    service.invoke("stopService");
                    text = "start";
                  } else {
                    service.startService();
                    text = "stop";
                  }
                  setState(() {});
                },
                child: Text(text)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationStreamController.close();
    super.dispose();
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIOSBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: false,
    ),
  );
  debugPrint("Service initialized");
}

@pragma("vm:entry-point")
Future<bool> onIOSBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma("vm:entry-point")
onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(Duration(seconds: 1), (timer) async {
    Position position = await Geolocator.getCurrentPosition();
    service.invoke("update", {
      "latitude": position.latitude,
      "longitude": position.longitude,
    });
  });
  print("Service started");
}
