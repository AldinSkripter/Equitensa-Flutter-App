import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import 'finance_common.dart';
import 'invoice_sheet.dart';

class _LineForm {
  _LineForm({
    String? description,
    String quantity = '1',
    String unit = 'Stk.',
    String price = '',
    this.rate = '20',
    String discount = '0',
  }) : desc = TextEditingController(text: description),
       qty = TextEditingController(text: quantity),
       unit = TextEditingController(text: unit),
       price = TextEditingController(text: price),
       discount = TextEditingController(text: discount);

  final TextEditingController desc, qty, unit, price, discount;
  String rate;

  void dispose() {
    for (final c in [desc, qty, unit, price, discount]) {
      c.dispose();
    }
  }

  static double? num(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

  bool get valid =>
      desc.text.trim().isNotEmpty &&
      (num(qty.text) ?? 0) > 0 &&
      (num(price.text) ?? -1) >= 0 &&
      (num(discount.text) ?? -1) >= 0;

  Map<String, dynamic> toJson() => {
    'description': desc.text.trim(),
    'quantity': qty.text.trim().replaceAll(',', '.'),
    'unit': unit.text.trim().isEmpty ? 'Stk.' : unit.text.trim(),
    'unitPrice': price.text.trim().replaceAll(',', '.'),
    'rate': rate,
    'discountPercent': discount.text.trim().replaceAll(',', '.'),
  };
}

class ComposerScreen extends ConsumerStatefulWidget {
  const ComposerScreen({super.key, required this.kind, this.editId});
  final String kind;
  final String? editId;

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  late String _kind = widget.kind == 'offer' ? 'offer' : 'invoice';
  Contact? _contact;
  String _issue = Fmt.today();
  String _service = Fmt.today();
  late String _due = DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10);
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final List<_LineForm> _lines = [];
  Map<String, dynamic>? _appearance;
  int _tab = 0;
  bool _saving = false;
  bool _submitted = false;
  bool _checking = false;
  Object? _previewError;
  FinDoc? _preview;
  Timer? _debounce;
  bool _loaded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _reference.dispose();
    _note.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _hydrate(FinanceSnapshot snap) {
    if (_loaded) return;
    _loaded = true;
    final country = snap.state.country;
    final unit = country == Country.si ? 'kos' : 'Stk.';
    final id = widget.editId;
    if (id != null) {
      final d = snap.state.documents.where((x) => x.id == id).firstOrNull;
      if (d != null) {
        _kind = d.kind;
        _contact = snap.state.contacts.where((c) => c.id == d.contactId).firstOrNull ?? d.customer;
        _issue = d.issueDate;
        _service = d.serviceDate;
        _due = d.dueDate;
        _reference.text = d.reference;
        _note.text = d.note;
        _appearance = d.appearance;
        for (final l in d.lines) {
          _lines.add(
            _LineForm(
              description: l.description,
              quantity: l.quantity,
              unit: l.unit,
              price: l.unitPrice,
              rate: l.rate,
              discount: l.discountPercent,
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _schedule(immediate: true),
        );
        return;
      }
    }
    _lines.add(_LineForm(unit: unit, rate: country.standardRate));
  }

  Map<String, dynamic> _body() => {
    'kind': _kind,
    'contactId': _contact?.id,
    'issueDate': _issue,
    'serviceDate': _service,
    'dueDate': _due,
    'reference': _reference.text.trim(),
    'note': _note.text.trim(),
    'appearance': _appearance,
    'lines': [for (final l in _lines) l.toJson()],
  };

  bool get _dirty =>
      _contact != null || _lines.any((l) => l.desc.text.isNotEmpty || l.price.text.isNotEmpty) || _note.text.isNotEmpty;
  bool get _valid =>
      _contact != null && _lines.isNotEmpty && _lines.every((l) => l.valid) && _due.compareTo(_issue) >= 0;

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    if (!_valid) {
      setState(() {
        _preview = null;
        _previewError = null;
      });
      return;
    }
    _debounce = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 550),
      () async {
        if (!mounted) return;
        setState(() => _checking = true);
        try {
          final p = await ref.read(repositoryProvider).preview(_body());
          if (mounted) {
            setState(() {
              _preview = p;
              _previewError = null;
            });
          }
        } on ApiException catch (e) {
          if (mounted) {
            setState(() {
              _preview = null;
              _previewError = e;
            });
          }
        } finally {
          if (mounted) setState(() => _checking = false);
        }
      },
    );
  }

  Future<void> _save() async {
    final t = trOf(ref);
    setState(() => _submitted = true);
    if (!_valid) {
      showSnack(
        context,
        t(
          'Bitte Kunde, Positionen, Beträge und Datumsangaben prüfen.',
          'Preverite stranko, postavke, zneske in datume.',
        ),
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final res = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => widget.editId == null
                ? repo.createDocument(rev, _body())
                : repo.editDocument(widget.editId!, rev, _body()),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      showSnack(context, t('Entwurf gespeichert.', 'Osnutek shranjen.'));
      context.pushReplacement('/finance/document/${res.id}');
    }
  }

  Future<void> _pickContact(FinanceSnapshot snap) async {
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ContactPicker(contacts: snap.state.contacts, selected: _contact?.id),
    );
    if (picked != null) {
      setState(() => _contact = picked);
      _schedule();
    }
  }

  Future<void> _pickDate(String current, void Function(String) set) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() => set(d.toIso8601String().substring(0, 10)));
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final snapAsync = ref.watch(financeProvider);
    return snapAsync.when(
      loading: () => SubPage(title: t('Dokument', 'Dokument'), child: const LoadingList()),
      error: (e, _) => SubPage(
        title: t('Dokument', 'Dokument'),
        child: ErrorView(
          error: e,
          onRetry: () => ref.read(financeProvider.notifier).reload(),
        ),
      ),
      data: (snap) {
        _hydrate(snap);
        final country = snap.state.country;
        final p = _preview;
        return PopScope(
          canPop: !_dirty || _saving,
          onPopInvokedWithResult: (did, _) async {
            if (did) return;
            final leave = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                  t('Entwurf verwerfen?', 'Zavržem osnutek?'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                content: Text(
                  t(
                    'Ihre nicht gespeicherten Eingaben gehen verloren.',
                    'Vaši neshranjeni vnosi bodo izgubljeni.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(t('Weiter bearbeiten', 'Nadaljuj z urejanjem')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      t('Verwerfen', 'Zavrzi'),
                      style: const TextStyle(color: Eq.danger),
                    ),
                  ),
                ],
              ),
            );
            if (leave == true && context.mounted) context.pop();
          },
          child: SubPage(
            kicker: 'Document Composer',
            title: widget.editId != null
                ? t(
                    'Aus dem Entwurf wird Ihr Dokument.',
                    'Osnutek postane vaš dokument.',
                  )
                : t('Ein neuer Auftrag.', 'Novo naročilo.'),
            bottom: Row(
              children: [
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Gesamt', 'Skupaj'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.eq.muted,
                          ),
                        ),
                        Text(
                          fmt.money(p.grossCents),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Eq.violet,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: EqButton(
                    label: t('Entwurf speichern', 'Shrani osnutek'),
                    icon: LucideIcons.save,
                    busy: _saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.eq.violetSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        for (final (i, label, icon) in [
                          (0, t('Daten', 'Podatki'), LucideIcons.fileText),
                          (
                            1,
                            t('Live-Dokument', 'Dokument v živo'),
                            LucideIcons.eye,
                          ),
                        ])
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _tab = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _tab == i ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _tab == i ? Eq.cardShadow : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 15,
                                      color: _tab == i ? Eq.violet : context.eq.muted,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                        color: _tab == i ? Eq.violet : context.eq.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _tab == 0 ? _form(snap, country, t, fmt) : _previewTab(snap, t),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewTab(FinanceSnapshot snap, Tr t) => ListView(
    key: const ValueKey('preview'),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: [
      Row(
        children: [
          Icon(LucideIcons.eye, size: 14, color: context.eq.muted),
          const SizedBox(width: 6),
          Text(
            t('Live-Dokument', 'Dokument v živo'),
            style: TextStyle(
              color: context.eq.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _checking ? t('Wird berechnet…', 'Izračun…') : t('Serverseitig berechnet', 'Izračunano na strežniku'),
            style: TextStyle(color: context.eq.muted, fontSize: 12.5),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_preview != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE9F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0D8EA)),
          ),
          child: InvoiceSheet(
            profile: snap.state.profile,
            companyName: snap.state.profile.name,
            country: snap.state.country,
            design: DocDesign.merge([
              snap.state.profile.design,
              (_appearance?['design'] as Map?)?.cast<String, dynamic>(),
            ]),
            accent: (_appearance?['accent'] as String?) ?? snap.state.profile.accent,
            doc: _preview,
          ),
        )
      else
        StateMessageBox(
          icon: LucideIcons.fileText,
          title: t(
            'Hier nimmt Ihr Dokument Form an.',
            'Tukaj nastaja vaš dokument.',
          ),
          body: _previewError != null
              ? errorMessage(t, _previewError!)
              : t(
                  'Kunden wählen und Leistungen eintragen. Die Vorschau zeigt die berechneten Werte, bevor Sie speichern.',
                  'Izberite stranko in vnesite storitve. Predogled pokaže izračun pred shranjevanjem.',
                ),
        ),
      const SizedBox(height: 10),
      Text(
        t(
          'Vorschau eines Entwurfs. PDF-Umbrüche können abweichen.',
          'Predogled osnutka. Prelomi v PDF se lahko razlikujejo.',
        ),
        style: TextStyle(color: context.eq.faint, fontSize: 12),
      ),
    ],
  );

  Widget _form(FinanceSnapshot snap, Country country, Tr t, Fmt fmt) {
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return ListView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _StepHeader('01', t('Die Grundlagen', 'Osnovni podatki')),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.eq.violetSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              for (final (k, label) in [
                ('invoice', t('Rechnung', 'Račun')),
                ('offer', t('Angebot', 'Ponudba')),
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: widget.editId != null
                        ? null
                        : () {
                            setState(() => _kind = k);
                            _schedule();
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kind == k ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _kind == k ? Eq.cardShadow : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kind == k ? Eq.violet : context.eq.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Labeled(
          t('Kunde', 'Stranka'),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickContact(snap),
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: _submitted && _contact == null ? t('Bitte Kunden wählen', 'Izberite stranko') : null,
                suffixIcon: const Icon(LucideIcons.chevronDown, size: 18),
              ),
              child: Text(
                _contact?.name ?? t('Kontakt auswählen', 'Izberite stik'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15.5,
                  color: _contact == null ? context.eq.faint : context.eq.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DateField(
                t('Ausgestellt', 'Izdano'),
                _issue,
                () => _pickDate(_issue, (v) => _issue = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                t('Leistung', 'Dobava'),
                _service,
                () => _pickDate(_service, (v) => _service = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DateField(
          t('Fälligkeit', 'Zapadlost'),
          _due,
          () => _pickDate(_due, (v) => _due = v),
          error: _due.compareTo(_issue) < 0 ? t('Vor dem Rechnungsdatum', 'Pred datumom računa') : null,
        ),
        const SizedBox(height: 14),
        EqField(
          label: t('Referenz (optional)', 'Referenca (neobvezno)'),
          controller: _reference,
          onChanged: (_) => _schedule(),
        ),
        _StepHeader(
          '02',
          t('Ihre Leistungen', 'Vaše storitve'),
          trailing: '${_lines.length}/100',
        ),
        for (var i = 0; i < _lines.length; i++) ...[
          _lineCard(i, country, t, decimal),
          const SizedBox(height: 12),
        ],
        EqButton(
          kind: BtnKind.secondary,
          label: t('Position hinzufügen', 'Dodaj postavko'),
          icon: LucideIcons.plus,
          onPressed: _lines.length >= 100
              ? null
              : () {
                  setState(
                    () => _lines.add(
                      _LineForm(
                        unit: country == Country.si ? 'kos' : 'Stk.',
                        rate: country.standardRate,
                      ),
                    ),
                  );
                },
        ),
        _StepHeader('03', t('Die persönliche Note', 'Osebna nota')),
        EqField(
          label: t('Nachricht für dieses Dokument', 'Sporočilo za ta dokument'),
          controller: _note,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _totals(t, fmt),
      ],
    );
  }

  Widget _totals(Tr t, Fmt fmt) {
    final p = _preview;
    Widget row(String l, int? c, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            l,
            style: TextStyle(
              fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              fontSize: big ? 16 : 14,
              color: context.eq.ink2,
            ),
          ),
          const Spacer(),
          Text(
            c == null ? '—' : fmt.money(c),
            style: TextStyle(
              fontWeight: big ? FontWeight.w700 : FontWeight.w600,
              fontSize: big ? 22 : 14,
              color: big ? Eq.violet : context.eq.ink2,
              letterSpacing: big ? -0.6 : 0,
            ),
          ),
        ],
      ),
    );
    return EqCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.badgeCheck, size: 16, color: Eq.violet),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  t(
                    'Serverseitig berechnet – verbindlich',
                    'Izračunano na strežniku – zavezujoče',
                  ),
                  style: TextStyle(
                    color: context.eq.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_checking)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          row('Netto', p?.netCents),
          row(t('USt.', 'DDV'), p?.taxCents),
          const Divider(height: 18),
          row(t('Gesamt', 'Skupaj'), p?.grossCents, big: true),
          if (_previewError != null) ...[
            const SizedBox(height: 8),
            NoticeBanner(errorMessage(t, _previewError!), color: Eq.danger),
          ],
        ],
      ),
    );
  }

  Widget _lineCard(
    int i,
    Country country,
    Tr t,
    List<TextInputFormatter> decimal,
  ) {
    final l = _lines[i];
    String? err(
      TextEditingController c, {
      bool number = false,
      bool positive = false,
    }) {
      if (!_submitted) return null;
      if (c.text.trim().isEmpty) return t('Pflichtfeld', 'Obvezno polje');
      if (number) {
        final v = _LineForm.num(c.text);
        if (v == null || (positive && v <= 0)) return t('Ungültig', 'Neveljavno');
      }
      return null;
    }

    return EqCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Kicker(
                '${t('Position', 'Postavka')} ${(i + 1).toString().padLeft(2, '0')}',
              ),
              const Spacer(),
              _MiniBtn(
                LucideIcons.arrowUp,
                i == 0
                    ? null
                    : () => setState(() {
                        final x = _lines.removeAt(i);
                        _lines.insert(i - 1, x);
                        _schedule();
                      }),
              ),
              _MiniBtn(
                LucideIcons.arrowDown,
                i == _lines.length - 1
                    ? null
                    : () => setState(() {
                        final x = _lines.removeAt(i);
                        _lines.insert(i + 1, x);
                        _schedule();
                      }),
              ),
              _MiniBtn(
                LucideIcons.copy,
                _lines.length >= 100
                    ? null
                    : () => setState(() {
                        _lines.insert(
                          i + 1,
                          _LineForm(
                            description: l.desc.text,
                            quantity: l.qty.text,
                            unit: l.unit.text,
                            price: l.price.text,
                            rate: l.rate,
                            discount: l.discount.text,
                          ),
                        );
                        _schedule();
                      }),
              ),
              _MiniBtn(
                LucideIcons.trash2,
                _lines.length == 1
                    ? null
                    : () => setState(() {
                        _lines.removeAt(i).dispose();
                        _schedule();
                      }),
                danger: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Labeled(
            t('Beschreibung', 'Opis'),
            child: TextField(
              controller: l.desc,
              maxLines: 2,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                counterText: '',
                hintText: t(
                  'Was haben Sie für Ihren Kunden geleistet?',
                  'Kaj ste opravili za stranko?',
                ),
                errorText: err(l.desc),
              ),
              onChanged: (_) => _schedule(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: EqField(
                  label: t('Menge', 'Količina'),
                  controller: l.qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formatters: decimal,
                  onChanged: (_) => _schedule(),
                  validator: null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EqField(
                  label: t('Einheit', 'Enota'),
                  controller: l.unit,
                  onChanged: (_) => _schedule(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Labeled(
                  t('Preis netto', 'Neto cena'),
                  child: TextField(
                    controller: l.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: decimal,
                    decoration: InputDecoration(
                      suffixText: '€',
                      errorText: err(l.price, number: true),
                    ),
                    onChanged: (_) => _schedule(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EqField(
                  label: t('Rabatt %', 'Popust %'),
                  controller: l.discount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  formatters: decimal,
                  onChanged: (_) => _schedule(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Labeled(
            t('USt. %', 'DDV %'),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final r in country.rates)
                  ChoiceChip(
                    label: Text('$r %'),
                    selected: l.rate == r,
                    showCheckmark: false,
                    selectedColor: Eq.violet,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: l.rate == r ? Eq.violet : context.eq.line),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: l.rate == r ? Colors.white : context.eq.ink2,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => l.rate = r);
                      _schedule();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StateMessageBox extends StatelessWidget {
  const StateMessageBox({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => EqCard(
    padding: const EdgeInsets.all(26),
    child: Column(
      children: [
        Icon(icon, size: 36, color: Eq.violet),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.eq.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.eq.muted, height: 1.5),
        ),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader(this.n, this.title, {this.trailing});
  final String n;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: context.eq.violetSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            n,
            style: const TextStyle(
              color: Eq.violet,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: context.eq.ink2,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(color: context.eq.faint, fontSize: 12.5),
          ),
      ],
    ),
  );
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn(this.icon, this.onTap, {this.danger = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => IconButton(
    visualDensity: VisualDensity.compact,
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 17,
      color: onTap == null ? context.eq.line : (danger ? Eq.danger : context.eq.muted),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField(this.label, this.value, this.onTap, {this.error});
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) => Labeled(
    label,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: error,
          suffixIcon: const Icon(LucideIcons.calendar, size: 17),
        ),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
    ),
  );
}

class _ContactPicker extends ConsumerWidget {
  const _ContactPicker({required this.contacts, required this.selected});
  final List<Contact> contacts;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trOf(ref);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t('Kontakt auswählen', 'Izberite stik'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/finance/contact');
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(t('Neu', 'Nov')),
                ),
              ],
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? StateMessage(
                    icon: LucideIcons.users,
                    title: t('Noch keine Kontakte', 'Še ni stikov'),
                    body: t(
                      'Legen Sie Ihren ersten Kunden an.',
                      'Dodajte prvo stranko.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      return EqCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => Navigator.pop(context, c),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: context.eq.violetSoft,
                              child: Text(
                                c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Eq.violet,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${c.postalCode} ${c.city}'.trim(),
                                    style: TextStyle(
                                      color: context.eq.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (c.id == selected)
                              const Icon(
                                LucideIcons.check,
                                color: Eq.violet,
                                size: 18,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
