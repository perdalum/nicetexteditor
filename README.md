# NiceTextEditor

NiceTextEditor is a small macOS plain-text editor modelled after TextEdit. It is built with SwiftUI and AppKit’s modern `NSTextView` editing widget.

## Features

- Opens and saves plain-text files.
- Uses the macOS proportional system font, SF Pro, by default.
- Lets you configure the proportional font and editor font size from the toolbar or Settings.
- Lets you configure the full-screen text width as a percentage of the screen width.
- Keeps files as plain text while rendering selected markup regions differently.
- Shows nroff-style verbatim blocks in SF Mono:

```text
This is proportional text.
.VB
This line is shown in SF Mono.
    Indentation is preserved visually.
.VE
Back to proportional text.
```

Only the text between `.VB` and `.VE` is rendered monospace; the marker lines remain normal text and are saved unchanged.

## Requirements

- macOS 14 or later
- Swift 5.9 or later

## Build and run

From the repository root:

```sh
cd nicetexteditor
swift run
```

Build a simple `.app` bundle:

```sh
cd nicetexteditor
make app
open build/NiceTextEditor.app
```

Open the native Xcode project:

```sh
open NiceTextEditor.xcodeproj
```

Or build it from the command line:

```sh
xcodebuild -project NiceTextEditor.xcodeproj -scheme NiceTextEditor build
```

Open a file from the command line:

```sh
cd nicetexteditor
swift run NiceTextEditor /path/to/file.txt
```

## Project layout

```text
Package.swift
Info.plist
Makefile
Sources/NiceTextEditor/
```

## License

MIT. See [LICENSE](LICENSE).
