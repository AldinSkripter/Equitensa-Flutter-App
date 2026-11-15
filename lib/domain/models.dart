enum Country {
  de('DE', 'Deutschland', [19, 7, 0]),
  at('AT', 'Österreich', [20, 13, 10, 0]),
  si('SI', 'Slovenija', [22, 9, 5, 0]);

  const Country(this.code, this.label, this.vatRates);
  final String code;
  final String label;
  final List<int> vatRates;

  /// Default UI language follows the registered company country, never GPS or device locale.
  String get defaultLanguage => this == Country.si ? 'sl' : 'de';

  String get flag => switch (this) {
    Country.de => '🇩🇪',
    Country.at => '🇦🇹',
    Country.si => '🇸🇮',
  };
}

enum FinancePlan {
  start('finance_start', 799, 1),
  business('finance_business', 1999, 2),
  pro('finance_pro', 2999, 3);

  const FinancePlan(this.id, this.monthlyNetCents, this.seats);
  final String id;
  final int monthlyNetCents;
  final int seats;

  bool get hasExpenses => this != FinancePlan.start;
  bool get hasRecurring => this == FinancePlan.pro;
}

enum AppModule { pay, finance }

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.payActive,
    required this.plan,
  });

  final String id;
  final String name;
  final Country country;
  final String city;
  final bool payActive;

  /// `null` means Finance is not activated for this company.
  final FinancePlan? plan;

  bool get financeActive => plan != null;
  bool hasModule(AppModule m) => m == AppModule.pay ? payActive : financeActive;

  Company copyWith({FinancePlan? plan}) => Company(
    id: id,
    name: name,
    country: country,
    city: city,
    payActive: payActive,
    plan: plan ?? this.plan,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    this.email = '',
    this.vatId = '',
    this.business = true,
  });

  final String id;
  final String name;
  final String city;
  final Country country;
  final String email;
  final String vatId;
  final bool business;
}

enum InvoiceStatus { draft, issued, paid, overdue }

class InvoiceLine {
  const InvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.rate,
    this.unit = 'h',
  });

  final String description;

  /// Decimal strings, as required by the backend contract.
  final String quantity;
  final String unitPrice;
  final int rate;
  final String unit;
}

class Totals {
  const Totals({
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
  });
  final int netCents;
  final int taxCents;
  final int grossCents;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.contact,
    required this.issueDate,
    required this.dueDate,
    required this.status,
    required this.lines,
    required this.totals,
    required this.revision,
    this.number,
  });

  final String id;
  final String? number;
  final Contact contact;
  final DateTime issueDate;
  final DateTime dueDate;
  final InvoiceStatus status;
  final List<InvoiceLine> lines;
  final Totals totals;
  final int revision;
}

class Expense {
  const Expense({
    required this.id,
    required this.supplier,
    required this.date,
    required this.amountCents,
    required this.category,
    this.hasReceipt = false,
  });

  final String id;
  final String supplier;
  final DateTime date;
  final int amountCents;
  final String category;
  final bool hasReceipt;
}

class ReceiptSuggestion {
  const ReceiptSuggestion({
    required this.supplier,
    required this.reference,
    required this.incurredOn,
    required this.amountCents,
    required this.category,
  });

  final String supplier;
  final String reference;
  final DateTime incurredOn;
  final int amountCents;
  final String category;
}

class FinanceOverview {
  const FinanceOverview({
    required this.openCents,
    required this.overdueCents,
    required this.paidMonthCents,
    required this.expensesMonthCents,
    required this.monthlyRevenueCents,
    required this.revision,
  });

  final int openCents;
  final int overdueCents;
  final int paidMonthCents;
  final int expensesMonthCents;
  final List<int> monthlyRevenueCents;
  final int revision;
}

class JobCategory {
  const JobCategory({
    required this.name,
    required this.women,
    required this.men,
    required this.avgWomenCents,
    required this.avgMenCents,
  });

  final String name;
  final int women;
  final int men;
  final int avgWomenCents;
  final int avgMenCents;

  double get gapPercent =>
      avgMenCents == 0 ? 0 : (avgMenCents - avgWomenCents) / avgMenCents * 100;

  /// The EU Pay Transparency Directive triggers a joint pay assessment at a 5% gap.
  bool get flagged => gapPercent.abs() >= 5;
}

enum StepStatus { done, active, todo }

class WorkflowStep {
  const WorkflowStep(this.key, this.status);
  final String key;
  final StepStatus status;
}

class PayOverview {
  const PayOverview({
    required this.employees,
    required this.rawGapPercent,
    required this.adjustedGapPercent,
    required this.categories,
    required this.steps,
  });

  final int employees;
  final double rawGapPercent;
  final double adjustedGapPercent;
  final List<JobCategory> categories;
  final List<WorkflowStep> steps;
}

sealed class RepoException implements Exception {
  const RepoException();
}

class OfflineException extends RepoException {
  const OfflineException();
}

class DeniedException extends RepoException {
  const DeniedException();
}

/// 403 FINANCE_PLAN_UPGRADE_REQUIRED
class PlanUpgradeException extends RepoException {
  const PlanUpgradeException();
}

/// 409 FINANCE_VERSION_CONFLICT
class VersionConflictException extends RepoException {
  const VersionConflictException(this.serverRevision);
  final int serverRevision;
}

class ValidationException extends RepoException {
  const ValidationException(this.messageKey);
  final String messageKey;
}
