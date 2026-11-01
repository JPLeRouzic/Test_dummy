# MedQuest Flutter — clean foundation

This is a new Flutter application scaffold created from the supplied `client_v0.zip`.
The original project is preserved under `reference/anatomo_original/` and is **not**
part of the Flutter build. This prevents old Anatomo screens, imports, assets and
application entry points from interfering with the new MedQuest application.

## Included in this first foundation

- One Flutter entry point (`lib/main.dart`) and one `runApp()`.
- Riverpod as the dependency/state-management foundation.
- GoRouter with four persistent bottom-navigation branches.
- A French dashboard, question catalog, revision placeholder and settings screen.
- Dio configured through `--dart-define=API_BASE_URL=...`.
- A SQLite database foundation with cached cases and a user-associated pending-answer table.
- The original source and assets retained for selective reuse and comparison.

## Not implemented yet

Authentication, token refresh, question detail/answer submission, server-side grading,
answer synchronization, spaced-repetition scheduling, RevenueCat, reminders, ECOS,
virtual-patient simulation and anatomy viewer integration are deliberately not wired
into this baseline. They should be added as separate, testable features.

## Requirements

Use a Flutter SDK compatible with Dart 3.5 or later. Check your installed versions:

```bash
flutter --version
dart --version
```

## Generate Android and iOS runners

The uploaded source did not include a complete set of usable platform runners for
this new application. Generate them with the installed Flutter SDK:

```bash
./bootstrap_platforms.sh
```

This uses `fr.medquest` as an example reverse-domain organization. Change it before
creating the runners if you have a different identifier. The command creates Android
and iOS platform folders; it does not import the old Anatomo identifiers.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST/YOUR_API_ROOT
```

`API_BASE_URL` must be the root to which `/cases` can be appended. Do not put a trailing
slash if your server/proxy normalizes paths inconsistently; Dio accepts either form,
but choose one convention and keep it consistent.

For example, if the endpoint is `https://example.org/medquest/api/cases`, use
`https://example.org/medquest/api` as the base URL.

## Backend contract currently assumed

The catalog screen currently expects:

```json
{
  "items": [
    {"id": 12, "title": "Titre", "category": "Cardiologie", "locked": false}
  ]
}
```

The question-detail and answer endpoints are not yet implemented in this scaffold.
Before implementing them, review `reference/anatomo_original/lib/core/PHP_API.md`.
That document is a proposal from the previous project, not proof that the PHP
endpoints already exist.

### Important grading/security decision

Do not send `is_correct` flags to the mobile client before the student submits an
answer. The server should calculate the grade and return the correction/explanation
after submission. Premium-content authorization must also be enforced by the PHP
server, not only by hiding a button in Flutter.

## Reusing Anatomo components

The supplied ZIP contains anatomy Dart source files, but the atlas image folders
referenced by those files (`assets/atlas/...`, `assets/web/...`) are absent from the
archive. Therefore the 2D atlas and 3D viewer cannot be integrated or tested from
this ZIP alone.

Potentially reusable code, after a separate review:
- anatomy content parsing and quiz-generation logic;
- atlas controller and selection model;
- atlas rendering and viewer code, once its complete assets and licence are available;
- generic UI elements after removing Anatomo-specific theme/settings dependencies.

Do not copy the old `main.dart`, `app.dart`, router, update service, or platform identity.
The original project is retained for reference only.

## Android/iOS identifiers

This scaffold intentionally does not copy the Anatomo Android/iOS project configuration.
When creating platform folders for this project, use your own final application ID and
bundle identifier. Example placeholder: `fr.medquest.app`. Confirm availability and
your preferred reverse-domain identifier before publishing.
