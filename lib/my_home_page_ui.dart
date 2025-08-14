import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'dart:async';


class MyHomePageUI extends StatelessWidget {
  const MyHomePageUI({
    super.key,
    required this.title,
    required this.torchOn,
    required this.onToggleTorch,
    required this.cameraSelection,
    required this.cameraKey,
    required this.scanBoxHeight,
    required this.onScanValue,
    required this.nameController,
    required this.idController,
    required this.hasilScan1,
    required this.waktu1,
    required this.hasilScan2,
    required this.waktu2,
    required this.selisih,
    required this.selangWaktu,
    required this.onRefresh,
    required this.onSave,
  });

  final String title;
  final bool torchOn;
  final VoidCallback onToggleTorch;
  final int cameraSelection;
  final GlobalKey<ScalableOCRState> cameraKey;
  final double scanBoxHeight;

  // callback ke parent untuk proses debounce + dialog
  final Future<void> Function(String value) onScanValue;

  // input
  final TextEditingController nameController;
  final TextEditingController idController;

  // data tampilan
  final String hasilScan1;
  final String waktu1;
  final String hasilScan2;
  final String waktu2;
  final double selisih;
  final String selangWaktu;

  // actions
  final VoidCallback onRefresh;
  final Future<void> Function()? onSave; // null = disabled

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Kamera background
        Positioned.fill(
          child: Container(
            color: Colors.black,
          ),
        ),

        // Area scan dengan kotak
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Panel data
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header merah
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(
                  child: Text(
                    "Data Hasil Scan",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Isi panel
              Container(
                width: double.infinity,
                color: Colors.grey[200],
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ID
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(
                        labelText: "ID",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hasil Baca 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Hasil Baca 1",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(waktu1),
                          ],
                        ),
                        Text(
                          hasilScan1,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Hasil Baca 2
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Hasil Baca 2",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(waktu2),
                          ],
                        ),
                        Text(
                          hasilScan2,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Selisih
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Selisih Pembacaan",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(selisih.toString()),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Selang Waktu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Selang Waktu",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(selangWaktu),
                      ],
                    ),
                  ],
                ),
              ),

              // Tombol bawah
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[700],
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save),
                      label: const Text("Simpan"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[700],
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}