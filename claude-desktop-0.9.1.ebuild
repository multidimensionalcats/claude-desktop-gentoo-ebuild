# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Claude Desktop - AI assistant application by Anthropic (unofficial Linux build)"
HOMEPAGE="https://claude.ai"

# Downloads the official Windows installer and adapts it for Linux
SRC_URI="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe -> claude-setup-${PV}-x64.exe"

LICENSE="Anthropic-ToS"
SLOT="0"
KEYWORDS="~amd64"
IUSE="wayland"

# Runtime dependencies for the bundled Electron
RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxshmfence
	x11-libs/libXScrnSaver
	x11-libs/pango
	wayland? (
		dev-libs/wayland
		x11-libs/libxkbcommon
	)
"

# Build dependencies
BDEPEND="
	app-arch/p7zip
	media-gfx/icoutils
	net-libs/nodejs[npm]
"

S="${WORKDIR}"

# Network access needed for npm, binary downloads, no source mirroring
RESTRICT="mirror strip network-sandbox"

# Pre-built binaries from the bundled Electron
QA_PREBUILT="
	usr/lib/claude-desktop/node_modules/electron/dist/electron
	usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox
	usr/lib/claude-desktop/node_modules/electron/dist/chrome_crashpad_handler
	usr/lib/claude-desktop/node_modules/electron/dist/libEGL.so
	usr/lib/claude-desktop/node_modules/electron/dist/libGLESv2.so
	usr/lib/claude-desktop/node_modules/electron/dist/libffmpeg.so
	usr/lib/claude-desktop/node_modules/electron/dist/libvk_swiftshader.so
	usr/lib/claude-desktop/node_modules/electron/dist/libvulkan.so.1
"

src_unpack() {
	mkdir -p "${S}/build" || die "Failed to create build directory"

	cd "${S}/build" || die

	# Extract the Windows installer using p7zip
	einfo "Extracting Windows installer..."
	7z x "${DISTDIR}/claude-setup-${PV}-x64.exe" || die "Failed to extract installer"

	# Find and extract the embedded NuGet package
	local nupkg_file=$(find . -name "AnthropicClaude*-full.nupkg" | head -1)
	if [[ -z "${nupkg_file}" ]]; then
		die "Could not find AnthropicClaude nupkg file"
	fi
	
	einfo "Extracting application package: ${nupkg_file}"
	7z x "${nupkg_file}" || die "Failed to extract nupkg"
}

