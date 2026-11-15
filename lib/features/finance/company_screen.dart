import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import 'finance_common.dart';
import 'invoice_sheet.dart';

const _presets = [
  ('Equitensa', '#7451f8', '#f4f1fc', '#272238'),
  ('Graphite', '#252b38', '#f2f3f5', '#252b38'),
  ('Forest', '#23634e', '#edf5f0', '#223b31'),
  ('Terracotta', '#a44832', '#fbf0e9', '#492e27'),
  ('Ocean', '#245aa5', '#edf3fb', '#223349'),
];

Color _c(String hex) => Color(0xFF000000 | int.parse(hex.replaceAll('#', ''), radix: 16));

/// "Firma & Design": the customer-controlled invoice appearance and company data, saved to the
/// same backend profile the web app uses. The preview is the very same sheet renderer.
class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _ctl = {
    for (final k in [
      'name',
      'address',
      'postalCode',
      'city',
      'taxId',
      'vatId',
      'iban',
      'email',
      'footer',
      'invoiceTitle',
      'offerTitle',
    ])
      k: TextEditingController(),
  };
  late Map<String, dynamic> _design;
  String _accent = '#7451f8';
  String _logo = '';
  bool _loaded = false;
  bool _saving = false;
  bool _confirmCountry = false;
  int _tab = 0;

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(FinanceSnapshot snap) {
    if (_loaded) return;
    _loaded = true;
    final p = snap.state.profile;
    for (final k in [
      'name',
      'address',
      'postalCode',
      'city',
      'taxId',
      'vatId',
      'iban',
      'email',
      'footer',
    ]) {
      _ctl[k]!.text = (p.raw[k] ?? '').toString();
    }
    _accent = p.accent;
    _logo = p.logo;
    final base = DocDesign.merge([p.design]);
    _design = {
      ...p.design,
      'template': base.template,
      'font': base.font,
      'density': base.density,
      'logoPosition': base.logoPosition,
      'textColor': base.textColor,
      'surfaceColor': base.surfaceColor,
      'fontSize': base.fontSize.toInt(),
      'logoWidth': base.logoWidth.toInt(),
      'pageMargin': base.pageMargin.toInt(),
      'titleSize': base.titleSize.toInt(),
    };
    _ctl['invoiceTitle']!.text = base.invoiceTitle;
    _ctl['offerTitle']!.text = base.offerTitle;
    _confirmCountry = snap.state.countryConfirmed;
  }

  FinanceProfile _draftProfile(FinanceSnapshot snap) => FinanceProfile.fromJson({
    ...snap.state.profile.raw,
    for (final k in [
      'name',
      'address',
      'postalCode',
      'city',
      'taxId',
      'vatId',
      'iban',
      'email',
      'footer',
    ])
      k: _ctl[k]!.text,
    'accent': _accent,
    'logo': _logo,
    'design': _design,
  });

  Future<void> _pickLogo() async {
    final t = trOf(ref);
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final isJpg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    if ((!isPng && !isJpg) || bytes.length > 250000) {
      if (mounted) {
        showSnack(
          context,
          t(
            'Logo: PNG oder JPEG bis 250 KB.',
            'Logotip: PNG ali JPEG do 250 KB.',
          ),
          error: true,
        );
      }
      return;
    }
    setState(
      () => _logo = 'data:image/${isPng ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}',
    );
  }

  Future<void> _save(FinanceSnapshot snap) async {
    final t = trOf(ref);
    if (!_confirmCountry) {
      showSnack(
        context,
        t(
          'Bitte bestätigen Sie das Land Ihres Unternehmens.',
          'Potrdite državo svojega podjetja.',
        ),
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    final body = {
      'country': snap.state.country.code,
      'confirmCountry': true,
      for (final k in [
        'name',
        'address',
        'postalCode',
        'city',
        'taxId',
        'vatId',
        'iban',
        'email',
        'footer',
      ])
        k: _ctl[k]!.text.trim(),
      'accent': _accent,
      'logo': _logo,
      'design': {
        ..._design,
        'invoiceTitle': _ctl['invoiceTitle']!.text.trim(),
        'offerTitle': _ctl['offerTitle']!.text.trim(),
      },
    };
    final res = await guarded(
      context,
      ref,
      () => ref.read(financeProvider.notifier).mutate((rev) => ref.read(repositoryProvider).saveProfile(rev, body)),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      showSnack(
        context,
        t('Design & Firma gespeichert.', 'Izgled in podjetje shranjena.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final snapAsync = ref.watch(financeProvider);
    return snapAsync.when(
      loading: () => SubPage(
        title: t('Firma & Design', 'Podjetje in izgled'),
        child: const LoadingList(),
      ),
      error: (e, _) => SubPage(
        title: t('Firma & Design', 'Podjetje in izgled'),
        child: ErrorView(
          error: e,
          onRetry: () => ref.read(financeProvider.notifier).reload(),
        ),
      ),
      data: (snap) {
        _hydrate(snap);
        final profile = _draftProfile(snap);
        return SubPage(
          kicker: 'Document Design Studio',
          title: t(
            'Ihre Marke. Auf jeder Rechnung.',
            'Vaša znamka. Na vsakem računu.',
          ),
          bottom: EqButton(
            label: t('Design & Firma speichern', 'Shrani izgled in podjetje'),
            icon: LucideIcons.save,
            busy: _saving,
            onPressed: () => _save(snap),
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
                        (0, 'Design', LucideIcons.palette),
                        (
                          1,
                          t('Firmendaten', 'Podatki podjetja'),
                          LucideIcons.building2,
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
                child: _tab == 0 ? _design_(snap, profile, t) : _data(snap, t),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _design_(FinanceSnapshot snap, FinanceProfile profile, Tr t) {
    Widget chips(String key, List<(String, String)> options) => Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: _design[key] == o.$1,
            showCheckmark: false,
            selectedColor: Eq.violet,
            backgroundColor: Colors.white,
            side: BorderSide(color: _design[key] == o.$1 ? Eq.violet : context.eq.line),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: _design[key] == o.$1 ? Colors.white : context.eq.ink2,
            ),
            onSelected: (_) => setState(() => _design[key] = o.$1),
          ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            Icon(LucideIcons.eye, size: 14, color: context.eq.muted),
            const SizedBox(width: 6),
            Text(
              t('Live-Vorschau', 'Predogled v živo'),
              style: TextStyle(
                color: context.eq.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'A4 · ${_design['template']}',
              style: TextStyle(color: context.eq.faint, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE9F5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0D8EA)),
          ),
          child: InvoiceSheet(
            profile: profile,
            companyName: profile.name,
            country: snap.state.country,
            design: DocDesign.merge([
              _design,
              {
                'invoiceTitle': _ctl['invoiceTitle']!.text,
                'offerTitle': _ctl['offerTitle']!.text,
              },
            ]),
            accent: _accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t(
            'Das Design gilt für neue Dokumente und Entwürfe. Bereits ausgestellte Testdokumente behalten ihren gespeicherten Stand.',
            'Izgled velja za nove dokumente in osnutke. Že izdani testni dokumenti obdržijo shranjeno stanje.',
          ),
          style: TextStyle(color: context.eq.faint, fontSize: 12, height: 1.4),
        ),
        _h('01', t('Vorlage', 'Predloga')),
        chips('template', [
          ('signature', 'Signature'),
          ('minimal', 'Minimal'),
          ('editorial', 'Editorial'),
          ('business', 'Business'),
        ]),
        _h('02', t('Farbwelt', 'Barvna paleta')),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in _presets)
              GestureDetector(
                onTap: () => setState(() {
                  _accent = p.$2;
                  _design['surfaceColor'] = p.$3;
                  _design['textColor'] = p.$4;
                }),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _c(p.$2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accent == p.$2 ? Eq.violet : Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _c(p.$2).withValues(alpha: 0.4),
                            blurRadius: _accent == p.$2 ? 14 : 4,
                          ),
                        ],
                      ),
                      child: _accent == p.$2
                          ? const Icon(
                              LucideIcons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.$1,
                      style: TextStyle(fontSize: 11, color: context.eq.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
        _h('03', t('Typografie & Layout', 'Tipografija in postavitev')),
        Labeled(
          t('Schrift', 'Pisava'),
          child: chips('font', [
            ('sans', 'Arial'),
            ('serif', 'Georgia'),
            ('mono', 'Consolas'),
          ]),
        ),
        const SizedBox(height: 14),
        Labeled(
          t('Abstände', 'Razmiki'),
          child: chips('density', [
            ('comfortable', t('Großzügig', 'Zračno')),
            ('compact', t('Kompakt', 'Kompaktno')),
          ]),
        ),
        const SizedBox(height: 14),
        Labeled(
          t('Logo-Position', 'Položaj logotipa'),
          child: chips('logoPosition', [
            ('right', t('Rechts', 'Desno')),
            ('left', t('Links', 'Levo')),
          ]),
        ),
        const SizedBox(height: 14),
        _slider(t('Schriftgröße', 'Velikost pisave'), 'fontSize', 9, 13),
        _slider(t('Seitenränder', 'Robovi strani'), 'pageMargin', 30, 60),
        _slider(t('Titelgröße', 'Velikost naslova'), 'titleSize', 18, 36),
        _h('04', t('Ihr Logo', 'Vaš logotip')),
        EqCard(
          onTap: _pickLogo,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.eq.violetSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _logo.isEmpty
                    ? const Icon(LucideIcons.upload, color: Eq.violet)
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.memory(
                          base64Decode(_logo.split(',').last),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Logo auswählen', 'Izberi logotip'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Eq.violet,
                      ),
                    ),
                    Text(
                      'PNG / JPEG · 250 KB',
                      style: TextStyle(color: context.eq.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (_logo.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _logo = ''),
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: Eq.danger,
                  ),
                ),
            ],
          ),
        ),
        _h('05', t('Titel', 'Naslovi')),
        EqField(
          label: t(
            'Rechnungstitel (leer = Standard)',
            'Naslov računa (prazno = privzeto)',
          ),
          controller: _ctl['invoiceTitle'],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        EqField(
          label: t(
            'Angebotstitel (leer = Standard)',
            'Naslov ponudbe (prazno = privzeto)',
          ),
          controller: _ctl['offerTitle'],
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _data(FinanceSnapshot snap, Tr t) {
    Widget f(
      String key,
      String de,
      String sl, {
      TextInputType? type,
      int lines = 1,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: EqField(
        label: t(de, sl),
        controller: _ctl[key],
        keyboardType: type,
        maxLines: lines,
        onChanged: (_) => setState(() {}),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        f('name', 'Firmenname', 'Ime podjetja'),
        f('address', 'Adresse', 'Naslov'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: f(
                'postalCode',
                'PLZ',
                'Pošt. št.',
                type: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: f('city', 'Ort', 'Kraj')),
          ],
        ),
        f('vatId', 'USt-IdNr.', 'Davčna številka za DDV'),
        if (snap.state.country == Country.de) f('taxId', 'Steuernummer', 'Davčna številka'),
        f('iban', 'IBAN', 'IBAN'),
        f('email', 'E-Mail', 'E-pošta', type: TextInputType.emailAddress),
        f(
          'footer',
          'Kontakt, Registerangaben & Grußtext',
          'Kontakt, registrski podatki in pozdrav',
          lines: 4,
        ),
        EqCard(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Eq.violet,
            value: _confirmCountry,
            onChanged: (v) => setState(() => _confirmCountry = v ?? false),
            title: Text(
              t(
                'Ich bestätige ${snap.state.country.label} als Land meines Unternehmens.',
                'Potrjujem ${snap.state.country.label} kot državo svojega podjetja.',
              ),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slider(String label, String key, int min, int max) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Text(
              '${_design[key]}',
              style: const TextStyle(
                color: Eq.violet,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: (_design[key] as int).toDouble().clamp(
            min.toDouble(),
            max.toDouble(),
          ),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: Eq.violet,
          onChanged: (v) => setState(() => _design[key] = v.round()),
        ),
      ],
    ),
  );

  Widget _h(String n, String title) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
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
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: context.eq.ink2,
          ),
        ),
      ],
    ),
  );
}
