import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  // Request Camera Permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // Request Bluetooth Permissions
  static Future<bool> requestBluetoothPermissions() async {
    if (await Permission.bluetoothScan.isPermanentlyDenied ||
        await Permission.bluetoothConnect.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
  }

  // Request Location Permission (for WiFi scanning)
  static Future<bool> requestLocationPermission() async {
    if (await Permission.location.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    final status = await Permission.location.request();
    return status.isGranted;
  }

  // Request all permissions at once
  static Future<Map<String, bool>> requestAllPermissions() async {
    return {
      'camera': await requestCameraPermission(),
      'bluetooth': await requestBluetoothPermissions(),
      'location': await requestLocationPermission(),
    };
  }

  // Check if permission is granted
  static Future<bool> isCameraGranted() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> isBluetoothGranted() async {
    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted;
  }

  static Future<bool> isLocationGranted() async {
    return await Permission.location.isGranted;
  }
}