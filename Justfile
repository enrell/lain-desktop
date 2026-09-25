# Lain desktop task runner. `just` lists recipes; `just <name>` runs one.
# Dev loop: `just run` (rebuild + launch against your server) and give
# feedback. No commits, tags, or pushes without explicit approval.

# List recipes.
default:
    @just --list

# Configure a Release build directory when missing.
configure:
    test -d build || cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Build the desktop binary.
build: configure
    cmake --build build

# Headless suites (no window opens).
test: build
    ctest --test-dir build --output-on-failure

# Rebuild and launch the dev client (uses your saved server + session).
run: build
    ./build/lain

# Print the dev client version.
version: build
    ./build/lain --version

# Install the locally built client over ~/.local/bin (binary, launcher,
# icon). Overwrites an AppImage install of the same files.
install-desktop: build
    install -Dm755 build/lain ~/.local/bin/lain-desktop
    install -Dm644 packaging/lain-desktop.desktop ~/.local/share/applications/lain-desktop.desktop
    install -Dm644 packaging/lain-desktop.png ~/.local/share/icons/hicolor/256x256/apps/lain-desktop.png
    update-desktop-database ~/.local/share/applications || true
