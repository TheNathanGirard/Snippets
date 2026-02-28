#!/bin/bash
# =============================================================================
# Gnome Desktop Customization Script for Ubuntu 24.04
# =============================================================================
# This script will:
#   1. Backup existing Gnome settings
#   2. Install Gnome Shell Extension tools
#   3. Install Dash to Dock extension
#   4. Install Apps Menu extension
#   5. Apply a custom Gnome settings configuration
# =============================================================================

set -euo pipefail

# ----- Colors ----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
header() { echo -e "\n${CYAN}=== $* ===${NC}"; }

# ----- Sanity checks ---------------------------------------------------------
[[ "$EUID" -eq 0 ]] && error "Do NOT run this script as root. Run as your regular user."
command -v gnome-shell &>/dev/null || error "Gnome Shell not found. Is this a Gnome desktop session?"

GNOME_VERSION=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
log "Detected Gnome Shell major version: ${GNOME_VERSION}"

# =============================================================================
# STEP 1 — Backup Gnome Settings
# =============================================================================
header "STEP 1: Backing Up Gnome Settings"

BACKUP_DIR="$HOME/.gnome-backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

log "Exporting dconf settings to ${BACKUP_DIR}/dconf-backup.ini ..."
dconf dump / > "$BACKUP_DIR/dconf-backup.ini"

log "Copying gsettings schemas list ..."
gsettings list-schemas > "$BACKUP_DIR/gsettings-schemas.txt"

# Backup current enabled extensions list
gsettings get org.gnome.shell enabled-extensions > "$BACKUP_DIR/enabled-extensions.txt" 2>/dev/null || true

log "Backup complete → ${BACKUP_DIR}"
echo ""
echo "  To restore later, run:"
echo "    dconf load / < ${BACKUP_DIR}/dconf-backup.ini"
echo ""

# =============================================================================
# STEP 2 — Install Gnome Extension Tools
# =============================================================================
header "STEP 2: Installing Gnome Extension Tools"

log "Updating apt package list ..."
sudo apt-get update -qq

log "Installing gnome-shell-extensions, gnome-tweaks, gnome-shell-extension-manager ..."
sudo apt-get install -y \
    gnome-shell-extensions \
    gnome-tweaks \
    gnome-shell-extension-manager \
    curl \
    jq \
    unzip

log "Installing GNOME Extensions CLI (gnome-extensions-cli) via pip ..."
pip install --user gnome-extensions-cli --break-system-packages 2>/dev/null || \
    warn "pip install of gnome-extensions-cli failed (optional, continuing)."

# Helper: install extension via GNOME Extensions website API
install_extension_by_uuid() {
    local UUID="$1"
    local NAME="$2"

    header "Installing Extension: ${NAME} (${UUID})"

    # Check if already installed
    if gnome-extensions list | grep -q "^${UUID}$"; then
        log "${NAME} is already installed."
        gnome-extensions enable "${UUID}" || warn "Could not enable ${UUID} (may need a shell restart)."
        return 0
    fi

    # Fetch extension metadata from extensions.gnome.org
    local API_URL="https://extensions.gnome.org/extension-query/?uuid=${UUID}"
    local META
    META=$(curl -s "https://extensions.gnome.org/extension-query/?uuid=${UUID}" 2>/dev/null) || {
        warn "Network unavailable — skipping download of ${NAME}."
        return 1
    }

    local EXT_ID
    EXT_ID=$(echo "$META" | jq -r '.extensions[0].pk // empty')

    if [[ -z "$EXT_ID" ]]; then
        warn "Could not find extension ID for ${UUID}. Skipping."
        return 1
    fi

    local SHELL_VER
    SHELL_VER=$(gnome-shell --version | awk '{print $3}')

    local DOWNLOAD_URL="https://extensions.gnome.org/download-extension/${UUID}.shell-extension.zip?shell_version=${SHELL_VER}"

    local TMP_ZIP
    TMP_ZIP=$(mktemp /tmp/gnome-ext-XXXXXX.zip)

    log "Downloading ${NAME} for Gnome ${SHELL_VER} ..."
    curl -sL "$DOWNLOAD_URL" -o "$TMP_ZIP" || {
        warn "Download failed for ${NAME}."
        rm -f "$TMP_ZIP"
        return 1
    }

    local INSTALL_DIR="$HOME/.local/share/gnome-shell/extensions/${UUID}"
    mkdir -p "$INSTALL_DIR"
    unzip -qo "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"

    log "Installed ${NAME} to ${INSTALL_DIR}"

    # Compile schemas if present
    if [[ -d "${INSTALL_DIR}/schemas" ]]; then
        glib-compile-schemas "${INSTALL_DIR}/schemas/" 2>/dev/null || true
    fi

    # Enable the extension
    gnome-extensions enable "${UUID}" 2>/dev/null || \
        warn "Could not enable ${UUID} now — it will be enabled after Gnome Shell restarts."

    log "${NAME} installation complete."
}

# =============================================================================
# STEP 3 — Install Dash to Dock
# =============================================================================
header "STEP 3: Dash to Dock"

