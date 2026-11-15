# Native web feature parity

The Flutter client calls the existing Equitensa web backend. There is no second database, calculation engine, numbering service, or embedded web application. This inventory describes the web implementation inspected on 2026-11-15.

## Pay

| Web workflow | Native entry | Shared backend |
| --- | --- | --- |
| Reporting year and overview | Pay overview, report, year selector | analysis, workflow, reporting-plan |
| All seven indicator groups, hourly/annual comparisons, protected groups and quartiles | Pay → All metrics | analysis |
| Annual file import, encoding, worksheet/ZIP/path selection, mapping, quality checks, corrections and optional explicit AI suggestions | Pay → Data & integrations → File import | import/preview, import/quality, import/assist, import |
| Monthly HR and payroll records, classification, reconciliation, annual finalization, reset | Pay → Monthly payroll | payroll, payroll/preview, payroll/stage, payroll/codes, payroll/finalize, payroll/reset |
| Snapshot-bound company profile, objective category criteria, documented/scored job evaluation, representative agreement | Pay → Prepare report | employer-context, workflow |
| Explanations, actions, remediation proof and leave-return outcomes | Pay → Prepare report | workflow |
| Management approval, consultation, reporting date, joint assessment | Pay → Prepare report | workflow |
| Audience-specific drafts/prepared report and assessment downloads, PDF/CSV/XML/TXT/XLSX/JSON/HTML | Pay → Reports & exports | reports/:format |
| Requests, protected individual responses, dispatch records and annual rights notices | Pay → Information rights | requests, requests/:id/answer, requests/:id/close, rights-notice, rights-notice/document |
| Pay ranges, progression and criteria/vacancy documents | Pay → Pay criteria | pay-criteria, pay-criteria/document |
| Employer evidence, all 37 articles and evidence documents | Pay → Employer evidence; exports | employer-controls, employer-controls/:format, evidence/:format |
| DE/AT national supplements and documents; SI unavailable status | Pay → National report | national-report, national-report/document |
| API keys, one-time secret display, revocation, pending delivery import/discard, guides and history | Pay → Data & integrations | integrations, integrations/keys, integrations/batches, import/history |
| Retention policy, holds, inventory fingerprint, explicit year erasure and backup-erasure receipts | Pay → Privacy & retention | data-retention and its delete-year, receipts, backup-complete endpoints |
| Subscription terms, hosted checkout/portal, sandbox activation and cancellation preview/confirmation | Pay → Package & billing | billing and its checkout, sandbox-confirm, portal, cancellation endpoints |

## Finance

| Web workflow | Native entry | Shared backend |
| --- | --- | --- |
| Overview, quotes, invoices, contacts, expenses and plans | Existing Finance tabs | finance and existing versioned routes |
| Worldwide recipient countries, independent of DE/AT/SI issuer markets | Contact editor → searchable country picker | finance/contacts; ISO list matches shared/contact-countries.js (249) |
| EU B2B service/reverse-charge mode and evidence | Invoice editor | finance/preview, finance/documents; server tax rules |
| Product catalogue, archive flag and use in a document | Finance → Products & services | finance/products, finance/products/:id |
| Bank CSV preview/import, duplicate detection and explicit invoice allocation | Finance → Bank reconciliation | finance/bank/preview, finance/bank/import, finance/bank/:id/allocate |
| Recurring templates, pause/resume, manual run and opted-in creation of due drafts on opening | Finance → Recurring invoices | finance/recurring, finance/recurring/:id/toggle, finance/recurring/run |
| Open receivables and CSV | Finance → Receivables | finance/receivables, finance/receivables.csv |
| Offer status transitions and conversion | Document → More actions; convert | finance/documents/:id/offer-status, convert |
| Time-limited frozen share links and revocation | Document → More actions | finance/documents/:id/share |
| Original files/bundles, email/reminder drafts and external delivery evidence | Document → More actions | originals/:file, bundle.zip, email-draft, reminder.eml, delivery |
| Photograph, image/PDF/XML selection, OCR/structured draft review and receipt attachment | Expenses → Scan; expense details | receipt-scan, receipt-import, expenses/:id, expenses/:id/attachments, attachments/:id |
| Company design, saved library, custom document appearance, typography, colors, columns, blocks and test payment QR | Company & design; design library/studio; invoice editor | settings, designs, designs/:id/remove, qr-preview |
| Validated structured test exports, issue review and stored originals | Invoice editor / document | einvoice-preview, issue-check, issue |
| Filtered CSV, JSON backup, ZIP originals/data, activity | Finance → Exports & activity | export.csv, export, archive.zip |

## Account

Shared company display name/logo, login/registration, verification, password reset/change, MFA enrollment/enable/disable and one-time recovery codes use the existing account endpoints. Company-country registration remains separate from interface language and customer country.

## Backend limitations retained

- Finance is released by the backend only for isolated demo accounts. A production release must be implemented and enabled on the web backend; the mobile client does not bypass that gate.
- Live bank feeds, production structured invoicing, team invitations, direct vendor connectors and automatic national submission remain unavailable where the web backend reports them unavailable.
- Prepared Pay exports require the same active subscription and server readiness checks as the web.
- Hosted billing opens in the system browser. No card collection or payment processing is implemented in Flutter.
- Native release authentication/HTTPS configuration still needs the production deployment contract. No new authentication service was introduced.

## Validation

`test/parity_backend_test.dart` exercises annual import → ready workflow → prepared report and joint assessment inputs, requests, criteria, national reports, billing sandbox, keys, company brand, lifecycle cleanup, monthly payroll and advanced Finance actions against an isolated local demo backend. Requests are paced to respect the shared API rate limit.

`test/parity_ui_test.dart` covers all added module screens in light/dark mode, all 249 recipient-country codes, a BA contact payload/refetch, and snapshot conflicts retaining unsaved input. Existing authentication, finance calculation/PDF, theme persistence and responsive layout tests remain in place.

Android APK and web preview builds are validated on Windows. iOS compilation and real-device behavior require macOS/Xcode and device testing; they are not claimed by these checks.
