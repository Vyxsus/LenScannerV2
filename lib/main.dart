import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
//-import 'package:lenscannerv4/splash_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lenscannerv4/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Permission.camera.request();
  await Permission.storage.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Scalable OCR',
      theme: ThemeData(primarySwatch: Colors.blue),
      //home: const MyHomePage(title: 'LenScanner'),
      home: const AuthWrapper(),
      // initialRoute: '/',
      // routes: {
        // '/home': (context) => const MyHomePage(title: 'Flutter Scalable OCR'),
      // },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        //1. Kalau ada error, tampilkan pesan
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Terjadi kesalahan: ${snapshot.error}'),
            ),
          );
        }
        //2. Tunggu sampai stream aktif (loaded)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        //3. Kalau user sudah login (data != null), masuk ke Home
        if (snapshot.data != null) {
          return MyHomePage(
            key: ValueKey(snapshot.data!.uid),
            title: 'LenScanner',
          );
        }
        //4. Kalau belum login, tampilkan LoginPage
        return const LoginPage();
      },
    );
  }
}


class _MyHomePageState extends State<MyHomePage> {
  String name = "";
  String id = "";
  String hasilScan1 = "";
  String hasilScan2 = "";
  String waktu1 = "";
  String waktu2 = "";
  double selisih = 0.0;
  String selangWaktu = "";

  int scanStep = 1;
  bool torchOn = false;
  bool loading = false;
  bool dialogShown = false;
  int cameraSelection = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? debounceTimer;
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();

  @override
  void initState() {
    super.initState();
    ensureAllFilesAccess().then((granted) {
      if (granted) loadLastScanFromExcel();
    });
  }

  Future<void> playBeep() async {
    await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
  }


  Future<Directory?> getDownloadDirectory() async {
    // 1) Pastikan permission
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (Platform.version.contains('SDK 30') ||
          Platform.version.contains('SDK 31') ||
          Platform.version.contains('SDK 32')) {
        // Android 11+ gunakan MANAGE
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }
    }

    // 2) Coba langsung path hard-coded
    final direct = Directory('/storage/emulated/0/Download');
    if (await direct.exists()) {
      debugPrint("📂 Hard-coded Download dir: ${direct.path}");
      return direct;
    }

    // 3) Fallback ke path_provider
    final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
    if (dirs != null && dirs.isNotEmpty) {
      debugPrint("📂 Fallback Download dir: ${dirs.first.path}");
      return dirs.first;
    }

