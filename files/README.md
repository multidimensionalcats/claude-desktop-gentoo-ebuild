# Claude Desktop for Gentoo Linux

This is an unofficial Gentoo ebuild for Claude Desktop, Anthropic's AI assistant application. Since Anthropic doesn't provide official Linux builds, this package extracts and adapts the Windows version for Linux.

## What This Package Does

1. **Downloads** the official Windows installer
2. **Extracts** the application from the Windows executable
3. **Bundles** a modern Electron runtime (v31.0.0)
4. **Replaces** Windows-specific native modules with Linux-compatible stubs
5. **Packages** everything as a proper Gentoo package

## Installation

### Prerequisites
- Active internet connection (downloads Electron during build)
- Node.js with npm support: `emerge net-libs/nodejs[npm]`

### Install from Local Overlay

1. Create a local overlay:
   ```bash
   sudo eselect repository create local
   ```

2. Create the package directory:
   ```bash
   sudo mkdir -p /var/db/repos/local/app-misc/claude-desktop
   ```

3. Copy the ebuild:
   ```bash
   sudo cp claude-desktop-0.9.1.ebuild /var/db/repos/local/app-misc/claude-desktop/
   ```

4. Generate manifest:
   ```bash
   cd /var/db/repos/local/app-misc/claude-desktop
   sudo ebuild claude-desktop-0.9.1.ebuild manifest
   ```

5. Install:
   ```bash
   sudo emerge app-misc/claude-desktop
   ```

### USE Flags

- `wayland` - Enable Wayland support (automatically detected at runtime)

## Usage

### Basic Usage
```bash
claude-desktop                 # Normal launch
claude-desktop --no-sandbox   # Launch without sandbox (less secure)
```

### Configuration

- **MCP Configuration**: `~/.config/Claude/claude_desktop_config.json`
- **Application Data**: `~/.config/Claude/`

### OAuth Login Setup

If Google/OAuth login hangs, ensure the protocol handler is registered:
```bash
xdg-mime default claude-desktop.desktop x-scheme-handler/claude
update-desktop-database
```

## Features

- ✅ Full Claude AI assistant functionality
- ✅ MCP (Model Context Protocol) support  
- ✅ Native desktop integration
- ✅ Automatic Wayland/X11 detection
- ✅ System tray integration
- ✅ Keyboard shortcuts (Ctrl+Alt+Space)

## Technical Details

### Architecture
This package works by:
- Extracting the cross-platform Electron app from Windows installer
- Replacing Windows-specific `claude-native` module with stub implementation
- Bundling compatible Electron runtime instead of using ancient system version
- Setting up proper permissions and desktop integration

### Dependencies
The bundled Electron requires standard Linux desktop libraries:
- GTK+3, Cairo, Pango for UI rendering
- ALSA for audio, Mesa for graphics  
- X11 or Wayland display server
- D-Bus, cups, NSS for system integration

### File Locations
- **Application**: `/usr/lib/claude-desktop/`
- **Launcher**: `/usr/bin/claude-desktop`
- **Desktop Entry**: `/usr/share/applications/claude-desktop.desktop`
- **Icons**: `/usr/share/icons/hicolor/*/apps/claude-desktop.png`

## Troubleshooting

### Common Issues

**Application won't start:**
- Run `claude-desktop` from terminal to see error messages
- Check that all dependencies are installed
- Try `claude-desktop --no-sandbox` as last resort

**OAuth login hangs:**
- Register protocol handler: `xdg-mime default claude-desktop.desktop x-scheme-handler/claude`
- Check default browser settings
- Ensure network connectivity

**Permission errors:**
- Chrome sandbox needs SUID: `/usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox`
- Should be automatically set by package, but can be fixed manually:
  ```bash
  sudo chown root:root /usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox
  sudo chmod 4755 /usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox
  ```

**Build failures:**
- Ensure network access during emerge
- Check that Node.js has npm support: `emerge -1 net-libs/nodejs[npm]`
- Retry if npm downloads fail (network issues)

### Debug Information
Run with debug output:
```bash
ELECTRON_ENABLE_LOGGING=1 claude-desktop
```

## Security Notes

- This package bundles a complete Electron runtime
- Electron sandbox is enabled by default (recommended)
- Uses SUID permissions on chrome-sandbox (standard for Electron apps)
- Network access required during build for npm downloads

## Legal

- **Claude Desktop**: Proprietary software by Anthropic, subject to their Terms of Service
- **This Ebuild**: Provided as-is for educational purposes
- **Electron**: MIT licensed, bundled during build

## Credits

Based on successful Linux packaging work by:
- [k3d3's claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) (NixOS)
- [aaddrick/claude-desktop-arch](https://github.com/aaddrick/claude-desktop-arch) (Arch Linux)
- [Various Debian/Ubuntu builders](https://github.com/aaddrick/claude-desktop-debian)

Adapted for Gentoo Linux with proper ebuild practices and dependency management.
