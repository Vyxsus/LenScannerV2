import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:lenscannerv4/splash_screen.dart';
import 'my_home_page_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lenscannerv4/login_page.dart';


Future<void> main() async {
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
      home: AuthWrapper(),
      initialRoute: '/',
      routes: {
        '/':(context)=> const SplashScreen(),
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

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const MyHomePage(title: 'LenScanner');
        }
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

  final TextEditingController nameController = TextEditingController();
  final TextEditingController idController = TextEditingController();

  Timer? debounceTimer;
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();

  @override
  void initState() {
    super.initState();
    nameController.text = name;
    idController.text = id;
    // listener agar variabel name/id tetap update
    nameController.addListener(() => name = nameController.text);
    idController.addListener(() => id = idController.text);
    loadLastScanFromExcel();
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    _audioPlayer.dispose();
    nameController.dispose();
    idController.dispose();
    super.dispose();
  }

  Future<void> playBeep() async {
    await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
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

    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data tersimpan di: $filePath')),
      );
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
    double parsedSelisih = 0;
    bool isValid = true;
    bool showError = false;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          void validate(String input) {
            final onlyDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
            if (onlyDigits.length == 8) {
              final formatted = input.replaceAll(RegExp(r'[^0-9]'), '');
              final formattedDouble = double.tryParse(
                formatted.substring(0, 5) + '.' + formatted.substring(5),
              );
              final scan1 = double.tryParse(hasilScan1) ?? 0;
              parsedSelisih = (formattedDouble ?? 0) - scan1;

              if (parsedSelisih <= 0) {
                playBeep();
                setStateDialog(() {
                  isValid = false;
                  showError = true;
                });
              } else {
                setStateDialog(() {
                  isValid = true;
                  showError = false;
                });
              }
            } else {
              setStateDialog(() {
                isValid = false;
                showError = true;
              });
            }
          }

          return AlertDialog(
            title: Text('Konfirmasi Scan $step'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Edit hasil jika perlu",
                    border: const OutlineInputBorder(),
                    errorText: showError ? 'Selisih tidak boleh negatif atau nol.' : null,
                  ),
                  onChanged: validate,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Ulang'),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                child: const Text('OK'),
              ),
            ],
          );
        });
      },
    );

    if (confirm == true) {
      final input = controller.text.trim();
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
    }
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
  // dipanggil UI saat OCR mengirim teks; debounced & dialog guard ada di sini
  Future<void> _onScanValue(String value) async {
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
  }
  @override
  Widget build(BuildContext context) {
    // ukuran kotak scan disamakan untuk kamera & overlay
    final double scanBoxHeight = MediaQuery.of(context).size.height / 3;

    return MyHomePageUI(
      title: widget.title,
      torchOn: torchOn,
      onToggleTorch: () => setState(() => torchOn = !torchOn),
      cameraSelection: cameraSelection,
      cameraKey: cameraKey,
      scanBoxHeight: scanBoxHeight,
      onScanValue: _onScanValue,
      nameController: nameController,
      idController: idController,
      hasilScan1: hasilScan1,
      waktu1: waktu1,
      hasilScan2: hasilScan2,
      waktu2: waktu2,
      selisih: selisih,
      selangWaktu: selangWaktu,
      onRefresh: refreshScan,
      onSave: hasilScan2.isNotEmpty ? confirmAndSave : null,
    );
  }
}