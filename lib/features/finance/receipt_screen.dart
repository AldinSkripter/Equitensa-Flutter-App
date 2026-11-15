import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'expenses_screen.dart';
import 'finance_common.dart';
import '../workspace/workspace_widgets.dart';

enum _Stage { capture, scanning, review }

/// Camera/gallery -> review -> upload -> expense. Images are sent as the same bytes as on web.
/// Limits from the backend contract: JPEG/PNG <= 2,000,000 bytes, <= 6000 px; HEIC is converted by the picker.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, this.manual = false});
  final bool manual;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  static const _maxBytes = 2000000;
  final _picker = ImagePicker();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late _Stage _stage = widget.manual ? _Stage.review : _Stage.capture;
  Uint8List? _bytes;
  String _filename = 'receipt.jpg';
  String _date = Fmt.today();
  String _category = 'office';
  bool _reviewed = false;
  bool _recognised = false;
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in [_supplier, _reference, _amount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _capture(ImageSource source) async {
    final t = trOf(ref);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxBytes) {
        if (mounted) {
          showSnack(
            context,
            t('Die Datei ist größer als 2 MB.', 'Datoteka je večja od 2 MB.'),
            error: true,
          );
        }
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name.isEmpty ? 'receipt.jpg' : file.name;
        _stage = _Stage.scanning;
      });
      await _scan();
    } on PlatformException {
      if (mounted) {
        showSnack(
          context,
          t(
            'Kamera nicht verfügbar oder Berechtigung verweigert. Sie können manuell erfassen.',
            'Kamera ni na voljo ali dovoljenje ni odobreno. Vnesete lahko ročno.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await pickDocument(maxBytes: _maxBytes);
      if (file == null || !mounted) return;
      setState(() {
        _bytes = file.bytes;
        _filename = file.name;
        _stage = _Stage.scanning;
      });
      await _scan();
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _scan() async {
    try {
      final r = await ref.read(repositoryProvider).scanReceipt(_filename, _bytes!);
      if (!mounted) return;
      setState(() {
        _supplier.text = r.supplier;
        _reference.text = r.reference;
        _amount.text = r.amount;
        if (r.incurredOn.isNotEmpty) _date = r.incurredOn;
        if (expenseCategories.contains(r.category)) _category = r.category;
        _note.text = r.note;
        _recognised = true;
        _stage = _Stage.review;
      });
    } catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() {
        _recognised = false;
        _stage = _Stage.review;
      });
    }
  }

  Future<void> _save() async {
    final t = trOf(ref);
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    setState(() => _submitted = true);
    final needsReview = _bytes != null && !_reviewed;
    if (_supplier.text.trim().isEmpty ||
        _reference.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        needsReview) {
      showSnack(
        context,
        t(
          'Bitte prüfen Sie die markierten Angaben.',
          'Preverite označene podatke.',
        ),
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final fields = {
      'supplier': _supplier.text.trim(),
      'reference': _reference.text.trim(),
      'incurredOn': _date,
      'amount': amount.toStringAsFixed(2),
      'category': _category,
      'note': _note.text.trim(),
    };
    final repo = ref.read(repositoryProvider);
    final res = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => _bytes == null
                ? repo.createExpense(rev, fields)
                : repo.importReceipt(
                    revision: rev,
                    filename: _filename,
                    bytes: _bytes!,
                    fields: fields,
                  ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      showSnack(context, t('Ausgabe gespeichert.', 'Strošek shranjen.'));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final snap = ref.watch(financeProvider).value;
    final blocked = snap != null && !snap.hasFeature('expenses');
    return SubPage(
      kicker: 'Equitensa Finance',
      title: t('Beleg erfassen', 'Zajem računa'),
      bottom: _stage == _Stage.review && !blocked
          ? EqButton(
              label: t('Als Ausgabe speichern', 'Shrani kot strošek'),
              icon: LucideIcons.check,
              busy: _saving,
              onPressed: _save,
            )
          : null,
      child: blocked
          ? StateMessage(
              icon: LucideIcons.sparkles,
              title: t('Im Paket nicht enthalten', 'Ni vključeno v paket'),
              body: t(
                'Belegerkennung ist ab dem Paket Business verfügbar.',
                'Prepoznava računov je na voljo od paketa Business naprej.',
              ),
              actionLabel: t('Pakete ansehen', 'Poglej pakete'),
              onAction: () => context.push('/finance/plans'),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: switch (_stage) {
                _Stage.capture => _capturePane(t),
                _Stage.scanning => _scanning(t),
                _Stage.review => _review(t),
              },
            ),
    );
  }

  Widget _capturePane(Tr t) => ListView(
    key: const ValueKey('capture'),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
    children: [
      Container(
        height: 210,
        decoration: BoxDecoration(
          gradient: Eq.heroGradient,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
            ),
            const Icon(LucideIcons.scanLine, size: 54, color: Colors.white),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(
        t('Beleg erfassen', 'Zajem računa'),
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: context.eq.ink2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        t(
          'Foto oder Datei hochladen. Die Erkennung ist nur ein Vorschlag – Aussteller, Datum und Betrag prüfen Sie selbst. Es erfolgt keine automatische Buchung oder Vorsteuerberechnung.',
          'Naložite fotografijo ali datoteko. Prepoznava je le predlog – izdajatelja, datum in znesek preverite sami. Samodejnega knjiženja ali odbitka DDV ni.',
        ),
        style: TextStyle(color: context.eq.muted, height: 1.5),
      ),
      const SizedBox(height: 22),
      EqButton(
        label: t('Foto aufnehmen', 'Slikaj'),
        icon: LucideIcons.camera,
        onPressed: () => _capture(ImageSource.camera),
      ),
      const SizedBox(height: 10),
      EqButton(
        kind: BtnKind.secondary,
        label: t('Aus Galerie wählen', 'Izberi iz galerije'),
        icon: LucideIcons.image,
        onPressed: () => _capture(ImageSource.gallery),
      ),
      const SizedBox(height: 10),
      EqButton(
        kind: BtnKind.secondary,
        label: t('PDF, XML oder Bilddatei wählen', 'Izberi PDF, XML ali sliko'),
        icon: LucideIcons.fileUp,
        onPressed: _pickFile,
      ),
      const SizedBox(height: 6),
      EqButton(
        kind: BtnKind.ghost,
        label: t('Manuell erfassen', 'Vnesi ročno'),
        onPressed: () => setState(() => _stage = _Stage.review),
      ),
    ],
  );

  Widget _scanning(Tr t) => Center(
    key: const ValueKey('scanning'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _bytes!,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ListTile(leading: const Icon(LucideIcons.fileText), title: Text(_filename)),
            ),
          ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          t('Beleg wird gelesen …', 'Branje računa …'),
          style: TextStyle(fontWeight: FontWeight.w600, color: context.eq.ink2),
        ),
      ],
    ),
  );

  Widget _review(Tr t) => ListView(
    key: const ValueKey('review'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      if (_bytes != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            _bytes!,
            height: 170,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ListTile(leading: const Icon(LucideIcons.fileText), title: Text(_filename)),
          ),
        ),
        const SizedBox(height: 12),
      ],
      NoticeBanner(
        _bytes == null
            ? t(
                'Manuelle Erfassung – es wurde nichts automatisch erkannt.',
                'Ročni vnos – nič ni bilo samodejno prepoznano.',
              )
            : _recognised
            ? t(
                'Bitte prüfen: Die Erkennung kann Aussteller und Empfänger oder Rechnungs- und Fälligkeitsdatum verwechseln.',
                'Preverite: prepoznava lahko zamenja izdajatelja in prejemnika ali datum računa in zapadlosti.',
              )
            : t(
                'Nichts erkannt – bitte Angaben selbst eintragen.',
                'Nič ni prepoznano – podatke vnesite sami.',
              ),
        color: _recognised ? Eq.violet : Eq.warning,
      ),
      const SizedBox(height: 18),
      EqField(
        label: t('Lieferant', 'Dobavitelj'),
        controller: _supplier,
        validator: null,
      ),
      if (_submitted && _supplier.text.trim().isEmpty) _err(t('Pflichtfeld', 'Obvezno polje')),
      const SizedBox(height: 14),
      EqField(label: t('Belegnummer', 'Referenca'), controller: _reference),
      if (_submitted && _reference.text.trim().isEmpty) _err(t('Pflichtfeld', 'Obvezno polje')),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EqField(
              label: t('Betrag (brutto)', 'Znesek (bruto)'),
              controller: _amount,
              suffixText: '€',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Labeled(
              t('Datum', 'Datum'),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(
                      () => _date = d.toIso8601String().substring(0, 10),
                    );
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Labeled(
        t('Kategorie', 'Kategorija'),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final c in expenseCategories)
              ChoiceChip(
                avatar: Icon(
                  categoryIcon(c),
                  size: 15,
                  color: _category == c ? Colors.white : context.eq.muted,
                ),
                label: Text(categoryLabel(t, c)),
                selected: _category == c,
                showCheckmark: false,
                selectedColor: Eq.violet,
                backgroundColor: Colors.white,
                side: BorderSide(color: _category == c ? Eq.violet : context.eq.line),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _category == c ? Colors.white : context.eq.ink2,
                ),
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      EqField(label: t('Notiz', 'Opomba'), controller: _note, maxLines: 2),
      if (_bytes != null) ...[
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Eq.violet,
          value: _reviewed,
          onChanged: (v) => setState(() => _reviewed = v ?? false),
          title: Text(
            t(
              'Ich habe die Angaben mit dem Originalbeleg geprüft.',
              'Podatke sem preveril z izvirnim računom.',
            ),
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          subtitle: _submitted && !_reviewed
              ? Text(
                  t('Bitte bestätigen', 'Prosimo, potrdite'),
                  style: const TextStyle(color: Eq.danger, fontSize: 12.5),
                )
              : null,
        ),
        TextButton(
          onPressed: () => setState(() => _stage = _Stage.capture),
          child: Text(t('Neu aufnehmen', 'Ponovno slikaj')),
        ),
      ],
    ],
  );

  Widget _err(String m) => Padding(
    padding: const EdgeInsets.only(top: 5, left: 4),
    child: Text(m, style: const TextStyle(color: Eq.danger, fontSize: 12.5)),
  );
}
