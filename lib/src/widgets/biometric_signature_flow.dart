import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device_integrity_report.dart';
import '../device_integrity_signature.dart';
import '../signature_exceptions.dart';
import '../signature_service.dart';
import '../signature_storage.dart';
import '../signature_verifier.dart';

/// What to sign: [deviceSignature] from integrity report, or a [challenge] string.
sealed class SignaturePayload {
  const SignaturePayload();
}

/// Sign the device integrity signature (from report).
final class DeviceSignaturePayload extends SignaturePayload {
  const DeviceSignaturePayload();
}

/// Sign a challenge string (e.g. from server).
final class ChallengePayload extends SignaturePayload {
  const ChallengePayload(this.challenge);
  final String challenge;
}

/// Result of the signature flow.
class BiometricSignatureFlowResult {
  const BiometricSignatureFlowResult({
    required this.signResult,
    required this.deviceReport,
  });

  final SignResult signResult;
  final DeviceIntegrityReport deviceReport;
}

enum _SignMode { deviceSignature, challenge }

enum _Step { deviceIntegrity, prepareKeys, authenticate, sign, done }

/// Unified flow: challenge input, generate signature with expandable step details, and verify.
///
/// - Challenge input: toggle Device signature / Challenge; when Challenge, show TextField
/// - Steps: each has expandable details (tap icon to expand, collapsed by default)
/// - Verify: widget to try verification (callback or built-in)
class BiometricSignatureFlow extends StatefulWidget {
  const BiometricSignatureFlow({
    super.key,
    this.signatureService,
    this.initialPayload = const DeviceSignaturePayload(),
    this.title = 'Biometric signature',
    this.subtitle = 'Generate & verify secure signatures',
    this.throwOnCompromised = false,
    this.onSuccess,
    this.onError,
    this.onVerify,
  });

  final SignatureService? signatureService;
  final SignaturePayload initialPayload;
  final String title;
  final String subtitle;
  final bool throwOnCompromised;
  final void Function(BiometricSignatureFlowResult result)? onSuccess;
  final void Function(Object error)? onError;
  /// Called when user taps Verify. App should POST result to server and handle response.
  final void Function(BiometricSignatureFlowResult result)? onVerify;

  @override
  State<BiometricSignatureFlow> createState() => _BiometricSignatureFlowState();
}

class _BiometricSignatureFlowState extends State<BiometricSignatureFlow> {
  late SignatureService _service;
  _SignMode _mode = _SignMode.deviceSignature;
  final TextEditingController _challengeController = TextEditingController();
  final FocusNode _challengeFocus = FocusNode();
  _Step _currentStep = _Step.deviceIntegrity;
  final Set<_Step> _completedSteps = {};
  final Set<_Step> _expandedSteps = {};
  bool _isRunning = false;
  bool _isComplete = false;
  BiometricSignatureFlowResult? _result;
  Object? _error;
  DeviceIntegrityReport? _deviceReport;

  late SignatureStorage _storage;
  StoredSignature? _stored;
  bool _storedLoaded = false;
  VerifyResult? _verifyResult;
  bool _verifyRunning = false;

  static const _steps = [
    _Step.deviceIntegrity,
    _Step.prepareKeys,
    _Step.authenticate,
    _Step.sign,
    _Step.done,
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.signatureService ?? SignatureService();
    _storage = SignatureStorage();
    _loadStored();
    if (widget.initialPayload is ChallengePayload) {
      _mode = _SignMode.challenge;
      _challengeController.text =
          (widget.initialPayload as ChallengePayload).challenge;
    }
  }

  @override
  void dispose() {
    _challengeController.dispose();
    _challengeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadStored() async {
    final s = await _storage.load();
    if (mounted) setState(() {
      _stored = s;
      _storedLoaded = true;
    });
  }

  Future<void> _saveToFile() async {
    final r = _result;
    if (r == null) return;
    await _storage.save(StoredSignature.fromSignResult(r.signResult));
    if (mounted) {
      setState(() => _stored = StoredSignature.fromSignResult(r.signResult));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to stored_signature.json')),
      );
    }
  }

