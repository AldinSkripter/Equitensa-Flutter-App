import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import 'conflict.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final value = ref.watch(contactsProvider);

    List<Contact> filter(List<Contact> l) => _q.isEmpty
        ? l
        : l
              .where(
                (c) => '${c.name} ${c.city}'.toLowerCase().contains(
                  _q.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.violet,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/customer/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(s.t('new_customer')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: s.t('search'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: AsyncBody<List<Contact>>(
              value: value,
              onRefresh: () async => ref.invalidate(contactsProvider),
              isEmpty: (l) => filter(l).isEmpty,
              empty: StateMessage(
                icon: Icons.groups_rounded,
                title: s.t('empty_customers_title'),
                body: s.t('empty_customers_body'),
                actionLabel: s.t('new_customer'),
                onAction: () => context.push('/customer/new'),
              ),
              builder: (context, list) {
                final shown = filter(list);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = shown[i];
                    return AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Brand.violet.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              c.name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: Brand.violet,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  c.city,
                                  style: const TextStyle(color: Brand.muted),
                                ),
                              ],
                            ),
                          ),
                          Pill(
                            s.t(c.business ? 'business' : 'private'),
                            color: c.business ? Brand.violet : Brand.muted,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _email = TextEditingController();
  final _vat = TextEditingController();
  bool _business = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _email.dispose();
    _vat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final rev = await ref.latestRevision();
      await ref
          .read(repositoryProvider)
          .createContact(
            revision: rev,
            name: _name.text.trim(),
            city: _city.text.trim(),
            email: _email.text.trim(),
            vatId: _vat.text.trim().toUpperCase(),
            business: _business,
          );
      ref.refreshFinanceData();
      if (mounted) context.pop();
    } on VersionConflictException {
      if (!mounted) return;
      ref.refreshFinanceData();
      final c = await showConflictDialog(context);
      if (c == ConflictChoice.reloadAndRetry && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final country = ref.watch(sessionProvider)!.country;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? s.t('required') : null;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('new_customer'))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(s.t('save')),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(s.t('business')),
                  icon: const Icon(Icons.business_rounded),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(s.t('private')),
                  icon: const Icon(Icons.person_rounded),
                ),
              ],
              selected: {_business},
              onSelectionChanged: (v) => setState(() => _business = v.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.t('name')),
              validator: required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s.t('city')),
              validator: required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: s.t('email')),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                    ? null
                    : s.t('invalid_email');
              },
            ),
            if (_business) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _vat,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: s.t('vat_id'),
                  hintText: '${country.code}…',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return RegExp(r'^[A-Za-z]{2}[A-Za-z0-9]{8,12}$').hasMatch(v)
                      ? null
                      : s.t('invalid_vat');
                },
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '${s.t('country')}: ${country.flag} ${country.label}',
              style: const TextStyle(color: Brand.muted),
            ),
          ],
        ),
      ),
    );
  }
}
