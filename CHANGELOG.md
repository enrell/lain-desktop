# Changelog

All notable changes to the Lain desktop client are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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
