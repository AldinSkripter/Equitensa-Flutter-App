import 'dart:math';

import '../domain/models.dart';
import '../domain/repository.dart';

/// Synthetic, in-memory stand-in for the Equitensa backend. No real payroll data.
class MockRepository implements EquitensaRepository {
  MockRepository(this.flags);

  /// Read lazily so toggles in the account screen apply immediately.
  final DemoFlags Function() flags;

  static const _companies = [
    Company(
      id: 'de-1',
      name: 'Demo Atelier GmbH',
      country: Country.de,
      city: 'Berlin',
      payActive: true,
      plan: FinancePlan.business,
    ),
    Company(
      id: 'at-1',
      name: 'Demo Atelier GmbH',
      country: Country.at,
      city: 'Wien',
      payActive: true,
      plan: FinancePlan.start,
    ),
    Company(
      id: 'si-1',
      name: 'Demo Atelje d.o.o.',
      country: Country.si,
      city: 'Ljubljana',
      payActive: false,
      plan: FinancePlan.pro,
    ),
  ];

  Company? _company;
  int _revision = 1;
  int _seq = 3;
  List<Contact> _contacts = [];
  List<Invoice> _invoices = [];
  List<Expense> _expenses = [];

  Future<void> _latency([int ms = 450]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    if (flags().offline) throw const OfflineException();
  }

  Company get _co => _company ?? (throw const DeniedException());

  @override
  Future<List<Company>> companies() async {
    await _latency(350);
    return _companies;
  }

  @override
  Future<Company> selectCompany(String id) async {
    await _latency(300);
    _company = _companies.firstWhere((c) => c.id == id);
    _revision = 1;
    _seed(_company!);
    return _company!;
  }

