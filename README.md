# DistanceCalculator

A macOS menu bar app that calculates driving time from a starting address to any city, using Apple's MapKit routing (traffic-aware, no API key required).

Everything happens inside the dropdown menu — no windows are opened.

## Features

- Lives in the menu bar as a 🚗 icon (no Dock icon)
- **From** box pre-filled, and editable for one-off trips
- **To** box accepts a city name (`Philadelphia`) or a full address
- Traffic-aware drive time and mileage via Apple MapKit, shown in bold in the menu
- Result updates in place while the menu stays open; last result stays visible
- Geocoded addresses are cached for the life of the app

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — for `swiftc` and `clang`
- Internet connection (geocoding and routing use Apple's servers)

## Build

```bash
./build.sh
```

This compiles the Swift app and the C launcher, then assembles `DistanceCalculator.app` in the project root.

## Run

```bash
open DistanceCalculator.app
```

Or launch it from ApplicationManager — it is auto-discovered as `DistanceCalculator`. To install permanently:

```bash
cp -r DistanceCalculator.app /Applications/
```

## Usage

1. Click the 🚗 icon in the menu bar.
2. The **To** box is already focused — type a destination city.
3. Press **Return** or click **Calculate**.
4. The drive time appears in bold below the form, e.g. `To Philadelphia: 1 hr, 26 min (65 mi)`.
5. To use a different starting point, edit the **From** box before calculating (it resets to the default next launch).

Errors (unknown place, no drivable route) appear in the same result line. **Cancel** or Escape closes the menu; **Quit** (⌘Q) exits the app.

The Unix process is named `distancecalc` (`pkill -f distancecalc` to stop it from a terminal); Activity Monitor shows it as **DistanceCalculator**.

## Project layout

| File | Purpose |
|------|---------|
| `DistanceCalculator.swift` | The app: status item, in-menu form, geocoding + ETA via MapKit |
| `launcher.c` | Compiled C launcher; the bundle's executable, spawns the Swift binary |
| `build.sh` | Compiles both binaries and assembles the `.app` bundle |

### Why the launcher spawns instead of exec()ing

When LaunchServices starts the bundle and the registered process replaces itself with `exec()`, macOS never places the status item's window and the menu bar icon stays invisible. The launcher therefore `posix_spawn`s the Swift binary as a child and exits.
