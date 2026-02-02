# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AppToDmg is a macOS SwiftUI application that converts .app bundles into shareable .dmg installer files. The app uses native Apple frameworks only with no external dependencies.

## Build Commands

```bash
# Build the project
xcodebuild -project AppToDmg.xcodeproj -scheme AppToDmg -configuration Debug build

# Build for release
xcodebuild -project AppToDmg.xcodeproj -scheme AppToDmg -configuration Release build

# Clean build
xcodebuild -project AppToDmg.xcodeproj -scheme AppToDmg clean
```

## Architecture

- **AppToDmgApp.swift**: Main app entry point using SwiftUI's `@main` and `WindowGroup`
- **ContentView.swift**: Primary UI view (currently placeholder, needs implementation)

The app runs in a sandboxed environment with read-only access to user-selected files. DMG creation will likely require invoking `hdiutil` via Process/NSTask.

## Configuration

- **Bundle ID**: com.nhershy.AppToDmg
- **Deployment Target**: macOS 26.2+
- **Signing**: Automatic with hardened runtime enabled
- **Sandbox**: Enabled with user-selected file read access
