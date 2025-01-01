import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'fetchLocation') {
      bool locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        print('Location services are disabled.');
        return Future.value(false);
      }
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen((Position position) {
        debugPrint(
            'setreaming Latitude: ${position.latitude}, Longitude: ${position.longitude}');
      });
    }
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _location = 'Location not fetched';
  bool _permissionsGranted = false;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // Check and request location permission
    LocationPermission locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      locationPermission = await Geolocator.requestPermission();
    }

    // Check and request notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Update state based on permissions
    setState(() {
      _permissionsGranted =
          locationPermission == LocationPermission.whileInUse ||
              locationPermission == LocationPermission.always;
    });
  }

  void _startService() async {
    if (_permissionsGranted) {
      Workmanager().registerPeriodicTask("service", "fetchLocation",
          initialDelay: Duration(seconds: 1));
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen((Position position) {
        setState(() {
          _location =
              'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background service started')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all required permissions')),
      );
    }
  }

  void _stopService() {
    _locationSubscription?.cancel();
    _locationSubscription = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Background service stopped')),
    );
  }

  void _fetchLocationManually() async {
    if (!_permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all required permissions')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _location =
          'Latitude: ${position.latitude}, Longitude: ${position.longitude}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location & Notification Service')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _fetchLocationManually,
            child: const Text('Fetch Location Manually'),
          ),
          ElevatedButton(
            onPressed: _startService,
            child: const Text('Start Background Service'),
          ),
          ElevatedButton(
            onPressed: _stopService,
            child: const Text('Stop Background Service'),
          ),
          const SizedBox(height: 20),
          Text(
            _location,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
