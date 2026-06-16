# Changelog

All notable changes to NiceTextEditor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses informal semantic versioning while pre-1.0.

## [0.1.0] - 2026-06-13

### Added

- Initial SwiftUI macOS plain-text editor application.
- TextEdit-like editing surface backed by AppKit `NSTextView`.
- Open, new, save, and save-as support for plain-text files.
- Configurable proportional editor font and font size.
- Default proportional rendering using the macOS system font, SF Pro.
- Nroff-like `.VB` / `.VE` verbatim block rendering using SF Mono while preserving the original plain text.
- Settings window for editor font configuration.
- Makefile target to build a simple `.app` bundle.
- Plain-text document type metadata in `Info.plist`.
- Configurable full-screen text width as a percentage of screen width.
- Native Xcode project with a shared `NiceTextEditor` scheme.
- MPW/BBEdit-style UNIX worksheet support with one background `/bin/zsh` process per document.
- Configurable worksheet shortcuts for running a selection, replacing a selection with pipeline output, and inserting pipeline output after a selection.
- Worksheet menu command for resetting the active document shell.
- Application Support `WorksheetStartup.zsh` file for worksheet shell PATH, zsh functions, aliases, exports, and options.
- Settings button to reveal the worksheet startup file in Finder.
