import 'package:flutter/material.dart';

/// An attractive section explaining what device integrity means and what we check.
///
/// Helps users understand why we verify their device.
class DeviceIntegrityInfoSection extends StatelessWidget {
  const DeviceIntegrityInfoSection({
    super.key,
    this.title = 'How we protect you',
    this.subtitle,
    this.showAllChecks = true,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool showAllChecks;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: compact ? 20 : 24,
              color: colorScheme.primary.withOpacity(0.8),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _CheckItem(
          icon: Icons.block_rounded,
          title: 'Root & Jailbreak',
          description: 'Detects if your device is modified for elevated access.',
          compact: compact,
        ),
        _CheckItem(
          icon: Icons.phone_android_rounded,
          title: 'Real device',
          description: 'Ensures you\'re not using an emulator or simulator.',
          compact: compact,
        ),
        if (showAllChecks) ...[
          _CheckItem(
            icon: Icons.bug_report_outlined,
            title: 'Debug & tampering',
            description: 'Detects debugging tools or app hooks.',
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: compact ? 18 : 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
