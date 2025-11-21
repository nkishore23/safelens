class DetectedDevice {
  final String name;
  final String ipAddress;
  final int riskLevel;
  final String type;

  DetectedDevice({
    required this.name,
    required this.ipAddress,
    required this.riskLevel,
    required this.type,
  });
}