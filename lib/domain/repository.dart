import 'models.dart';

/// Single seam between UI and backend. The mock implements it today; an HTTP adapter
/// against the shared Equitensa backend replaces it once native auth/staging exist.
/// The phone never computes authoritative totals: [calculate] is a server call.
abstract class EquitensaRepository {
  Future<List<Company>> companies();
  Future<Company> selectCompany(String id);

  Future<FinanceOverview> financeOverview();
  Future<List<Contact>> contacts();
  Future<Contact> createContact({
    required int revision,
    required String name,
    required String city,
    required String email,
    required String vatId,
    required bool business,
  });

  Future<List<Invoice>> invoices();
  Future<Totals> calculate(List<InvoiceLine> lines);
  Future<Invoice> saveDraft({
    required int revision,
    required Contact contact,
    required DateTime issueDate,
    required DateTime dueDate,
    required List<InvoiceLine> lines,
  });
  Future<Invoice> markPaid(String invoiceId, {required int revision});

  Future<List<Expense>> expenses();
  Future<ReceiptSuggestion> scanReceipt(String filename, List<int> bytes);
  Future<Expense> importReceipt({
    required int revision,
    required ReceiptSuggestion reviewed,
    required String filename,
  });

  Future<PayOverview> payOverview();
  Future<FinancePlan?> setDemoPlan(FinancePlan plan);
}

/// Developer switches used to demonstrate the required error states.
class DemoFlags {
  const DemoFlags({this.offline = false, this.conflict = false});
  final bool offline;
  final bool conflict;

  DemoFlags copyWith({bool? offline, bool? conflict}) => DemoFlags(
    offline: offline ?? this.offline,
    conflict: conflict ?? this.conflict,
  );
}
