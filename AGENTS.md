# lain-desktop — Agent Instructions

Read this file before touching code. Native Qt 6 Quick/QML client for
the Lain server, libmpv playback, real server API only.

## Stack (do not change without explicit user instruction)

- Qt 6.5+ Quick/QML + C++17, CMake 3.21+ Ninja, libmpv (headers + pkg-config).
- All HTTP through `src/ServerClient.*` (QNetworkAccessManager). QML never calls HTTP directly.
- Playback: direct-play plan from `GET /api/items/{id}/playback`, authenticated URL, resume saved position, bounded progress writes (10s + pause/seek/end/exit).
- Thumbnails from server `GET /api/items/{id}/thumbnail`; enrichment overlays (Auto, NFO, Kitsu, AniList, Jikan) re-render without restart.
- Theme follows live Omarchy palette. States offline/login/ready explicit; 401 returns to login, never silent fail.
- Tests headless: `ctest` with `QT_QPA_PLATFORM=offscreen` (`serverclient` + `qml` suites). Must stay green.

## Commands

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/lain
ctest --test-dir build --output-on-failure
```

## Commit discipline

Short imperative subjects. This repo is the client; the server lives in
`projects/lain`. Do not mix them.

## Repository language

- English is the canonical language for source code, comments, tests, plans,
  project documentation, contributor instructions, and the advisor wiki.
- Other languages are allowed only in explicitly identified translations,
  localization resources, or language-specific documentation variants.
- User-facing text must be translatable; do not hard-code a second language in
  source files as a substitute for localization.

## Advisor protocol (mandatory for long tasks)

An `advisor` subagent owns project direction. It reads
`docs/advisor/decisions.md` (citable `DD-XXX`), `docs/advisor/taste.md`,
`docs/advisor/open-questions.md`, plus this file and `README.md`.
It has no edit/shell rights; it only answers. Web is for external
technical facts, never overrides the wiki.

The executor (you) MUST call it via the `subagent` tool with
`agent: advisor` when any of these appear:

- direction/scope doubt, conflict between decisions, irreversible or
  permanent-cost choice (native dependency, playback engine swap, public
  behavior, navigation/login/resume flow change)
- need for external validation before an important change
- anything listed in `docs/advisor/taste.md` as never-decide-alone

Call format: objective + current plan + specific questions (max 5) +
relevant file paths. Load skill `advisor-triage` output contract and
obey it: `answered` cite `DD-XXX` and proceed; `needs-user` append the
row to `docs/advisor/open-questions.md` and STOP that slice until the
user answers. Plans MUST cite decisions (`DD-001`, ...) for every
load-bearing choice.
