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
  
  double? elapsedTime;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.high);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
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
        title: const Text('Görüntü İşlemeli Düşme Tespiti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                selectedBox = null;
                isTracking = false;
                elapsedTime = null;
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
            },
            child: CameraPreview(controller!),
          ),
          if (selectedBox != null)
            Positioned.fromRect(
              rect: selectedBox!,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isTracking ? Colors.green : Colors.red,
                    width: 3,
                  ),
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedBox == null
                          ? 'Parmağınızla ekrandaki cismin etrafına bir kutu çizin.'
                          : (isTracking ? 'Cisim kilitlendi! Düşüş bekleniyor...' : 'Seçim yapılıyor...'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (elapsedTime != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Düşüş Süresi: ${elapsedTime!.toStringAsFixed(3)} s',
                        style: const TextStyle(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold),
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
