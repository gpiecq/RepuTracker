# Changelog

## [1.0.0] - 2026-03-06

### Added

- Account-wide reputation tracking across all characters via SavedVariables
- Main window with draggable header and ESC-to-close support
- Minimap button (draggable on minimap edge, position saved)
- Reputation scanning on login (2s delay) and on faction updates (1s throttle)
- Cross-character reputation display grouped by faction name, sorted by header then name
- Character rows showing name (class-colored), level, reputation bar with progress, and standing label
- Text search filter for reputation names
- Standing dropdown filter (All / Hated through Exalted)
- Multi-select reputation dropdown filter with scrollable panel and Clear button
- Filter state persistence between sessions
- ElvUI compatibility (frame skinning, font integration)
- Slash commands: `/rt` (toggle), `/rt reset` (reset data with confirmation)
- Widget pool pattern for efficient scroll content rendering
