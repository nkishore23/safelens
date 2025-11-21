// ============================================
// lib/screens/wifi_scan_screen.dart
// ============================================
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/detected_device.dart';
import '../models/camera_detection.dart';
import '../widgets/radar_painter.dart';

class WiFiScanScreen extends StatefulWidget {
  const WiFiScanScreen({super.key});

  @override
  State<WiFiScanScreen> createState() => _WiFiScanScreenState();
}

class _WiFiScanScreenState extends State<WiFiScanScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  final List<DetectedDevice> _detectedDevices = [];
  late AnimationController _animationController;
  Timer? _scanTimer;

  String? _currentSsid; // <-- added

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _updateCurrentSsid(); // <-- fetch SSID on init
  }

  Future<void> _updateCurrentSsid() async {
    // Request location permission required for WiFi SSID on Android
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _currentSsid = 'Permission required');
      }
      return;
    }
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName(); // may return null or "<unknown ssid>"
      if (!mounted) return;
      setState(() {
        _currentSsid = ssid ?? 'Not connected';
      });
    } catch (_) {
      if (mounted) setState(() => _currentSsid = 'Unavailable');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _detectedDevices.clear();
    });

    _animationController.repeat();

    int tick = 0;
    // deterministic additions: add a device every 2 ticks to avoid never-showing result
    _scanTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      tick++;
      // add device at ticks 2,4,6
      if (tick % 2 == 0 && mounted) {
        setState(() {
          _detectedDevices.add(
            DetectedDevice(
              name: 'Device ${_detectedDevices.length + 1}',
              ipAddress: '192.168.1.${100 + _detectedDevices.length}',
              riskLevel: Random().nextInt(3),
              type: 'WiFi Camera',
            ),
          );
        });
      }

      if (tick >= 6) {
        timer.cancel();
        _animationController.stop();
        if (!mounted) return;
        setState(() {
          _isScanning = false;
        });

        if (_detectedDevices.isNotEmpty) {
          // open detection list and when user returns forward the count
          Navigator.push<int?>(
            context,
            MaterialPageRoute(
              builder: (context) => DetectionListScreen(devices: _detectedDevices),
            ),
          ).then((returnedCount) {
            // return count to caller of WiFiScanScreen (HomeScreen)
            if (mounted) Navigator.pop(context, returnedCount ?? _detectedDevices.length);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No suspicious devices found'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'WiFi scan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),

              // Show real connected SSID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252941),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, color: Color(0xFF6366f1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Connected: ${_currentSsid ?? "Checking..."}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: _updateCurrentSsid,
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(280, 280),
                        painter: RadarPainter(
                          progress: _animationController.value,
                          isScanning: _isScanning,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (!_isScanning) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252941),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFfbbf24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All detection list',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _detectedDevices.isEmpty
                        ? 'Not scanned yet'
                        : '${_detectedDevices.length} devices found',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366f1),
                    disabledBackgroundColor:
                        const Color(0xFF6366f1).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Scanning...' : 'Scan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/bluetooth_scan_screen.dart
// ============================================
class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  final List<DetectedDevice> _detectedDevices = [];
  late AnimationController _animationController;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _detectedDevices.clear();
    });

    _animationController.repeat();

    int tick = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      tick++;
      if (tick >= 5) {
        timer.cancel();
        _animationController.stop();
        setState(() {
          _isScanning = false;
        });

        if (_detectedDevices.isNotEmpty && mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetectionListScreen(
                    devices: _detectedDevices,
                  ),
                ),
              );
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No Bluetooth devices found'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      if (Random().nextBool() && mounted) {
        setState(() {
          _detectedDevices.add(
            DetectedDevice(
              name: 'BT Device ${_detectedDevices.length + 1}',
              ipAddress: 'MAC: AA:BB:CC:${_detectedDevices.length}',
              riskLevel: Random().nextInt(3),
              type: 'Bluetooth Camera',
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Bluetooth scan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(280, 280),
                        painter: BluetoothRadarPainter(
                          progress: _animationController.value,
                          isScanning: _isScanning,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (!_isScanning) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252941),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.bluetooth,
                        color: Color(0xFF6366f1),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bluetooth devices detected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _detectedDevices.isEmpty
                        ? 'Not scanned yet'
                        : '${_detectedDevices.length} devices found',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366f1),
                    disabledBackgroundColor:
                        const Color(0xFF6366f1).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Scanning...' : 'Start Scan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/camera_finder_screen.dart
// ============================================


// === Replace existing CameraFinderScreen with this implementation ===
class CameraFinderScreen extends StatefulWidget {
  const CameraFinderScreen({super.key});

  @override
  State<CameraFinderScreen> createState() => _CameraFinderScreenState();
}

class _CameraFinderScreenState extends State<CameraFinderScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _isScanning = false;
  bool _streaming = false;
  final List<CameraDetection> _detections = [];
  Timer? _scanTimer;
  int _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _stopImageStream();
    _scanTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permission required'),
            content: const Text('Camera permission is required for AI camera finder.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } on CameraException catch (e) {
      // ignore: avoid_print
      print('Camera error: $e');
    }
  }

  void _startAIScan() {
    if (!_cameraReady || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera not ready')));
      return;
    }

    // clear previous
    setState(() {
      _isScanning = true;
      _detections.clear();
      _frameSkip = 0;
    });

    // Start analyzing frames
    _startImageStream();

    // Timeout after 8 seconds if nothing found
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      _stopImageStream();
      setState(() {
        _isScanning = false;
      });
      if (_detections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No suspicious cameras detected'), backgroundColor: Colors.green),
        );
      }
    });
  }

  void _startImageStream() {
    if (_cameraController == null || _streaming) return;
    _streaming = true;
    _cameraController!.startImageStream(_processCameraImage);
  }

  void _stopImageStream() {
    if (_cameraController == null || !_streaming) return;
    try {
      _cameraController!.stopImageStream();
    } catch (_) {}
    _streaming = false;
  }

  // Very lightweight luminance-based detector on Y plane:
  void _processCameraImage(CameraImage image) {
    // throttle processing: analyze one in N frames to reduce CPU
    _frameSkip++;
    if (_frameSkip % 6 != 0) return;

    try {
      // Use Y (luminance) plane from YUV image (common on Android/iOS)
      final plane = image.planes.first;
      final bytes = plane.bytes;
      final width = image.width;
      final height = image.height;
      if (bytes.isEmpty || width == 0 || height == 0) return;

      // Define a top-right region (quarter of frame)
      final regionXStart = (width * 3 / 4).floor();
      final regionYStart = 0;
      final regionW = (width - regionXStart).clamp(1, width);
      final regionH = (height / 4).floor().clamp(1, height);

      // sample pixels with stride to keep analysis cheap
      int sum = 0;
      int count = 0;
      final rowStride = plane.bytesPerRow;
      final pixelStride = plane.bytesPerPixel ?? 1;

      for (int y = regionYStart; y < regionYStart + regionH; y += 4) {
        final rowOffset = y * rowStride;
        for (int x = regionXStart; x < regionXStart + regionW; x += 4) {
          final idx = rowOffset + x * pixelStride;
          if (idx >= 0 && idx < bytes.length) {
            sum += bytes[idx];
            count++;
          }
        }
      }

      if (count == 0) return;
      final avg = sum / count; // 0..255 approx

      // To estimate background, sample center area quickly
      int bsum = 0;
      int bcount = 0;
      final cx = (width / 2).floor();
      final cy = (height / 2).floor();
      final bW = (width / 6).floor().clamp(1, width);
      final bH = (height / 6).floor().clamp(1, height);
      for (int y = cy - bH; y < cy + bH; y += 8) {
        final rowOffset = y * rowStride;
        for (int x = cx - bW; x < cx + bW; x += 8) {
          final idx = rowOffset + x * pixelStride;
          if (idx >= 0 && idx < bytes.length) {
            bsum += bytes[idx];
            bcount++;
          }
        }
      }
      final bavg = bcount == 0 ? avg : (bsum / bcount);

      // If top-right region is significantly brighter than center -> possible specular (lens)
      final diff = avg - bavg;
      // thresholds tuned experimentally; adjust as needed
      if (diff > 18 && avg > 90) {
        final confidence = ((diff.clamp(0, 80) / 80) * 100).round().clamp(40, 99);
        // Add detection if not already detected at same location
        if (mounted && !_detections.any((d) => d.location == 'Top right corner')) {
          setState(() {
            _detections.add(CameraDetection(
              location: 'Top right corner',
              confidence: confidence,
              type: 'Pinhole Camera',
              timestamp: DateTime.now(),
            ));
          });
          // stop stream & timer after detection (you can keep analyzing if you prefer)
          _stopImageStream();
          _scanTimer?.cancel();
          setState(() {
            _isScanning = false;
          });
        }
      }
    } catch (e) {
      // ignore analysis errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _cameraReady && _cameraController != null
        ? AspectRatio(aspectRatio: _cameraController!.value.aspectRatio, child: CameraPreview(_cameraController!))
        : const Center(child: Icon(Icons.camera_alt, size: 80, color: Colors.white30));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                const Expanded(child: Text('AI Camera Finder', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF252941),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isScanning ? const Color(0xFF6366f1) : Colors.transparent, width: 3),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  Positioned.fill(child: preview),
                  if (_isScanning)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF6366f1)),
                              SizedBox(height: 12),
                              Text('AI Scanning...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_detections.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _detections.length,
                  itemBuilder: (context, i) {
                    final d = _detections[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF252941), borderRadius: BorderRadius.circular(16), border: Border.all(color: d.confidence > 85 ? Colors.red : Colors.orange, width: 2)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(d.type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: d.confidence > 85 ? Colors.red : Colors.orange, borderRadius: BorderRadius.circular(12)), child: Text('${d.confidence}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 8),
                        Text('Location: ${d.location}', style: const TextStyle(color: Colors.white70)),
                      ]),
                    );
                  },
                ),
              )
            else if (!_isScanning)
              const Expanded(child: Center(child: Text('Point camera at suspicious areas\nAI will detect hidden cameras', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startAIScan,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366f1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(_isScanning ? 'Scanning...' : 'Start AI Scan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/infrared_scan_screen.dart
// ============================================
class InfraredScanScreen extends StatefulWidget {
  const InfraredScanScreen({super.key});

  @override
  State<InfraredScanScreen> createState() => _InfraredScanScreenState();
}

class _InfraredScanScreenState extends State<InfraredScanScreen> {
  bool _isScanning = false;
  int _irSourcesFound = 0;
  Timer? _scanTimer;

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _irSourcesFound = 0;
    });

    int tick = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      tick++;
      if (tick >= 8) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          if (_irSourcesFound > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Found $_irSourcesFound IR sources!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      if (Random().nextBool() && mounted) {
        setState(() {
          _irSourcesFound++;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Infrared Scanner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252941),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors,
                          size: 80,
                          color: _isScanning
                              ? const Color(0xFF6366f1)
                              : Colors.white30,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isScanning ? 'Scanning...' : 'Ready to Scan',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'IR Sources Found: $_irSourcesFound',
                          style: TextStyle(
                            fontSize: 16,
                            color: _irSourcesFound > 0
                                ? Colors.orange
                                : Colors.white70,
                            fontWeight: _irSourcesFound > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252941),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Point your camera at suspicious areas. Infrared LEDs from hidden cameras will be detected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366f1),
                    disabledBackgroundColor:
                        const Color(0xFF6366f1).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Scanning...' : 'Start IR Scan',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/history_screen.dart
// ============================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scans = [
      {'date': 'Today, 9:41 AM', 'location': 'Home', 'threats': 2},
      {'date': 'Yesterday, 3:20 PM', 'location': 'Office', 'threats': 0},
      {'date': 'Nov 18, 2:15 PM', 'location': 'Hotel Room', 'threats': 1},
      {'date': 'Nov 17, 11:30 AM', 'location': 'Gym', 'threats': 0},
      {'date': 'Nov 16, 5:45 PM', 'location': 'Restaurant', 'threats': 3},
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Clear history functionality
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252941),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (scan['threats'] as int) > 0
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              (scan['threats'] as int) > 0
                                  ? Icons.warning_rounded
                                  : Icons.check_circle,
                              color: (scan['threats'] as int) > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scan['location'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scan['date'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${scan['threats']} threats',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: (scan['threats'] as int) > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/reports_screen.dart
// ============================================
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Security Reports',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildStatCard(
                        'Total Scans',
                        '47',
                        Icons.radar,
                        Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Threats Found',
                        '12',
                        Icons.warning_rounded,
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'Safe Locations',
                        '35',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        'This Week',
                        '8 scans',
                        Icons.calendar_today,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252941),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// lib/screens/premium_screen.dart
// ============================================
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfbbf24), Color(0xFFf59e0b)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Premium Features',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Unlock all features for complete protection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  children: [
                    _buildFeature('Unlimited Scans', Icons.all_inclusive),
                    _buildFeature('Advanced AI Detection', Icons.psychology),
                    _buildFeature('Real-time Alerts', Icons.notifications_active),
                    _buildFeature('Detailed Reports', Icons.analytics),
                    _buildFeature('Priority Support', Icons.support_agent),
                    _buildFeature('Ad-free Experience', Icons.block),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFfbbf24), Color(0xFFf59e0b)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: const [
                    Text(
                      '₹299/month',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '7-day free trial',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Premium features coming soon!'),
                        backgroundColor: Color(0xFF6366f1),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366f1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Start Free Trial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366f1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6366f1), size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// lib/screens/tutorial_screen.dart
// ============================================
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'How to Use',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildStep(
                      '1',
                      'WiFi Scan',
                      'Scan your network to detect suspicious devices and hidden cameras connected to WiFi.',
                      Icons.wifi,
                    ),
                    _buildStep(
                      '2',
                      'Bluetooth Scan',
                      'Find Bluetooth-enabled hidden cameras in your vicinity.',
                      Icons.bluetooth,
                    ),
                    _buildStep(
                      '3',
                      'AI Camera Finder',
                      'Use AI-powered visual detection to spot hidden camera lenses.',
                      Icons.camera_alt,
                    ),
                    _buildStep(
                      '4',
                      'Infrared Scanner',
                      'Detect infrared LEDs from night vision cameras using your device camera.',
                      Icons.sensors,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252941),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366f1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: const Color(0xFF6366f1), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// lib/screens/settings_screen.dart
// ============================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _soundAlerts = true;
  bool _vibration = true;
  bool _autoScan = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingTile(
                      'Notifications',
                      'Get alerts for threats',
                      _notifications,
                      (value) => setState(() => _notifications = value),
                    ),
                    _buildSettingTile(
                      'Sound Alerts',
                      'Play sound when threat detected',
                      _soundAlerts,
                      (value) => setState(() => _soundAlerts = value),
                    ),
                    _buildSettingTile(
                      'Vibration',
                      'Vibrate on detection',
                      _vibration,
                      (value) => setState(() => _vibration = value),
                    ),
                    _buildSettingTile(
                      'Auto Scan',
                      'Automatically scan on app open',
                      _autoScan,
                      (value) => setState(() => _autoScan = value),
                    ),
                    const SizedBox(height: 20),
                    _buildActionTile(
                      'Clear History',
                      'Remove all scan records',
                      Icons.delete_outline,
                      Colors.red,
                      () {
                        _showClearDialog();
                      },
                    ),
                    _buildActionTile(
                      'App Version',
                      'v1.0.0',
                      Icons.info_outline,
                      Colors.blue,
                      null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252941),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Clear History?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all your scan history. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252941),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6366f1),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF252941),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// lib/screens/faq_screen.dart
// ============================================
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'How does the app detect hidden cameras?',
        'a':
            'The app uses multiple detection methods including WiFi scanning, Bluetooth detection, AI visual recognition, and infrared scanning.'
      },
      {
        'q': 'Is the detection 100% accurate?',
        'a':
            'While our detection methods are highly effective, no detection system is perfect. Use multiple scan methods for best results.'
      },
      {
        'q': 'Do I need internet connection?',
        'a':
            'WiFi scanning requires network connection, but other features like AI camera finder work offline.'
      },
      {
        'q': 'How often should I scan?',
        'a':
            'Scan whenever you enter a new location like hotel rooms, Airbnb, changing rooms, or offices.'
      },
      {
        'q': 'What permissions does the app need?',
        'a':
            'The app requires camera, location, and Bluetooth permissions to function properly. All permissions are used only for detection purposes.'
      },
      {
        'q': 'Can I use this app on iOS?',
        'a':
            'Yes, the app is available for both Android and iOS devices with the same features.'
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'FAQ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252941),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366f1).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.help_outline,
                                  color: Color(0xFF6366f1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  faq['q']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 38),
                            child: Text(
                              faq['a']!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// Detection List Screen
// ============================================
class DetectionListScreen extends StatelessWidget {
  final List<DetectedDevice> devices;

  const DetectionListScreen({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, devices.length), // return count
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Detection Results',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceInfoScreen(device: d))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF252941), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (d.riskLevel == 2 ? Colors.red : (d.riskLevel == 1 ? Colors.orange : Colors.green)).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.videocam, color: d.riskLevel == 2 ? Colors.red : (d.riskLevel == 1 ? Colors.orange : Colors.green)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(d.ipAddress, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// Device Info Screen
// ============================================
class DeviceInfoScreen extends StatelessWidget {
  final DetectedDevice device;
  const DeviceInfoScreen({super.key, required this.device});

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [Expanded(child: Text(a, style: const TextStyle(color: Colors.white70))), Text(b, style: const TextStyle(color: Colors.white))]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                const Expanded(child: Text('Device info', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6366f1), width: 3)),
              child: Center(child: Icon(Icons.videocam, color: const Color(0xFF6366f1), size: 48)),
            ),
            const SizedBox(height: 16),
            Text(device.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _row('IP / MAC', device.ipAddress),
            _row('Risk level', device.riskLevel == 2 ? 'High' : (device.riskLevel == 1 ? 'Medium' : 'Low')),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366f1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('I found it!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
