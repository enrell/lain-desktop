# Developer taste — lain-desktop

Edit this freely. The advisor treats it as authoritative over model opinion and web research.

## Principles

- Thin native client: the UI reacts to the real server and never invents data.
- Reliable playback matters more than visual effects.
- The Omarchy theme is identity, not decoration: follow its live palette and radius.
- Keep offscreen tests green; validation must not require opening a window.

## Concrete preferences

- C++ should be Qt-idiomatic and use RAII, without raw `new` where QObject/QML ownership applies. Keep QML declarative and heavy logic in C++ (`ServerClient`, `MpvItem`).
- UX states are explicit (offline, login, ready), HTTP 401 returns to login, and sections without data do not render.
- Use asynchronous debounced search, bounded progress reporting, and simple audio/subtitle pickers.
- Use an editorial and cinematic composition for media discovery; administration, lists, and Settings are dense, utilitarian, and structured as sections or tables without excessive artificial cards.
- Advanced features must explain themselves in the interface: a short primary label plus additional information through a help icon accessible by hover and keyboard focus.
- The wizard adapts choices to the detected environment and explains consequences before installing or changing the system.
- PT-BR and English have complete localization coverage; screens never mix languages accidentally.
- Repository-authored prose is English. Other languages belong only in explicit localization or translated-document variants.
- Use short imperative commit subjects.

## Never decide without the user (examples)

- Change the UI language policy, replace libmpv, or add a heavy native dependency.
- Change navigation, setup/login flow, or resume/progress behavior.
- Break compatibility with the `projects/lain` server API.

## Open

- <!-- Example: card density, shortcut defaults, view order, string tone. -->
