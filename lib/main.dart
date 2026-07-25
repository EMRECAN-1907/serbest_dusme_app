import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

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
      home: const KameraTakipSayfasi(),
    );
  }
}

class KameraTakipSayfasi extends StatefulWidget {
  const KameraTakipSayfasi({super.key});

  @override
  State<KameraTakipSayfasi> createState() => _KameraTakipSayfasiState();
}

class _KameraTakipSayfasiState extends State<KameraTakipSayfasi> {
  CameraController? controller;
  Rect? selectedBox;
  Offset? startPoint;
  
  bool isTracking = false;
  bool isProcessing = false;
  bool timerStarted = false;
  
  Stopwatch stopwatch = Stopwatch();
  double? elapsedTime;
  int? referenceLuma; // Cismin ilk kilitlendiği anki ışık/renk değeri

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      // Görüntü işlemenin telefonu kitlememesi için Medium çözünürlük
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  void _startVisionProcessing() {
    if (controller == null || !controller!.value.isInitialized) return;
    
    stopwatch.reset();
    timerStarted = false;
    referenceLuma = null;

    // Kameradan saniyede 30 kare (frame) okumaya başlıyoruz
    controller!.startImageStream((CameraImage image) {
      if (!isTracking || isProcessing || timerStarted) return;
      isProcessing = true;

      try {
        if (image.format.group == ImageFormatGroup.yuv420) {
          final bytes = image.planes[0].bytes; 
          
          int sampleSum = 0;
          int sampleCount = 0;
          
          // Sensör algılaması: Görüntünün merkez piksellerinin renk/ışık ortalamasını alıyoruz
          int startIdx = (bytes.length ~/ 2) - 1000;
          for (int i = startIdx; i < startIdx + 2000; i += 2) {
            if (i > 0 && i < bytes.length) {
              sampleSum += bytes[i];
              sampleCount++;
            }
          }
          
          int currentLuma = sampleCount > 0 ? (sampleSum ~/ sampleCount) : 0;

          if (referenceLuma == null) {
            // Cisim ilk çizildiğinde pikselleri hafızaya kaydet
            referenceLuma = currentLuma;
          } else {
            // Cisim aşağı kaydığında pikseller (ışık) referanstan sapar
            int difference = (currentLuma - referenceLuma!).abs();
            if (difference > 12) { // Hassasiyet eşiği: Cisim hareket etti!
              stopwatch.start();
              setState(() {
                timerStarted = true;
              });
              // Süre başladığında telefonu rahatlatmak için arka plan analizini durdur
              controller!.stopImageStream();
            }
          }
        }
      } catch (e) {
        // Olası kamera okuma hatalarını yut
      } finally {
        isProcessing = false;
      }
    });
  }

  void _stopTimer() {
    if (stopwatch.isRunning) {
      stopwatch.stop();
      setState(() {
        elapsedTime = stopwatch.elapsedMilliseconds / 1000.0;
        isTracking = false;
      });
    }
  }

  @override
  void dispose() {
    if (controller?.value.isStreamingImages == true) {
      controller?.stopImageStream();
    }
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensörlü Düşme Tespiti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sıfırla',
            onPressed: () {
              if (controller?.value.isStreamingImages == true) {
                controller?.stopImageStream();
              }
              setState(() {
                selectedBox = null;
                isTracking = false;
                timerStarted = false;
                elapsedTime = null;
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
              setState(() {
                startPoint = details.localPosition;
                selectedBox = Rect.fromPoints(startPoint!, startPoint!);
                isTracking = false;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                if (startPoint != null) {
                  selectedBox = Rect.fromPoints(startPoint!, details.localPosition);
                }
              });
            },
            onPanEnd: (details) {
              setState(() {
                isTracking = true;
              });
              // Kutu çizimi bittiğinde görüntü işlemeyi başlat
              _startVisionProcessing();
            },
            child: CameraPreview(controller!),
          ),
          
          if (selectedBox != null)
            Positioned.fromRect(
              rect: selectedBox!,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: timerStarted ? Colors.transparent : (isTracking ? Colors.green : Colors.red),
                    width: 3,
                  ),
                  color: timerStarted ? Colors.transparent : Colors.red.withOpacity(0.2),
                ),
              ),
            ),
            
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedBox == null
                          ? 'Cismin etrafına parmağınızla kutu çizin.'
                          : (timerStarted 
                              ? 'DÜŞÜŞ ALGILANDI! KRONOMETRE ÇALIŞIYOR...' 
                              : 'Cisim kilitlendi. Düşmesi bekleniyor...'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: timerStarted ? FontWeight.bold : FontWeight.normal,
                        color: timerStarted ? Colors.amberAccent : Colors.white
                      ),
                    ),
                    if (timerStarted && elapsedTime == null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 70),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: _stopTimer,
                        child: const Text('YERE ÇARPTI (DURDUR)', 
                          style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                    if (elapsedTime != null) ...[
                      const SizedBox(height: 15),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 5),
                      Text(
                        'Ölçülen Süre (t): ${elapsedTime!.toStringAsFixed(3)} saniye',
                        style: const TextStyle(fontSize: 20, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ]
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
