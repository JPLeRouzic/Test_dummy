Choosing the client technology

Flutter gives you one Dart codebase for Android and iOS, good performance, and a consistent UI. It works well with a REST/JSON backend. The main alternative is React Native (with Expo), which is a better fit if you or your team already know JavaScript/TypeScript. Both are accepted by the stores without issue.

I’d avoid simply wrapping your website in a WebView (Capacitor, Cordova, etc.) as the main approach. It’s the fastest to build, but it’s the riskiest for approval. Apple’s guideline 4.2 (“minimum functionality”) regularly rejects apps that are essentially a website in a shell, and Google can flag low-value apps too.

Backend: turn the PHP site into an API
Move your business logic into services or classes that both the website and the API call, rather than duplicating it. Frameworks like Laravel or Symfony (API Platform) make this easy, but plain PHP works too.
Build a versioned JSON API (/api/v1/...) and describe it with an OpenAPI spec. You can generate Dart client code from it, which saves a lot of work.
Use token-based authentication (OAuth2 or JWT with refresh tokens, or Laravel Sanctum), HTTPS everywhere, and rate limiting.
Plan for versioning from day one. Old app versions stay installed on users’ phones for a long time, so you can’t break the API freely.
What improves your chances of store approval

Both stores care less about the technology than about these points:

Real app value. Offer things a mobile app does better than a website: push notifications, offline caching, biometric login, camera or share integration, a UI designed for touch. This is the best protection against Apple’s 4.2 rejection.
Account deletion. If users can create an account in the app, both stores require a way to delete it from within the app.
Privacy. You need a privacy policy URL, Google’s Data Safety form, and Apple’s privacy “nutrition labels.” Declare honestly any analytics or ad SDKs you use.
Payments. Digital goods and subscriptions generally must go through Apple In-App Purchase and Google Play Billing. Physical goods and real-world services can use your own payment system. Rules vary by region and have been changing, so check the current guidelines for your case.
Login rules. If you offer third-party login (Google, Facebook), Apple requires an equivalent privacy-preserving option, typically Sign in with Apple.
User-generated content. If users can post content, you need reporting, blocking, and moderation.
Reviewer access. Give Apple and Google a working demo account and brief notes, since reviewers can’t use the app otherwise.
Stability. Crashes, broken links, and placeholder content are among the most common rejection reasons.
-----------------------
MedQuest is a good fit for a mobile app, and a few things on your site will shape the strategy.

Why your app should be a strong candidate

Spaced repetition is the best argument for a native app. Daily review reminders (push notifications), offline access to your question sets, progress tracking and short sessions on the metro are all things a website does poorly. Build the app around that. It is also your protection against Apple’s “minimum functionality” rejection, because the app clearly does more than the website.

The four areas that will decide approval

1. Payments (the most important one). You sell a 24h pass (€1.99) and a monthly subscription (€9.99). Content consumed inside the app is digital, so:

On iOS you must use Apple In-App Purchase. On Android you must use Google Play Billing. The stores take roughly 15–30%, so factor that into your pricing, or keep prices slightly higher in-app.
The 24h pass maps to a non-renewing or consumable product, and the monthly plan to an auto-renewing subscription.
A library like RevenueCat (it has a Flutter SDK) handles both stores and lets your PHP backend check “is this user subscribed?” through one webhook or API. This saves a lot of pain.
Users who subscribe on your website can generally log in to the app and use what they paid for. But you usually can’t point them from the app to your web payment page, and the rules differ between the US, the EU and other regions and keep changing. Check Apple’s and Google’s current guidelines for France and the EU before designing the paywall screens.

2. Medical content. Apple scrutinizes health and medical apps (guideline 1.4.1). Education for students is fine, but:

State clearly that the app is for educational purposes and not for diagnosis or real patient care. This matters especially for the patient simulator.
Cite your sources or say who validates the content, such as authors or reviewers. Reviewers like seeing credibility.
Do not describe the app as a medical device.

3. The forum (user-generated content). Both stores require:

A way to report posts and block users
Moderation you can actually perform, with a stated response time
Terms of use that users accept, with no tolerance for abusive content

Since medical students might share exam material or patient information, add a line in the rules forbidding any identifiable patient data.

4. Accounts and privacy.

Account deletion must be possible from within the app, not only by emailing you.
Your site has a privacy page, so check that it covers the app. You’ll need the URL for both stores, plus Google’s Data Safety form and Apple’s privacy labels. As a French/EU service you also need to be GDPR-compliant, which means honest consent for any analytics.
Registration is by email and password, so Sign in with Apple is not required unless you add Google or Facebook login. If you do add one, you must also offer Sign in with Apple.
Technical recommendations specific to your site
Authentication: your site passes a token= in URLs. For the API, don’t reuse that pattern. Use proper login with short-lived access tokens plus refresh tokens, sent in an Authorization header, and store them in the phone’s secure storage.
API split: the MCQ cases, spaced-repetition scheduling, ECOS exams, forum and subscription status all map naturally to JSON endpoints. Keep the repetition algorithm on the server so the website and the app stay in sync.
Offline mode: download sets of cases for offline use and sync answers when the connection returns. This is the feature that most differentiates you from the website.
Virtual patient simulator: this is currently an HTML page. For a first version you could show it inside a WebView, but only as one feature inside an otherwise native app, never as the core experience. For a polished version, rebuild it natively in Flutter.
Free tier: keep your free content (three questions per module, the mini simulator, small ECOS sets) in the app. Reviewers can then see real functionality without paying, which speeds approval.
Suggested order of work
Build the API (auth, questions, answers/progress, subscription status), documented with OpenAPI.
Build the Flutter MVP with login, the free MCQ browse, and the spaced-repetition review with reminders.
Add subscriptions through RevenueCat and test them with TestFlight and Google’s closed testing. Payments are where most first submissions get rejected, so test them early.
Add the forum with reporting and blocking, then the ECOS and simulator.
Prepare the submission: demo account with an active subscription, review notes explaining the paid tiers, privacy policy, account deletion and a medical disclaimer.
------------------
Here is a feature-first structure. Each feature (quiz, review, ECOS, forum...) owns its data, logic and screens, so you can ship the MVP first and add features later without restructuring.

