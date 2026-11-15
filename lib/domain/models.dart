// Models mirror the real Equitensa backend JSON (shared by web and app).
// Money is integer cents; quantities and entered prices stay decimal strings.

typedef Json = Map<String, dynamic>;

Json _m(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
List<Json> _l(Object? o) => o is List ? [for (final e in o) _m(e)] : <Json>[];
String _s(Object? o, [String d = '']) => o == null ? d : o.toString();
int _i(Object? o, [int d = 0]) => o is num ? o.toInt() : int.tryParse(_s(o)) ?? d;
bool _b(Object? o, [bool d = false]) => o is bool ? o : d;

enum Country {
  de('DE', 'Deutschland', 'de-DE', 'de', '19', ['19', '7'], '🇩🇪'),
  at('AT', 'Österreich', 'de-AT', 'de', '20', [
    '20',
    '13',
    '10',
    '4.9',
  ], '🇦🇹'),
  si('SI', 'Slovenija', 'sl-SI', 'sl', '22', ['22', '9.5', '5'], '🇸🇮');

  const Country(
    this.code,
    this.label,
    this.locale,
    this.language,
    this.standardRate,
    this.rates,
    this.flag,
  );
  final String code;
  final String label;
  final String locale;

  /// Default UI language follows the registered company country, never GPS or device locale.
  final String language;
  final String standardRate;
  final List<String> rates;
  final String flag;

  static Country parse(Object? v) => Country.values.firstWhere(
    (c) => c.code == _s(v).toUpperCase(),
    orElse: () => Country.de,
  );
}

class Company {
  const Company({required this.id, required this.name, required this.country});
  final String id;
  final String name;
  final Country country;

  factory Company.fromJson(Json j) => Company(
    id: _s(j['id']),
    name: _s(j['name']),
    country: Country.parse(j['country']),
  );
}

class Me {
  const Me({
    required this.company,
    required this.email,
    required this.role,
    required this.emailVerified,
    required this.mfaEnabled,
    required this.demo,
  });
  final Company company;
  final String email;
  final String role;
  final bool emailVerified;
  final bool mfaEnabled;
  final bool demo;

  factory Me.fromJson(Json j) {
    final u = _m(j['user']);
    return Me(
      company: Company.fromJson(_m(j['company'])),
      email: _s(u['email']),
      role: _s(u['role']),
      emailVerified: _b(u['emailVerified']),
      mfaEnabled: _b(u['mfaEnabled']),
      demo: _b(j['demo']),
    );
  }
}

/// Customer-controlled invoice appearance (never inherits the app theme).
class DocDesign {
  const DocDesign({
    this.template = 'signature',
    this.font = 'sans',
    this.density = 'comfortable',
    this.logoPosition = 'right',
    this.textColor = '#272238',
    this.surfaceColor = '#f4f1fc',
    this.fontSize = 10,
    this.logoWidth = 100,
    this.pageMargin = 45,
    this.titleSize = 24,
    this.titleAlign = 'left',
    this.tableStyle = '',
    this.invoiceTitle = '',
    this.offerTitle = '',
    this.columns = const [
      'position',
      'description',
      'quantity',
      'unitPrice',
      'total',
    ],
    this.blocks = const [],
  });

  final String template, font, density, logoPosition, textColor, surfaceColor;
  final String titleAlign, tableStyle, invoiceTitle, offerTitle;
  final num fontSize, logoWidth, pageMargin, titleSize;
  final List<String> columns;
  final List<DocBlock> blocks;

  /// Later maps override earlier ones, like `{...defaults, ...profile.design, ...appearance.design}`.
  factory DocDesign.merge(Iterable<Json?> layers) {
    final j = <String, dynamic>{};
    for (final l in layers) {
      if (l != null) j.addAll(l);
    }
    num n(String k, num d) => j[k] is num ? j[k] as num : (num.tryParse(_s(j[k])) ?? d);
    String s(String k, String d) => _s(j[k]).isEmpty ? d : _s(j[k]);
    return DocDesign(
      template: s('template', 'signature'),
      font: s('font', 'sans'),
      density: s('density', 'comfortable'),
      logoPosition: s('logoPosition', 'right'),
      textColor: s('textColor', '#272238'),
      surfaceColor: s('surfaceColor', '#f4f1fc'),
      fontSize: n('fontSize', 10),
      logoWidth: n('logoWidth', 100),
      pageMargin: n('pageMargin', 45),
      titleSize: n('titleSize', 24),
      titleAlign: s('titleAlign', 'left'),
      tableStyle: _s(j['tableStyle']),
      invoiceTitle: _s(j['invoiceTitle']),
      offerTitle: _s(j['offerTitle']),
      columns: j['columns'] is List
          ? [for (final c in j['columns'] as List) _s(c)]
          : const ['position', 'description', 'quantity', 'unitPrice', 'total'],
      blocks: [for (final b in _l(j['blocks'])) DocBlock.fromJson(b)],
    );
  }
}

class DocBlock {
  const DocBlock({
    required this.position,
    required this.heading,
    required this.body,
  });
  final String position, heading, body;
  factory DocBlock.fromJson(Json j) => DocBlock(
    position: _s(j['position']),
    heading: _s(j['heading']),
    body: _s(j['body']),
  );
}

class FinanceProfile {
  const FinanceProfile({
    required this.name,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.taxId,
    required this.vatId,
    required this.iban,
    required this.email,
    required this.logo,
    required this.accent,
    required this.footer,
    required this.design,
    required this.raw,
  });

  final String name, address, postalCode, city, taxId, vatId, iban, email, logo, accent, footer;
  final Json design;
  final Json raw;

  factory FinanceProfile.fromJson(Json j) => FinanceProfile(
    name: _s(j['name']),
    address: _s(j['address']),
    postalCode: _s(j['postalCode']),
    city: _s(j['city']),
    taxId: _s(j['taxId']),
    vatId: _s(j['vatId']),
    iban: _s(j['iban']),
    email: _s(j['email']),
    logo: _s(j['logo']),
    accent: _s(j['accent'], '#7451f8'),
    footer: _s(j['footer']),
    design: _m(j['design']),
    raw: j,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.address,
    required this.postalCode,
    required this.city,
    required this.country,
    required this.vatId,
    required this.email,
    required this.business,
    required this.publicBody,
  });

  final String id, name, address, postalCode, city, vatId, email;
  final Country country;
  final bool business, publicBody;

  factory Contact.fromJson(Json j) => Contact(
    id: _s(j['id']),
    name: _s(j['name']),
    address: _s(j['address']),
    postalCode: _s(j['postalCode']),
    city: _s(j['city']),
    country: Country.parse(j['country']),
    vatId: _s(j['vatId']),
    email: _s(j['email']),
    business: _b(j['business'], true),
    publicBody: _b(j['publicBody']),
  );
}

