import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/files.dart';
import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import 'finance_common.dart';
import 'invoice_sheet.dart';

String _newRequestKey() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
}

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  bool _busy = false;

  Future<void> _sharePdf(FinDoc d) async {
    final t = trOf(ref);
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(repositoryProvider).documentPdf(d.id);
      await shareBytes(
        bytes,
        '${d.number ?? 'draft-${d.id}'}.pdf',
        'application/pdf',
      );
    } on ApiException catch (e) {
      if (mounted) showApiError(context, e);
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          t(
            'Die Datei konnte nicht geteilt werden.',
            'Datoteke ni bilo mogoče deliti.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _duplicate(FinDoc d) async {
    final t = trOf(ref);
    final copy = await guarded(
      context,
      ref,
      () => ref.read(financeProvider.notifier).mutate((rev) => ref.read(repositoryProvider).duplicate(d.id, rev)),
    );
    if (copy != null && mounted) {
      showSnack(
        context,
        t('Kopie als Entwurf angelegt.', 'Kopija ustvarjena kot osnutek.'),
      );
      context.pushReplacement('/finance/document/${copy.id}');
    }
  }

  Future<void> _convert(FinDoc d) async {
    final t = trOf(ref);
    final inv = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => ref.read(repositoryProvider).convertOffer(d.id, rev),
          ),
    );
    if (inv != null && mounted) {
      showSnack(
        context,
        t(
          'Rechnungsentwurf aus dem Angebot erstellt.',
          'Osnutek računa iz ponudbe je ustvarjen.',
        ),
      );
      context.pushReplacement('/finance/document/${inv.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final fmt = fmtOf(ref);
    final snap = ref.watch(financeProvider);
    return snap.when(
      loading: () => const SubPage(title: '…', child: LoadingList()),
      error: (e, _) => SubPage(
        title: t('Dokument', 'Dokument'),
        child: ErrorView(
          error: e,
          onRetry: () => ref.read(financeProvider.notifier).reload(),
        ),
      ),
      data: (data) {
        final d = data.state.documents.where((x) => x.id == widget.id).firstOrNull;
        if (d == null) {
          return SubPage(
            title: t('Dokument', 'Dokument'),
            child: StateMessage(
              icon: LucideIcons.searchX,
              title: t('Nicht gefunden', 'Ni najdeno'),
              body: t(
                'Dieses Dokument existiert nicht mehr oder gehört zu einem anderen Unternehmen.',
                'Ta dokument ne obstaja več ali pripada drugemu podjetju.',
              ),
            ),
          );
        }
        final st = statusOf(t, d);
        final design = designFor(data.state, d);
        final hasOffer = data.state.documents.any(
          (x) => x.sourceOfferId == d.id,
        );
        return SubPage(
          kicker: kindLabel(t, d.kind),
          title: d.number ?? t('Entwurf', 'Osnutek'),
          actions: [
            IconButton(
              tooltip: t('Weitere Aktionen', 'Dodatna dejanja'),
              icon: const Icon(LucideIcons.ellipsis),
              onPressed: () => context.push('/finance/manage-document/${d.id}'),
            ),
            if (d.isDraft)
              GestureDetector(
                onTap: () => context.push(
                  '/finance/compose?edit=${d.id}&kind=${d.kind}',
                ),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.eq.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: context.eq.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.pencil,
                        size: 15,
                        color: Eq.violet,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        t('Bearbeiten', 'Uredi'),
                        style: const TextStyle(
                          color: Eq.violet,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          child: RefreshIndicator(
            color: Eq.violet,
            onRefresh: () => ref.read(financeProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                EqCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill(st.label, color: st.color),
                            const SizedBox(height: 10),
                            Text(
                              d.customer.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: context.eq.ink2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${t('Fällig', 'Zapadlost')}: ${d.dueDate}',
                              style: TextStyle(
                                color: context.eq.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmt.money(d.grossCents),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.8,
                              color: context.eq.ink2,
                            ),
                          ),
                          if (d.isUnpaid)
                            Text(
                              '${fmt.money(d.outstandingCents)} ${t('offen', 'odprto')}',
                              style: const TextStyle(
                                color: Eq.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(LucideIcons.eye, size: 14, color: context.eq.muted),
                      const SizedBox(width: 6),
                      Text(
                        t('Dokument vom Server', 'Dokument s strežnika'),
                        style: TextStyle(
                          color: context.eq.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEE9F5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE0D8EA)),
                  ),
                  child: InvoiceSheet(
                    profile: data.state.profile,
                    companyName: data.state.profile.name,
                    country: data.state.country,
                    design: design,
                    accent: accentFor(data.state, d),
                    doc: d,
                    watermark: d.isDraft,
                  ),
                ),
                if (d.payments.isNotEmpty) ...[
                  SectionTitle(t('Zahlungen', 'Plačila')),
                  for (final p in d.payments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EqCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.circleCheck,
                              color: Eq.success,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${p.paidOn}${p.reference.isEmpty ? '' : ' · ${p.reference}'}',
                                style: TextStyle(color: context.eq.muted),
                              ),
                            ),
                            Text(
                              fmt.money(p.amountCents),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                EqButton(
                  label: t('PDF teilen', 'Deli PDF'),
                  icon: LucideIcons.share,
                  busy: _busy,
                  onPressed: () => _sharePdf(d),
                ),
                const SizedBox(height: 10),
                if (d.isDraft && data.demo)
                  EqButton(
                    kind: BtnKind.secondary,
                    label: t('Testausstellung prüfen', 'Preveri testno izdajo'),
                    icon: LucideIcons.fileCheck,
                    onPressed: () => showIssueSheet(context, ref, d),
                  ),
                if (d.isUnpaid) ...[
                  const SizedBox(height: 10),
                  EqButton(
                    kind: BtnKind.secondary,
                    label: t('Zahlung erfassen', 'Evidentiraj plačilo'),
                    icon: LucideIcons.banknote,
                    onPressed: () => showPaymentSheet(context, ref, d),
                  ),
                ],
                if (d.isOffer && !hasOffer) ...[
                  const SizedBox(height: 10),
                  EqButton(
                    kind: BtnKind.secondary,
                    label: t('In Rechnung umwandeln', 'Pretvori v račun'),
                    trailingIcon: LucideIcons.arrowRight,
                    onPressed: () => _convert(d),
                  ),
                ],
                const SizedBox(height: 10),
                EqButton(
                  kind: BtnKind.ghost,
                  label: t('Kopieren', 'Kopiraj'),
                  icon: LucideIcons.copy,
                  onPressed: () => _duplicate(d),
                ),
                for (final o in d.originals.where(
                  (o) => o['extension'] != 'pdf',
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: EqButton(
                      kind: BtnKind.ghost,
                      label: '${o['format'] ?? 'XML'} (${o['extension']})',
                      icon: LucideIcons.download,
                      onPressed: () async {
                        final bytes = await ref
                            .read(repositoryProvider)
                            .api
                            .getBytes(
                              '/finance/documents/${d.id}/originals/${o['id']}',
                            );
                        await shareBytes(
                          bytes,
                          '${d.number ?? d.id}.${o['extension']}',
                          'application/xml',
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- payment

Future<void> showPaymentSheet(BuildContext context, WidgetRef ref, FinDoc d) {
  final t = trOf(ref);
  final amount = TextEditingController(
    text: (d.outstandingCents / 100).toStringAsFixed(2),
  );
  final reference = TextEditingController();
  var paidOn = Fmt.today();
  var busy = false;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Zahlung erfassen', 'Evidentiraj plačilo'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: context.eq.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(
                'Nur manuell erfasst – es wird keine Bankbuchung ausgelöst.',
                'Samo ročni vnos – bančna transakcija se ne sproži.',
              ),
              style: TextStyle(color: context.eq.muted),
            ),
            const SizedBox(height: 18),
            EqField(
              label: t('Betrag', 'Znesek'),
              controller: amount,
              suffixText: '€',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            const SizedBox(height: 14),
            Labeled(
              t('Zahlungsdatum', 'Datum plačila'),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.parse(paidOn),
                    firstDate: DateTime.parse(d.issueDate),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setS(() => paidOn = p.toIso8601String().substring(0, 10));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(LucideIcons.calendar, size: 18),
                  ),
                  child: Text(
                    paidOn,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EqField(
              label: t('Referenz (optional)', 'Referenca (neobvezno)'),
              controller: reference,
            ),
            const SizedBox(height: 20),
            EqButton(
              label: t('Zahlung speichern', 'Shrani plačilo'),
              icon: LucideIcons.check,
              busy: busy,
              onPressed: () async {
                setS(() => busy = true);
                final ok = await guarded(
                  context,
                  ref,
                  () => ref
                      .read(financeProvider.notifier)
                      .mutate(
                        (rev) => ref
                            .read(repositoryProvider)
                            .recordPayment(
                              d.id,
                              revision: rev,
                              amount: amount.text.replaceAll(',', '.'),
                              paidOn: paidOn,
                              reference: reference.text.trim(),
                            ),
                      ),
                );
                if (ctx.mounted) {
                  setS(() => busy = false);
                  if (ok != null) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------- issue

Future<void> showIssueSheet(BuildContext context, WidgetRef ref, FinDoc d) {
  final country = ref.read(countryProvider);
  final formats = switch (country) {
    Country.de => ['xrechnung', 'zugferd'],
    Country.at => ['ebinterface', 'ubl'],
    Country.si => ['eslog', 'ubl'],
  };
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _IssueSheet(doc: d, formats: d.isInvoice ? formats : const []),
  );
}

class _IssueSheet extends ConsumerStatefulWidget {
  const _IssueSheet({required this.doc, required this.formats});
  final FinDoc doc;
  final List<String> formats;

  @override
  ConsumerState<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends ConsumerState<_IssueSheet> {
  late String? _format = widget.formats.isEmpty ? null : widget.formats.first;
  // One request key per user intent, reused for retries after a lost response.
  final String _requestKey = _newRequestKey();
  IssueCheck? _check;
  Object? _error;
  bool _loading = true;
  bool _confirm = false;
  bool _scope = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ref.read(repositoryProvider).issueCheck(widget.doc.id, format: _format);
      if (mounted) setState(() => _check = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatName(String f) =>
      const {
        'xrechnung': 'XRechnung',
        'zugferd': 'ZUGFeRD',
        'ebinterface': 'ebInterface 6.1',
        'eslog': 'e-SLOG 2.0',
        'ubl': 'UBL 2.1',
      }[f] ??
      f;

  Future<void> _issue() async {
    final t = trOf(ref);
    setState(() => _busy = true);
    final res = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => ref
                .read(repositoryProvider)
                .issue(
                  widget.doc.id,
                  revision: rev,
                  requestKey: _requestKey,
                  format: _format,
                ),
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null) {
      Navigator.pop(context);
      showSnack(
        context,
        t(
          'Testdokument ausgestellt: ${res.number ?? ''}',
          'Testni dokument izdan: ${res.number ?? ''}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final c = _check;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Testausstellung prüfen', 'Preveri testno izdajo'),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: context.eq.ink2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t(
                'Prüft Pflichtfelder – keine Empfänger- oder Schema-Akzeptanz. Erstellt ein markiertes Testdokument.',
                'Preveri obvezna polja – ne sprejema prejemnika ali sheme. Ustvari označen testni dokument.',
              ),
              style: TextStyle(color: context.eq.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (widget.formats.isNotEmpty) ...[
              Labeled(
                t('Rechnungsformat', 'Oblika računa'),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final f in widget.formats)
                      ChoiceChip(
                        label: Text(_formatName(f)),
                        selected: _format == f,
                        showCheckmark: false,
                        selectedColor: Eq.violet,
                        labelStyle: TextStyle(
                          color: _format == f ? Colors.white : context.eq.ink2,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) {
                          setState(() => _format = f);
                          _load();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              NoticeBanner(errorMessage(t, _error!), color: Eq.danger)
            else if (c != null) ...[
              if (c.fields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Eq.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.circleCheck,
                        color: Eq.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t(
                            'Alle Pflichtangaben sind vorhanden.',
                            'Vsi obvezni podatki so prisotni.',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  t('Das fehlt noch:', 'Še manjka:'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.eq.ink2,
                  ),
                ),
                const SizedBox(height: 8),
                for (final f in c.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.circleAlert,
                            size: 16,
                            color: Eq.warning,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            issueProblemLabel(t, f),
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                EqButton(
                  kind: BtnKind.secondary,
                  label: t('Firma & Design öffnen', 'Odpri podjetje in izgled'),
                  icon: LucideIcons.settings,
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/finance/company');
                  },
                ),
              ],
              if (c.ready) ...[
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Eq.violet,
                  value: _confirm,
                  onChanged: (v) => setState(() => _confirm = v ?? false),
                  title: Text(
                    t(
                      'Ich bestätige die Angaben dieses Dokuments.',
                      'Potrjujem podatke tega dokumenta.',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Eq.violet,
                  value: _scope,
                  onChanged: (v) => setState(() => _scope = v ?? false),
                  title: Text(
                    t(
                      'Es handelt sich um eine inländische B2B-Rechnung in EUR.',
                      'Gre za domači B2B račun v EUR.',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                EqButton(
                  label: t('Testdokument ausstellen', 'Izdaj testni dokument'),
                  icon: LucideIcons.fileCheck,
                  busy: _busy,
                  onPressed: _confirm && _scope ? _issue : null,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
