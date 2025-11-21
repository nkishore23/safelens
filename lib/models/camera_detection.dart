class CameraDetection {
  final String location;
  final int confidence;
  final String type;
  final DateTime timestamp;

  CameraDetection({
    required this.location,
    required this.confidence,
    required this.type,
    required this.timestamp,
  });
}