import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

import '../../services/firmware_marketplace_service.dart';

/// Result returned when a repository is added or scanned.
class QrRepoResult {
  final String repoUrl;
  final String? preselectedAsset;

  const QrRepoResult({
    required this.repoUrl,
    this.preselectedAsset,
  });
}

/// Modal dialog for adding a firmware repository via QR code scan or URL input.
class QrRepoScannerModal extends StatefulWidget {
  const QrRepoScannerModal({super.key});

  /// Displays the modal dialog and returns the scanned or entered repository result.
  static Future<QrRepoResult?> show(BuildContext context) {
    return showDialog<QrRepoResult>(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (ctx) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: QrRepoScannerModal(),
      ),
    );
  }

  @override
  State<QrRepoScannerModal> createState() => _QrRepoScannerModalState();
}

class _QrRepoScannerModalState extends State<QrRepoScannerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  MobileScannerController? _scannerController;
  String? _errorMessage;
  bool _hasScanned = false;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _isMobile ? 2 : 1,
      vsync: this,
    );

    if (_isMobile) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _processPayload(String rawPayload) {
    if (_hasScanned) return;
    final clean = rawPayload.trim();
    if (clean.isEmpty) return;

    String? targetAsset;
    String repoUrl = clean;

    // Handle deep links: radiokit://firmware?url=...&asset=...
    if (clean.startsWith('radiokit://') || clean.startsWith('radiokit:')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        final queryUrl = uri.queryParameters['url'] ?? uri.queryParameters['repo'];
        if (queryUrl != null && queryUrl.isNotEmpty) {
          repoUrl = queryUrl;
        }
        targetAsset = uri.queryParameters['asset'];
      }
    }

    final parsed = FirmwareMarketplaceService.parseRepoUrl(repoUrl);
    if (parsed == null) {
      setState(() {
        _errorMessage = 'Invalid GitHub repository URL or QR payload.';
      });
      return;
    }

    _hasScanned = true;
    final normalized = 'https://github.com/${parsed.$1}/${parsed.$2}';
    Navigator.of(context).pop(QrRepoResult(
      repoUrl: normalized,
      preselectedAsset: targetAsset,
    ));
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: tokens.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.qrCode,
                      color: tokens.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ADD FIRMWARE REPO',
                      style: GoogleFonts.changa(
                        color: tokens.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x,
                        size: 18, color: tokens.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar (if mobile)
            if (_isMobile)
              TabBar(
                controller: _tabController,
                indicatorColor: tokens.primary,
                labelColor: tokens.primary,
                unselectedLabelColor: tokens.onSurface.withValues(alpha: 0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.camera_alt_rounded, size: 18), text: 'SCAN QR'),
                  Tab(icon: Icon(Icons.link_rounded, size: 18), text: 'PASTE URL'),
                ],
              ),

            // Tab views / Body
            Expanded(
              child: _isMobile
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildScannerView(tokens),
                        _buildManualInputView(tokens),
                      ],
                    )
                  : _buildManualInputView(tokens),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView(RKTokens tokens) {
    if (_scannerController == null) {
      return Center(
        child: Text('Camera scanner unavailable.',
            style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.6))),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final rawValue = barcode.rawValue;
              if (rawValue != null && rawValue.isNotEmpty) {
                _processPayload(rawValue);
                break;
              }
            }
          },
        ),

        // QR frame overlay
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: tokens.primary, width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Point camera at repository QR code',
                style: GoogleFonts.martianMono(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInputView(RKTokens tokens) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTER REPOSITORY URL',
            style: GoogleFonts.changa(
              color: tokens.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a GitHub repository link or project URL containing release binaries.',
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Input field
          TextField(
            controller: _urlController,
            autofocus: true,
            style: GoogleFonts.martianMono(
              color: tokens.onSurface,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'https://github.com/owner/repo',
              hintStyle: GoogleFonts.martianMono(
                color: tokens.onSurface.withValues(alpha: 0.3),
                fontSize: 12,
              ),
              prefixIcon: Icon(PhosphorIcons.githubLogo,
                  size: 18, color: tokens.primary),
              suffixIcon: IconButton(
                icon: Icon(PhosphorIcons.clipboard,
                    size: 18, color: tokens.primary),
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
              ),
              filled: true,
              fillColor: tokens.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: tokens.onSurface.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: tokens.primary, width: 1.5),
              ),
            ),
            onSubmitted: _processPayload,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: tokens.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: tokens.error, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],

          const Spacer(),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CANCEL',
                    style: GoogleFonts.changa(
                        color: tokens.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _processPayload(_urlController.text),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('ADD REPOSITORY',
                    style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
