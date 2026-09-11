# lain-desktop decisions (citable in plans)

Use these IDs in plans and advisor calls: `DD-001`, etc.
Update this file when the user answers a `needs-user` question.

## Stack and runtime

- `DD-001` — Use Qt 6 Quick/QML for UI, libmpv for playback, and the real server API. No mock data and no browser runtime. Source: `README.md:7`.
- `DD-002` — Requirements are Linux, Qt 6.5+, libmpv headers and pkg-config, CMake 3.21+, and C++17. Source: `README.md:39`.
- `DD-003` — Build with `cmake -S . -B build -G Ninja`, `cmake --build build`, and run `./build/lain`. Source: `README.md:52`.

## Client architecture

- `DD-004` — All HTTP goes through `src/ServerClient.*` using QNetworkAccessManager: session, catalog, search, enrichment, playback plan, progress, and thumbnails. QML never performs HTTP directly. Source: `README.md:96`.
- `DD-005` — Playback uses the direct-play plan from `GET /api/items/{id}/playback`, an authenticated URL, resume from saved position, and bounded progress writes at 10-second intervals plus pause, seek, end, and exit. Source: `README.md:22`.
- `DD-006` — Thumbnails come from the server endpoint `GET /api/items/{id}/thumbnail` as the fallback when poster or cover art is unavailable. Source: `README.md:26`.
- `DD-007` — In-app enrichment offers Auto, NFO, Kitsu, AniList, and Jikan providers; enrich, refresh, and remove operations re-render the UI without restarting. Source: `README.md:29`.
- `DD-008` — The theme follows the live Omarchy palette: background, foreground, accent, urgent, muted, and corner radius. Source: `README.md:32`.

## Testing and discipline

- `DD-009` — Keep the headless `ctest` suite green under `QT_QPA_PLATFORM=offscreen`, with no window opening: the QTest `serverclient` suite and Qt Quick Test `qml` suite. Source: `README.md:34`.
- `DD-010` — Project layout: `src/main.cpp` is the entry point, `src/MpvItem.*` renders libmpv through an OpenGL FBO, `src/OmarchyTheme.*` supplies the palette, `qml/Main.qml` owns the shell and login gate, and views/components live under `qml/`. Source: `README.md:95`.
- `DD-011` — The server lives in `projects/lain` and the client lives here; do not mix their commits. Login, offline, and ready states remain explicit, and HTTP 401 returns to login rather than failing silently. Source: `README.md:14`.

## Product direction

- `DD-012` — Planning covers Lain's complete target state as implementable and verifiable milestones, beginning with a complete first-use journey. Source: interview 2026-09-11.
- `DD-013` — The desktop provides complete server administration to administrators in addition to the consumption experience. Source: interview 2026-09-11.
- `DD-014` — Required desktop/server evolution uses versioned API contracts; each repository keeps its implementation, tests, and commits separate. Source: interview 2026-09-11.
- `DD-015` — Anime, movies, and series have product parity; the committed media scope is personal video, excluding music, audiobooks, photos, and live TV. Source: interview 2026-09-11.
- `DD-016` — The final product is Linux-only and preserves native Omarchy integration. Source: interview 2026-09-11.
- `DD-017` — The local setup wizard detects existing servers and tools and offers only provisioning methods available in the environment (Docker, service, or binary), explains trade-offs, and uses Polkit for privileged actions. Source: interview 2026-09-11.
- `DD-018` — The desktop may start, stop, or update only local servers it provisioned; detected external installations are connection and diagnostic targets only. Source: interview 2026-09-11.
- `DD-019` — After completing first use, stable identity and a correct collection model take priority over advanced playback, automation, or remote access. Source: interview 2026-09-11.
- `DD-020` — All UI strings are internationalizable; PT-BR and English are supported with locale detection and manual selection. Source: interview 2026-09-11.
- `DD-021` — English is the only canonical repository language for code, comments, tests, plans, project documentation, contributor instructions, and wikis in both repositories. Non-English content is limited to explicitly identified translations, localization resources, and language-specific documentation variants. Source: interview 2026-09-11.
- `DD-022` — The Polkit helper allowlist is extended: it may write/enable/start desktop-provisioned systemd user units and owned compose stacks, install the server binary to user paths, fix media directory permissions, and manage Docker for owned instances. No system-path writes outside owned scope. Source: user answer QQ-S3-01, 2026-09-11.
- `DD-023` — When the wizard finds an existing reachable server and local provisioning tools, the default is to connect to the existing server to avoid duplicate servers and data; local provisioning is offered as a secondary path with trade-off explanations. Source: user answer QQ-S3-02, 2026-09-11.
- `DD-024` — Desktop-provisioned ownership is recorded in QSettings plus an on-disk marker/compose label; owned instances support start/stop/update/uninstall/logs while external servers support connect/diagnostics only. Source: user answer QQ-S3-03, 2026-09-11.
- `DD-025` — When the Docker daemon is missing, the wizard offers binary versus user-service fallback only and explains the manual Docker path; it does not offer guided Docker installation. Source: user answer QQ-S3-04, 2026-09-11.
- `DD-026` — Provisioned servers track the latest release with a notify/manual-apply update flow; automatic updates are forbidden. Source: user answer QQ-S3-05, 2026-09-11.
- `DD-027` — Settings uses single scrolling dense sections in order Connection/Libraries/Users/Plugins/Maintenance/Language/Appearance/About, as sections/tables without excessive cards. Source: user answer QQ-S4-01, 2026-09-11.
- `DD-028` — The desktop exposes full server administration to admins (libraries, scan, users, plugins, backup/restore) with explicit confirmation on every destructive action, limited to what the versioned server API supports. Source: user answer QQ-S4-02, 2026-09-11.
- `DD-029` — Media identity v2 uses content/library-based stable IDs that survive move/rename, with an alias/migration map for existing path-derived IDs under a versioned contract. Source: user answer QQ-S4-03, 2026-09-11.
- `DD-030` — Series navigation groups file episodes into a series/season/episode hierarchy with a Specials section. Source: user answer QQ-S4-04, 2026-09-11.
- `DD-031` — Playback auto-resumes saved position and autoplays the next episode; defaults live in Settings/Playback plus a per-series toggle. Source: user answer QQ-S4-05, 2026-09-11.
- `DD-032` — Failed progress writes queue last-position-per-item (persisted, bounded) and flush on reconnect with queued-client-wins. Source: user answer QQ-S5-01, 2026-09-11.
- `DD-033` — Closing hardening is request timeouts/retries, input validation, and log hygiene; permission checks stay frozen at DD-022 and navigation, resume behavior, API compatibility, and the offscreen suite remain untouched. Source: user answer QQ-S5-02, 2026-09-11.