Folder structure:
medquest_app/
├── pubspec.yaml
├── analysis_options.yaml
├── l10n.yaml
├── assets/
│   ├── images/
│   └── virtualpatient/            # only if you embed the HTML simulator at first
├── lib/
│   ├── main.dart                  # entry point, env setup
│   ├── app.dart                   # MaterialApp.router, theme, localization
│   │
│   ├── core/
│   │   ├── config/                # env.dart (API base URL per dev/prod)
│   │   ├── network/
│   │   │   ├── api_client.dart    # Dio instance
│   │   │   ├── auth_interceptor.dart   # adds Bearer token, handles refresh on 401
│   │   │   └── api_exception.dart
│   │   ├── storage/
│   │   │   ├── secure_storage.dart     # tokens (flutter_secure_storage)
│   │   │   └── local_db.dart           # offline cache (drift/SQLite)
│   │   ├── routing/
│   │   │   └── app_router.dart    # go_router, auth redirect guards
│   │   ├── theme/
│   │   ├── notifications/         # local reminders + push setup
│   │   ├── widgets/               # shared buttons, loaders, error views
│   │   └── utils/
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/              # auth_api.dart, auth_repository.dart
│   │   │   ├── domain/            # user.dart
│   │   │   └── presentation/      # login, register, delete_account screens + controllers
│   │   │
│   │   ├── catalog/               # browse questions by category (free tier)
│   │   │   ├── data/ domain/ presentation/
│   │   │
│   │   ├── quiz/                  # MCQ case player
│   │   │   ├── data/              # question_api.dart, question_repository.dart
│   │   │   ├── domain/            # clinical_case.dart, answer.dart
│   │   │   └── presentation/      # case_screen, result_screen, widgets/
│   │   │
│   │   ├── review/                # spaced repetition (your core feature)
│   │   │   ├── data/              # syncs answers, downloads due cards
│   │   │   ├── domain/            # review_session.dart
│   │   │   └── presentation/      # daily_review_screen, stats_screen
│   │   │
│   │   ├── ecos/                  # OSCE-style exams
│   │   ├── simulator/             # virtual patient (WebView first, native later)
│   │   ├── forum/                 # threads, posts, report/block users
│   │   ├── subscription/
│   │   │   ├── data/              # revenuecat_service.dart, entitlement_repository.dart
│   │   │   └── presentation/      # paywall_screen, restore_purchases
│   │   └── settings/              # privacy, terms, medical disclaimer, delete account
│   │
│   └── l10n/
│       └── app_fr.arb             # French strings (add app_en.arb later if needed)
│
├── test/                          # unit tests for repositories and controllers
├── integration_test/
├── android/
└── ios/

Layers inside each feature
data: talks to the API and the local database. Contains the API class (Dio calls), DTOs (JSON models) and a repository that decides between network and local cache.
domain: plain Dart models and business rules, with no Flutter or HTTP code.
presentation: screens, widgets and state controllers.

This separation keeps the offline logic out of your widgets, which makes it testable.

Recommended packages
Purpose	Package
State management	flutter_riverpod
Navigation	go_router
HTTP	dio
JSON models	freezed + json_serializable
Offline database	drift (SQLite)
Secure token storage	flutter_secure_storage
In-app purchases	purchases_flutter (RevenueCat)
Push notifications	firebase_messaging
Local reminders	flutter_local_notifications
WebView (simulator v1)	webview_flutter
French localization	flutter_localizations + intl
Crash reporting	firebase_crashlytics or sentry_flutter

If you write an OpenAPI spec for your PHP API, you can generate the Dart client with openapi-generator instead of hand-writing data/ API classes.

Practical advice
Create the project with both platforms from day one: flutter create --org org.padiracinnovation --platforms=android,ios medquest_app. The bundle ID is hard to change later and must match across both stores and RevenueCat.
Use two environments (dev and prod API URLs) via --dart-define or flavors, so TestFlight and closed-test builds can point at a staging server.
Offline sync: store answers locally with a “pending” flag and send them in batches. Let the server be the source of truth for the next review date.
Entitlements: the subscription feature should expose one simple value, such as isPremium, that the rest of the app reads. Never scatter purchase checks across screens.
Build the first milestone in this order: core → auth → catalog → quiz → review → subscription. Leave forum, ecos and simulator for the second release if time is short.

Native setup is still needed:

Android: add the POST_NOTIFICATIONS and RECEIVE_BOOT_COMPLETED permissions plus the plugin’s boot receiver in the manifest, and enable core library desugaring. The plugin’s README has the exact snippets.
iOS: set the notification-center delegate in AppDelegate.swift, as the README explains.
Plugin versions: if the compiler asks for uiLocalNotificationDateInterpretation, you have an older version of the plugin than the one I coded against. Add that argument as absoluteTime.

Before going live
Version pins: the new packages are flutter_local_notifications, timezone, flutter_timezone, shared_preferences, purchases_flutter and url_launcher. I haven’t pinned versions, so use the latest of each.
Exam date: intervals can reach 120 days or more. For students with a fixed exam date, you may want to cap intervals so cards come back before it.
Store rules: in the paywall, don’t add links that send users to your website’s payment page. The store rules differ by region, as discussed earlier.

