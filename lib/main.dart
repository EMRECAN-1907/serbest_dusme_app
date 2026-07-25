import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const SerbestDusmeApp());
}

class SerbestDusmeApp extends StatelessWidget {
  const SerbestDusmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const OtomatikDusmeSayfasi(),
    );
  }
}

class OtomatikDusmeSayfasi extends StatefulWidget {
  const OtomatikDusmeSayfasi({super.key});

  @override
  State<OtomatikDusmeSayfasi> createState() => _OtomatikDusmeSayfasiState();
}

class _OtomatikDusmeSayfasiState extends State<OtomatikDusmeSayfasi> {
  CameraController? controller;
  Rect? selectedBox;
  Offset? startPoint;
  
  bool isReadyToDetect = false;
  bool isRunning = false;
  bool isFinished = false;
  
  Stopwatch stopwatch = Stopwatch();
  double? finalTime;
  double? calculatedHeight;
  double? calculatedVelocity;
  
  int? baselineTopLuma;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  void _startCameraAnalysis() {
    if (controller == null || !controller!.value.isInitialized) return;
    
    stopwatch.reset();
    isRunning = false;
    isFinished = false;
    finalTime = null;
    baselineTopLuma = null;

    controller!.startImageStream((CameraImage image) {
      if (!isReadyToDetect || isFinished) return;

      try {
        if (image.format.group == ImageFormatGroup.yuv420) {
          final bytes = image.planes[0].bytes;
          int width = image.width;
          int height = image.height;

          // Çizilen kutunun içindeki piksel/ışık değişimini analiz et
          if (selectedBox != null) {
            int boxX = (selectedBox!.left * width / MediaQuery.of(context).size.width).clamp(0, width - 10).toInt();
            int boxY = (selectedBox!.top * height / MediaQuery.of(context).size.height).clamp(0, height - 10).toInt();
            int boxW = (selectedBox!.width * width / MediaQuery.of(context).size.width).clamp(10, width - boxX).toInt();
            int boxH = (selectedBox!.height * height / MediaQuery.of(context).size.height).clamp(10, height - boxY).toInt();

            int sum = 0;
            int count = 0;
            for (int y = boxY; y < boxY + boxH; y += 4) {
              for (int x = boxX; x < boxX + boxW; x += 4) {
                int index = y * width + x;
                if (index < bytes.length) {
                  sum += bytes[index];
                  count++;
                }
              }
            }

            int currentLuma = count > 0 ? (sum ~/ count) : 0;

            if (baselineTopLuma == null) {
              baselineTopLuma = currentLuma;
            } else if (!isRunning) {
              int diff = (currentLuma - baselineTopLuma!).abs();
              if (diff > 15) { // Cisim bırakıldığı an hareket algılandı!
                stopwatch.start();
                setState(() {
                  isRunning = true;
                });
                controller!.stopImageStream(); // İşlemciyi yormamak için akışı durdur
              }
            }
          }
        }
      } catch (e) {
        // Hata yönetimi
      }
    });
  }

  void _stopTimerManually() {
    if (stopwatch.isRunning) {
      stopwatch.stop();
      double t = stopwatch.elapsedMicroseconds / 1000000.0;
      double g = 9.81;
      setState(() {
        finalTime = t;
        calculatedHeight = 0.5 * g * pow(t, 2).toDouble();
        calculatedVelocity = g * t;
        isFinished = true;
        isReadyToDetect = false;
      });
      if (controller?.value.isStreamingImages == true) {
        controller!.stopImageStream();
      }
    }
  }

  @override
  void dispose() {
    if (controller?.value.isStreamingImages == true) {
      controller!.stopImageStream();
    }
    controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı Serbest Düşme Lab'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sıfırla',
            onPressed: () {
              if (controller?.value.isStreamingImages == true) {
                controller!.stopImageStream();
              }
              setState(() {
                selectedBox = null;
                isReadyToDetect = false;
                isRunning = false;
                isFinished = false;
                finalTime = null;
                calculatedHeight = null;
                calculatedVelocity = null;
                stopwatch.reset();
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) {
              if (isFinished) return;
              setState(() {
                startPoint = details.localPosition;
                selectedBox = Rect.fromPoints(startPoint!, startPoint!);
                isReadyToDetect = false;
                isRunning = false;
              });
            },
            onPanUpdate: (details) {
              if (isFinished) return;
              setState(() {
                if (startPoint != null) {
                  selectedBox = Rect.fromPoints(startPoint!, details.localPosition);
                }
              });
            },
            onPanEnd: (details) {
              if (selectedBox != null) {
                setState(() {
                  isReadyToDetect = true;
                });
                _startCameraAnalysis();
              }
            },
            child: CameraPreview(controller!),
          ),

          if (selectedBox != null)
            Positioned.fromRect(
              rect: selectedBox!,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isRunning ? Colors.amber : (isReadyToDetect ? Colors.green : Colors.red),
                    width: 3,
                  ),
                  color: isRunning ? Colors.amber.withOpacity(0.3) : Colors.green.withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    isRunning ? 'DÜŞÜYOR...' : (isReadyToDetect ? 'KİLİTLENDİ' : 'ÇİZİLİYOR'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 25,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedBox == null
                          ? '1. Adım: Cismi tuttuğunuz başlangıç yerine kutu çizin.'
                          : (isRunning
                              ? 'Kronometre çalışıyor! Yere çarpınca durdurun.'
                              : (isReadyToDetect
                                  ? 'Cisim kilitlendi! Şimdi serbest bırakın.'
                                  : 'Kutuyu çizmeyi tamamlayın.')),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isRunning ? Colors.amberAccent : Colors.white,
                      ),
                    ),
                    
                    if (isRunning && !isFinished) ...[
                      const SizedBox(height: 15),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _stopTimerManually,
                        child: const Text(
                          'YERE ÇARPTI (DURDUR)',
                          style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],

                    if (finalTime != null) ...[
                      const SizedBox(height: 15),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        'Geçen Süre (t): ${finalTime!.toStringAsFixed(3)} s',
                        style: const TextStyle(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            'Yükseklik: ${calculatedHeight!.toStringAsFixed(2)} m',
                            style: const TextStyle(fontSize: 16, color: Colors.lightBlueAccent),
                          ),
                          Text(
                            'Çarpma Hızı: ${calculatedVelocity!.toStringAsFixed(2)} m/s',
                            style: const TextStyle(fontSize: 16, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
