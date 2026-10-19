# Disastron

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Latest Release](https://img.shields.io/github/v/release/jger/disastron?label=Download%20APK)](https://github.com/jger/disastron/releases/latest)

**Disastron** is a free, open-source, **offline-first emergency readiness and calm decision-support app**. When mobile networks fail, power is scarce, or you need reliable answers without leaving your device, Disastron keeps essential tools, survival guides, and optional on-device AI in your pocket.

---

## Download for Android

You can download the latest signed Android APK (~250 MB) directly from **[GitHub Releases](https://github.com/jger/disastron/releases/latest)**:

1. Go to the **[Latest Release](https://github.com/jger/disastron/releases/latest)** page and download **`disastron-<version>.apk`**.
2. Open the downloaded file on your Android phone or tablet (allow *Install unknown apps* if prompted).
3. *(Optional)* To use offline AI chat, open **Settings → Offline model** inside the app to download an on-device model over Wi-Fi.

> **Important:** By downloading or using Disastron, you acknowledge that it is an **offline educational and preparedness reference tool only**—not a medical device, not medical advice, and not a substitute for emergency services (such as 112 or 911). Provided "AS IS" without warranty; see [Important Notices](#important-notices) below.

<details>
<summary>Verify your download (SHA-256 checksum & update notes)</summary>

Each release includes a `.sha256` file next to the APK. To verify the file on macOS or Linux:

```bash
shasum -a 256 -c disastron-<version>.apk.sha256
```

**Updating:** Future GitHub APK releases are signed with the same key and can be installed directly over an existing GitHub APK install without losing your data. Note that if you installed Disastron from Google Play, you cannot cross-update directly between the Play Store version and the GitHub APK without uninstalling first.
</details>

---

## Features

Everything in Disastron is designed around one core principle: **work offline** so maps, cell towers, and cloud accounts are never single points of failure.

- **Dashboard** — Quick snapshot of your device battery, rough location (via GPS), **day/night sun times**, and **typical seasonal temperatures** from bundled climate data.
- **Call Help** — Offline **emergency numbers by country**, automatically matched to your detected region when location access is enabled.
- **CPR & Emergency Planning** — One-tap access to bundled **offline survival and first-aid guides** (CPR essentials, home emergency kits, evacuation prep).
- **SOS Signal** — Screen and flashlight **Morse code SOS**, optional **high-visibility alarm tone**, and **vibration**.
- **Offline Wiki** — Searchable library of emergency preparedness and medical reference articles stored completely on your device.
- **Checklists (Todos)** — Simple on-device checklists to track supplies and preparation steps.
- **Offline AI Chat** — Private, **100% on-device AI assistant** (powered by local Gemma models). Supports attaching a photo from your camera or gallery when using a multimodal model. No account, no cloud server, and no internet connection required once a model is installed.
- **Battery-Aware Themes** — Multiple appearance modes, including **Dark High Contrast** for readability in difficult conditions and lower OLED battery use.

---

## Why Disastron Exists

The goal is to offer the **strongest help we can build—without artificial limits**—to anyone who needs it. **Human life is not a market segment**; access to solid guidance in a crisis should not be gated by subscriptions, ads, or vendor lock-in.

### About the Name

**Disastron** comes from Ancient Greek **δις** (*dis*, “twice” or “doubly”) and **ἄστρον** (*astron*, “star”) — **δις ἄστρον**, evoking an **ill‑starred** moment. The English word *disaster* comes from the same image via Italian (*disastro*) and Latin (*dis-* + *astrum*): fate turning against you under unfavorable stars.

---

## Privacy

Disastron is **offline-first** by design:
- **No accounts, analytics, or cloud chat servers.**
- **Location** stays on your device and is used only to show local emergency numbers, sun times, and regional climate context when you grant permission.
- **Network requests** happen only when you explicitly choose to download an optional AI model file (from Hugging Face or a custom URL).

---

## Important Notices

- **Not a medical device & not medical advice** — Disastron is **not a medical device** (under EU MDR, US FDA, or any other regulatory framework) and is not intended to diagnose, treat, cure, triage, monitor, or prevent any disease or injury. Wiki articles (including CPR reminders), checklists, and on-device AI chat outputs are strictly for **general education and preparedness only**. They are **not** a substitute for certified first-aid training, professional medical care, or calling official emergency services (such as 112 or 911) when someone is hurt or unwell.
- **Emergency numbers** — The bundled list is maintained in good faith; always **verify emergency numbers** for your region ahead of time. Official guidance from local authorities always takes precedence.
- **SOS, alarm, torch, vibration** — Use signaling tools **only where lawful and safe**; they can distract others or cause distress if misused.
- **On-device AI** — Local AI models can **hallucinate or produce inaccurate, incomplete, or unsafe output**. Never rely on AI outputs for life-critical or medical decisions; always use your own judgment and seek professional human help.
- **No warranty / limitation of liability** — Disastron is provided **"AS IS"**, without warranty of any kind. Neither the author nor contributors shall be liable for any injury, loss of life, or damages arising from the use or inability to use this software.

---

## Contributing & Development

Application source code and bundled assets are released under the [MIT License](LICENSE). Contributions are welcome!

- **Developer setup, architecture, E2E testing (Patrol), and release pipeline:** see **[CONTRIBUTING.md](CONTRIBUTING.md)**
- **Wiki content attribution & licensing:** see **[CONTENT_ATTRIBUTION.md](CONTENT_ATTRIBUTION.md)**
- **Community guidelines:** see **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)**
- **Reporting security issues:** see **[SECURITY.md](SECURITY.md)**

---

## Legal & Licenses

- **Open Source License:** Copyright (c) 2024–2026 Jannis Gerardis. Licensed under the [MIT License](LICENSE).
- **Third-Party Software:** Full license texts for libraries used in Disastron are available in [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md), [`third_party_licenses.txt`](third_party_licenses.txt), and [`NOTICE`](NOTICE).
- **Downloaded AI Models:** Optional model weights downloaded inside the app (such as Gemma checkpoints from Hugging Face) are governed by their respective model licenses (e.g. [Google Gemma Terms of Use](https://ai.google.dev/gemma/terms)), separate from the MIT license of this repository.
- **Trademarks:** **Gemma** and **Hugging Face** are trademarks of their respective owners. Disastron is an independent project and is not endorsed by Google or Hugging Face.
