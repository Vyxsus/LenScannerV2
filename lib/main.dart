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
        '/': (context) => const SplashScreen(),
        '/home': (context) => const MyHomePage(title: 'Flutter Scalable OCR'),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MyHomePage(title: 'LenScanner');
        }
        return const LoginPage();
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
  bool dialogShown = false;
  Timer? debounceTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final GlobalKey<ScalableOCRState> cameraKey = GlobalKey<ScalableOCRState>();

  @override
  void initState() {
    super.initState();
    nameController.text = name;
    idController.text = id;
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

  Future<Directory?> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
    final direct = Directory('/storage/emulated/0/Download');
    if (await direct.exists()) return direct;
    final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
    if (dirs != null && dirs.isNotEmpty) return dirs.first;
    return null;
  }

  Future<bool> ensureAllFilesAccess() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    await openAppSettings();
    return false;
  }

  Future<void> loadLastScanFromExcel() async {
    final downloadsDir = await getDownloadDirectory();
    if (downloadsDir == null) return;
    final filePath = '${downloadsDir.path}/DataScan.xlsx';
    final file = File(filePath);

    if (!file.existsSync()) {
      final excel = Excel.createExcel();
      excel['Sheet1'].appendRow([
        'Nama', 'ID', 'Hasil Scan 1', 'Hasil Scan 2', 'Selisih', 'Waktu Simpan'
      ]);
      final bytes = excel.encode();
      if (bytes != null) await file.writeAsBytes(bytes, flush: true);
      return;
    }

    try {
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Sheet1'];
      if (sheet.rows.length > 1) {
        final lastRow = sheet.rows.last;
        setState(() {
          hasilScan1 = lastRow[2]?.value.toString() ?? "";
          waktu1 = lastRow[5]?.value.toString() ?? "";
          scanStep = 2;
        });
      }
    } catch (_) {}
  }

  String formatHasil(String hasil) {
    final angka = hasil.replaceAll(RegExp(r'[^0-9]'), '');
    if (angka.length == 8) {
      return angka.substring(0, 5) + '.' + angka.substring(5);
    }
    return hasil;
  }

  void hitungSelisih() {
    final num1 = double.tryParse(hasilScan1) ?? 0;
    final num2 = double.tryParse(hasilScan2) ?? 0;
    selisih = num2 - num1;

    try {
      final fmt = DateFormat("HH:mm:ss dd/MM/yyyy");
      final t1 = fmt.parse(waktu1);
      final t2 = fmt.parse(waktu2);
      final diff = t2.difference(t1);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;

      selangWaktu = [
        if (days > 0) "$days hari",
        "$hours jam",
        "$minutes menit"
      ].join(' ');
    } catch (_) {
      selangWaktu = "";
    }
  }

  Future<void> saveToExcel() async {
    final downloadsDir = await getDownloadDirectory();
    if (downloadsDir == null || !await ensureAllFilesAccess()) return;
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
      await loadLastScanFromExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data tersimpan di: $filePath')),
        );
      }
    }
  }

  Future<void> confirmAndSave() async {
    final conf = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (conf == true) await saveToExcel();
  }

  Future<void> confirmScan(String hasil, int step) async {
    final controller = TextEditingController(text: formatHasil(hasil.trim()));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          bool valid = false;
          void validate(String input) {
            final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
            if (digits.length == 8) {
              final val = double.tryParse(digits.substring(0,5) + '.' + digits.substring(5)) ?? 0;
              valid = step == 1 || val > (double.tryParse(hasilScan1) ?? 0);
            } else {
              valid = false;
            }
            if (!valid) playBeep();
            setStateDialog(() {});
          }

          return AlertDialog(
            title: Text('Konfirmasi Scan $step'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Edit hasil jika perlu",
                border: OutlineInputBorder(),
              ),
              onChanged: validate,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ulang')),
              ElevatedButton(
                onPressed: valid
                    ? () {
                        final input = controller.text.trim();
                        if (step == 1) {
                          hasilScan1 = input;
                          waktu1 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
                          scanStep = 2;
                        } else {
                          hasilScan2 = input;
                          waktu2 = DateFormat("HH:mm:ss dd/MM/yyyy").format(DateTime.now());
                          hitungSelisih();
                        }
                        setState(() {});
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('OK'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _onScanValue(String value) async {
    if (value.isEmpty || dialogShown) return;
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      dialogShown = true;
      await confirmScan(value, scanStep);
      dialogShown = false;
    });
  }

  void refreshScan() {
    setState(() {
      hasilScan2 = "";
      selisih = 0.0;
      selangWaktu = "";
      waktu2 = "";
      scanStep = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanBoxHeight = MediaQuery.of(context).size.height / 3;
    return MyHomePageUI(
      title: widget.title,
      torchOn: torchOn,
      onToggleTorch: () => setState(() => torchOn = !torchOn),
      cameraSelection: 0,
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