DASH_TO_DOCK_UUID="dash-to-dock@micxgx.gmail.com"
install_extension_by_uuid "$DASH_TO_DOCK_UUID" "Dash to Dock"

# =============================================================================
# STEP 4 — Install Apps Menu
# =============================================================================
header "STEP 4: Apps Menu"

APPS_MENU_UUID="apps-menu@gnome-shell-extensions.gcampax.github.com"
install_extension_by_uuid "$APPS_MENU_UUID" "Apps Menu"

# =============================================================================
# STEP 5 — Apply Custom Gnome Settings
# =============================================================================
header "STEP 5: Applying Custom Gnome Settings"

log "Applying interface & theme settings ..."

# ---- Appearance -------------------------------------------------------------
# Use Adwaita-dark theme (built-in, always available)
gsettings set org.gnome.desktop.interface gtk-theme        'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme     'prefer-dark'
gsettings set org.gnome.desktop.interface icon-theme       'Adwaita'
gsettings set org.gnome.desktop.interface cursor-theme     'Adwaita'

# ---- Fonts ------------------------------------------------------------------
gsettings set org.gnome.desktop.interface font-name        'Ubuntu 11'
gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 13'
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
gsettings set org.gnome.desktop.interface font-hinting    'slight'

# ---- Desktop ----------------------------------------------------------------
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.background show-desktop-icons false 2>/dev/null || true

# ---- Workspaces -------------------------------------------------------------
gsettings set org.gnome.mutter dynamic-workspaces         true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# ---- Window Manager ---------------------------------------------------------
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.desktop.wm.preferences focus-mode   'click'
gsettings set org.gnome.mutter center-new-windows           true

# ---- Taskbar / Top Bar ------------------------------------------------------
gsettings set org.gnome.desktop.interface clock-show-weekday true
gsettings set org.gnome.desktop.interface clock-show-seconds false
gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true

# ---- Touchpad ---------------------------------------------------------------
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click  true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true

# ---- Night Light (blue light filter) ----------------------------------------
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled    true
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 3700

# ---- Power ------------------------------------------------------------------
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type      'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900

# ---- File Manager (Nautilus) ------------------------------------------------
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view'
gsettings set org.gnome.nautilus.icon-view default-zoom-level      'standard'
gsettings set org.gnome.nautilus.preferences show-hidden-files      false

# ---- Dash to Dock Settings (applied after extension is enabled) -------------
if gnome-extensions list | grep -q "^${DASH_TO_DOCK_UUID}$"; then
    log "Configuring Dash to Dock ..."
    DOCK_SCHEMA="org.gnome.shell.extensions.dash-to-dock"

    gsettings set "$DOCK_SCHEMA" dock-position       'BOTTOM'   2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" extend-height        false      2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" dock-fixed           false      2>/dev/null || true  # auto-hide
    gsettings set "$DOCK_SCHEMA" autohide             true       2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" intellihide          true       2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" dash-max-icon-size   48         2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" show-trash           true       2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" show-mounts          true       2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" transparency-mode    'FIXED'    2>/dev/null || true
    gsettings set "$DOCK_SCHEMA" background-opacity   0.7        2>/dev/null || true
    log "Dash to Dock configured."
else
    warn "Dash to Dock not yet active — dock settings will apply after shell restart."
fi

# ---- Enable Extensions in Shell ---------------------------------------------
log "Ensuring extensions are enabled in Gnome Shell ..."
CURRENT_EXTS=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null | tr -d "[]'" | tr ',' '\n' | sed 's/^ //;s/ $//' | grep -v '^$' || true)

add_extension_to_enabled() {
    local UUID="$1"
    if ! echo "$CURRENT_EXTS" | grep -qF "$UUID"; then
        CURRENT_EXTS="${CURRENT_EXTS}"$'\n'"${UUID}"
    fi
}

add_extension_to_enabled "$DASH_TO_DOCK_UUID"
add_extension_to_enabled "$APPS_MENU_UUID"

# Rebuild the gsettings array string
NEW_EXTS_ARRAY=$(echo "$CURRENT_EXTS" | grep -v '^$' | sed "s/^/'/;s/$/'/" | paste -sd ',' -)
gsettings set org.gnome.shell enabled-extensions "[${NEW_EXTS_ARRAY}]" 2>/dev/null || \
    warn "Could not update enabled-extensions via gsettings (try after restart)."

# =============================================================================
# Done
# =============================================================================
header "All Done!"

echo ""
log "Summary of changes:"
echo "  ✔  Gnome settings backed up to: ${BACKUP_DIR}"
echo "  ✔  Gnome tools installed (gnome-tweaks, extension-manager)"
echo "  ✔  Dash to Dock extension installed/enabled"
echo "  ✔  Apps Menu extension installed/enabled"
echo "  ✔  Custom Gnome settings applied (dark theme, fonts, dock, night light, etc.)"
echo ""
warn "Some extension changes require a Gnome Shell restart to take full effect."
echo "  • On Wayland (default in Ubuntu 24.04): Log out and log back in."
echo "  • On X11: Press Alt+F2, type 'r', press Enter."
echo ""
log "To restore original settings at any time:"
echo "    dconf load / < ${BACKUP_DIR}/dconf-backup.ini"
echo ""