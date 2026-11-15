import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../domain/models.dart';
import 'finance_common.dart';
import 'sales_screen.dart';
import 'contact_country_picker.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    return FinanceView(
      builder: (context, snap) {
        final q = _q.toLowerCase();
        final list = snap.state.contacts
            .where(
              (c) => '${c.name} ${c.city} ${c.vatId}'.toLowerCase().contains(q),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
          children: [
            PageHeader(
              kicker: 'Equitensa Finance / ${snap.state.country.code}',
              title: t('Kontakte', 'Stiki'),
              subtitle: t(
                'Kunden und Lieferanten – für Rechnungen, Angebote und Belege.',
                'Stranke in dobavitelji – za račune, ponudbe in dokumente.',
              ),
            ),
            const SizedBox(height: 18),
            EqButton(
              label: t('Kontakt anlegen', 'Dodaj stik'),
              icon: LucideIcons.userPlus,
              onPressed: () => context.push('/finance/contact'),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: t('Kontakt suchen', 'Poišči stik'),
                prefixIcon: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: context.eq.faint,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              StateMessageInline(
                icon: LucideIcons.users,
                title: t('Noch keine Kontakte', 'Še ni stikov'),
                body: t(
                  'Legen Sie Ihren ersten Kunden an, um Rechnungen zu erstellen.',
                  'Dodajte prvo stranko za izdajo računov.',
                ),
              )
            else
              for (final c in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EqCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => context.push('/finance/contact?edit=${c.id}'),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: Eq.brandGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: context.eq.ink2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  c.city,
                                  c.vatId,
                                ].where((e) => e.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.eq.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pill(
                          c.business ? t('Firma', 'Podjetje') : t('Privat', 'Zasebno'),
                          color: c.business ? Eq.violet : context.eq.muted,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _city = TextEditingController();
  final _vat = TextEditingController();
  final _email = TextEditingController();
  bool _business = true;
  bool _publicBody = false;
  String? _country;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _postal, _city, _vat, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(FinanceSnapshot snap) {
    if (_loaded) return;
    _loaded = true;
    _country = snap.state.country.code;
    final c = snap.state.contacts.where((x) => x.id == widget.editId).firstOrNull;
    if (c != null) {
      _name.text = c.name;
      _address.text = c.address;
      _postal.text = c.postalCode;
      _city.text = c.city;
      _vat.text = c.vatId;
      _email.text = c.email;
      _business = c.business;
      _publicBody = c.publicBody;
      _country = c.countryCode;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'postalCode': _postal.text.trim(),
      'city': _city.text.trim(),
      'vatId': _vat.text.trim().toUpperCase(),
      'email': _email.text.trim(),
      'country': _country!,
      'business': _business,
      'publicBody': _publicBody,
    };
    final repo = ref.read(repositoryProvider);
    final res = await guarded(
      context,
      ref,
      () => ref
          .read(financeProvider.notifier)
          .mutate(
            (rev) => widget.editId == null
                ? repo.createContact(rev, fields)
                : repo.updateContact(widget.editId!, rev, fields),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/finance/contacts');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = trOf(ref);
    final snapAsync = ref.watch(financeProvider);
    return snapAsync.when(
      loading: () => SubPage(title: t('Kontakt', 'Stik'), child: const LoadingList()),
      error: (e, _) => SubPage(
        title: t('Kontakt', 'Stik'),
        child: ErrorView(
          error: e,
          onRetry: () => ref.read(financeProvider.notifier).reload(),
        ),
      ),
      data: (snap) {
        _hydrate(snap);
        String? required(String? v) => (v == null || v.trim().isEmpty) ? t('Pflichtfeld', 'Obvezno polje') : null;
        return SubPage(
          kicker: 'Equitensa Finance',
          title: widget.editId == null ? t('Neuer Kontakt', 'Nov stik') : t('Kontakt bearbeiten', 'Uredi stik'),
          actions: [
            if (widget.editId != null)
              IconButton(
                tooltip: t('Dokument erstellen', 'Ustvari dokument'),
                icon: const Icon(LucideIcons.filePlus),
                onPressed: () => context.push('/finance/compose?kind=invoice&contact=${widget.editId}'),
              ),
          ],
          bottom: EqButton(
            label: t('Speichern', 'Shrani'),
            icon: LucideIcons.save,
            busy: _saving,
            onPressed: _save,
          ),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.eq.violetSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      for (final (b, label) in [
                        (true, t('Firma', 'Podjetje')),
                        (false, t('Privat', 'Zasebno')),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _business = b),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _business == b ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _business == b ? Eq.cardShadow : null,
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _business == b ? Eq.violet : context.eq.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                EqField(
                  label: t('Name', 'Ime'),
                  controller: _name,
                  validator: required,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                EqField(
                  label: t('Adresse', 'Naslov'),
                  controller: _address,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: EqField(
                        label: t('PLZ', 'Pošt. št.'),
                        controller: _postal,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: EqField(
                        label: t('Ort', 'Kraj'),
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                EqField(
                  label: t('E-Mail', 'E-pošta'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                      ? null
                      : t('Ungültige E-Mail', 'Neveljavna e-pošta'),
                ),
                if (_business) ...[
                  const SizedBox(height: 14),
                  EqField(
                    label: t('USt-IdNr.', 'Davčna številka za DDV'),
                    controller: _vat,
                    textCapitalization: TextCapitalization.characters,
                    hint: '${_country ?? ''}…',
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Eq.violet,
                    value: _publicBody,
                    onChanged: (v) => setState(() => _publicBody = v),
                    title: Text(
                      t('Öffentliche Stelle', 'Javni organ'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Labeled(
                  t('Land', 'Država'),
                  hint: t(
                    'Inländische Kunden oder EU-B2B-Dienstleistungen mit geprüften Steuerangaben.',
                    'Domače stranke ali EU B2B storitve s preverjenimi davčnimi podatki.',
                  ),
                  child: EqCard(
                    onTap: () async {
                      final code = await chooseContactCountry(
                        context,
                        selected: _country ?? snap.state.country.code,
                        sl: t.sl,
                      );
                      if (code != null && mounted) setState(() => _country = code);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${contactCountryName(_country ?? snap.state.country.code, t.sl)} · $_country'),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 18),
                      ],
                    ),
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
