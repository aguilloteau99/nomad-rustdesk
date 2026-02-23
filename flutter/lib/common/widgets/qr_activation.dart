import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR code widget for mobile license activation
/// Encodes: nomad-activate://{KEY}@{SERVER_URL}
class QrActivationWidget extends StatelessWidget {
  final String licenseKey;
  final String serverUrl;

  const QrActivationWidget({
    Key? key,
    required this.licenseKey,
    required this.serverUrl,
  }) : super(key: key);

  String get qrData {
    // Extract domain from full URL (strip https://, http://, trailing slash)
    String domain = serverUrl
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
    return 'nomad-activate://$licenseKey@$domain';
  }

  @override
  Widget build(BuildContext context) {
    if (licenseKey.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Activate a license key first',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Scan with your phone to activate Nomad',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 280,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                licenseKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Or enter this key manually on your mobile device',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