class DocLine {
  const DocLine({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.rate,
    required this.discountPercent,
    required this.discountCents,
    required this.netCents,
  });

  final String description, unit, quantity, unitPrice, rate, discountPercent;
  final int discountCents, netCents;

  factory DocLine.fromJson(Json j) => DocLine(
    description: _s(j['description']),
    unit: _s(j['unit']),
    quantity: _s(j['quantity'], '1'),
    unitPrice: _s(j['unitPrice'], '0'),
    rate: _s(j['rate']),
    discountPercent: _s(j['discountPercent'], '0'),
    discountCents: _i(j['discountCents']),
    netCents: _i(j['netCents']),
  );
}

class TaxLine {
  const TaxLine(this.rate, this.netCents, this.taxCents);
  final String rate;
  final int netCents, taxCents;
  factory TaxLine.fromJson(Json j) => TaxLine(_s(j['rate']), _i(j['netCents']), _i(j['taxCents']));
}

class Payment {
  const Payment(this.id, this.amountCents, this.paidOn, this.reference);
  final String id, paidOn, reference;
  final int amountCents;
  factory Payment.fromJson(Json j) => Payment(
    _s(j['id']),
    _i(j['amountCents']),
    _s(j['paidOn']),
    _s(j['reference']),
  );
}

class FinDoc {
  const FinDoc({
    required this.id,
    required this.kind,
    required this.status,
    required this.number,
    required this.contactId,
    required this.customer,
    required this.issueDate,
    required this.serviceDate,
    required this.dueDate,
    required this.reference,
    required this.note,
    required this.lines,
    required this.taxes,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    required this.payments,
    required this.appearance,
    required this.createdAt,
    required this.sourceOfferId,
    required this.offerStatus,
    required this.originals,
    required this.raw,
  });