src_prepare() {
	default

	cd "${S}/build/lib/net45" || die "Could not find application directory"

	if [[ ! -f "resources/app.asar" ]]; then
		die "Could not find app.asar - application structure unexpected"
	fi

	# Install modern Electron and asar tools locally (like Arch package does)
	einfo "Installing local Electron and asar tools..."
	export NPM_CONFIG_CACHE="${S}/.npm-cache"
	export NPM_CONFIG_PROGRESS=false
	export NPM_CONFIG_LOGLEVEL=warn
	
	local attempt=1
	local max_attempts=3
	while [[ ${attempt} -le ${max_attempts} ]]; do
		einfo "Attempt ${attempt}/${max_attempts} to install electron and asar"
		if npm install electron@31.0.0 asar; then
			break
		elif [[ ${attempt} -lt ${max_attempts} ]]; then
			ewarn "npm install failed, retrying in 10 seconds..."
			sleep 10
			((attempt++))
		else
			die "Failed to install electron and asar after ${max_attempts} attempts"
		fi
	done

	# Extract app.asar to modify Windows-specific components
	einfo "Extracting app.asar for Linux compatibility modifications..."
	npx asar extract resources/app.asar resources/app.asar.unpacked.edit || die "Failed to extract app.asar"

	# Replace Windows-specific native module with Linux-compatible stub
	local native_module_dir="resources/app.asar.unpacked.edit/node_modules/claude-native"
	if [[ -d "${native_module_dir}" ]]; then
		einfo "Replacing claude-native module with Linux stub implementation"
		cat > "${native_module_dir}/index.js" <<-EOF || die "Failed to create native module stub"
// Linux stub implementation for claude-native module
// Provides compatible API for Windows-specific functionality
module.exports = {
  getAllWindows: () => [],
  getActiveWindow: () => null,
  getAllDisplays: () => [{ id: 0, bounds: { x: 0, y: 0, width: 1920, height: 1080 } }],
  getWindowBounds: () => ({ x: 0, y: 0, width: 800, height: 600 }),
  setWindowBounds: () => {},
  captureScreen: () => null,
  simulateMouseClick: () => {},
  simulateKeyPress: () => {},
  simulateKeyboardInput: () => {},
  getMousePosition: () => ({ x: 0, y: 0 }),
  setMousePosition: () => {},
  KeyboardKey: {
    // Common keyboard key constants
    Enter: 13, Space: 32, Tab: 9, Escape: 27,
    ArrowUp: 38, ArrowDown: 40, ArrowLeft: 37, ArrowRight: 39
  }
};
EOF
	else
		ewarn "Could not find claude-native module directory - application may not work correctly"
	fi

	# Copy internationalization files into app.asar structure
	einfo "Copying i18n files into app.asar structure..."
	mkdir -p resources/app.asar.unpacked.edit/resources/i18n || die "Failed to create i18n directory"
	cp resources/*.json resources/app.asar.unpacked.edit/resources/i18n/ 2>/dev/null || \
		ewarn "Could not copy i18n files - some language features may not work"

	# Repack the modified app.asar
	einfo "Repacking modified app.asar..."
	npx asar pack resources/app.asar.unpacked.edit resources/app.asar || die "Failed to repack app.asar"

	# Extract application icons if tools are available
	if command -v wrestool >/dev/null 2>&1 && command -v icotool >/dev/null 2>&1; then
		einfo "Extracting application icons..."
		wrestool -x -t 14 "${DISTDIR}/claude-setup-${PV}-x64.exe" > claude.ico 2>/dev/null || \
			ewarn "Could not extract icons from installer"
		if [[ -f claude.ico ]]; then
			icotool -x claude.ico || ewarn "Could not convert extracted icons"
		fi
	fi
}

src_install() {
	cd "${S}/build/lib/net45" || die

	local install_dir="/usr/lib/claude-desktop"
	
	# Install application resources
	einfo "Installing application files..."
	insinto "${install_dir}"
	doins -r resources/
	
	# Install bundled Electron runtime
	doins -r node_modules/
	
	# Set executable permissions on Electron binaries
	fperms +x "${install_dir}/node_modules/electron/dist/electron"
	fperms +x "${install_dir}/node_modules/electron/dist/chrome_crashpad_handler"
	if [[ -f "node_modules/electron/dist/chrome-sandbox" ]]; then
		fperms +x "${install_dir}/node_modules/electron/dist/chrome-sandbox"
	fi
	
	# Create launcher script
	einfo "Creating launcher script..."
	cat > "${T}/claude-desktop" <<-EOF || die "Failed to create launcher script"
#!/bin/bash
# Claude Desktop launcher script
# Launches Claude Desktop using bundled Electron runtime

# Application paths
CLAUDE_DIR="/usr/lib/claude-desktop"
ELECTRON_EXEC="\${CLAUDE_DIR}/node_modules/electron/dist/electron"

# Electron environment
export ELECTRON_IS_DEV=0

# Wayland support - automatically detected
ELECTRON_ARGS=()
if [[ "\${XDG_SESSION_TYPE}" == "wayland" ]]; then
	ELECTRON_ARGS+=(
		"--enable-features=UseOzonePlatform,WaylandWindowDecorations"
		"--ozone-platform=wayland"
	)
fi

# Launch Claude Desktop
cd "\${CLAUDE_DIR}" || {
	echo "Error: Could not find Claude Desktop installation" >&2
	exit 1
}

exec "\${ELECTRON_EXEC}" "\${ELECTRON_ARGS[@]}" "\${CLAUDE_DIR}/resources/app.asar" "\$@"
EOF

	exeinto /usr/bin
	doexe "${T}/claude-desktop"

	# Install desktop entry with protocol handling
	make_desktop_entry \
		"claude-desktop %u" \
		"Claude Desktop" \
		"claude-desktop" \
		"Development;Chat;Office;" \
		"MimeType=x-scheme-handler/claude;\nStartupWMClass=Claude\nStartupNotify=true\nComment=AI assistant by Anthropic"

	# Install extracted icons or create fallback
	local icon_installed=false
	for icon_file in claude_*_*.png; do
		if [[ -f "${icon_file}" ]]; then
			local icon_size=$(echo "${icon_file}" | sed 's/.*_\([0-9]*\)_.*/\1/')
			if [[ "${icon_size}" =~ ^[0-9]+$ ]] && [[ "${icon_size}" -ge 16 ]] && [[ "${icon_size}" -le 512 ]]; then
				newicon -s "${icon_size}" "${icon_file}" claude-desktop.png
				icon_installed=true
			fi
		fi
	done

	# Install fallback icon if extraction failed
	if [[ "${icon_installed}" == "false" ]]; then
		einfo "Creating fallback application icon..."
		cat > "${T}/claude-desktop.svg" <<-EOF || die "Failed to create fallback icon"
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" fill="#2563eb" rx="8"/>
  <text x="32" y="40" font-family="Arial" font-size="24" fill="white" text-anchor="middle">C</text>
</svg>
EOF
		doicon "${T}/claude-desktop.svg"
	fi

	# Install documentation
	newdoc "${FILESDIR}/README.md" README.md 2>/dev/null || true
}

