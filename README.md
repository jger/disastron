# Disastron

Offline-first Flutter app for **emergency readiness and calm decision support** when networks fail or you need answers without leaving the device.

## About the name

**Disastron** is formed from Ancient Greek **δις** (*dis*, here “twice” or “doubly”) and **ἄστρον** (*astron*, “star”) — **δις ἄστρον**, evoking a **bad omen in the stars** or an **ill‑starred** moment. English **disaster** comes from the same picture by another route: Italian *disastro* from Latin *dis-* + *astrum* (“star”), i.e. fate turning against you under unfavorable stars. The app name compresses that old sense of cosmic misalignment into one word.

## Why this exists

The goal is to offer the **strongest help we can build—without artificial limits**—to anyone who needs it. **Human life is not a market segment**; access to solid guidance in a crisis should not be gated by subscriptions or vendor lock-in.

**Open source:** the project is intended to go **open source once the maintainers consider it mature enough** to welcome contributors and public scrutiny without compromising safety or quality.

## Features

- **Dashboard** — Device snapshot (battery, rough place from GPS/geocoding), expandable **day/night** and **local conditions** (sun times, typical temperatures from bundled climate data). Pull-to-refresh.
- **Call help** — **Offline** emergency-number list **by detected country** (bundled JSON), with context from location where permissions allow.
- **CPR & planning** — Quick entry to **bundled offline wiki** articles (e.g. CPR essentials, home kit / trip prep). Not a substitute for professional services or training.
- **SOS signal** — Screen/torch **Morse SOS**, optional **alarm tone**, **vibration**, and **Bluetooth** awareness (user-toggled); use only where lawful and safe.
- **Wiki tab** — Full list of offline reference articles (markdown).
- **Todos** — Simple on-device checklist support (including chat-driven actions where implemented).
- **Chat** — **On-device** LLM inference (Gemma family via `flutter_gemma`); models downloaded to storage. Optional **Hugging Face token** only for authorized model downloads—**no app login**, no cloud chat backend in the default design.
- **Settings** — **Theme & appearance** (multiple modes, including dark high contrast for visibility and battery messaging), **offline model** install (presets, URL, file from device).

Core principle: **work offline** so maps, towers, and accounts are not single points of failure when things go wrong.

## Tech (short)

Flutter, Riverpod, Auto Route, `flutter_gemma`, bundled assets (wiki, emergency numbers, climate normals), local permissions for location / audio / vibration as required by the platform.

## License

See repository headers and `LICENSE` if present; licensing may be updated when the project is published openly.
