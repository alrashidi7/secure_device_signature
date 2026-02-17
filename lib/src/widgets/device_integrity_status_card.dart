import 'package:flutter/material.dart';

import '../device_integrity_report.dart';

/// A modern status card showing device integrity result (secure or compromised).
///
/// Uses a security-themed design with shield icon, gradient accents, and
/// clear visual feedback.
class DeviceIntegrityStatusCard extends StatelessWidget {
  const DeviceIntegrityStatusCard({
    super.key,
    required this.report,
    this.showMetadata = false,
    this.compact = false,
  });

  final DeviceIntegrityReport report;
  final bool showMetadata;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSecure = !report.isCompromised;
    final colorScheme = Theme.of(context).colorScheme;
    final secureColor = const Color(0xFF22C55E); // emerald-500
    final compromisedColor = const Color(0xFFF59E0B); // amber-500

    return Container(
      padding: compact ? const EdgeInsets.all(16) : const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSecure
              ? [
                  secureColor.withOpacity(0.12),
                  secureColor.withOpacity(0.04),
                ]
              : [
                  compromisedColor.withOpacity(0.12),
                  compromisedColor.withOpacity(0.04),
                ],
        ),
        border: Border.all(
          color: isSecure
              ? secureColor.withOpacity(0.4)
              : compromisedColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildShieldIcon(isSecure, secureColor, compromisedColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSecure ? 'Device Secure' : 'Security Warning',
                      style: TextStyle(
                      fontSize: compact ? 18 : 22,
                      fontWeight: FontWeight.w700,
                      color: isSecure ? secureColor : compromisedColor,
                      letterSpacing: -0.5,
                    ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSecure
                          ? 'Your device passed all integrity checks'
                          : 'Root, emulator, or tampering detected',
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showMetadata && report.metadata.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...report.metadata.entries.map(
              (e) => _MetadataRow(
                label: _formatKey(e.key),
                value: e.value?.toString() ?? '—',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShieldIcon(bool isSecure, Color secureColor, Color compromisedColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isSecure ? secureColor : compromisedColor).withOpacity(0.15),
      ),
      child: Icon(
        isSecure ? Icons.shield_rounded : Icons.shield_outlined,
        size: 32,
        color: isSecure ? secureColor : compromisedColor,
      ),
    );
  }

  String _formatKey(dynamic key) {
    final s = key.toString();
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(1)!.toLowerCase()}',
        );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
