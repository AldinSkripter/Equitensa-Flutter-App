import 'package:flutter/material.dart';

/// Lightweight localisation: German (DE/AT default), Slovenian (SI default) and English.
/// The UI language never changes company country rules; it is only presentation.
class S {
  S(this.lang);
  final String lang;

  static const supported = [Locale('de'), Locale('sl'), Locale('en')];
  static const delegate = _Delegate();

  @visibleForTesting
  static const strings = _strings;

  static S of(BuildContext context) => Localizations.of<S>(context, S)!;

  String t(String key) => _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
}

class _Delegate extends LocalizationsDelegate<S> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      const ['de', 'sl', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) async =>
      S(isSupported(locale) ? locale.languageCode : 'de');

  @override
  bool shouldReload(_Delegate old) => false;
}

const Map<String, Map<String, String>> _strings = {
  'tagline': {
    'de': 'Gehälter fair, Finanzen einfach – in einer App.',
    'sl': 'Pošteno plačilo, enostavne finance – v eni aplikaciji.',
    'en': 'Fair pay, simple finance – in one app.',
  },
  'choose_company': {
    'de': 'Unternehmen wählen',
    'sl': 'Izberite podjetje',
    'en': 'Choose company',
  },
  'choose_company_hint': {
    'de': 'Das Land ergibt sich aus Ihrem registrierten Unternehmen.',
    'sl': 'Država izhaja iz vašega registriranega podjetja.',
    'en': 'The country comes from your registered company.',
  },
  'demo_notice': {
    'de':
        'Demo-Modus mit synthetischen Daten. Die native Anmeldung (OAuth/PKCE) und die HTTPS-Staging-Umgebung stellt das Backend-Team bereit.',
    'sl':
        'Demo način s sintetičnimi podatki. Nativno prijavo (OAuth/PKCE) in HTTPS staging okolje zagotovi backend ekipa.',
    'en':
        'Demo mode with synthetic data. Native sign-in (OAuth/PKCE) and the HTTPS staging environment are provided by the backend team.',
  },
  'account': {'de': 'Konto', 'sl': 'Račun', 'en': 'Account'},
  'tab_overview': {'de': 'Übersicht', 'sl': 'Pregled', 'en': 'Overview'},
  'tab_invoices': {'de': 'Rechnungen', 'sl': 'Računi', 'en': 'Invoices'},
  'tab_customers': {'de': 'Kunden', 'sl': 'Kupci', 'en': 'Customers'},
  'tab_expenses': {'de': 'Ausgaben', 'sl': 'Stroški', 'en': 'Expenses'},
  'tab_reports': {'de': 'Bericht', 'sl': 'Poročilo', 'en': 'Report'},
  'tab_categories': {
    'de': 'Kategorien',
    'sl': 'Kategorije',
    'en': 'Categories',
  },
  'module_locked': {
    'de': 'nicht aktiviert',
    'sl': 'ni aktiviran',
    'en': 'not activated',
  },
  'locked_pay_title': {
    'de': 'PAY ist für dieses Unternehmen nicht aktiviert',
    'sl': 'PAY za to podjetje ni aktiviran',
    'en': 'PAY is not activated for this company',
  },
  'locked_finance_title': {
    'de': 'FINANCE ist für dieses Unternehmen nicht aktiviert',
    'sl': 'FINANCE za to podjetje ni aktiviran',
    'en': 'FINANCE is not activated for this company',
  },
  'locked_body': {
    'de':
        'Das Modul wird über Ihr Paket freigeschaltet. Das Wechseln der Ansicht kauft nichts. Wenden Sie sich an die Administration Ihres Unternehmens.',
    'sl':
        'Modul se odklene prek vašega paketa. Preklop pogleda ničesar ne kupi. Obrnite se na administratorja vašega podjetja.',
    'en':
        'The module is unlocked through your package. Switching views never purchases anything. Contact your company administrator.',
  },
  'close': {'de': 'Schließen', 'sl': 'Zapri', 'en': 'Close'},
  'retry': {'de': 'Erneut versuchen', 'sl': 'Poskusi znova', 'en': 'Try again'},
  'offline_title': {
    'de': 'Keine Verbindung',
    'sl': 'Ni povezave',
    'en': 'You are offline',
  },
  'offline_body': {
    'de':
        'Ihre Daten liegen sicher auf dem Server. Prüfen Sie die Verbindung und laden Sie erneut.',
    'sl':
        'Vaši podatki so varno na strežniku. Preverite povezavo in poskusite znova.',
    'en':
        'Your data is safe on the server. Check your connection and try again.',
  },
  'denied_title': {
    'de': 'Kein Zugriff',
    'sl': 'Ni dostopa',
    'en': 'Access denied',
  },
  'denied_body': {
    'de':
        'Für diesen Bereich fehlt Ihnen die Berechtigung oder das Modul ist nicht aktiviert.',
    'sl': 'Za to območje nimate dovoljenja ali modul ni aktiviran.',
    'en':
        'You do not have permission for this area or the module is not activated.',
  },
  'upgrade_title': {
    'de': 'Im Paket nicht enthalten',
    'sl': 'Ni vključeno v paket',
    'en': 'Not included in your package',
  },
  'upgrade_body': {
    'de':
        'Diese Funktion ist ab dem Paket Business verfügbar. Ihre bestehenden Daten bleiben erhalten.',
    'sl':
        'Ta funkcija je na voljo od paketa Business naprej. Vaši obstoječi podatki ostanejo.',
    'en':
        'This feature is available from the Business package. Your existing data stays available.',
  },
  'see_packages': {
    'de': 'Pakete ansehen',
    'sl': 'Poglej pakete',
    'en': 'View packages',
  },
  'error_title': {
    'de': 'Etwas ist schiefgelaufen',
    'sl': 'Nekaj je šlo narobe',
    'en': 'Something went wrong',
  },
  'error_body': {
    'de':
        'Die Anfrage konnte nicht abgeschlossen werden. Bitte versuchen Sie es erneut.',
    'sl': 'Zahteve ni bilo mogoče dokončati. Poskusite znova.',
    'en': 'The request could not be completed. Please try again.',
  },
  'err_validation': {
    'de': 'Bitte prüfen Sie die markierten Angaben.',
    'sl': 'Preverite označene podatke.',
    'en': 'Please check the highlighted fields.',
  },
  'conflict_title': {
    'de': 'Daten wurden geändert',
    'sl': 'Podatki so bili spremenjeni',
    'en': 'Data was changed',
  },
  'conflict_body': {
    'de':
        'Jemand hat diese Daten inzwischen im Web oder in der App geändert. Ihre Eingaben bleiben erhalten und werden nichts überschreiben, bis Sie bestätigen.',
    'sl':
        'Podatke je medtem nekdo spremenil v spletu ali aplikaciji. Vaši vnosi ostanejo in ničesar ne prepišejo, dokler ne potrdite.',
    'en':
        'Someone changed this data on the web or in the app. Your input is preserved and will not overwrite anything until you confirm.',
  },
  'conflict_reload': {
    'de': 'Neu laden und erneut speichern',
    'sl': 'Osveži in znova shrani',
    'en': 'Reload and save again',
  },
  'conflict_keep': {
    'de': 'Weiter bearbeiten',
    'sl': 'Nadaljuj z urejanjem',
    'en': 'Keep editing',
  },
  'discard_title': {
    'de': 'Entwurf verwerfen?',
    'sl': 'Zavržem osnutek?',
    'en': 'Discard draft?',
  },
  'discard_body': {
    'de': 'Ihre nicht gespeicherten Eingaben gehen verloren.',
    'sl': 'Vaši neshranjeni vnosi bodo izgubljeni.',
    'en': 'Your unsaved input will be lost.',
  },
  'discard': {'de': 'Verwerfen', 'sl': 'Zavrzi', 'en': 'Discard'},
  'new_invoice': {
    'de': 'Neue Rechnung',
    'sl': 'Nov račun',
    'en': 'New invoice',
  },
  'new_customer': {
    'de': 'Neuer Kunde',
    'sl': 'Nov kupec',
    'en': 'New customer',
  },
  'scan_receipt': {
    'de': 'Beleg scannen',
    'sl': 'Skeniraj račun',
    'en': 'Scan receipt',
  },
  'quick_actions': {
    'de': 'Schnellaktionen',
    'sl': 'Hitra dejanja',
    'en': 'Quick actions',
  },
  'open_receivables': {
    'de': 'Offene Forderungen',
    'sl': 'Odprte terjatve',
    'en': 'Open receivables',
  },
  'kpi_paid': {'de': 'Bezahlt', 'sl': 'Plačano', 'en': 'Paid'},
  'kpi_expenses': {'de': 'Ausgaben', 'sl': 'Stroški', 'en': 'Expenses'},
  'revenue_6m': {
    'de': 'Umsatz – 6 Monate',
    'sl': 'Prihodki – 6 mesecev',
    'en': 'Revenue – 6 months',
  },
  'recent_invoices': {
    'de': 'Letzte Rechnungen',
    'sl': 'Zadnji računi',
    'en': 'Recent invoices',
  },
  'see_all': {'de': 'Alle', 'sl': 'Vse', 'en': 'All'},
  'st_draft': {'de': 'Entwurf', 'sl': 'Osnutek', 'en': 'Draft'},
  'st_issued': {'de': 'Offen', 'sl': 'Odprto', 'en': 'Open'},
  'st_paid': {'de': 'Bezahlt', 'sl': 'Plačano', 'en': 'Paid'},
  'st_overdue': {'de': 'Überfällig', 'sl': 'Zapadlo', 'en': 'Overdue'},
  'filter_all': {'de': 'Alle', 'sl': 'Vsi', 'en': 'All'},
  'empty_invoices_title': {
    'de': 'Noch keine Rechnungen',
    'sl': 'Še ni računov',
    'en': 'No invoices yet',
  },
  'empty_invoices_body': {
    'de': 'Erstellen Sie Ihren ersten Entwurf. Beträge berechnet der Server.',
    'sl': 'Ustvarite prvi osnutek. Zneske izračuna strežnik.',
    'en': 'Create your first draft. The server calculates the amounts.',
  },
  'invoice': {'de': 'Rechnung', 'sl': 'Račun', 'en': 'Invoice'},
  'not_found': {'de': 'Nicht gefunden', 'sl': 'Ni najdeno', 'en': 'Not found'},
  'not_found_body': {
    'de':
        'Dieser Beleg existiert nicht mehr oder gehört zu einem anderen Unternehmen.',
    'sl': 'Ta dokument ne obstaja več ali pripada drugemu podjetju.',
    'en': 'This document no longer exists or belongs to another company.',
  },
  'server_document': {
    'de': 'Dokument vom Server',
    'sl': 'Dokument s strežnika',
    'en': 'Server document',
  },
  'share_pdf': {'de': 'PDF teilen', 'sl': 'Deli PDF', 'en': 'Share PDF'},
  'pdf_mock': {
    'de': 'Demo: Das PDF wird später vom Backend geladen und geteilt.',
    'sl': 'Demo: PDF bo pozneje naložen z backenda in deljen.',
    'en': 'Demo: the PDF will later be downloaded from the backend and shared.',
  },
  'mark_paid': {
    'de': 'Als bezahlt markieren',
    'sl': 'Označi kot plačano',
    'en': 'Mark as paid',
  },
  'draft_issue_hint': {
    'de':
        'Entwürfe werden nach Prüfung der Pflichtangaben auf dem Server ausgestellt.',
    'sl': 'Osnutki se izdajo na strežniku po preverbi obveznih podatkov.',
    'en':
        'Drafts are issued on the server after the required fields are checked.',
  },
  'bill_to': {'de': 'Rechnung an', 'sl': 'Račun za', 'en': 'Bill to'},
  'number': {'de': 'Nummer', 'sl': 'Številka', 'en': 'Number'},
  'issue_date': {
    'de': 'Rechnungsdatum',
    'sl': 'Datum izdaje',
    'en': 'Issue date',
  },
  'due_date': {'de': 'Fällig am', 'sl': 'Zapade', 'en': 'Due date'},
  'net': {'de': 'Netto', 'sl': 'Neto', 'en': 'Net'},
  'vat': {'de': 'USt.', 'sl': 'DDV', 'en': 'VAT'},
  'gross': {'de': 'Brutto', 'sl': 'Bruto', 'en': 'Gross'},
  'customer': {'de': 'Kunde', 'sl': 'Kupec', 'en': 'Customer'},
  'select_customer': {
    'de': 'Kunde auswählen',
    'sl': 'Izberite kupca',
    'en': 'Select customer',
  },
  'dates': {'de': 'Datum', 'sl': 'Datumi', 'en': 'Dates'},
  'date': {'de': 'Datum', 'sl': 'Datum', 'en': 'Date'},
  'lines': {'de': 'Positionen', 'sl': 'Postavke', 'en': 'Line items'},
  'line': {'de': 'Position', 'sl': 'Postavka', 'en': 'Line'},
  'add_line': {
    'de': 'Position hinzufügen',
    'sl': 'Dodaj postavko',
    'en': 'Add line',
  },
  'remove': {'de': 'Entfernen', 'sl': 'Odstrani', 'en': 'Remove'},
  'description': {'de': 'Beschreibung', 'sl': 'Opis', 'en': 'Description'},
  'quantity': {'de': 'Menge', 'sl': 'Količina', 'en': 'Quantity'},
  'unit_price': {
    'de': 'Einzelpreis',
    'sl': 'Cena na enoto',
    'en': 'Unit price',
  },
  'required': {'de': 'Pflichtfeld', 'sl': 'Obvezno polje', 'en': 'Required'},
  'invalid_number': {
    'de': 'Ungültige Zahl',
    'sl': 'Neveljavno število',
    'en': 'Invalid number',
  },
  'invalid_email': {
    'de': 'Ungültige E-Mail',
    'sl': 'Neveljaven e-naslov',
    'en': 'Invalid email',
  },
  'invalid_vat': {
    'de': 'Ungültige USt-IdNr.',
    'sl': 'Neveljavna davčna številka',
    'en': 'Invalid VAT ID',
  },
  'server_calculated': {
    'de': 'Vom Server berechnet – verbindlich',
    'sl': 'Izračunano na strežniku – zavezujoče',
    'en': 'Calculated by the server – authoritative',
  },
  'save_draft': {
    'de': 'Entwurf speichern',
    'sl': 'Shrani osnutek',
    'en': 'Save draft',
  },
  'save': {'de': 'Speichern', 'sl': 'Shrani', 'en': 'Save'},
  'search': {'de': 'Suchen', 'sl': 'Išči', 'en': 'Search'},
  'empty_customers_title': {
    'de': 'Noch keine Kunden',
    'sl': 'Še ni kupcev',
    'en': 'No customers yet',
  },
  'empty_customers_body': {
    'de': 'Legen Sie Ihren ersten Kunden an, um Rechnungen zu erstellen.',
    'sl': 'Dodajte prvega kupca za izdajo računov.',
    'en': 'Add your first customer to create invoices.',
  },
  'business': {'de': 'Firma', 'sl': 'Podjetje', 'en': 'Business'},
  'private': {'de': 'Privat', 'sl': 'Zasebno', 'en': 'Private'},
  'name': {'de': 'Name', 'sl': 'Ime', 'en': 'Name'},
  'city': {'de': 'Ort', 'sl': 'Kraj', 'en': 'City'},
  'email': {'de': 'E-Mail', 'sl': 'E-pošta', 'en': 'Email'},
  'vat_id': {'de': 'USt-IdNr.', 'sl': 'Davčna številka za DDV', 'en': 'VAT ID'},
  'country': {'de': 'Land', 'sl': 'Država', 'en': 'Country'},
  'empty_expenses_title': {
    'de': 'Noch keine Ausgaben',
    'sl': 'Še ni stroškov',
    'en': 'No expenses yet',
  },
  'empty_expenses_body': {
    'de':
        'Fotografieren Sie einen Beleg – Sie prüfen die erkannten Daten vor dem Speichern.',
    'sl': 'Slikajte račun – pred shranjevanjem preverite prepoznane podatke.',
    'en':
        'Photograph a receipt – you review the recognised data before saving.',
  },
  'cat_office': {'de': 'Büro', 'sl': 'Pisarna', 'en': 'Office'},
  'cat_software': {
    'de': 'Software',
    'sl': 'Programska oprema',
    'en': 'Software',
  },
  'cat_travel': {'de': 'Reisen', 'sl': 'Potovanja', 'en': 'Travel'},
  'cat_meals': {'de': 'Bewirtung', 'sl': 'Gostinstvo', 'en': 'Meals'},
  'cat_other': {'de': 'Sonstiges', 'sl': 'Drugo', 'en': 'Other'},
  'receipt_intro_title': {
    'de': 'Beleg erfassen',
    'sl': 'Zajem računa',
    'en': 'Capture a receipt',
  },
  'receipt_intro_body': {
    'de':
        'Foto oder Datei hochladen. Die Erkennung ist nur ein Vorschlag – Aussteller, Datum und Betrag prüfen Sie selbst.',
    'sl':
        'Naložite fotografijo ali datoteko. Prepoznava je le predlog – izdajatelja, datum in znesek preverite sami.',
    'en':
        'Upload a photo or file. Recognition is only a suggestion – you verify issuer, date and amount yourself.',
  },
  'take_photo': {'de': 'Foto aufnehmen', 'sl': 'Slikaj', 'en': 'Take photo'},
  'choose_file': {
    'de': 'Aus Galerie wählen',
    'sl': 'Izberi iz galerije',
    'en': 'Choose from gallery',
  },
  'enter_manually': {
    'de': 'Manuell erfassen',
    'sl': 'Vnesi ročno',
    'en': 'Enter manually',
  },
  'camera_unavailable': {
    'de':
        'Kamera nicht verfügbar oder Berechtigung verweigert. Sie können manuell erfassen.',
    'sl': 'Kamera ni na voljo ali dovoljenje ni odobreno. Vnesete lahko ročno.',
    'en':
        'Camera unavailable or permission denied. You can enter the data manually.',
  },
  'file_too_large': {
    'de': 'Die Datei ist größer als 2 MB.',
    'sl': 'Datoteka je večja od 2 MB.',
    'en': 'The file is larger than 2 MB.',
  },
  'scanning': {
    'de': 'Beleg wird gelesen …',
    'sl': 'Branje računa …',
    'en': 'Reading receipt…',
  },
  'review_hint': {
    'de':
        'Bitte prüfen: Die Erkennung kann Aussteller und Empfänger oder Rechnungs- und Fälligkeitsdatum verwechseln.',
    'sl':
        'Preverite: prepoznava lahko zamenja izdajatelja in prejemnika ali datum računa in zapadlosti.',
    'en':
        'Please review: recognition can confuse issuer and recipient, or invoice and due dates.',
  },
  'manual_hint': {
    'de': 'Manuelle Erfassung – es wurde nichts automatisch erkannt.',
    'sl': 'Ročni vnos – nič ni bilo samodejno prepoznano.',
    'en': 'Manual entry – nothing was recognised automatically.',
  },
  'supplier': {'de': 'Lieferant', 'sl': 'Dobavitelj', 'en': 'Supplier'},
  'reference': {'de': 'Belegnummer', 'sl': 'Referenca', 'en': 'Reference'},
  'amount_gross': {
    'de': 'Betrag (brutto)',
    'sl': 'Znesek (bruto)',
    'en': 'Amount (gross)',
  },
  'category': {'de': 'Kategorie', 'sl': 'Kategorija', 'en': 'Category'},
  'confirm_reviewed': {
    'de': 'Ich habe die Angaben mit dem Originalbeleg geprüft.',
    'sl': 'Podatke sem preveril z izvirnim računom.',
    'en': 'I have checked the details against the original receipt.',
  },
  'upload_expense': {
    'de': 'Als Ausgabe speichern',
    'sl': 'Shrani kot strošek',
    'en': 'Save as expense',
  },
  'retake': {'de': 'Neu aufnehmen', 'sl': 'Ponovno slikaj', 'en': 'Retake'},
  'receipt_saved': {
    'de': 'Ausgabe gespeichert',
    'sl': 'Strošek shranjen',
    'en': 'Expense saved',
  },
  'packages': {'de': 'Pakete', 'sl': 'Paketi', 'en': 'Packages'},
  'packages_notice': {
    'de':
        'Preisanzeige zur Information – der Wechsel hier ist eine Demo-Simulation und kein Kauf.',
    'sl':
        'Prikaz cen je informativen – zamenjava tukaj je demo simulacija in ne nakup.',
    'en':
        'Prices are informational – switching here is a demo simulation, not a purchase.',
  },
  'per_month_net': {
    'de': '/ Monat netto',
    'sl': '/ mesec neto',
    'en': '/ month net',
  },
  'seat': {'de': 'Platz', 'sl': 'uporabnik', 'en': 'seat'},
  'seats': {'de': 'Plätze', 'sl': 'uporabniki', 'en': 'seats'},
  'min_term': {
    'de': '12 Monate Mindestlaufzeit',
    'sl': '12 mesecev minimalna doba',
    'en': '12-month minimum term',
  },
  'current_plan': {
    'de': 'Aktuelles Paket',
    'sl': 'Trenutni paket',
    'en': 'Current package',
  },
  'demo_select': {
    'de': 'Demo: Paket simulieren',
    'sl': 'Demo: simuliraj paket',
    'en': 'Demo: simulate package',
  },
  'f_invoices': {
    'de': 'Kunden, Angebote und Rechnungen',
    'sl': 'Kupci, ponudbe in računi',
    'en': 'Customers, offers and invoices',
  },
  'f_pdf_xml': {
    'de': 'PDF und E-Rechnung (Testexport)',
    'sl': 'PDF in e-račun (testni izvoz)',
    'en': 'PDF and e-invoice (test export)',
  },
  'f_expenses': {
    'de': 'Ausgaben und Belegupload',
    'sl': 'Stroški in nalaganje računov',
    'en': 'Expenses and receipt upload',
  },
  'f_ocr': {
    'de': 'Belegerkennung per Kamera',
    'sl': 'Prepoznava računov s kamero',
    'en': 'Camera receipt recognition',
  },
  'f_bank': {
    'de': 'Bank-CSV und Zuordnung',
    'sl': 'Bančni CSV in usklajevanje',
    'en': 'Bank CSV and allocation',
  },
  'f_recurring': {
    'de': 'Wiederkehrende Entwürfe',
    'sl': 'Ponavljajoči osnutki',
    'en': 'Recurring drafts',
  },
  'adjusted_gap': {
    'de': 'Bereinigter Gender Pay Gap',
    'sl': 'Prilagojena razlika v plačah',
    'en': 'Adjusted gender pay gap',
  },
  'raw_gap': {'de': 'Unbereinigt', 'sl': 'Neprilagojeno', 'en': 'Unadjusted'},
  'employees': {'de': 'Beschäftigte', 'sl': 'zaposlenih', 'en': 'employees'},
  'women': {'de': 'Frauen', 'sl': 'Ženske', 'en': 'Women'},
  'men': {'de': 'Männer', 'sl': 'Moški', 'en': 'Men'},
  'avg_pay_by_category': {
    'de': 'Ø Monatsgehalt je Kategorie',
    'sl': 'Povp. mesečna plača po kategoriji',
    'en': 'Average monthly pay by category',
  },
  'needs_attention': {
    'de': 'Handlungsbedarf',
    'sl': 'Zahteva ukrepanje',
    'en': 'Needs attention',
  },
  'no_flags': {
    'de': 'Keine Kategorie überschreitet die 5-%-Schwelle.',
    'sl': 'Nobena kategorija ne presega 5 % praga.',
    'en': 'No category exceeds the 5% threshold.',
  },
  'joint_assessment': {
    'de':
        'Ab 5 % ohne Begründung ist eine gemeinsame Entgeltbewertung erforderlich.',
    'sl': 'Od 5 % naprej brez utemeljitve je potrebna skupna ocena plač.',
    'en': 'From 5% without justification a joint pay assessment is required.',
  },
  'threshold_note': {
    'de':
        'Demo-Daten. Berechnung und Berichte erstellt ausschließlich das Backend.',
    'sl': 'Demo podatki. Izračune in poročila pripravi izključno backend.',
    'en':
        'Demo data. Calculations and reports are produced by the backend only.',
  },
  'empty_categories_title': {
    'de': 'Keine Kategorien',
    'sl': 'Ni kategorij',
    'en': 'No categories',
  },
  'empty_categories_body': {
    'de':
        'Importieren Sie Gehaltsdaten im Web, um Vergleichskategorien zu bilden.',
    'sl':
        'Uvozite podatke o plačah v spletu za oblikovanje primerljivih kategorij.',
    'en': 'Import salary data on the web to build comparable categories.',
  },
  'empty_report_title': {
    'de': 'Kein Bericht in Vorbereitung',
    'sl': 'Poročilo se ne pripravlja',
    'en': 'No report in progress',
  },
  'empty_report_body': {
    'de':
        'Starten Sie die Berichtsvorbereitung im Web – hier sehen Sie den Fortschritt.',
    'sl': 'Pripravo poročila začnite v spletu – tukaj vidite napredek.',
    'en': 'Start report preparation on the web – track progress here.',
  },
  'report_progress': {
    'de': 'Berichtsfortschritt',
    'sl': 'Napredek poročila',
    'en': 'Report progress',
  },
  'workflow': {'de': 'Ablauf', 'sl': 'Potek', 'en': 'Workflow'},
  'download_report': {
    'de': 'Bericht herunterladen',
    'sl': 'Prenesi poročilo',
    'en': 'Download report',
  },
  'step_import': {
    'de': 'Gehaltsdaten importieren',
    'sl': 'Uvoz podatkov o plačah',
    'en': 'Import salary data',
  },
  'step_import_d': {
    'de': 'Daten prüfen und validieren.',
    'sl': 'Preverjanje in validacija podatkov.',
    'en': 'Check and validate the data.',
  },
  'step_categories': {
    'de': 'Vergleichskategorien',
    'sl': 'Primerljive kategorije',
    'en': 'Comparable categories',
  },
  'step_categories_d': {
    'de': 'Gleichwertige Tätigkeiten gruppieren.',
    'sl': 'Združevanje enakovrednih del.',
    'en': 'Group work of equal value.',
  },
  'step_analysis': {'de': 'Analyse', 'sl': 'Analiza', 'en': 'Analysis'},
  'step_analysis_d': {
    'de': 'Entgeltlücken je Kategorie ermitteln.',
    'sl': 'Ugotavljanje razlik v plačah po kategorijah.',
    'en': 'Determine pay gaps per category.',
  },
  'step_actions': {
    'de': 'Maßnahmen & Erklärungen',
    'sl': 'Ukrepi in pojasnila',
    'en': 'Actions & explanations',
  },
  'step_actions_d': {
    'de': 'Unterschiede begründen oder beheben.',
    'sl': 'Utemeljitev ali odprava razlik.',
    'en': 'Justify or resolve differences.',
  },
  'step_approval': {
    'de': 'Freigabe & Nachweis',
    'sl': 'Potrditev in dokazilo',
    'en': 'Approval & evidence',
  },
  'step_approval_d': {
    'de': 'Bericht freigeben und Nachweise sichern.',
    'sl': 'Potrditev poročila in shranitev dokazil.',
    'en': 'Approve the report and store evidence.',
  },
  'country_note': {
    'de':
        'Das Land ist das registrierte Unternehmensland und bestimmt die Regeln. Die Sprache ändert daran nichts.',
    'sl':
        'Država je registrirana država podjetja in določa pravila. Jezik tega ne spremeni.',
    'en':
        'The country is the registered company country and determines the rules. Language never changes it.',
  },
  'language': {'de': 'Sprache', 'sl': 'Jezik', 'en': 'Language'},
  'lang_auto': {'de': 'Auto', 'sl': 'Samodejno', 'en': 'Auto'},
  'workspace': {
    'de': 'Arbeitsbereich',
    'sl': 'Delovni prostor',
    'en': 'Workspace',
  },
  'not_activated': {
    'de': 'Nicht aktiviert',
    'sl': 'Ni aktivirano',
    'en': 'Not activated',
  },
  'security': {'de': 'Sicherheit', 'sl': 'Varnost', 'en': 'Security'},
  'security_hint': {
    'de': 'Geräte & Sitzungen',
    'sl': 'Naprave in seje',
    'en': 'Devices & sessions',
  },
  'auth_pending': {
    'de': 'Verfügbar, sobald die native Anmeldung des Backends bereitsteht.',
    'sl': 'Na voljo, ko bo nativna prijava na backendu pripravljena.',
    'en': 'Available once the backend native sign-in is ready.',
  },
  'demo_tools': {
    'de': 'Demo-Werkzeuge',
    'sl': 'Demo orodja',
    'en': 'Demo tools',
  },
  'sim_offline': {
    'de': 'Offline simulieren',
    'sl': 'Simuliraj brez povezave',
    'en': 'Simulate offline',
  },
  'sim_conflict': {
    'de': 'Versionskonflikt simulieren',
    'sl': 'Simuliraj konflikt različic',
    'en': 'Simulate version conflict',
  },
  'logout': {'de': 'Abmelden', 'sl': 'Odjava', 'en': 'Sign out'},
};
