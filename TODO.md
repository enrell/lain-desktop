# Fix TODO (dev loop: change → `just run` / `just up` → feedback)

No commits, tags, or pushes until every item is verified below.

## Player

- [ ] Video orientation: `MpvItem.cpp` flip is now `0` (was `1`, which
  turned every video upside down). Verify with a real video in the dev
  client (`just run`, play Silo) — image must be right-side up.
- [ ] Crash follow-up: the 0.2.0 AppImage segfault did NOT reproduce in a
  local build against the same server and data. Prime suspect remains
  the bundle (only `libqxcb.so` shipped, no Wayland plugin). Confirm
  fixed by the 0.3.0 AppImage once it is reinstalled from a release.

## Enrichment by default

- [ ] Fresh items auto-enrich with the Auto provider after catalog load
  (sequential, toggle in Settings/Maintenance, explicit removals stay
  removed). Verify: rescan/add a file, overlay appears without manual
  enrich.
- [ ] Non-admin behavior: enrich POST is admin-only server-side, so the
  chain no-ops after one attempt per item for regular users. Confirm no
  error spam in that case.

## Library folder picker (web)

- [ ] `GET /api/browse` lists server folders with media-root
  auto-detection (admin-only). Verify in Settings → Libraries → Add
  library: picker opens on the detected root, Up/navigate works,
  "Use this folder" fills path + name.
- [ ] Typing `/media/video/Animes` (singular) must be unpickable — only
  real directories are listed, so the typo class from the screenshot
  cannot happen through the picker.

## Enrichment that just happens (server default)

- [x] Scans auto-enrich every overlay-less item (NFO/local first,
  remote merge after; failures never fail the scan; no cap).
- [ ] Verify on the dev server: fresh scan enriches Silo/Darling rows
  (titles, posters, years) with zero manual enrich clicks.
- [ ] Verify the web Home feature block (backdrop + Continue pill).

## Web shell like the reference (uncommitted, e2e green)

- [x] Replace the desktop sidebar with the user-selected clean Monolith
  top navigation; preserve category links, search, account and status.
- [x] Build the user-selected hybrid Home: title-first Monolith hero plus
  familiar horizontal Continue, Recently Added and per-library rails;
  restrained cinematic motion honors reduced-motion.
- [x] e2e adapted (topbar submit, overlay-aware enrich flow, public
  Omarchy palette assertion) and green.
- [ ] Deliberately omitted (no backends exist): My Lists, Downloads,
  Discover sections; mobile nav unchanged.
- [x] Keep the WebUI in Svelte and bridge the server host's validated
  Omarchy palette through public `GET /api/theme`; CSS semantic tokens
  refresh every 3 seconds and fall back safely outside Omarchy.
- [ ] Verify live theming at `:5173`: switch Omarchy themes while the page
  stays open; background, surfaces, text, accent and status colors update.
- [ ] Visually verify the production Monolith + Nocturne hybrid at `:5173`
  with the real library artwork and report any desired scale/density tweaks.

## Build / packaging

- [ ] CI stays on `ubuntu-24.04` (newest LTS). Rationale: AppImages must
  build against an older libc to run everywhere; an Arch-built bundle
  would break on Debian/Ubuntu/Fedora targets. Wayland plugins are now
  seeded explicitly and a headless smoke boot fails the release on
  packaging crashes.
- [ ] Verify the 0.3.0 AppImage carries
  `usr/plugins/platforms/libqwayland-*.so` and boots natively on Wayland
  (no `Could not find the Qt platform plugin "wayland"` line).

## Dev loop (this file's workflow)

- [ ] `just up` (server repo): dev stack on :9360 + web HMR on :5173.
- [ ] `just run` (desktop repo): dev client against the dev server.
- [ ] `just install-desktop`: overwrites the AppImage install with the
  local build when a system-wide install is needed for feedback.
