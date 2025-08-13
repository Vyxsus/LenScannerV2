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
    final size = MediaQuery.of(context).size;

    // posisi kotak scan: center horizontal, margin 20 kiri/kanan
    final Rect scanRect = Rect.fromLTWH(
      20,
      size.height / 2 - (scanBoxHeight / 2),
      size.width - 40,
      scanBoxHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kamera full screen
          Positioned.fill(
            child: ScalableOCR(
              key: cameraKey,
              torchOn: torchOn,
              cameraSelection: cameraSelection,
              lockCamera: true,
              // kita biarkan kotak plugin hanya sebagai marker tipis (atau transparan)
              paintboxCustom: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0
                ..color = Colors.green,
              // offset bawaan plugin (boleh dibiarkan seperti sebelumnya)
              boxLeftOff: 5,
              boxBottomOff: 2.5,
              boxRightOff: 5,
              boxTopOff: 2.5,
              // tinggi kotak scan (disamakan dengan overlay)
              boxHeight: scanBoxHeight,
              getScannedText: (value) {
                onScanValue(value);
              },
            ),
          ),

          // Overlay gelap di luar kotak scan
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(scanRect: scanRect),
              ),
            ),
          ),

          // AppBar kustom (judul + tombol torch)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Scan Number",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleTorch,
                    icon: Icon(
                      torchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel bawah: input + hasil
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Kartu data
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRowInput("Nama", nameController),
                      _buildRowInput("ID", idController),
                      _buildRowData("Hasil Baca Sebelumnya", hasilScan1, waktu1),
                      _buildRowData("Hasil Baca Saat Ini", hasilScan2, waktu2),
                      _buildRowData("Selisih Pembacaan", selisih.toString(), ""),
                      _buildRowData("Selang Waktu", selangWaktu, ""),
                    ],
                  ),
                ),

                // Bar tombol bawah
                Container(
                  color: Colors.brown.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh, size: 30),
                          label: const Text("REFRESH"),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: onSave, // null => disabled
                          icon: const Icon(Icons.download, size: 30),
                          label: const Text("SIMPAN"),
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

  // ===== UI helpers =====
  Widget _buildRowInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
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
              child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (val1.isNotEmpty)
              Text(val1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (val2.isNotEmpty) const SizedBox(width: 8),
            if (val2.isNotEmpty)
              Text(val2, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

// ===== Overlay Painter (membuat "lubang" transparan untuk kotak scan) =====
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;
  _ScannerOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final background = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
    );

    final diff = Path.combine(PathOperation.difference, background, hole);
    canvas.drawPath(diff, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
