# Equitensa Flutter App

Native Flutter app for the Equitensa PAY and FINANCE workspaces.
Uses the same accounts, companies and API as the Equitensa web application.

## Toolchain

Flutter **3.50.0**, Dart **3.14**, Material UI **1.11.0** and Cupertino UI **1.1.6**.
The Flutter version is pinned in [.fvmrc](./.fvmrc). Use FVM or a matching SDK
when running the commands below. Android uses Gradle 9.5 and AGP 9.3.1.
The temporary design compatibility bridge keeps the legacy chart dependency themed.

## First run on a Mac / Xcode

Close Xcode, pull the latest project, and double-click [Prepare iOS.command](./Prepare%20iOS.command).
It uses the pinned Flutter SDK or downloads that SDK from the official Flutter repository
into the user's cache. It prepares iOS artifacts, resolves plugins and regenerates local
paths before opening the Xcode workspace. Xcode must be installed with first-launch setup
completed and its Command Line Tools selected. Choose Runner and an iPhone Simulator, then Run.
For a physical device, also configure your signing team and Developer Mode.

If Finder cannot execute the launcher, run `bash "Prepare iOS.command"` from the project root.
To point to a backend running on another computer, run
`API_BASE=http://YOUR_HOST:3000 bash "Prepare iOS.command"` instead. The launcher does not start
the backend. A simulator's localhost is the Mac; a real iPhone's localhost is the phone.

An Xcode shell error 127 needs the preceding error line to diagnose. One possible cause
after copying the Windows project is a generated Flutter configuration containing Windows
SDK paths. The launcher rewrites those generated files; do not copy the Windows SDK or
its generated configuration to the Mac. This preparation still requires a macOS build
to validate iOS compilation and device behavior.

## Local backend

Start the web backend on http://localhost:3000.
The iOS simulator uses localhost; the Android emulator uses 10.0.2.2:3000.
For a physical device, supply the host address with --dart-define=API_BASE=http://YOUR_HOST:3000.
Web previews require a same-origin /api proxy to that backend.

## Authentication

Registration and login call /api/auth/register and /api/auth/login.
The app restores /api/me, supports the email-verification gate, password reset,
and the backend's authenticator/backup-code challenge. Account security supports
native QR enrollment, activation, one-time recovery-code display and disabling 2FA. Native development
sessions use the backend cookie stored in OS secure storage. Web sessions use
same-origin browser cookies. Live mobile authentication still needs the agreed
HTTPS production configuration and mobile authentication contract.

## Workspace features

Native Pay now includes the import and report workflow, job evaluation, reviews, approvals,
monthly payroll, information rights, pay criteria, national reports, employer evidence,
integrations, retention and billing. Native Finance includes the product catalogue, bank CSV
reconciliation, recurring drafts, receivables, document delivery records, original files,
advanced designs and exports. Contacts use all 249 ISO recipient countries independently
of the DE/AT/SI issuer markets.

See [web feature inventory and backend limitations](./docs/web-parity.md).

## UI

Original brand asset, native launch screens/app icons and bundled Inter font.
Three swipeable introduction pages with skip and login actions. Registration
matches the web form: company first, business email, password, reporting country.
Responsive graphite account screens, password visibility/strength, server errors,
and floating Finance/Pay navigation with the create action centered between tabs.
Pushed iOS pages support the native back gesture.

Appearance offers explicit light and dark modes, with the preference saved locally.
The header toggles appearance directly; the language menu offers German and Slovenian
without changing the registered reporting country.
Switch it from the auth header, workspace header or Account settings. Documents
retain their paper colors in both modes. Returning to the app and pull-to-refresh
re-read shared backend data without replaying mutations.
Invoice rendering retains the web document templates and server totals.

## Validation

- flutter analyze --no-pub
- flutter test
- flutter build web --release --no-pub
- flutter build apk --debug

iOS builds require macOS with Xcode and Apple signing configuration. The Android
debug manifest allows the local HTTP backend; release configuration requires HTTPS.

Live tests use localhost:3000 and skip if unavailable. The registration check only
creates a synthetic account when /api/health reports demo mode.
