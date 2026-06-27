# snipt — Pricing & Feature Analysis

> Static-analysis-driven recommendations for monetizing snipt on the
> Play Store and a list of features the current codebase is missing.

## What the App Actually Is (verified from code)

- Local-only clipboard history manager. Drift + SQLCipher. No network
  permission in the manifest, no analytics, no telemetry, no IAP /
  billing code anywhere (grep'd for `purchase|billing|subscription|
  premium|revenuecat|in_app|ads` — zero hits).
- Three capture methods, all manual: foreground-service "Capture"
  notification action, Quick-Settings tile, share-sheet target, and
  in-app button. The onboarding screen is *explicitly honest* about
  Android 10+'s background-clipboard block.
- Core features present: capture, dedup (`contentHash` UNIQUE),
  FTS5 search, pin, retention (7 / 30 / 90 / forever), biometric app
  lock with re-arm on resume, encrypted DB, dark mode, Material 3 +
  dynamic color, haptics, skeleton loaders, debounced search.
- Clip types: `text`, `url`, `richText` (the schema has the slot,
  but `ClipType.classify` only emits `text` and `url`).
- Soft-delete with `deletedAt` tombstones, UUIDs, `updatedAt` —
  designed to be sync-ready, but sync is not implemented.

## What Is Missing (verified against the audit and roadmap)

1. **Hard Play Store blockers:** no privacy policy, no real keystore,
   default Flutter app icon, no ProGuard / R8 rules, version still
   `1.0.0+1`, pubspec description still `"A new Flutter project."`
2. **Feature gaps in the roadmap that are unbuilt:** pagination
   (50-row cap), export / import, home-screen widget, clipboard
   auto-clear timer, PIN fallback for lock, branded notification icon.
3. **"Designed for sync" but no sync UI / backend / auth.**

---

## Part 1 — Pricing Recommendation

### Bottom line

> **Launch free, with a single one-time Pro unlock at $4.99.**
> **No subscription, no ads.**

### Why free-first, not paid-up-front

- The defining UX friction is *Android itself*. Users must grant a
  notification permission, allow a foreground service, and accept a
  persistent notification with a Capture action. Many will bounce
  before they ever see a paywall. A gate on first launch loses the
  funnel.
- The core differentiator is privacy / local-only. That message lands
  hardest when the app opens and works immediately, not behind $4.99.
- Competitor reference: Google Keep is free, Gboard clipboard is
  free, Microsoft SwiftKey clipboard is free. Paid clipboard apps
  (Clipboard Manager Pro, etc.) tend to die in the long tail.
  A one-time unlock survives because the privacy promise justifies
  a single act of support.

### Why one-time, not subscription

- Subscriptions on a single-device local utility create churn
  incentive with no churn reason — users won't churn, but they also
  won't re-subscribe, and Google takes 15% forever on whatever they
  do pay.
- The feature set doesn't naturally renew. "Pin a clip" is not
  recurring value.
- The only subscription argument would be cross-device sync, but
  sync isn't built yet. When it is, the network cost (Firebase,
  Supabase, E2EE key escrow) finally justifies a recurring price.
- A pay-once price keeps the privacy story clean — no Play Billing
  banner, no "auto-renews" disclosure on a clipboard app with zero
  server.

### Why no ads

- The app is local-only with no network permission. Adding ads would
  require a network permission, which is the *one* thing your privacy
  copy promises to never do. Ads would break the SQLCipher-only
  "nothing leaves the device" pitch.
- A clipboard app is too fast to monetize on impressions. Users open,
  copy, leave.

### Pricing tiers — recommended launch structure

**Free tier (everything except below):**
- All current features: capture, search, pin, retention, app lock,
  dark mode, dynamic color, FTS5 search.
- Soft cap: 200 stored clips. Above that, oldest non-pinned get
  pruned. (No popup, no nag — the retention setting already prunes
  non-pinned; just lower the default to make it visible.)
- No export, no sync.

**Snipt Pro (one-time unlock, $4.99):**
- Unlimited clips.
- Export / import (JSON + text file).
- Clipboard auto-clear timer (1h / 24h / 7d / manual).
- Custom app-lock PIN fallback when biometrics are unavailable.
- Home-screen widget for one-tap capture.
- Custom themes / accent color picker.
- Future: per-clip labels / categories.
- Future: rich-clip rendering (the schema has `richText`; ship it).

### Why $4.99 specifically

- Clipboard managers cluster between $1.99 (junk tier) and $6.99
  (Clipboard Manager Pro). $4.99 is the Play Store impulse-buy
  sweet spot: low enough to be "fine, why not", high enough to be
  meaningful revenue on a small install base.
- $2.99 works as a lower-friction point, but you'll be tempted to
  keep adding Pro-only features to make it feel worth it. $4.99
  buys you room to give meaningful things.
- A $9.99 lifetime tier is *not* recommended at launch. A clipboard
  app with no clear v2 roadmap can't justify the higher number, and
  it splits the funnel.

### Subscription later?

Not at v1.0. If / when you ship encrypted cross-device sync, add it
as **Pro+ (annual, $2.99/yr)** on top of the lifetime Pro unlock.
Pro owners get it free. The annual price covers Firebase / Supabase
egress and key-rotation storage.

### Global pricing (Play Store country tiers)

- **Tier 1** (US, UK, DE, JP, AU, CA): $4.99
- **Tier 2** (IN, BR, ID, MX, TR, …): $1.99–$2.99 — the privacy
  pitch lands hard in markets where cloud clipboard sync isn't
  trusted.
- Don't do "free trial then $4.99" — it's a friction mismatch with
  the one-time-purchase promise. Either they buy or they don't.

### Revenue expectations (honest, not hype)

- Clipboard utilities cap out at low-6-figure installs even on a
  great Play Store run. At 2% conversion × $4.99 × 50k installs
  ≈ $5,000.
- The privacy story is the brand play, not the revenue play. Use
  the install base to grow the dev portfolio, not to fund a team.

---

## Part 2 — Necessary Features You're Missing

### A. Ship-blocking (Play Store will reject without these)

1. **Privacy policy** on a hosted URL. Play Console requires it for
   biometric + FGS permissions. One-pager on a static site is fine.
2. **Real release keystore** — generate `.jks`, fill
   `android/key.properties`.
3. **Branded app icon** (512×512 PNG) + adaptive icon
   (foreground / background layers, plus a monochrome variant for
   Android 13+ themed icons).
4. **Replace pubspec description** (currently `"A new Flutter
   project."`).
5. **Bump `version: 1.0.0+1`** deliberately and decide a build /
   version scheme.
6. **ProGuard / R8 keep rules** — verify with
   `flutter build appbundle --release` that Drift and Pigeon survive
   minification.
7. **Branded notification icon** (currently
   `android.R.drawable.ic_menu_save`). White silhouette on
   transparent is the Android norm.
8. **Store listing assets:** screenshots (phone + tablet), feature
   graphic 1024×500, short + long description, content rating.

### B. Should-ship-with-Pro (group them as the Pro unlock)

1. **Export / import (JSON).** Backs up the encrypted DB contents
   but also exports plaintext. This is the feature most "I lost my
   phone" users will pay for. Wire to `path_provider` and the system
   share-sheet.
2. **Auto-clear timer.** Already half-architected in settings
   (retention 7/30/90/0). Add 1h and 24h options and a "clear all"
   action.
3. **PIN fallback for app lock.** Audit flagged it. PIN goes in
   `flutter_secure_storage` (already wired).
4. **Home-screen widget.** AppWidgetProvider in Kotlin, Pigeon
   method to trigger capture from widget button. The single biggest
   "feels pro" feature for a clipboard app.
5. **Custom theme / accent.** Material 3 dynamic color is already
   there; an accent picker for non-themable devices completes it.
6. **Pagination / load-more.** Currently 50-row cap. Below 50 clips
   nobody notices, but at 200+ clips the cap is a wall. Make it a
   `ScrollController` listener that bumps `limit` by 50. **Not a
   Pro feature** — gating it is unfriendly. Ship it free.

### C. Post-launch / optional (only after v1 is in users' hands)

1. **Rich-clip rendering.** The `richText` enum entry exists; the
   classifier returns `text` for everything. Real rich clips
   (HTML, formatted text) is a whole subsystem — likely a v1.1.
2. **Labels / categories / smart folders** (Pro). Boosts Pro's
   perceived value once the unlock exists.
3. **Per-source app filter** (Pro). "Only capture from WhatsApp"
   etc. Real power-user feature.
4. **Clipboard watch-list:** notify me when clipboard contains a
   pattern (Pro). Niche but sticky.
5. **Cross-device encrypted sync** (subscription). Designed for,
   not built. Needs auth, key-escrow model, conflict resolution.
   Whole separate product.

### D. Don't do these

- **"AI summarization of clips"** — needs network, breaks the
  privacy pitch, also gimmicky.
- **"Floating bubble" capture.** You already have the permission,
  but a persistent overlay is the #1 thing Android OEMs kill in the
  background. Don't make it a flagship feature.
- **Web clipper / browser extension.** Different product, different
  surface, different support load.
- **"Themes marketplace".** Niche, support-heavy, low ROI.

---

## Part 3 — Recommended Order of Operations

1. Ship blockers (A1–A8) as a single "Play Store ready" release.
2. Build Pro unlock infra: pick a billing lib (RevenueCat if you
   want analytics, `in_app_purchase` from Google if you want
   zero-fee), add an `entitlement` flag to settings, gate B1–B5
   in code.
3. Ship B6 (pagination) in the same release — free.
4. B1 (export / import) is the most-requested feature by
   clipboard-app users historically. Ship it as Pro.
5. B4 (home-screen widget) is the most visible Pro feature. Ship
   it second.
6. B2, B3, B5 are the polish. They can land in v1.1.
7. Watch the C-list for v1.2+. Do not let C2 (sync) start before
   you have paying users telling you they want it.

---

## Part 4 — Caveat

This document was generated by static reading of the codebase,
`docs/AUDIT_REVIEW.md`, and `docs/PLAYSTORE_ROADMAP.md`, cross-checked
against the actual `lib/` files. `flutter analyze` and `flutter test`
were *not* re-run for this analysis. The pricing tiering and feature
list are recommendations, not measurements of user demand.

For a validation pass, wire RevenueCat sandbox keys, build a landing
page, or run a small Play Store pre-launch survey.
