# AROKI

A modern, Android-compatible media client for Flutter that plays video from **declarative, signed connector repositories**. AROKI lets you browse catalogs, search titles, and stream episodes from community-owned "connectors" while keeping the source-of-truth for each connector in a **versioned, content-addressed Git repository**.

> AROKI Flutter — `v2.0.38+51`

## Features

- **Floating glassmorphic navigation** — a frosted, blurred bottom pill bar that floats over content across the three main tabs.
- **Discover** — a modern, continuously paginated catalog with section rails (e.g. *Recently Added*, *Popular*), pull-to-refresh, skeleton loading, and infinite scroll.
- **Search** — full-text title search against the active connector, with paginated results.
- **Library** — Continue Watching, Saved titles, and watch History with save/unsave toggles.
- **Detail pages** — episode lists with audio variant selection (Sub / Dub) per episode.
- **Video playback** — stream player with HLS/MP4 candidates, quality labels and external subtitles.
- **Verified sources** — repository index + connector manifest SHA-256 integrity verification and signing.

## How it works

AROKI fetches a **repository index** from a GitHub repo such as `kas021/AROKI-Connectors`:

```
index.json            → verified repository index (signed, lists connectors)
connectors/<id>/...   → signed connector manifests (declarative operations)
```

Each **connector manifest** declares, in a connector-agnostic declarative format:

- `discovery` — named sections (e.g. *Latest*, *Popular*), each with an HTML/JSON request and item extraction rules
- `search` — a query URL template with extraction fields
- `details` — title, synopsis, poster, genres
- `episodes` — flat, aggregated or panel-based episode lists
- `streams` — multi-step stream resolution with playback headers and subtitles

The **DeclarativeExtractionEngine** executes these manifests natively: it issues HTTP requests, parses HTML/JSON, resolves field paths and transforms (`absolutize`, `trim`, `removePrefix`, `firstInteger`, …), and maps everything to typed models — no JavaScript, WebView, or custom scraping code in the app.

## Architecture

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry, main shell, floating glass navigation bar |
| `lib/theme/aroki_theme.dart` | iOS-inspired dark design system (colors, glass overlays, typography) |
| `lib/state/aroki_app_state.dart` | `ChangeNotifier` app state: repositories, connectors, saved/recent titles, playback history |
| `lib/screens/` | Discover, Search, Library, Detail, Player, Profile & Sources |
| `lib/models/connector_models.dart` | Repository index, manifest, catalog item, episode, subtitle, stream models |
| `lib/services/declarative_extraction_engine.dart` | Executes declarative manifest operations over HTTP |
| `lib/services/repository_fetcher_service.dart` | Fetches and verifies repository index + connector manifests |
| `test/` | Widget and unit tests |

## Getting started

Prerequisites: [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.x).

```sh
flutter pub get
flutter run
```

### Analyze and test

```sh
flutter analyze
flutter test
```

## Adding a connector repository

In **Profile & Sources**, enter a GitHub repo (e.g. `kas021/AROKI-Connectors`) and tap **Add**. AROKI downloads and verifies the repository index, offers every available connector, and activates the first *active* source automatically.

## Stack

- [Flutter](https://docs.flutter.dev/) + Dart 3
- [`http`](https://pub.dev/packages/http), [`html`](https://pub.dev/packages/html) — networking and parsing
- [`crypto`](https://pub.dev/packages/crypto) — SHA-256 integrity checks
- [`provider`](https://pub.dev/packages/provider) — state management
- [`video_player`](https://pub.dev/packages/video_player) + [`chewie`](https://pub.dev/packages/chewie) — playback
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — local persistence