  void _seed(Company c) {
    final country = c.country;
    final now = DateTime.now();
    DateTime d(int back) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: back));
    final names = switch (country) {
      Country.de => [
        ('Nordlicht Studio GmbH', 'Hamburg', 'DE123456789'),
        ('Kaffeehaus Meyer', 'München', ''),
        ('Brandt & Partner', 'Köln', 'DE987654321'),
      ],
      Country.at => [
        ('Alpenblick OG', 'Salzburg', 'ATU12345678'),
        ('Café Sperl', 'Wien', ''),
        ('Donau Consulting', 'Linz', 'ATU87654321'),
      ],
      Country.si => [
        ('Triglav Digital d.o.o.', 'Ljubljana', 'SI12345678'),
        ('Kavarna Bled', 'Bled', ''),
        ('Soča Consulting', 'Nova Gorica', 'SI87654321'),
      ],
    };
    _contacts = [
      for (var i = 0; i < names.length; i++)
        Contact(
          id: 'c$i',
          name: names[i].$1,
          city: names[i].$2,
          country: country,
          vatId: names[i].$3,
          business: names[i].$3.isNotEmpty,
          email: 'kontakt$i@example.com',
        ),
    ];
    final vat = country.vatRates.first;
    Invoice inv(
      String id,
      String? no,
      int ci,
      int ago,
      int due,
      InvoiceStatus s,
      double qty,
      double price,
    ) {
      final lines = [
        InvoiceLine(
          description: 'Consulting',
          quantity: '$qty',
          unitPrice: price.toStringAsFixed(2),
          rate: vat,
        ),
      ];
      return Invoice(
        id: id,
        number: no,
        contact: _contacts[ci],
        issueDate: d(ago),
        dueDate: d(ago - due),
        status: s,
        lines: lines,
        totals: _total(lines),
        revision: 1,
      );
    }

    _invoices = [
      inv('i1', 'R-2026-0012', 0, 5, 14, InvoiceStatus.issued, 12, 125),
      inv('i2', 'R-2026-0011', 2, 38, 14, InvoiceStatus.overdue, 8, 140),
      inv('i3', 'R-2026-0010', 1, 20, 14, InvoiceStatus.paid, 4, 95),
      inv('i4', null, 0, 0, 14, InvoiceStatus.draft, 6, 125),
      inv('i5', 'R-2026-0009', 2, 55, 14, InvoiceStatus.paid, 20, 110),
    ];
    _expenses = [
      Expense(
        id: 'e1',
        supplier: 'Büro Depot',
        date: d(3),
        amountCents: 4590,
        category: 'office',
        hasReceipt: true,
      ),
      Expense(
        id: 'e2',
        supplier: 'Cloud Hosting',
        date: d(9),
        amountCents: 2900,
        category: 'software',
        hasReceipt: true,
      ),
      Expense(
        id: 'e3',
        supplier: 'Bahn Ticket',
        date: d(14),
        amountCents: 8420,
        category: 'travel',
      ),
    ];
  }

  static int _cents(String s) =>
      (double.parse(s.replaceAll(',', '.')) * 100).round();

  static Totals _total(List<InvoiceLine> lines) {
    var net = 0;
    var tax = 0;
    for (final l in lines) {
      final lineNet =
          (double.parse(l.quantity.replaceAll(',', '.')) * _cents(l.unitPrice))
              .round();
      net += lineNet;
      tax += (lineNet * l.rate / 100).round();
    }
    return Totals(netCents: net, taxCents: tax, grossCents: net + tax);
  }

  void _checkRevision(int revision) {
    if (flags().conflict) {
      _revision++;
      throw VersionConflictException(_revision);
    }
    if (revision != _revision) throw VersionConflictException(_revision);
  }

  @override
  Future<FinanceOverview> financeOverview() async {
    await _latency();
    if (!_co.financeActive) throw const DeniedException();
    int sum(Iterable<Invoice> i) =>
        i.fold(0, (a, b) => a + b.totals.grossCents);
    final rnd = Random(_co.country.index + 7);
    return FinanceOverview(
      openCents: sum(_invoices.where((i) => i.status == InvoiceStatus.issued)),
      overdueCents: sum(
        _invoices.where((i) => i.status == InvoiceStatus.overdue),
      ),
      paidMonthCents: sum(
        _invoices.where((i) => i.status == InvoiceStatus.paid),
      ),
      expensesMonthCents: _expenses.fold(0, (a, b) => a + b.amountCents),
      monthlyRevenueCents: [
        for (var i = 0; i < 6; i++) 450000 + rnd.nextInt(380000),
      ],
      revision: _revision,
    );
  }

  @override
  Future<List<Contact>> contacts() async {
    await _latency();
    return List.unmodifiable(_contacts);
  }

  @override
  Future<Contact> createContact({
    required int revision,
    required String name,
    required String city,
    required String email,
    required String vatId,
    required bool business,
  }) async {
    await _latency();
    _checkRevision(revision);
    final c = Contact(
      id: 'c${_seq++}',
      name: name,
      city: city,
      country: _co.country,
      email: email,
      vatId: vatId,
      business: business,
    );
    _contacts = [c, ..._contacts];
    _revision++;
    return c;
  }

  @override
  Future<List<Invoice>> invoices() async {
    await _latency();
    return List.unmodifiable(_invoices);
  }

  @override
  Future<Totals> calculate(List<InvoiceLine> lines) async {
    await _latency(350);
    return _total(lines);
  }

  @override
  Future<Invoice> saveDraft({
    required int revision,
    required Contact contact,
    required DateTime issueDate,
    required DateTime dueDate,
    required List<InvoiceLine> lines,
  }) async {
    await _latency(600);
    _checkRevision(revision);
    final inv = Invoice(
      id: 'i${_seq++}',
      contact: contact,
      issueDate: issueDate,
      dueDate: dueDate,
      status: InvoiceStatus.draft,
      lines: lines,
      totals: _total(lines),
      revision: 1,
    );
    _invoices = [inv, ..._invoices];
    _revision++;
    return inv;
  }

  @override
  Future<Invoice> markPaid(String invoiceId, {required int revision}) async {
    await _latency();
    _checkRevision(revision);
    final old = _invoices.firstWhere((i) => i.id == invoiceId);
    final paid = Invoice(
      id: old.id,
      number: old.number,
      contact: old.contact,
      issueDate: old.issueDate,
      dueDate: old.dueDate,
      status: InvoiceStatus.paid,
      lines: old.lines,
      totals: old.totals,
      revision: old.revision + 1,
    );
    _invoices = [for (final i in _invoices) i.id == invoiceId ? paid : i];
    _revision++;
    return paid;
  }

  @override
  Future<List<Expense>> expenses() async {
    await _latency();
    if (!_co.plan!.hasExpenses) throw const PlanUpgradeException();
    return List.unmodifiable(_expenses);
  }

  @override
  Future<ReceiptSuggestion> scanReceipt(
    String filename,
    List<int> bytes,
  ) async {
    await _latency(1400);
    if (!_co.plan!.hasExpenses) throw const PlanUpgradeException();
    // Synthetic recognition result; the real one comes from POST /finance/receipt-scan.
    return ReceiptSuggestion(
      supplier: 'Büro Depot',
      reference: 'RE-${1000 + Random().nextInt(8999)}',
      incurredOn: DateTime.now().subtract(const Duration(days: 1)),
      amountCents: 6790,
      category: 'office',
    );
  }

  @override
  Future<Expense> importReceipt({
    required int revision,
    required ReceiptSuggestion reviewed,
    required String filename,
  }) async {
    await _latency(800);
    if (!_co.plan!.hasExpenses) throw const PlanUpgradeException();
    _checkRevision(revision);
    if (reviewed.supplier.trim().isEmpty || reviewed.amountCents <= 0) {
      throw const ValidationException('err_validation');
    }
    final e = Expense(
      id: 'e${_seq++}',
      supplier: reviewed.supplier,
      date: reviewed.incurredOn,
      amountCents: reviewed.amountCents,
      category: reviewed.category,
      hasReceipt: true,
    );
    _expenses = [e, ..._expenses];
    _revision++;
    return e;
  }

  @override
  Future<PayOverview> payOverview() async {
    await _latency(600);
    if (!_co.payActive) throw const DeniedException();
    const cats = [
      JobCategory(
        name: 'Engineering',
        women: 14,
        men: 38,
        avgWomenCents: 612000,
        avgMenCents: 648000,
      ),
      JobCategory(
        name: 'Customer Success',
        women: 22,
        men: 11,
        avgWomenCents: 421000,
        avgMenCents: 429000,
      ),
      JobCategory(
        name: 'Sales',
        women: 9,
        men: 17,
        avgWomenCents: 498000,
        avgMenCents: 561000,
      ),
      JobCategory(
        name: 'Operations',
        women: 16,
        men: 12,
        avgWomenCents: 455000,
        avgMenCents: 458000,
      ),
      JobCategory(
        name: 'Management',
        women: 5,
        men: 13,
        avgWomenCents: 782000,
        avgMenCents: 874000,
      ),
    ];
    return const PayOverview(
      employees: 157,
      rawGapPercent: 9.4,
      adjustedGapPercent: 4.1,
      categories: cats,
      steps: [
        WorkflowStep('step_import', StepStatus.done),
        WorkflowStep('step_categories', StepStatus.done),
        WorkflowStep('step_analysis', StepStatus.active),
        WorkflowStep('step_actions', StepStatus.todo),
        WorkflowStep('step_approval', StepStatus.todo),
      ],
    );
  }

  @override
  Future<FinancePlan?> setDemoPlan(FinancePlan plan) async {
    await _latency(300);
    _company = _co.copyWith(plan: plan);
    return plan;
  }
}
