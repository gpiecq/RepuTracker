# RepuTracker

**Track and compare reputations across all your characters at a glance.**

RepuTracker is a lightweight World of Warcraft addon for TBC Classic (Anniversary Edition) that scans and displays reputation data from every character on your account in a single unified window.

## Features

- **Account-wide reputation tracking** — Automatically scans and stores reputation data for each character that logs in
- **Cross-character comparison** — View all your characters' standing for any given faction side by side
- **Text search filter** — Quickly find a specific reputation by name
- **Standing filter** — Filter by standing level (Hated, Hostile, Neutral, Friendly, Honored, Revered, Exalted)
- **Reputation multi-select filter** — Pick specific reputations from a scrollable dropdown to narrow the display
- **Minimap button** — Draggable button on the minimap edge to toggle the window
- **Persistent data** — All data and filter settings are saved between sessions via SavedVariables
- **ElvUI compatible** — Automatic frame skinning and font integration when ElvUI is detected

## Usage

- **Left-click** the minimap button to toggle the window
- `/rt` or `/reputracker` — Toggle the window
- `/rt reset` — Reset all saved data (with confirmation)

## Technical Details

| | |
|---|---|
| **Interface** | 20505 (TBC Classic Anniversary) |
| **SavedVariables** | `RepuTrackerDB` (account-wide) |
| **Files** | `Core.lua`, `Data.lua`, `UI.lua` |

### Architecture

- **Core.lua** — Addon namespace, constants (standings, colors, class colors), utility functions, event bus (`RegisterCallback` / `FireCallback`), SavedVariables initialization, slash commands
- **Data.lua** — Reputation scanning (`ScanReputations`), data grouping and filtering (`GetGroupedReputations`), reputation name collection (`GetAllReputationNames`), WoW event handling with throttled `UPDATE_FACTION` (1s debounce)
- **UI.lua** — Minimap button, main window with drag support, filter bar (search, standing dropdown, reputation multi-select), scrollable display with widget pool pattern, ElvUI compatibility helpers

### Key Events

| Event | Action |
|---|---|
| `ADDON_LOADED` | Initialize SavedVariables, create UI |
| `PLAYER_ENTERING_WORLD` | Delayed reputation scan (2s) |
| `UPDATE_FACTION` | Throttled re-scan (1s debounce) |
| `DATA_UPDATED` | Refresh display |
| `FILTER_CHANGED` | Refresh display |
| `TOGGLE_WINDOW` | Show/hide main window |

## Installation

1. Download or clone this repository
2. Copy the `RepuTracker` folder into your `World of Warcraft\_anniversary_\Interface\AddOns\` directory
3. Restart WoW or `/reload`
