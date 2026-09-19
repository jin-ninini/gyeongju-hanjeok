import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  bool _cameraUseAccepted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('친구 QR 스캔'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: _cameraUseAccepted
            ? [
                IconButton(
                  tooltip: '플래시',
                  onPressed: _controller.toggleTorch,
                  icon: const Icon(Icons.flashlight_on_outlined),
                ),
              ]
            : null,
      ),
      body: _cameraUseAccepted
          ? _buildScanner()
          : _buildCameraPermissionNotice(),
    );
  }

  Widget _buildCameraPermissionNotice() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.goldLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 58,
                  color: AppColors.forest,
                ),
                const SizedBox(height: 18),
                const Text(
                  '카메라 사용 안내',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '친구의 경주한적 QR 코드를 스캔하기 위해 카메라를 사용합니다.\n\n'
                  '카메라는 선택 권한이며, 허용하지 않아도 QR 스캔을 제외한 다른 기능은 이용할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        // 이 선택 이후에만 MobileScanner를 생성합니다.
                        // 따라서 운영체제 카메라 권한 요청보다 먼저
                        // 앱 자체 용도 안내와 사용자의 선택이 이루어집니다.
                        _cameraUseAccepted = true;
                      });
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('카메라 사용하기'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 255,
              height: 255,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.goldLight,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 54,
          child: Text(
            '상대방 마이페이지의 경주한적 QR을 네모 안에 맞춰주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    final memberCode = _extractMemberCode(raw);
    if (memberCode == null) return;

    _handled = true;
    Navigator.of(context).pop(memberCode);
  }

  String? _extractMemberCode(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.scheme.toLowerCase() == 'gyeongjuhanjeok' &&
        uri.host == 'friend' &&
        uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.first).trim().toUpperCase();
    }

    final normalized = raw.toUpperCase().replaceAll(' ', '');
    final match = RegExp(r'GJ-[A-Z2-9]{6}').firstMatch(normalized);
    return match?.group(0);
  }
}
