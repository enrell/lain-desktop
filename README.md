# lain-desktop

[![CI](https://github.com/enrell/lain-desktop/actions/workflows/ci.yml/badge.svg)](https://github.com/enrell/lain-desktop/actions/workflows/ci.yml)
[![Release](https://github.com/enrell/lain-desktop/actions/workflows/release.yml/badge.svg)](https://github.com/enrell/lain-desktop/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

The native desktop client for [Lain](https://github.com/enrell/lain), the
local-first media server. Qt 6 Quick/QML for the interface, libmpv for
playback, and the real server API — no embedded mock data, no browser
runtime.

## Features

- **First-run setup and login.** Server URL, admin creation, persisted
  session; offline/login/ready states are explicit, 401s return you to
  login instead of failing silently.
- **Library browsing.** Home hero + continue watching + recently added,
  movies/shows grids with server-side genres and sorting, collections
  derived from enrichment genres, async search with debounce, detail
  pages with artwork and enrichment (sections without data simply do
  not render).
- **Playback with resume.** Direct-play plans from
  `GET /api/items/{id}/playback`; authenticated stream URL; resume from
  saved position; progress written in bounded windows (10 s + pause,
  seek, end, exit); audio/subtitle track pickers, volume, shaders.
- **Server thumbnails.** Cards and detail fall back to
  `GET /api/items/{id}/thumbnail` (ffmpeg-extracted and disk-cached on
  the server) when there is no poster/cover yet.
- **Metadata enrichment in-app.** Admins pick a provider (Auto, NFO,
  Kitsu, AniList, Jikan), enrich/refresh/remove overlays, and the UI
  re-renders from the new overlay without a restart.
- **Theme-native.** Follows the Omarchy palette live (background,
  foreground, accent, urgent, muted, corner radius).
- **Headless test suite.** Qt Quick Test + QTest under `ctest` with
  `QT_QPA_PLATFORM=offscreen`; no window ever opens.

## Requirements

Linux with Qt **6.5+** and libmpv (headers + pkg-config), plus CMake
3.21+ and a C++17 compiler.

| Distro | Packages |
| --- | --- |
| Arch | `base-devel cmake ninja qt6-base qt6-declarative mpv` |
| Debian/Ubuntu | `build-essential cmake ninja-build qt6-base-dev qt6-declarative-dev qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts libmpv-dev` |
| Fedora | `cmake ninja-build qt6-qtbase-devel qt6-qtdeclarative-devel mpv-libs-devel` |

## Build & run

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/lain
```

On first run, point it at your server (default
`http://127.0.0.1:9360`), create the admin account if the server is
fresh, and sign in. The server must be running; see the
[server quickstart](https://github.com/enrell/lain#install).

## Tests

```sh
cmake -S . -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

Two suites run offscreen under `ctest`:

- `serverclient` — 13 QTest cases for the HTTP client against a stub
  gateway (login/setup states, catalog and enrichment normalization,
  search, playback plan + resume URL, progress writes, expired token,
  metadata providers, enrich/remove, thumbnail URL).
- `qml` — Qt Quick Test suites for `LoginView` (real mouse clicks),
  `HomeView`, `DetailView`, `SearchOverlay` and the playback API,
  driven by the real `ServerClient` against the same stub.

## Install

- Interactive Linux installer (server + desktop, all combinations):
  see the [server README](https://github.com/enrell/lain#interactive-linux-installer).
- Release AppImages: [Releases](https://github.com/enrell/lain-desktop/releases)
  publish `lain-desktop_<version>_linux_x86_64.AppImage` with a
  `.sha256` sidecar. Qt and libmpv/FFmpeg are bundled; run it directly
  (`chmod +x` then `./lain-desktop_*.AppImage`). If FUSE is unavailable,
  `./lain-desktop_*.AppImage --appimage-extract-and-run` works anywhere.
  Bundled libraries keep their own licenses (Qt LGPL-3.0, libmpv/FFmpeg
  GPL-2.0-or-later); sources are linked from the release notes.

## Layout

```text
src/main.cpp         app entry, context properties (server, omarchy, buildTs)
src/ServerClient.*   QNetworkAccessManager client: session, catalog, search,
                     enrichment, playback plan, progress, thumbnails
src/MpvItem.*        libmpv render API (OpenGL FBO), tracks, shaders, stop/end
src/OmarchyTheme.*   live Omarchy palette + corner radius
qml/Main.qml         shell: navigation, routing, shortcuts, login gate
qml/views/           Login, Home, Library, Detail, Collections, Player,
                     SearchOverlay, Settings
qml/components/      Hero, cards, rows, seek bar, player buttons, header
qml/theme/           design tokens + formatting helpers
tests/               stub gateway, QTest and Qt Quick Test suites
```

## License

Apache-2.0. See [LICENSE](LICENSE).
