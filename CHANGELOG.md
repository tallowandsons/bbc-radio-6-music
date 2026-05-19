# Changelog

## 0.0.5

### Added
- Menu bar can now display the current show instead of the track (e.g. "Lauren Laverne 10:00–13:00") — configurable in Preferences
- "Show in menu bar" preference replaces the old on/off toggle: choose between Now playing, Current show, or Nothing

## 0.0.4

### Fixed
- Released binary is now a universal binary, supporting both Apple Silicon and Intel Macs

## 0.0.3

### Added
- GitHub releases workflow — tagged versions are built and published automatically

## 0.0.2

### Added
- Volume control in Preferences
- Preferences window with Last.fm setup, playback options
- Left click to pause / play (configurable)
- Right-click context menu with Now Playing, Play/Pause, Preferences, Quit
- Pause badge on menu bar icon when stream is paused
- App icon for Finder / Launchpad
- Enable/disable scrobbling independently of having API credentials

### Fixed
- Last.fm scrobbling no longer runs when the stream is paused
- Last track in a listening session is now correctly scrobbled on pause
- Moved Last.fm session key out of Keychain to avoid unsigned-app access prompt

## 0.0.1

### Added
- Live stream of BBC Radio 6 Music (320kbps HLS)
- Now Playing metadata from BBC API shown in menu bar
- Media key support (play/pause)
- Last.fm scrobbling via OAuth
