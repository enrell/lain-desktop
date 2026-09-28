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

## Visual QA loop (mandatory for layout/UI work)

`verify()`-style tests do not see pixels. Any task that changes layout,
spacing, colors, or imagery is unfinished until reviewed via screenshot.
Screenshots are expensive context: **one image per iteration, never a
batch**. Follow this protocol strictly.

1. Pick ONE surface, smallest first — a single card/component before the
   page that composes it. Shell order: cards → Hero/MediaRow → views →
   TopBar → Player rail.
2. Produce exactly one PNG for it:
   ```sh
   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR=1 \
     ./build/tests/tst_qml -input tests/qml/tst_shot_<surface>.qml
   ```
   Each `tst_shot_*.qml` mounts the surface inside
   `Rectangle { color: Tokens.bgPrimary; width: 1440 }` (a bare Item grabs
   transparent and renders white) and calls `grabImage(...).save()` into
   `build/shots/<surface>.png`.
3. Read ONLY that PNG. Write the concrete bugs as a bullet list
   (alignment, clipping, overflow, contrast, spacing) before editing.
   Fetch a web reference only when a bug is ambiguous:
   ```sh
   chromium --headless --screenshot=/tmp/web-<surface>.png \
     --window-size=1440,900 <url>
   ```
   At most two images in context at once (QML shot + its web reference).
4. Fix, rebuild, re-shoot, re-read. Repeat until the surface is clean.
5. Move to the next surface. Do not open another surface's PNG while the
   current one is unresolved.

Determinism rules:

- fixed capture width per surface (1440 default; 1920 only when checking
  density); `QT_SCALE_FACTOR=1`; stub-server data only, never a real one;
- `MpvItem` renders nothing under the software backend — judge the player
  by its chrome and episode rail, never by the video area;
- shots live under `build/shots/` and are never committed;
- optional `grabImage(...).equals(baseline)` asserts may be added later,
  but the read-and-fix loop above is the contract for layout changes.

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
