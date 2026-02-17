import 'package:flutter/material.dart';

import '../device_integrity_report.dart';
import '../device_integrity_signature.dart';
import '../security_exception.dart';
import 'device_integrity_info_section.dart';
import 'device_integrity_status_card.dart';

/// A complete, drop-in widget for device integrity checks.
///
/// Use this widget in your app — no need to build your own UI.
/// Shows an attractive security-themed layout with:
/// - Hero header
/// - "Check Now" button
/// - Status card (secure / compromised)
/// - Info section explaining what we verify
///
/// Example:
/// ```dart
/// DeviceIntegrityChecker(
///   onSecure: () => Navigator.push(...),
///   onCompromised: () => showDialog(...),
/// )
/// ```
class DeviceIntegrityChecker extends StatefulWidget {
  const DeviceIntegrityChecker({
    super.key,
    this.api,
    this.throwOnCompromised = false,
    this.showInfoSection = true,
    this.showMetadata = false,
    this.title = 'Device security',
    this.subtitle = 'We verify your device to keep your data safe',
    this.checkButtonLabel = 'Check device',
    this.onSecure,
    this.onCompromised,
    this.onError,
  });

  final DeviceIntegritySignature? api;
  final bool throwOnCompromised;
  final bool showInfoSection;
  final bool showMetadata;
  final String title;
  final String subtitle;
  final String checkButtonLabel;
  final VoidCallback? onSecure;
  final VoidCallback? onCompromised;
  final void Function(Object error)? onError;

  @override
  State<DeviceIntegrityChecker> createState() => _DeviceIntegrityCheckerState();
}

class _DeviceIntegrityCheckerState extends State<DeviceIntegrityChecker> {
  late DeviceIntegritySignature _api;
  DeviceIntegrityReport? _report;
  SecurityException? _securityException;
  Object? _genericError;
  bool _isLoading = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? DeviceIntegritySignature();
  }

  Future<void> _runCheck() async {
    setState(() {
      _isLoading = true;
      _report = null;
      _securityException = null;
      _genericError = null;
      _hasChecked = true;
    });

    try {
      final report = await _api.getReport(
        throwOnCompromised: widget.throwOnCompromised,
      );

      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });

      if (report.isCompromised) {
        widget.onCompromised?.call();
      } else {
        widget.onSecure?.call();
      }
    } on SecurityException catch (e) {
      if (!mounted) return;
      setState(() {
        _securityException = e;
        _isLoading = false;
      });
      widget.onCompromised?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _genericError = e;
        _isLoading = false;
      });
      widget.onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header
          _buildHeader(colorScheme),
          const SizedBox(height: 32),

          // Check button
          _buildCheckButton(theme),
          const SizedBox(height: 24),

          // Loading
          if (_isLoading) _buildLoading(),
          if (_isLoading) const SizedBox(height: 24),

          // Security exception (thrown)
          if (_securityException != null) _buildExceptionCard(),
          if (_securityException != null) const SizedBox(height: 24),

          // Generic error
          if (_genericError != null) _buildErrorCard(),
          if (_genericError != null) const SizedBox(height: 24),

          // Status card
          if (_report != null) ...[
            DeviceIntegrityStatusCard(
              report: _report!,
              showMetadata: widget.showMetadata,
              compact: !widget.showInfoSection,
            ),
            const SizedBox(height: 24),
          ],

          // Info section
          if (widget.showInfoSection) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: DeviceIntegrityInfoSection(
                title: widget.title == 'Device security'
                    ? 'How we protect you'
                    : 'What we verify',
                subtitle: 'We run these checks to ensure a trusted environment.',
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.2),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.shield_rounded,
            size: 36,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckButton(ThemeData theme) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _runCheck,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: _isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : Icon(
              _hasChecked && _report != null
                  ? Icons.refresh_rounded
                  : Icons.verified_user_rounded,
            ),
      label: Text(
        _isLoading ? 'Checking...' : (_hasChecked ? 'Check again' : widget.checkButtonLabel),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Verifying device integrity...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExceptionCard() {
    final e = _securityException!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Text(
                'Security issue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            e.reason,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade800,
            ),
          ),
          if (e.message != null) ...[
            const SizedBox(height: 4),
            Text(
              e.message!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _genericError.toString(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