  final String id, kind, status, contactId, issueDate, serviceDate, dueDate, reference, note, createdAt;
  final String? number, sourceOfferId, offerStatus;
  final Contact customer;
  final List<DocLine> lines;
  final List<TaxLine> taxes;
  final int netCents, taxCents, grossCents;
  final List<Payment> payments;
  final Json? appearance;
  final List<Json> originals;
  final Json raw;

  bool get isInvoice => kind == 'invoice';
  bool get isOffer => kind == 'offer';
  bool get isDraft => status == 'draft';
  int get paidCents => payments.fold(0, (a, p) => a + p.amountCents);
  bool get isUnpaid => isInvoice && status == 'issued' && paidCents < grossCents;
  int get outstandingCents => grossCents - paidCents;

  bool isOverdue(String today) => isUnpaid && dueDate.compareTo(today) < 0;

  factory FinDoc.fromJson(Json j) => FinDoc(
    id: _s(j['id']),
    kind: _s(j['kind'], 'invoice'),
    status: _s(j['status'], 'draft'),
    number: j['number'] == null ? null : _s(j['number']),
    contactId: _s(j['contactId']),
    customer: Contact.fromJson(_m(j['customer'])),
    issueDate: _s(j['issueDate']),
    serviceDate: _s(j['serviceDate']),
    dueDate: _s(j['dueDate']),
    reference: _s(j['reference']),
    note: _s(j['note']),
    lines: [for (final l in _l(j['lines'])) DocLine.fromJson(l)],
    taxes: [for (final t in _l(j['taxes'])) TaxLine.fromJson(t)],
    netCents: _i(j['netCents']),
    taxCents: _i(j['taxCents']),
    grossCents: _i(j['grossCents']),
    payments: [for (final p in _l(j['payments'])) Payment.fromJson(p)],
    appearance: j['appearance'] is Map ? _m(j['appearance']) : null,
    createdAt: _s(j['createdAt']),
    sourceOfferId: j['sourceOfferId'] == null ? null : _s(j['sourceOfferId']),
    offerStatus: _m(j['offerTracking'])['status'] == null ? null : _s(_m(j['offerTracking'])['status']),
    originals: _l(j['originals']),
    raw: j,
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.supplier,
    required this.reference,
    required this.incurredOn,
    required this.amountCents,
    required this.category,
    required this.note,
  });
  final String id, supplier, reference, incurredOn, category, note;
  final int amountCents;

  factory Expense.fromJson(Json j) => Expense(
    id: _s(j['id']),
    supplier: _s(j['supplier']),
    reference: _s(j['reference']),
    incurredOn: _s(j['incurredOn']),
    amountCents: _i(j['amountCents']),
    category: _s(j['category'], 'other'),
    note: _s(j['note']),
  );
}

class FinanceState {
  const FinanceState({
    required this.revision,
    required this.country,
    required this.countryConfirmed,
    required this.profile,
    required this.contacts,
    required this.documents,
    required this.expenses,
    required this.subscription,
  });

  final int revision;
  final Country country;
  final bool countryConfirmed;
  final FinanceProfile profile;
  final List<Contact> contacts;
  final List<FinDoc> documents;
  final List<Expense> expenses;
  final Json? subscription;

  /// Package ID of the saved demo subscription, `null` = full exploration.
  String? get planId => subscription == null ? null : _s(subscription!['plan']);

  factory FinanceState.fromJson(Json j) => FinanceState(
    revision: _i(j['revision']),
    country: Country.parse(j['country']),
    countryConfirmed: _b(j['countryConfirmed']),
    profile: FinanceProfile.fromJson(_m(j['profile'])),
    contacts: [for (final c in _l(j['contacts'])) Contact.fromJson(c)],
    documents: [for (final d in _l(j['documents'])) FinDoc.fromJson(d)],
    expenses: [for (final e in _l(j['expenses'])) Expense.fromJson(e)],
    subscription: j['subscription'] is Map ? _m(j['subscription']) : null,
  );
}

class PlanInfo {
  const PlanInfo(this.id, this.name, this.monthlyCents, this.includedSeats);
  final String id, name;
  final int monthlyCents, includedSeats;
  factory PlanInfo.fromJson(Json j) => PlanInfo(
    _s(j['id']),
    _s(j['name']),
    _i(j['monthlyCents']),
    _i(j['includedSeats']),
  );