    debugPrint("❌ getDownloadDirectory: gagal menemukan folder download");
    return null;
  }


  Future<void> requestStoragePermission() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      print("✅ Izin storage diberikan");
    } else {
      print("❌ Izin storage ditolak");
    }
  }

  Future<bool> ensureAllFilesAccess() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    // Minta izin
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Jika masih ditolak, arahkan user ke Settings
    await openAppSettings();
    return false;
  }


  // --- Baca data terakhir dari Excel ---
  Future<void> loadLastScanFromExcel() async {
    final downloadsDir = await getDownloadDirectory();
    if (downloadsDir == null) {
      // return saja tanpa Snackbar
      return;
    }

    final filePath = '${downloadsDir.path}/DataScan.xlsx';
    final file = File(filePath);

    if (!file.existsSync()) {
      // buat file baru jika belum ada
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        'Nama',
        'ID',
        'Hasil Scan 1',
        'Hasil Scan 2',
        'Selisih',
        'Waktu Simpan',
      ]);
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return;
    }

    // baca file yang sudah ada
    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Sheet1'];

      if (sheet.rows.length > 1) {
        final lastRow = sheet.rows.last;
        setState(() {
          hasilScan1 = lastRow[3]?.value.toString() ?? "";
          waktu1     = lastRow[5]?.value.toString() ?? "";
          scanStep   = 2;
        });
      }
    } catch (_) {
      // silent fail
    }
  }

  // --- Format angka hasil scan ---
  String formatHasil(String hasil) {
    String angkaBersih = hasil.replaceAll(RegExp(r'[^0-9]'), '');
    if (angkaBersih.length == 8) {
      return angkaBersih.substring(0, 5) + '.' + angkaBersih.substring(5);
    }
    return hasil;
  }

  // --- Hitung selisih angka & waktu ---
  void hitungSelisih() {
    double num1 = double.tryParse(hasilScan1) ?? 0;
    double num2 = double.tryParse(hasilScan2) ?? 0;
    selisih = num2 - num1;
  
    try {
      DateFormat format = DateFormat("HH:mm:ss dd/MM/yyyy");
      DateTime t1 = format.parse(waktu1);
      DateTime t2 = format.parse(waktu2);
      Duration diff = t2.difference(t1);
  
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
  
      String hasil = "";
      if (days > 0) hasil += "$days hari ";
      hasil += "$hours jam $minutes menit";
  
      selangWaktu = hasil;
    } catch (_) {
      selangWaktu = "";
    }
  }


  // --- Simpan ke Excel ---
  Future<void> saveToExcel() async {
    try {
      final downloadsDir = await getDownloadDirectory();
      if (downloadsDir == null) return;

      if (!await ensureAllFilesAccess()) return;

      final filePath = '${downloadsDir.path}/DataScan.xlsx';
      final file = File(filePath);

      Excel excel;
      Sheet sheet;
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        excel = Excel.decodeBytes(bytes);
        sheet = excel['Sheet1'];
      } else {
        excel = Excel.createExcel();
        sheet = excel['Sheet1'];
        sheet.appendRow(['Nama','ID','Hasil Scan 1','Hasil Scan 2','Selisih','Waktu Simpan']);
      }

      sheet.appendRow([name, id, hasilScan1, hasilScan2, selisih.toString(), waktu2]);

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes, flush: true);
        // langsung refresh data
        await loadLastScanFromExcel();
      }
    } catch (_) {
      // silent fail
    }
  }

  // --- Konfirmasi sebelum simpan final ---
  Future<void> confirmAndSave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Data Final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nama: $name"),
            Text("ID: $id"),
            Text("Scan 1: $hasilScan1"),
            Text("Scan 2: $hasilScan2"),
            Text("Selisih: $selisih"),
            Text("Selang Waktu: $selangWaktu"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await saveToExcel();
    }
  }

  // --- Konfirmasi hasil scan ---
  Future<void> confirmScan(String hasil, int step) async {
    final cleaned = hasil.trim();
    final controller = TextEditingController(text: formatHasil(cleaned));

    bool isInputValid(String input) {
      final onlyDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      // Harus tepat 8 digit
      if (onlyDigits.length != 8) return false;
      // Jika step 2, pastikan selisih > 0
      if (step == 2) {
        final parsed = double.tryParse(
          '${onlyDigits.substring(0, 5)}.${onlyDigits.substring(5)}',
        ) ??
            0;
        final scan1 = double.tryParse(hasilScan1) ?? 0;
        return parsed > scan1;
      }
      return true;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Scan $step'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Edit hasil jika perlu",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ulang'),
          ),
          ElevatedButton(
            onPressed: () {
              final input = controller.text.trim();
              final valid = isInputValid(input);
              if (!valid) {
                // Mainkan beep hanya jika input tidak valid
                playBeep();
                return;
              }
              // Hanya sampai sini jika valid
              if (step == 1) {
                hasilScan1 = input;
                waktu1 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
                setState(() => scanStep = 2);
              } else {
                hasilScan2 = input;
                waktu2 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
                hitungSelisih();
                setState(() {});
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // --- Reset scan ---
  void refreshScan() {
    setState(() {
      hasilScan2 = "";
      selisih = 0.0;
      selangWaktu = "";
      waktu2 = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ScalableOCR(
              key: cameraKey,
              torchOn: torchOn,
              cameraSelection: cameraSelection,
              lockCamera: true,
              paintboxCustom: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.0
                ..color = Colors.green,
              boxLeftOff: 5,
              boxBottomOff: 2.5,
              boxRightOff: 5,
              boxTopOff: 2.5,
              boxHeight: MediaQuery.of(context).size.height / 3,
              getScannedText: (value) {
                if (value.isEmpty || dialogShown) return;
                debounceTimer?.cancel();
                debounceTimer = Timer(const Duration(milliseconds: 800), () async {
                  dialogShown = true;
                  if (scanStep == 1) {
                    await confirmScan(value, 1);
                  } else {
                    await confirmScan(value, 2);
                  }
                  dialogShown = false;
                });
              },
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  boxHeight: MediaQuery.of(context).size.height / 6,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment(0, -0.3),
            child: Text(
              "Scan Number",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRowInput("Nama", name, (val) => setState(() => name = val)),
                      _buildRowInput("ID", id, (val) => setState(() => id = val)),
                      _buildRowData("Hasil Baca Sebelumnya", hasilScan1, waktu1),
                      _buildRowData("Hasil Baca Saat Ini", hasilScan2, waktu2),
                      _buildRowData("Selisih Pembacaan", selisih.toString(), ""),
                      _buildRowData("Selang Waktu", selangWaktu, ""),
                    ],
                  ),
                ),

                Container(
                  color: Colors.brown.shade800,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: refreshScan,
                          icon: Icon(Icons.refresh, size: 30),
                          label: Text("REFRESH"),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: hasilScan2.isNotEmpty ? confirmAndSave : null,
                          icon: Icon(Icons.download, size: 30),
                          label: Text("SIMPAN"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowInput(String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        SizedBox(height: 4),
        TextField(
          style: TextStyle(fontSize: 18),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: value),
          onChanged: onChanged,
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRowData(String label, String val1, String val2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (val1.isNotEmpty)
              Text(val1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (val2.isNotEmpty) SizedBox(width: 8),
            if (val2.isNotEmpty)
              Text(val2, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
          ],
        ),
        Divider(),
      ],
    );
  }
}

Widget _buildScanWithTime(String label, String value, String time) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(fontSize: 16),
      ),
      if (time.isNotEmpty) ...[
        SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(color: Colors.grey),
        ),
      ],
      SizedBox(height: 12), // spacing antar blok
    ],
  );
}

/// Painter untuk membuat area luar scan box gelap
  class _ScannerOverlayPainter extends CustomPainter {
    final double boxHeight;
    _ScannerOverlayPainter({required this.boxHeight});

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.black.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        20,
        size.height / 2 - boxHeight / 2,
        size.width - 40,
        boxHeight,
      );

      // Gambarkan overlay hitam seluruh layar
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      // Potong kotak scan agar transparan
      final clearPaint = Paint()
        ..blendMode = BlendMode.clear;
      canvas.drawRect(rect, clearPaint);
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }
