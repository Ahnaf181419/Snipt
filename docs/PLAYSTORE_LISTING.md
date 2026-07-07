# Play Store listing & form answers

Copy-paste reference for the Google Play Console. Every field needed for
the first release of `dev.frostflux.snipt` is pre-answered below.

---

## 1. Store listing

### App name (30 chars max)
```
Snipt: Clipboard Manager
```
(25 chars. Brand first, category second. The colon is the standard Play
Store convention for "Brand: Category" and reads as a tagline.)

### Short description (80 chars max)
```
Local-first clipboard. Pin, search & reuse text. Nothing leaves your device.
```
(78 chars. Hits the privacy differentiator + the three verbs users care
about. Keyword-optimised: clipboard, pin, search.)

### Full description (4000 chars max)

```
Catch every clip. Forget nothing. Own everything.

snipt saves text and images you copy so you can search, pin, and reuse
them — even hours or days later. Everything stays on your device. No
accounts, no cloud sync, no telemetry, no ads.

WHY SNIPT

• You copy a tracking number at 9am, need it at 3pm, and forgot it.
• You want clipboard history without giving a third-party app full read
  access to your pasteboard 24/7.
• You screenshot an address and want to find it again by typing
  "Berlin" — not by scrolling your gallery.

FEATURES

📋 Full clipboard history
   Text, links, phone numbers, and images — every clip saved with a
   timestamp.

🔍 Search that actually works
   Type any word. Results filter in real time across your entire
   history.

📌 Pin the important ones
   Phone numbers, license keys, addresses. Pinned clips stay on top
   forever, even when history rolls over.

🖼️ Image clips
   Share or pick an image. Save it, and copy it back to any other
   app's pasteboard in one tap.

📤 Quick share & save
   Tap to copy. Long-press to share. Save images straight to your
   gallery.

THREE WAYS TO CAPTURE

1. Capture button — open snipt, tap +, paste from your clipboard or
   pick an image.
2. Quick-Settings tile — pull down the notification shade, tap the
   snipt tile, done.
3. Share sheet — share text or images to snipt from any app.

ON ANDROID 10+ BACKGROUND CLIPBOARD ACCESS — BE HONEST

Android 10 (API 29) blocks apps from reading your clipboard in the
background for privacy. This is a good thing — it stops rogue apps
from snooping your pasteboard. But it also means snipt cannot
silently capture everything you copy in the background.

If you want a clipboard manager that ignores Android's privacy rules
and reads your pasteboard 24/7 in the background, this is not the
app for you. snipt works with the OS, not around it. For
background-style capture, the Quick-Settings tile or share sheet
both take one tap.

PRIVACY

• No accounts. No sign-in. No email.
• All data stored locally, encrypted with SQLCipher (AES-256). The
  key is sealed by the Android Keystore.
• No analytics SDK. No crash reporter. No remote logging.
• No network access required. The app works fully offline.
• snipt has no servers, so there's nothing to leak, subpoena, or
  breach.

FREE vs PRO

Free:
• 200 most recent clips
• 200 MB of image storage
• All core features: search, pin, delete, share

Pro (one-time purchase, no subscription):
• Unlimited clips
• Unlimited image storage
• Early access to new features

Made by an indie developer in Dhaka, Bangladesh.

Found a bug? Tap the in-app feedback link. No trackers between us.
```

### What's new (release notes for v1.0.0)
```
First release. Capture, search, pin, and share clipboard clips and
images — all on-device, all encrypted.
```

---

## 2. App content (rating questionnaire)

Fill this in under **Policy → App content**.

### Content rating (IARC questionnaire)
| Question | Answer |
|---|---|
| Violence | No |
| Sexual content | No |
| Language (user-generated) | No — no user-generated text is shared publicly |
| Controlled substances | No |
| Tobacco, alcohol, drugs | No |
| Gambling | No |
| User-generated content | No |
| **Resulting rating** | **Everyone (ESRB E / PEGI 3)** |

### Ads
```
No
```

### In-app purchases
```
Yes
```
- One non-consumable: "Snipt Pro" (unlimited clips + unlimited image storage)
- Price tier: pick your own (suggested $4.99 USD or equivalent)

