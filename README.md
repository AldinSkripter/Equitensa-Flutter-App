# Equitensa Flutter App

One Flutter app (iOS + Android) with **PAY** and **FINANCE** workspaces for the Equitensa platform.
The app uses the same backend, company and records as the web app. It never computes
authoritative totals, numbers or reports itself.

## Status

First milestone, built against a **mock repository** because the backend has not yet delivered
native auth (OAuth/PKCE) or an HTTPS staging environment (see the team handoff ZIP).

| Area | State |
|---|---|
| Brand, premium theme (violet `#7451f8`), PAY/FINANCE switch in the same place in both workspaces | done |
| Company selection (DE / AT / SI), country from the company, DE/AT default German, SI default Slovenian, UI language override | done |
| Locked modules explained, never purchased by switching | done |
| Finance: overview + chart, invoices (filter, detail/preview), invoice editor with server-calculated totals, customers, expenses, packages | done (mock) |
| Camera/gallery -> review -> upload -> expense (Business/Pro only) | done (mock OCR) |
| Pay: overview (gap gauge, category chart, 5% flags), report workflow, categories | done (mock) |
| Loading, empty, offline, denied, upgrade-required, validation and revision-conflict states | done |
| Real HTTP adapter, secure token storage, PDF download/share, issue/delivery flow | pending backend contract |

## Architecture

```
lib/
  domain/    models + EquitensaRepository (the single seam to the backend)
  data/      MockRepository (synthetic data, simulated latency/offline/conflict)
  core/      theme, l10n (de/sl/en), providers (Riverpod), shared widgets
  features/  auth, shell, finance, pay, account
```

To go live, implement `EquitensaRepository` against the backend (`/api/v1` once agreed) and swap
`repositoryProvider`. UI code does not change.

Rules from the handoff that the code follows:

- Money is integer cents; quantity and entered prices are decimal strings.
- Mutations carry the latest `state.revision`; a 409 shows a conflict dialog and keeps the user's input.
- Retries are disabled (`ProviderScope(retry: ...)`); no blind replay of creates or payments.
- No secrets, tokens or payroll data in source. Demo data is synthetic.

## Run

```
flutter pub get
flutter run
flutter analyze
flutter test
```

Account -> *Demo tools* simulates offline mode and a version conflict.
