import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'conflict.dart';

class _LineForm {
  _LineForm(this.rate);
  final desc = TextEditingController();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  int rate;

  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
  }

  bool get valid =>
      desc.text.trim().isNotEmpty &&
      _num(qty.text) != null &&
      _num(price.text) != null;

  InvoiceLine toLine() => InvoiceLine(
    description: desc.text.trim(),
    quantity: qty.text.trim().replaceAll(',', '.'),
    unitPrice: price.text.trim().replaceAll(',', '.'),
    rate: rate,
  );

  static double? _num(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));
}

class InvoiceEditorScreen extends ConsumerStatefulWidget {
  const InvoiceEditorScreen({super.key});

  @override
  ConsumerState<InvoiceEditorScreen> createState() =>
      _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  Contact? _contact;
  late DateTime _issue = DateTime.now();
  late DateTime _due = DateTime.now().add(const Duration(days: 14));
  late final List<_LineForm> _lines;
  Totals? _totals;
  bool _calculating = false;
  bool _saving = false;
  bool _submitted = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _lines = [_LineForm(ref.read(sessionProvider)!.country.vatRates.first)];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _scheduleCalc() {
    _debounce?.cancel();
    final valid = _lines.where((l) => l.valid).toList();
    if (valid.isEmpty) {
      setState(() => _totals = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _calculating = true);
      try {
        final t = await ref.read(repositoryProvider).calculate([
          for (final l in valid) l.toLine(),
        ]);
        if (mounted) setState(() => _totals = t);
      } catch (e) {
        if (mounted) showError(context, e);
      } finally {
        if (mounted) setState(() => _calculating = false);
      }
    });
  }

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _submitted = true);
    if (_contact == null || !_lines.every((l) => l.valid)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.t('err_validation'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final rev = await ref.latestRevision();
      final inv = await ref
          .read(repositoryProvider)
          .saveDraft(
            revision: rev,
            contact: _contact!,
            issueDate: _issue,
            dueDate: _due,
            lines: [for (final l in _lines) l.toLine()],
          );
      ref.refreshFinanceData();
      if (mounted) context.pushReplacement('/invoice/${inv.id}');
    } on VersionConflictException {
      if (!mounted) return;
      // Form state is untouched, so the user's input survives the conflict.
      final choice = await showConflictDialog(context);
      ref.refreshFinanceData();
      if (choice == ConflictChoice.reloadAndRetry && mounted) {
        setState(() => _saving = false);
        await _save();
        return;
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickContact() async {
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ContactPicker(),
    );
    if (picked != null) setState(() => _contact = picked);
  }

  Future<void> _pickDate(bool issue) async {
    final d = await showDatePicker(
      context: context,
      initialDate: issue ? _issue : _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => issue ? _issue = d : _due = d);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = ref.watch(languageProvider);
    final country = ref.watch(sessionProvider)!.country;

    return PopScope(
      child: Scaffold(
        appBar: AppBar(title: Text(s.t('new_invoice'))),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(s.t('save_draft')),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            SectionTitle(s.t('customer')),
            AppCard(
              onTap: _pickContact,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Brand.violet.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Brand.violet,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _contact == null
                        ? Text(
                            s.t('select_customer'),
                            style: TextStyle(
                              color: _submitted ? Brand.danger : Brand.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _contact!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _contact!.city,
                                style: const TextStyle(color: Brand.muted),
                              ),
                            ],
                          ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Brand.muted),
                ],
              ),
            ),
            SectionTitle(s.t('dates')),
            Row(
              children: [
                Expanded(
                  child: _dateField(
                    s.t('issue_date'),
                    _issue,
                    lang,
                    () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    s.t('due_date'),
                    _due,
                    lang,
                    () => _pickDate(false),
                  ),
                ),
              ],
            ),
            SectionTitle(s.t('lines')),
            for (var i = 0; i < _lines.length; i++) ...[
              _lineCard(i, country, s),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _lines.add(_LineForm(country.vatRates.first))),
              icon: const Icon(Icons.add_rounded),
              label: Text(s.t('add_line')),
            ),
            const SizedBox(height: 20),
            _totalsCard(s, lang),
          ],
        ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime d,
    String lang,
    VoidCallback onTap,
  ) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
      ),
      child: Text(
        fmtDate(d, lang),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _lineCard(int i, Country country, S s) {
    final l = _lines[i];
    String? err(TextEditingController c, {bool number = false}) {
      if (!_submitted) return null;
      if (c.text.trim().isEmpty) return s.t('required');
      if (number && _LineForm._num(c.text) == null) {
        return s.t('invalid_number');
      }
      return null;
    }

    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${s.t('line')} ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  tooltip: s.t('remove'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _lines.removeAt(i).dispose();
                    _scheduleCalc();
                  }),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Brand.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: l.desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: s.t('description'),
              errorText: err(l.desc),
            ),
            onChanged: (_) => _scheduleCalc(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: l.qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: decimal,
                  decoration: InputDecoration(
                    labelText: s.t('quantity'),
                    errorText: err(l.qty, number: true),
                  ),
                  onChanged: (_) => _scheduleCalc(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: l.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: decimal,
                  decoration: InputDecoration(
                    labelText: s.t('unit_price'),
                    suffixText: '€',
                    errorText: err(l.price, number: true),
                  ),
                  onChanged: (_) => _scheduleCalc(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                s.t('vat'),
                style: const TextStyle(
                  color: Brand.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in country.vatRates)
                      ChoiceChip(
                        label: Text('$r%'),
                        selected: l.rate == r,
                        showCheckmark: false,
                        selectedColor: Brand.violet,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: l.rate == r ? Colors.white : Brand.ink,
                        ),
                        onSelected: (_) {
                          setState(() => l.rate = r);
                          _scheduleCalc();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalsCard(S s, String lang) {
    final t = _totals;
    Widget row(String l, int? c, {bool big = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            l,
            style: TextStyle(
              fontWeight: big ? FontWeight.w800 : FontWeight.w500,
              fontSize: big ? 17 : 14,
            ),
          ),
          const Spacer(),
          c == null
              ? const Text('—')
              : Text(
                  fmtMoney(c, lang),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: big ? 22 : 14,
                    color: big ? Brand.violet : Brand.ink,
                  ),
                ),
        ],
      ),
    );
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 18,
                color: Brand.violet,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.t('server_calculated'),
                  style: const TextStyle(
                    color: Brand.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_calculating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          row(s.t('net'), t?.netCents),
          row(s.t('vat'), t?.taxCents),
          const Divider(height: 20),
          row(s.t('gross'), t?.grossCents, big: true),
        ],
      ),
    );
  }
}

class _ContactPicker extends ConsumerWidget {
  const _ContactPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final contacts = ref.watch(contactsProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.t('select_customer'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    context.push('/customer/new');
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s.t('new_customer')),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<List<Contact>>(
              value: contacts,
              onRefresh: () async => ref.invalidate(contactsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: StateMessage(
                icon: Icons.groups_rounded,
                title: s.t('empty_customers_title'),
                body: s.t('empty_customers_body'),
              ),
              builder: (_, list) => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Brand.border),
                  ),
                  title: Text(
                    list[i].name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(list[i].city),
                  onTap: () => Navigator.of(context).pop(list[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
