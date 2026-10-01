# Changelog

All notable changes to the Lain desktop client are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Web parity (DD-037): Settings adopts the web rail (YOU: Profile,
  Playback, Connections, Security, Desktop; SERVER: Libraries, Users,
  Transcoding, Integrations, Plugins, Backup) with hairline rows,
  `g`-chords and `[`/`]` section cycling.
- Profile: display name, bio, avatar upload, initials or one of eight
  mascots; avatars appear in the header, account menu and Users.
- Security: change password with automatic session re-mint.
- Connections and My list: link AniList (redirect or pin code), sync,
  scrobble, disconnect, and browse the unified list by type and status.
- Admin: server folder picker when adding libraries, scan diagnostics
  per root, per-user playback limits, AniList OAuth integration, full
  transcoding settings with staged save and live sessions, and a web
  style plugin Replace dialog.
- Ctrl+K command palette over actions, pages, every settings row and
  library titles; web account menu; scanning indicator; toasts.
- Home: Next up, Continue reading and Read next rows, plus the web's
  "no library" / "not scanned" empty states with admin actions.
- Item page: Reset progress and admin Delete file.
- Comic and manga reader with reading direction, two-page spreads and
  web-compatible progress.
- Default and per-library-type Anime4K effect applied at playback start.

### Fixed
- Release builds no longer crash in the accent palette on newer Qt.
- Visual-QA shots create `build/shots/` and sign in when run alone.
- PT-BR covers every interface string again.

## [0.3.0] - 2026-09-11

### Added
- Desktop self-update: Settings/About checks the latest release and
  applies AppImage updates with checksum verification and launcher
  icon refresh. Manual apply only, restart to take effect.
- `--version` and `--help` flags.

### Fixed
- AppImage ships native Wayland platform plugins instead of forcing
  XWayland through a foreign GL stack.
- Release packaging runs a headless smoke boot that fails the build
  on packaging crashes.
- Confirmation dialog no longer anchors inside layouts.

## [0.2.0] - 2026-09-11

### Added
- Complete PT-BR localization: English sources with a PT-BR dictionary,
  system-locale detection, and manual selection in Settings.
- First-run provisioning wizard: detects an existing server and local
  Docker/systemd tooling, defaults to connecting, and provisions new
  local servers via Docker Compose, systemd user service, or binary.
- Owned-only lifecycle: start, stop, update, and uninstall for
  desktop-provisioned installations; external servers stay
  connect-and-diagnose only. Privileged media fixes go through Polkit.
- Full server administration in Settings: libraries, users, plugin
  composition (reorder/swap with generation-conflict review), library
  scan, database backup download, and maintenance status.
- Series navigation: series/season/episode hierarchy with a Specials
  section for unnumbered items.
- Playback defaults: auto-resume, autoplay next episode, and per-series
  autoplay overrides in Settings/Playback.
- Offline progress queue: failed writes persist bounded per item and
  flush with client-wins on reconnect, with a queued-count indicator.
- Hardening: transfer timeouts, one GET retry on transport errors, and
  client-side input validation mirroring server rules.

### Fixed
- Installed launcher now carries `Icon=lain-desktop`, the Lain display
  name, and matching `StartupWMClass`.
- Catalog loading pages through the full collection instead of stopping
  at 500 items.
- `PATCH` requests (user disable/role/password) are sent as PATCH
  instead of falling through to GET.

## [0.1.0] - 2026-09-10

- Initial public release: native Qt Quick client with libmpv playback,
  direct-play plans, enrichment overlays, Omarchy live theme, and
  headless `ctest` suites.
