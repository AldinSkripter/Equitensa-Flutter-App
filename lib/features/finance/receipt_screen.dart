import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'conflict.dart';

enum _Stage { capture, scanning, review }

/// Camera/gallery -> review -> upload -> expense. Business/Pro only.
/// Images are re-encoded as JPEG within the backend limits (<= 2,000,000 bytes, <= 2000px side here).
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  static const _maxBytes = 2000000;
  final _picker = ImagePicker();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  _Stage _stage = _Stage.capture;
  Uint8List? _bytes;
  String _filename = 'receipt.jpg';
  DateTime _date = DateTime.now();
  String _category = 'office';
  bool _reviewed = false;
  bool _uploading = false;
  bool _recognised = false;

  @override
  void dispose() {
    _supplier.dispose();
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    final s = S.of(context);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxBytes) {
        if (mounted) _snack(s.t('file_too_large'));
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name.isEmpty ? 'receipt.jpg' : file.name;
        _stage = _Stage.scanning;
      });
      await _scan();
    } on PlatformException {
      // Permission denied or no camera: offer manual entry without implying recognition.
      if (mounted) _snack(s.t('camera_unavailable'));
    }
  }

  Future<void> _scan() async {
    try {
      final r = await ref
          .read(repositoryProvider)
          .scanReceipt(_filename, _bytes!);
      if (!mounted) return;
      setState(() {
        _supplier.text = r.supplier;
        _reference.text = r.reference;
        _amount.text = (r.amountCents / 100).toStringAsFixed(2);
        _date = r.incurredOn;
        _category = r.category;
        _recognised = true;
        _stage = _Stage.review;
      });
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      setState(() {
        _stage = _Stage.review;
        _recognised = false;
      });
    }
  }

  void _manual() => setState(() {
    _bytes = null;
    _recognised = false;
    _stage = _Stage.review;
  });

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _upload() async {
    final s = S.of(context);
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (_supplier.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        !_reviewed) {
      _snack(s.t('err_validation'));
      return;
    }
    setState(() => _uploading = true);
    try {
      final rev = await ref.latestRevision();
      await ref
          .read(repositoryProvider)
          .importReceipt(
            revision: rev,
            filename: _filename,
            reviewed: ReceiptSuggestion(
              supplier: _supplier.text.trim(),
              reference: _reference.text.trim(),
              incurredOn: _date,
              amountCents: (amount * 100).round(),
              category: _category,
            ),
          );
      ref.refreshFinanceData();
      if (mounted) {
        _snack(s.t('receipt_saved'));
        context.pop();
      }
    } on VersionConflictException {
      if (!mounted) return;
      ref.refreshFinanceData();
      final c = await showConflictDialog(context);
      if (c == ConflictChoice.reloadAndRetry && mounted) {
        setState(() => _uploading = false);
        await _upload();
        return;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final plan = ref.watch(sessionProvider)?.plan;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('scan_receipt'))),
      body: plan?.hasExpenses != true
          ? ErrorView(error: const PlanUpgradeException(), onRetry: () {})
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_stage) {
                _Stage.capture => _capturePane(s),
                _Stage.scanning => _scanningPane(s),
                _Stage.review => _reviewPane(s),
              },
            ),
    );
  }

  Widget _capturePane(S s) => ListView(
    key: const ValueKey('capture'),
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: Brand.financeGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Icon(
          Icons.document_scanner_rounded,
          size: 84,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        s.t('receipt_intro_title'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        s.t('receipt_intro_body'),
        style: const TextStyle(color: Brand.muted, height: 1.45),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => _capture(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_rounded),
        label: Text(s.t('take_photo')),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _capture(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(s.t('choose_file')),
      ),
      const SizedBox(height: 12),
      TextButton(onPressed: _manual, child: Text(s.t('enter_manually'))),
    ],
  );

  Widget _scanningPane(S s) => Center(
    key: const ValueKey('scanning'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(_bytes!, height: 220, fit: BoxFit.cover),
          ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 18),
        Text(
          s.t('scanning'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _reviewPane(S s) {
    final lang = ref.watch(languageProvider);
    return ListView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.all(20),
      children: [
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _bytes!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (_recognised ? Brand.violet : Brand.warning).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _recognised
                    ? Icons.auto_awesome_rounded
                    : Icons.edit_note_rounded,
                color: _recognised ? Brand.violet : Brand.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.t(_recognised ? 'review_hint' : 'manual_hint'),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _supplier,
          decoration: InputDecoration(labelText: s.t('supplier')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: InputDecoration(labelText: s.t('reference')),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: s.t('amount_gross'),
                  suffixText: '€',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: s.t('date')),
                  child: Text(
                    fmtDate(_date, lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(labelText: s.t('category')),
          items: [
            for (final c in const [
              'office',
              'software',
              'travel',
              'meals',
              'other',
            ])
              DropdownMenuItem(value: c, child: Text(s.t('cat_$c'))),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Brand.violet,
          value: _reviewed,
          onChanged: (v) => setState(() => _reviewed = v ?? false),
          title: Text(
            s.t('confirm_reviewed'),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _uploading ? null : _upload,
          child: _uploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(s.t('upload_expense')),
        ),
        TextButton(
          onPressed: () => setState(() => _stage = _Stage.capture),
          child: Text(s.t('retake')),
        ),
      ],
    );
  }
}