  Future<void> _runVerifyChallenge() async {
    if (_stored == null || _verifyRunning) return;
    final challenge = _challengeController.text.trim();
    if (challenge.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a challenge first')),
      );
      return;
    }
    setState(() {
      _verifyRunning = true;
      _verifyResult = null;
    });
    try {
      final signResult = await _service.signChallenge(challenge,
          throwOnCompromised: widget.throwOnCompromised);
      if (!mounted) return;
      final vr = SignatureVerifier().verify(signResult, _stored!);
      setState(() {
        _verifyResult = vr;
        _verifyRunning = false;
      });
    } on Object catch (e) {
      if (mounted) setState(() {
        _verifyResult = VerifyError(e.toString());
        _verifyRunning = false;
      });
    }
  }

  SignaturePayload get _payload {
    if (_mode == _SignMode.challenge) {
      final c = _challengeController.text.trim();
      return ChallengePayload(c.isEmpty ? 'test-challenge' : c);
    }
    return const DeviceSignaturePayload();
  }

  Future<void> _runFlow() async {
    if (_isRunning) return;
    if (_mode == _SignMode.challenge && _challengeController.text.trim().isEmpty) {
      _challengeFocus.requestFocus();
      return;
    }

    setState(() {
      _isRunning = true;
      _currentStep = _Step.deviceIntegrity;
      _completedSteps.clear();
      _isComplete = false;
      _result = null;
      _error = null;
      _deviceReport = null;
    });

    String payloadToSign;

    try {
      if (_payload is ChallengePayload) {
        payloadToSign = (_payload as ChallengePayload).challenge;
        _tick(_Step.deviceIntegrity);
      } else {
        _animateTo(_Step.deviceIntegrity);
        final di = DeviceIntegritySignature();
        final report = await di.getReport(
          throwOnCompromised: widget.throwOnCompromised,
        );
        if (!mounted) return;
        _deviceReport = report;
        payloadToSign = report.signature;
        _tick(_Step.deviceIntegrity);
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      _animateTo(_Step.prepareKeys);
      await _service.ensureKeys();
      if (!mounted) return;
      _tick(_Step.prepareKeys);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      _animateTo(_Step.authenticate);
      final signResult = await _service.sign(
        payloadToSign,
        promptMessage: 'Verify identity to sign',
        throwOnCompromised: widget.throwOnCompromised,
      );
      if (!mounted) return;

      _deviceReport ??= signResult.deviceReport;
      _tick(_Step.authenticate);
      _tick(_Step.sign);

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      _tick(_Step.done);
      _animateTo(_Step.done);
      setState(() {
        _result = BiometricSignatureFlowResult(
          signResult: signResult,
          deviceReport: _deviceReport!,
        );
        _isComplete = true;
        _isRunning = false;
      });
      widget.onSuccess?.call(_result!);
    } on BiometricHardwareUnavailableException catch (e) {
      _handleError(e);
    } on UserCanceledException catch (e) {
      _handleError(e);
    } on Object catch (e) {
      _handleError(e);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() => _isRunning = false);
    setState(() => _error = e);
    widget.onError?.call(e);
  }

  void _tick(_Step step) {
    if (!mounted) return;
    setState(() => _completedSteps.add(step));
    setState(() => _currentStep = step);
  }

  void _animateTo(_Step step) {
    if (!mounted) return;
    setState(() => _currentStep = step);
  }

  void _toggleExpand(_Step step) {
    setState(() {
      if (_expandedSteps.contains(step)) {
        _expandedSteps.remove(step);
      } else {
        _expandedSteps.add(step);
      }
    });
  }

  void _verify() {
    final r = _result;
    if (r == null) return;
    if (widget.onVerify != null) {
      widget.onVerify!(r);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set onVerify to handle verification'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(cs),
          const SizedBox(height: 24),
          _buildChallengeInput(cs),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _buildErrorCard(),
            const SizedBox(height: 20),
          ],
          if (!_isComplete && !_isRunning) _buildStartButton(),
          if (_isRunning || _isComplete) ...[
            _buildChecklist(cs),
            const SizedBox(height: 24),
          ],
          if (_isComplete && _result != null) ...[
            _buildSuccessCard(cs),
            const SizedBox(height: 16),
            _buildSaveSection(cs),
            const SizedBox(height: 24),
            _buildVerifySection(cs),
            const SizedBox(height: 24),
            _buildFullCycleTestSection(cs),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.2),
                cs.primary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.fingerprint_rounded, size: 32, color: cs.primary),
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 15,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeInput(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What to sign',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_SignMode>(
            segments: const [
              ButtonSegment(
                value: _SignMode.deviceSignature,
                icon: Icon(Icons.phone_android_rounded, size: 18),
                label: Text('Device signature'),
              ),
              ButtonSegment(
                value: _SignMode.challenge,
                icon: Icon(Icons.tag_rounded, size: 18),
                label: Text('Challenge'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          if (_mode == _SignMode.challenge) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _challengeController,
              focusNode: _challengeFocus,
              decoration: InputDecoration(
                labelText: 'Challenge (from server)',
                hintText: 'Paste or type challenge string',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _challengeController.clear(),
                ),
              ),
              maxLines: 2,
              enabled: !_isRunning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return FilledButton.icon(
      onPressed: _runFlow,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Generate signature'),
    );
  }

  Widget _buildChecklist(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: cs.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Steps',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._steps.map((s) => _ChecklistStep(
                step: s,
                label: _stepLabel(s),
                icon: _stepIcon(s),
                isDone: _completedSteps.contains(s) || _isComplete,
                isCurrent: s == _currentStep && _isRunning,
                isExpanded: _expandedSteps.contains(s),
                onTap: () => _toggleExpand(s),
                details: _stepDetails(s, cs),
              )),
        ],
      ),
    );
  }

  String _stepLabel(_Step s) {
    switch (s) {
      case _Step.deviceIntegrity:
        return _payload is ChallengePayload ? 'Challenge ready' : 'Device integrity';
      case _Step.prepareKeys:
        return 'Secure keys';
      case _Step.authenticate:
        return 'Biometric auth';
      case _Step.sign:
        return 'Sign payload';
      case _Step.done:
        return 'Complete';
    }
  }

  IconData _stepIcon(_Step s) {
    switch (s) {
      case _Step.deviceIntegrity:
        return Icons.phone_android_rounded;
      case _Step.prepareKeys:
        return Icons.key_rounded;
      case _Step.authenticate:
        return Icons.fingerprint_rounded;
      case _Step.sign:
        return Icons.draw_rounded;
      case _Step.done:
        return Icons.check_circle_rounded;
    }
  }

  Widget? _stepDetails(_Step s, ColorScheme cs) {
    switch (s) {
      case _Step.deviceIntegrity:
        if (_deviceReport != null) {
          final r = _deviceReport!;
          return _DetailsBlock(
            children: [
              _DetailRow('Signature', r.signature),
              _DetailRow('Compromised', '${r.isCompromised}'),
              if (r.metadata.isNotEmpty)
                ...r.metadata.entries
                    .map((e) => _DetailRow(e.key.toString(), e.value?.toString() ?? '')),
            ],
          );
        }
        if (_payload is ChallengePayload) {
          return _DetailsBlock(
            children: [
              _DetailRow(
                'Challenge',
                (_payload as ChallengePayload).challenge,
              ),
            ],
          );
        }
        return const _DetailsBlock(
          children: [Text('Run flow to see device report')],
        );
      case _Step.prepareKeys:
        return const _DetailsBlock(
          children: [
            Text(
              'Hardware-backed keys are created in secure storage. '
              'They survive app reinstall where supported.',
            ),
          ],
        );
      case _Step.authenticate:
        return const _DetailsBlock(
          children: [
            Text(
              'User authenticates with fingerprint or face. '
              'Keys are bound to biometrics.',
            ),
          ],
        );
      case _Step.sign:
        if (_result != null) {
          final r = _result!.signResult;
          return _DetailsBlock(
            children: [
              _DetailRow('Signature', r.signature),
              if (r.publicKey != null) _DetailRow('Public key', r.publicKey!),
              _DetailRow('Signed payload', r.signedPayload),
              _DetailRow('Device signature', r.deviceSignature),
            ],
          );
        }
        return const _DetailsBlock(
          children: [Text('Signature will appear after completion')],
        );
      case _Step.done:
        return const _DetailsBlock(
          children: [Text('All steps completed successfully.')],
        );
    }
  }

  Widget _buildSuccessCard(ColorScheme cs) {
    const green = Color(0xFF22C55E);
    final r = _result!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            green.withValues(alpha: 0.12),
            green.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: green, size: 28),
              const SizedBox(width: 12),
              Text(
                'Signature generated',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CopyableRow(label: 'Device', value: r.deviceReport.signature),
          _CopyableRow(label: 'Biometric', value: r.signResult.signature),
          if (r.signResult.publicKey != null)
            _CopyableRow(label: 'Public key', value: r.signResult.publicKey!),
        ],
      ),
    );
  }

  Widget _buildSaveSection(ColorScheme cs) {
    return OutlinedButton.icon(
      onPressed: _saveToFile,
      icon: const Icon(Icons.save_rounded),
      label: const Text('Save to file (acts as server storage)'),
    );
  }

  Widget _buildVerifySection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Text(
                'Verify',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.onVerify != null
                ? 'Try verification against your server.'
                : 'Set onVerify to enable verification.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _verify,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Verify (callback)'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCycleTestSection(ColorScheme cs) {
    if (!_storedLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Text(
                'Full cycle test',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _stored != null
                ? 'Stored: signature + publicKey loaded from file. Sign a challenge and verify against stored.'
                : 'Save above first to simulate server storage. Then sign a challenge and verify.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _challengeController,
            focusNode: _challengeFocus,
            decoration: const InputDecoration(
              labelText: 'Challenge to sign',
              hintText: 'e.g. server-nonce-123',
              border: OutlineInputBorder(),
            ),
            enabled: !_verifyRunning && _stored != null,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _stored != null && !_verifyRunning ? _runVerifyChallenge : null,
            icon: _verifyRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_rounded),
            label: Text(_verifyRunning ? 'Signing...' : 'Sign challenge & verify'),
          ),
          if (_verifyResult != null) ...[
            const SizedBox(height: 16),
            _buildVerifyResultCard(cs, _verifyResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifyResultCard(ColorScheme cs, VerifyResult vr) {
    return switch (vr) {
      VerifySuccess(:final message) => _resultCard(
          cs,
          const Color(0xFF22C55E),
          Icons.check_circle_rounded,
          'Verified',
          message ?? 'Public key matches. Same device.',
        ),
      VerifyDeviceMismatch(:final message) => _resultCard(
          cs,
          const Color(0xFFF59E0B),
          Icons.warning_rounded,
          'Device mismatch',
          message ?? 'Public key does not match stored.',
        ),
      VerifyError(:final message) => _resultCard(
          cs,
          Colors.red,
          Icons.error_rounded,
          'Error',
          message,
        ),
    };
  }

  Widget _resultCard(
    ColorScheme cs,
    Color color,
    IconData icon,
    String title,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error.toString(),
              style: TextStyle(color: Colors.red.shade800, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistStep extends StatelessWidget {
  const _ChecklistStep({
    required this.step,
    required this.label,
    required this.icon,
    required this.isDone,
    required this.isCurrent,
    required this.isExpanded,
    required this.onTap,
    this.details,
  });

  final _Step step;
  final String label;
  final IconData icon;
  final bool isDone;
  final bool isCurrent;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const green = Color(0xFF22C55E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isExpanded
                ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? green.withValues(alpha: 0.15)
                            : isCurrent
                                ? cs.primary.withValues(alpha: 0.15)
                                : cs.surfaceContainerHighest,
                      ),
                      child: isDone
                          ? Icon(Icons.check_rounded, color: green, size: 22)
                          : isCurrent
                              ? Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : Icon(
                                  icon,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  size: 20,
                                ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              if (isExpanded && details != null) ...[
                const SizedBox(height: 14),
                details!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.length > 60 ? '${value.substring(0, 60)}...' : value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}
