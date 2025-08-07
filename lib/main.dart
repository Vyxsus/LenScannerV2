import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:lenscannerv4/splash_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialRoute: '/',
      routes: {
        '/':(context) => const SplashScreen(),
        '/home': (context) => const MyHomePage(title: 'Flutter Scalable OCR'),
      },
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

  Timer? debounceTimer;
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();

  @override
  void initState() {
    super.initState();
    loadLastScanFromExcel();
  }

  // --- Baca data terakhir dari Excel ---
  Future<void> loadLastScanFromExcel() async {
    try {
      final filePath = '/storage/emulated/0/Download/DataScan.xlsx';
      final file = File(filePath);
  
      if (!file.existsSync()) return;
  
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Sheet1'];
  
      if (sheet.rows.length > 1) {
        var lastRow = sheet.rows.last;
  
        // Ambil hasil scan 2 terakhir sebagai hasilScan1 untuk pembacaan berikutnya
        setState(() {
          hasilScan1 = lastRow[3]?.value.toString() ?? ""; // kolom hasil scan 2
          waktu1 = lastRow[5]?.value.toString() ?? "";
          scanStep = 2; // langsung ke scan kedua
        });
      }
    } catch (e) {
      debugPrint("Gagal baca Excel: $e");
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
      selangWaktu = "${diff.inHours} jam ${diff.inMinutes % 60} menit";
    } catch (_) {
      selangWaktu = "";
    }
  }

  // --- Simpan ke Excel ---
  Future<void> saveToExcel() async {
    final now = DateTime.now();
    waktu2 = DateFormat("HH:mm:ss dd/MM/yyyy").format(now);
    hitungSelisih();
  
    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      downloadsDir = await getExternalStorageDirectory() ?? downloadsDir;
    }
  
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
      sheet.appendRow([
        'Nama',
        'ID',
        'Hasil Scan 1',
        'Hasil Scan 2',
        'Selisih',
        'Waktu Simpan'
      ]);
    }
  
    // Simpan data baru
    sheet.appendRow([
      name,
      id,
      hasilScan1,
      hasilScan2,
      selisih.toString(),
      waktu2
    ]);
  
    final fileBytes = excel.encode();
    await file.writeAsBytes(fileBytes!);
  
    // Setelah save, langsung refresh data terakhir untuk scan berikutnya
    await loadLastScanFromExcel();
  
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data tersimpan di: $filePath')),
    );
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
    final controller = TextEditingController(text: formatHasil(hasil));

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Scan $step'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Edit hasil jika perlu",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ulang'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (step == 1) {
        hasilScan1 = controller.text.trim();
        waktu1 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
        setState(() => scanStep = 2);
      } else {
        hasilScan2 = controller.text.trim();
        waktu2 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
        hitungSelisih();
        setState(() {}); // Update tampilan hasil scan 2
      }
    }
  }

  // --- Reset scan ---
  void refreshScan() {
    setState(() {
      scanStep = 1;
      hasilScan1 = "";
      hasilScan2 = "";
      selisih = 0.0;
      selangWaktu = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () => setState(() => torchOn = !torchOn),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!loading)
              ScalableOCR(
                key: cameraKey,
                torchOn: torchOn,
                cameraSelection: cameraSelection,
                lockCamera: true,
                paintboxCustom: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4.0
                  ..color = Colors.lightBlue,
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
            const SizedBox(height: 20),

            // Input Nama & ID
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Masukkan Nama', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => name = val),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Masukkan ID', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() => id = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Hasil Scan
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Hasil Baca Sebelumnya"),
                    subtitle: Text(hasilScan1),
                    trailing: Text(waktu1),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("Hasil Baca Saat Ini"),
                    subtitle: Text(hasilScan2),
                    trailing: Text(waktu2),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("Selisih Pembacaan"),
                    trailing: Text(selisih.toString()),
                  ),
                  ListTile(
                    title: const Text("Selang Waktu"),
                    trailing: Text(selangWaktu),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tombol kontrol
            ElevatedButton(
              onPressed: () {
                setState(() {
                  loading = true;
                  cameraSelection = cameraSelection == 0 ? 1 : 0;
                });
                Future.delayed(const Duration(milliseconds: 300), () {
                  setState(() => loading = false);
                });
              },
              child: const Text("Ganti Kamera"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: refreshScan,
              child: const Text("Refresh Scan"),
            ),
            const SizedBox(height: 10),
            if (hasilScan2.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: confirmAndSave,
                child: const Text("Simpan"),
              ),
          ],
        ),
      ),
    );
  }
}
