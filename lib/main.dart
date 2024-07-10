import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'QR Code Generator Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter phone number',
                hintText: '05555551234',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Klavyeyi kapat
                FocusScope.of(context).unfocus();
                setState(() {});
              },
              child: const Text('Generate QR Code'),
            ),
            const SizedBox(height: 20),
            if (_controller.text.isNotEmpty)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0), // 2 cm padding
                    color: Colors.white, // QR kod arkaplanı beyaz
                    child: QrImage(
                      data: 'tel:${_controller.text}',
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black, // QR kod içi siyah
                      errorStateBuilder: (cxt, err) {
                        return Container(
                          child: Center(
                            child: Text(
                              "Uh oh! Something went wrong...",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Scan the QR code and tap the phone number to make a call.',
                    style: TextStyle(fontSize: 16.0),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: SvgPicture.asset('assets/whatsapp.svg', height: 40),
                        onPressed: () => _shareQrCode(),
                      ),
                      IconButton(
                        icon: SvgPicture.asset('assets/instagram.svg', height: 40),
                        onPressed: () => _shareQrCode(),
                      ),
                      IconButton(
                        icon: SvgPicture.asset('assets/twitter.svg', height: 40),
                        onPressed: () => _shareQrCode(),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareQrCode() async {
    try {
      if (await _requestPermissions()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/qr_code.png';
        print('Saving QR code to $path');

        final qrValidationResult = QrValidator.validate(
          data: 'tel:${_controller.text}',
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.L,
        );

        if (qrValidationResult.status == QrValidationStatus.error) {
          print('Error generating QR code: ${qrValidationResult.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating QR code: ${qrValidationResult.error}')),
          );
          return;
        }

        final qrCode = qrValidationResult.qrCode;
        final painter = QrPainter.withQr(
          qr: qrCode!,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
          embeddedImageStyle: null,
          embeddedImage: null,
        );

        final picData = await painter.toImageData(2048, format: ui.ImageByteFormat.png);
        if (picData == null) {
          print('Failed to generate image data');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate image data')),
          );
          return;
        }

        final buffer = picData.buffer.asUint8List();
        final file = File(path);
        await file.writeAsBytes(buffer);

        // Resmi yeniden boyutlandır ve kenar boşlukları ekle
        final resizedFile = await _resizeImageWithPadding(file, 2400, 2400, 200);

        print('QR code saved successfully');

        await Share.shareFiles([resizedFile.path], text: 'Check out this QR code!');
      } else {
        print('Storage permission denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to share the QR code.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing QR code: $e')),
      );
      print('Error: $e');
    }
  }

  Future<File> _resizeImageWithPadding(File file, int width, int height, int padding) async {
    final originalImage = await decodeImageFromList(file.readAsBytesSync());

    final newWidth = width + padding * 2;
    final newHeight = height + padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint();
    canvas.drawColor(Colors.white, BlendMode.src);

    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
      Rect.fromLTWH(padding.toDouble(), padding.toDouble(), width.toDouble(), height.toDouble()),
      paint,
    );

    final newImage = await recorder.endRecording().toImage(newWidth, newHeight);
    final byteData = await newImage.toByteData(format: ui.ImageByteFormat.png);

    final buffer = byteData!.buffer.asUint8List();
    final resizedFile = File('${file.path}_resized.png');
    await resizedFile.writeAsBytes(buffer);

    return resizedFile;
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      } else {
        var status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          openAppSettings();
        }
      }
    } else if (Platform.isIOS) {
      // iOS için özel izin gerekmiyor
      return true;
    } else {
      if (await Permission.storage.isGranted) {
        return true;
      } else {
        var status = await Permission.storage.request();
        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          openAppSettings();
        }
      }
    }
    return false;
  }
}