### Government app
```
No
```

### COVID-19 contact tracing / status app
```
No
```

### Health apps
```
No
```

### VPN use
```
No
```

### Financial features
```
No
```

### Data deletion
```
Yes — but see Data Safety form below. The user can:
  • Delete individual clips (swipe or long-press menu)
  • Wipe all history (Settings → Storage)
  • Uninstall the app (which removes all data)
```

---

## 3. Data safety form

Fill this in under **Policy → App content → Data safety**.

### Data collection overview
```
No data is collected from this app.
```

Walk through each category to be explicit:

| Data type | Collected? | Shared? | Notes |
|---|---|---|---|
| Location | No | No | App has no location feature |
| Personal info (name, email, address, phone) | No | No | App does not ask for these |
| Financial info (payment, credit card) | No | No | Payment handled by Play Store; app never sees card data |
| Health & fitness | No | No | Not a health app |
| Messages (SMS, MMS, email) | No | No | Not a messaging app |
| Photos & videos | **Yes** (stored locally only) | No | User shares/picks images into the app's private storage. Never leaves device. |
| Audio files | No | No | Not collected |
| Files & docs | No | No | Not collected |
| Calendar | No | No | Not accessed |
| Contacts | No | No | Not accessed |
| App activity (in-app actions, search history) | **Yes** (stored locally only) | No | Stored in encrypted local DB. Never leaves device. |
| Web browsing | No | No | App has no browser |
| App info & performance (crash logs, diagnostics) | No | No | No crash reporter; no analytics SDK |
| Device ID | No | No | Not collected |

### Data security
```
Data is encrypted in transit: N/A (no network)
Data is encrypted at rest: Yes (AES-256 via SQLCipher)
User can request data deletion: Yes
Independent security review: No
```

### Data deletion URL
Not required — no data leaves the device. If asked, link to:
```
https://github.com/<your-username>/snipt (or your support page)
```

---

## 4. App access (testing instructions)

Under **Policy → App content → App access**.

```
No account required. The app works fully offline. To test capture,
the reviewer can:

  1. Open the app and tap the "Capture" button.
  2. Choose "Capture clipboard text" to paste the device clipboard.
  3. Or choose "Pick image from gallery" to select an image.

For Quick-Settings tile access:
  1. Pull down the notification shade.
  2. Tap the pencil/edit icon.
  3. Drag the "snipt" tile into the active tiles.
  4. Tap the tile to capture the current clipboard.
```

---

## 5. Foreground service justification (specialUse)

When Play Console asks you to justify the `FOREGROUND_SERVICE_SPECIAL_USE`
declaration, paste this in the FGS reasoning field:

```
Purpose: snipt provides a persistent on-device clipboard history
manager. The foreground service keeps a long-lived capture pipeline
alive so the user can trigger a capture from the persistent
notification or the Quick-Settings tile without re-launching the
app. Captures are dispatched to Flutter via a Pigeon channel and
written to an encrypted local database.

What data is accessed: the device clipboard (text + image MIME),
read only at user-initiated moments: (1) when the app gains window
focus, (2) when the user taps the capture notification action,
(3) when the user taps the Quick-Settings tile, (4) when the user
shares text/image into the app via the system share sheet. The
service never reads the clipboard in the background — Android 10+
(API 29) blocks that for any non-IME app, and snipt works with
that restriction rather than around it.

Why specialUse is required: snipt does not fit any of the
standard foreground service types defined by Android. It is not a
location, media playback, microphone, camera, health, remote
messaging, file sync, media projection, phone call, or short
service. The closest category is "dataSync", but the service is
not syncing data to a remote backend — it is buffering
user-initiated capture requests to a local encrypted database. A
persistent notification is shown at all times while the service
runs so the user can see it is active and stop it.

User controls: the user starts the service by tapping "Start
capture service" on the onboarding screen or in Settings. The
user can stop it at any time by tapping the "Stop" action on the
notification, by tapping the Quick-Settings tile to deactivate,
or by disabling in Settings.
```

---

## 6. Target audience & content

