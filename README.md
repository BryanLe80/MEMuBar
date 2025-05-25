# JustAMemBar

A macOS menu bar application that displays real-time memory statistics using XPC services.

## Features

- 📊 Real-time memory usage monitoring
- 🚨 Memory pressure detection (Normal/Warning/Critical)
- 💾 Swap usage tracking
- 🔄 XPC service architecture for secure system access
- 🎯 Clean, minimal menu bar interface

## Architecture

The app uses a two-part architecture:
- **Main App** (`JustAMemBar`): SwiftUI interface that displays memory stats
- **XPC Service** (`MemBarHelper`): Background service that gathers system memory information

This separation provides better security and stability by isolating system-level operations.

## Development

### Quick Start

Use the provided development scripts for easy building and testing:

```bash
# Super quick test (silent build + run)
./test.sh

# Build and run the app with logs
./dev.sh run

# Clean build (when having issues)
./dev.sh clean

# Just show XPC logs
./dev.sh logs

# Check app status
./dev.sh status
```

### Available Scripts

#### `./test.sh` - Quick Test
Super fast build and run for rapid iteration:
- Silent build (no verbose output)
- Automatic app launch
- Perfect for quick testing after code changes

#### `./dev.sh` - Development Helper
Quick shortcuts for common tasks:
- `./dev.sh run` - Build and run the app
- `./dev.sh clean` - Clean build and run
- `./dev.sh logs` - Show XPC communication logs
- `./dev.sh kill` - Kill running app instances
- `./dev.sh status` - Show app status
- `./dev.sh xcode` - Open project in Xcode

#### `./build_and_run.sh` - Full Build Script
Comprehensive build and run script with options:
- `./build_and_run.sh` - Standard build and run
- `./build_and_run.sh --clean` - Clean build
- `./build_and_run.sh --run-only` - Skip build, just run
- `./build_and_run.sh --logs-only` - Show logs only
- `./build_and_run.sh --help` - Show all options

### Manual Building

If you prefer to build manually:

```bash
# Build the project
xcodebuild -project JustAMemBar.xcodeproj -scheme JustAMemBar -configuration Debug build

# Run the app
open ~/Library/Developer/Xcode/DerivedData/JustAMemBar-*/Build/Products/Debug/JustAMemBar.app
```

### Monitoring XPC Communication

To debug XPC communication issues:

```bash
# Show XPC logs in real-time
log stream --predicate 'subsystem CONTAINS "First.JustAMemBar" OR subsystem CONTAINS "First.MemBarHelper"' --level debug --style compact
```

## Project Structure

```
JustAMemBar/
├── JustAMemBar/                    # Main app target
│   ├── ContentView.swift           # Main UI
│   ├── MemBarXPCClient.swift       # XPC client
│   ├── MemBarHelperProtocol.swift  # Shared protocol
│   └── JustAMemBarApp.swift        # App entry point
├── MemBarHelper/                   # XPC service target
│   ├── main.swift                  # XPC service implementation
│   └── Info.plist                  # Service configuration
├── build_and_run.sh               # Build and run script
├── dev.sh                         # Development helper
└── README.md                      # This file
```

## Memory Statistics

The app provides three key metrics:

1. **Memory Pressure**: System memory pressure level
   - Normal: System has adequate memory
   - Warning: Memory is getting low
   - Critical: System is under memory pressure

2. **Memory Used**: Total system memory currently in use
   - Calculated from active, inactive, and wired memory pages

3. **Swap Used**: Amount of swap space being used
   - Indicates when system is using disk for memory overflow

## Troubleshooting

### Build Issues
- Try a clean build: `./dev.sh clean`
- Check that both targets can see the shared protocol file
- Ensure XPC service is properly embedded in the main app

### XPC Communication Issues
- Check logs: `./dev.sh logs`
- Verify service bundle identifier matches in Info.plist
- Ensure proper code signing for both targets

### App Not Responding
- Kill existing instances: `./dev.sh kill`
- Check app status: `./dev.sh status`
- Look for crash logs in Console.app

## Requirements

- macOS 15.4+
- Xcode 16.0+
- Swift 5.0+

## License

This project is for educational purposes. 