  int get level => switch (id) {
    'finance_start' => 0,
    'finance_business' => 1,
    _ => 2,
  };
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.state,
    required this.plans,
    required this.capabilities,
    required this.demo,
    required this.stage,
  });

  final FinanceState state;
  final List<PlanInfo> plans;
  final Json capabilities;
  final bool demo;
  final String stage;

  FinanceSnapshot withState(FinanceState s) => FinanceSnapshot(
    state: s,
    plans: plans,
    capabilities: capabilities,
    demo: demo,
    stage: stage,
  );

  /// Mirrors `financeHasFeature` on the server; the server remains the authority.
  bool hasFeature(String feature) {
    final id = state.planId;
    if (id == null) return true;
    final level = plans.indexWhere((p) => p.id == id);
    if (level < 0) return false;
    return level >= (const {'bank': 1, 'expenses': 1, 'recurring': 2}[feature] ?? 0);
  }

  factory FinanceSnapshot.fromJson(Json j) => FinanceSnapshot(
    state: FinanceState.fromJson(_m(j['state'])),
    plans: [for (final p in _l(j['plans'])) PlanInfo.fromJson(p)],
    capabilities: _m(j['capabilities']),
    demo: _b(j['demo']),
    stage: _s(j['stage']),
  );
}

class Receipt {
  const Receipt({
    required this.supplier,
    required this.reference,
    required this.incurredOn,
    required this.amount,
    required this.category,
    required this.note,
  });
  final String supplier, reference, incurredOn, amount, category, note;

  factory Receipt.fromJson(Json j) {
    final s = j['suggestions'] is Map ? _m(j['suggestions']) : j;
    return Receipt(
      supplier: _s(s['supplier']),
      reference: _s(s['reference']),
      incurredOn: _s(s['incurredOn']),
      amount: _s(s['amount']),
      category: _s(s['category'], 'other'),
      note: _s(s['note']),
    );
  }
}

class IssueCheck {
  const IssueCheck(this.ready, this.fields, this.revision);
  final bool ready;
  final List<String> fields;
  final int revision;
  factory IssueCheck.fromJson(Json j) => IssueCheck(_b(j['ready']), [
    for (final f in (j['fields'] as List? ?? const [])) _s(f),
  ], _i(j['revision']));
}

class PayGroup {
  const PayGroup({
    required this.category,
    required this.count,
    required this.male,
    required this.female,
    required this.gap,
    required this.reviewRequired,
    required this.suppressed,
  });
  final String category;
  final int count, male, female;
  final double gap;
  final bool reviewRequired, suppressed;

  factory PayGroup.fromJson(Json j) => PayGroup(
    category: _s(j['category']),
    count: _i(j['count']),
    male: _i(j['male_count']),
    female: _i(j['female_count']),
    gap: (j['review_gap_hourly'] as num?)?.toDouble() ?? 0,
    reviewRequired: _b(j['review_required']),
    suppressed: _b(j['suppressed']),
  );
}

class PayAnalysis {
  const PayAnalysis({
    required this.year,
    required this.count,
    required this.male,
    required this.female,
    required this.other,
    required this.meanGap,
    required this.medianGap,
    required this.suppressed,
    required this.groups,
  });
  final int year, count, male, female, other;
  final double meanGap, medianGap;
  final bool suppressed;
  final List<PayGroup> groups;

  int get reviewCount => groups.where((g) => g.reviewRequired).length;

  factory PayAnalysis.fromJson(Json j) {
    final a = _m(j['analysis']);
    return PayAnalysis(
      year: _i(j['year']),
      count: _i(a['count']),
      male: _i(a['male_count']),
      female: _i(a['female_count']),
      other: _i(a['other_count']),
      meanGap: (a['mean_gap'] as num?)?.toDouble() ?? 0,
      medianGap: (a['median_gap'] as num?)?.toDouble() ?? 0,
      suppressed: _b(a['suppressed']),
      groups: [for (final g in _l(a['groups'])) PayGroup.fromJson(g)],
    );
  }
}

class PayReadiness {
  const PayReadiness(this.percent, this.ready, this.checks);
  final int percent;
  final bool ready;
  final List<({String id, bool done})> checks;

  factory PayReadiness.fromJson(Json j) {
    final r = _m(j['readiness']);
    return PayReadiness(_i(r['percent']), _b(r['ready']), [
      for (final c in _l(r['checks'])) (id: _s(c['id']), done: _b(c['done'])),
    ]);
  }
}