| Field | Answer |
|---|---|
| Target age group | 18+ (the questionnaire may force "all ages" — that's fine, the app is suitable for all ages) |
| Store listing app category | **Productivity** |
| Content rating | Everyone (from §2) |
| Designed for children | No |
| Designed for families | No |
| Contains ads | No |
| Contains IAP | Yes (Pro) |
| Available on Wear OS / TV / Auto | No |

---

## 7. Release configuration (when uploading the AAB)

| Field | Answer |
|---|---|
| Track | Production (or Internal testing first to validate) |
| App signing | **Use Google-managed signing** (recommended for new apps) |
| Release name | `1.0.0` |
| Release notes | Use the "What's new" text from §1 |
| Rollout | Start at 10% to catch install issues, then 100% after 24h |
| Device catalog | All devices that meet minSdk 24 |
| Country availability | Start with your own country, expand to all over a week |

---

## 8. Pre-launch checklist

- [ ] Icon (512×512 PNG) at `android/app/src/main/res/mipmap-*/ic_launcher.png`
- [ ] Feature graphic (1024×500 PNG/JPG) — design needs to be created
- [ ] Phone screenshots (minimum 4, 16:9 or 9:16) — at least one per major screen: history, search, capture, detail, settings
- [ ] Short description (80 chars) — §1
- [ ] Full description (≤4000 chars) — §1
- [ ] Privacy policy URL — host a simple page on GitHub Pages or your domain
- [ ] Data safety form — §3
- [ ] Content rating — §2
- [ ] App access instructions — §4
- [ ] FGS justification — §5
- [ ] IAP configured in Play Console → Monetize → Products → In-app products
- [ ] Internal testing track with 1–2 trusted testers before promoting to production
- [ ] Support email or URL in Play Console → Grow → Store presence

---

## 9. Post-launch monitoring (first 7 days)

- **Day 1**: Watch Play Console crash reports and Android Vitals. Roll
  out at 10% for 24h before bumping to 100%.
- **Day 2–3**: Bump rollout to 50% if no ANRs/crashes above 0.47%
  threshold.
- **Day 4–7**: 100% rollout. Respond to user reviews in the first
  48h — early reviews are weighted more heavily by the algorithm.
- **Day 7**: First review of install/uninstall funnel. Anything below
  30% Day-1 retention is a sign the onboarding or first-run experience
  needs work.

---

## Privacy policy

The full policy lives at `docs/PRIVACY_POLICY.md` in this repo.

### Hosting requirement

Play Console requires a **public URL** for the privacy policy. The
easiest hosting options for a one-time policy:

| Option | URL format | Cost |
|---|---|---|
| **GitHub Pages from this repo** | `https://<owner>.github.io/snipt/privacy` | Free |
| **GitLab Pages** | `https://<owner>.gitlab.io/snipt/privacy` | Free |
| **Notion public page** | `https://<handle>.notion.site/<id>` | Free |
| **Custom domain** | `https://frostflux.dev/privacy` | Domain cost only |

### Quickest path: GitHub Pages (4 commands)

```bash
# 1. Create a gh-pages branch with just the policy
git checkout -b gh-pages
# 2. Copy the policy into a path that Pages will serve
mkdir -p docs && cp docs/PRIVACY_POLICY.md docs/privacy.md
git add docs/privacy.md
git commit -m "docs: publish privacy policy"
git push -u origin gh-pages
# 3. In repo Settings → Pages, set source = gh-pages branch, root = /
# 4. Privacy policy URL becomes:
#    https://<owner>.github.io/snipt/privacy
```

### Paste this URL into Play Console

Under **Policy → App content → Privacy policy**, paste the hosted URL.
Copy the same URL into **Data Safety → Data deletion URL** if you set
data deletion to "Yes" (recommended for this app, even though
uninstall handles deletion entirely).

Replace `<owner>` with your actual GitHub username before publishing.

| File | Source | Notes |
|---|---|---|
| `app-release.aab` | `build/app/outputs/bundle/release/` | Upload this — Play Console handles APK generation per device |
| (do NOT upload) `app-release.apk` | `build/app/outputs/flutter-apk/` | For sideloading local testing only |