pkg_postinst() {
	xdg_pkg_postinst

	# Configure Electron sandbox (critical for security and functionality)
	local sandbox_path="${EROOT}/usr/lib/claude-desktop/node_modules/electron/dist/chrome-sandbox"
	if [[ -f "${sandbox_path}" ]]; then
		einfo "Configuring Electron sandbox permissions..."
		chown root:root "${sandbox_path}" || ewarn "Could not change ownership of chrome-sandbox"
		chmod 4755 "${sandbox_path}" || ewarn "Could not set SUID permissions on chrome-sandbox"
	fi

	# Register protocol handler
	einfo "Updating desktop database for protocol handling..."

	elog ""
	elog "Claude Desktop has been successfully installed!"
	elog ""
	elog "This is an unofficial Linux build that extracts and adapts the"
	elog "official Windows version using a bundled Electron runtime and"
	elog "Linux-compatible stubs for Windows-specific functionality."
	elog ""
	elog "Usage:"
	elog "  claude-desktop                 # Launch the application"
	elog "  claude-desktop --no-sandbox   # Launch without sandbox (less secure)"
	elog ""
	elog "Features:"
	elog "  • Full Claude AI assistant functionality"
	elog "  • MCP (Model Context Protocol) support"
	elog "  • Native desktop integration"
	elog "  • Automatic Wayland detection and support"
	elog ""
	elog "Configuration:"
	elog "  MCP settings: ~/.config/Claude/claude_desktop_config.json"
	elog "  Application data: ~/.config/Claude/"
	elog ""
	elog "Troubleshooting:"
	elog "  • Run from terminal to see debug output"
	elog "  • Check that all dependencies are installed"
	elog "  • For OAuth login issues, ensure claude:// protocol is registered:"
	elog "    xdg-mime default claude-desktop.desktop x-scheme-handler/claude"
	elog ""
	if use wayland; then
		elog "Wayland support is enabled and will be automatically detected."
	else
		elog "For Wayland support, rebuild with USE=wayland"
	fi
	elog ""
	elog "Note: This package downloads and bundles Electron during build."
	elog "      Network access is required during emerge."
}
