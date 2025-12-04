#!/bin/bash
#
# librewolf-hardening.sh
# - Apply arkenfox user.js to the default LibreWolf profile
# - Append LARBS overrides and extra tweaks
# - Enforce privacy extensions via policies.json

# 
# NOTE: Need to find replacement for VimVixen as it breakes some websites. Sadly it is unmaintanined currently...
#

# -------------------------------
# Safety checks
# -------------------------------
if [ "$EUID" -eq 0 ]; then
    echo "Please DO NOT run this script as root."
    echo "Run it as your normal user; it will use sudo only where needed."
    exit 1
fi

# -------------------------------
# Arkenfox + LARBS user.js setup
# -------------------------------

# URLs for latest configs
ARKENFOX_URL="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
LARBS_URL="https://raw.githubusercontent.com/LukeSmithxyz/voidrice/refs/heads/master/.config/firefox/larbs.js"

PROFILES_DIR="$HOME/.librewolf"
PROFILES_INI="$PROFILES_DIR/profiles.ini"

if [ ! -f "$PROFILES_INI" ]; then
    echo "profiles.ini not found at $PROFILES_INI"
    echo "Start LibreWolf once so it creates a profile, then rerun this script."
    exit 1
fi

# Get the profile whose Path ends with .default-default
PROFILE_REL="$(sed -n 's/^Path=\(.*\.default-default\)$/\1/p' "$PROFILES_INI" | head -n 1)"

if [ -z "$PROFILE_REL" ]; then
    echo "Could not determine LibreWolf profile (no .default-default path found)."
    exit 1
fi

PROFILE_PATH="$PROFILES_DIR/$PROFILE_REL"

if [ ! -d "$PROFILE_PATH" ]; then
    echo "Detected profile path does not exist: $PROFILE_PATH"
    exit 1
fi

echo "Using LibreWolf profile: $PROFILE_PATH"

# Backup existing user.js if it exists
if [ -f "$PROFILE_PATH/user.js" ]; then
    echo "Backing up existing user.js..."
    mv "$PROFILE_PATH/user.js" "$PROFILE_PATH/user.js.bak_$(date +%F_%T)"
fi

# Download arkenfox to user.js
echo "Downloading arkenfox user.js..."
if ! curl -fsSL "$ARKENFOX_URL" -o "$PROFILE_PATH/user.js"; then
    echo "Failed to download arkenfox user.js"
    exit 1
fi

echo "Arkenfox user.js applied to $PROFILE_PATH"

# Download larbs.js to a temp file
TMP_LARBS="$(mktemp)"
echo "Downloading larbs.js overrides..."
if ! curl -fsSL "$LARBS_URL" -o "$TMP_LARBS"; then
    echo "Failed to download larbs.js"
    rm -f "$TMP_LARBS"
    exit 1
fi

# (Optional) Save a copy of larbs.js in the profile for reference
cp "$TMP_LARBS" "$PROFILE_PATH/larbs.js"

# Append larbs.js to user.js so its prefs override arkenfox
echo -e "\n\n// ===== LARBS OVERRIDES (appended after arkenfox) =====\n" >> "$PROFILE_PATH/user.js"
cat "$TMP_LARBS" >> "$PROFILE_PATH/user.js"

# Clean up temp file
rm -f "$TMP_LARBS"

# Append dark-mode / fingerprinting tweaks
cat >> "$PROFILE_PATH/user.js" << 'EOF'

// ===== DARK MODE FINGERPRINTING TWEAKS =====
// Allow sites to see prefers-color-scheme while keeping FPP
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.fingerprintingProtection.overrides", "+AllTargets,-CSSPrefersColorScheme");

// ===== UI TWEAKS =====
// Never show the bookmarks toolbar
user_pref("browser.toolbars.bookmarks.visibility", "never");

EOF

echo "larbs.js overrides and extra tweaks appended to $PROFILE_PATH/user.js"

# -------------------------------
# Extension policies setup
# -------------------------------

POLICY_FILE="/usr/lib/librewolf/distribution/policies.json"

# Check jq
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to edit $POLICY_FILE but was not found."
    echo "Install jq (e.g. sudo pacman -S jq / sudo apt install jq) and rerun the script."
    exit 1
fi

if [ ! -f "$POLICY_FILE" ]; then
    echo "policies.json not found at $POLICY_FILE"
    echo "Skipping extension policy configuration."
else
    echo "Using policies file: $POLICY_FILE"

    # Backup existing policies.json
    BACKUP="${POLICY_FILE}.bak_$(date +%F_%T)"
    echo "Backing up existing policies.json to:"
    echo "  $BACKUP"
    sudo cp "$POLICY_FILE" "$BACKUP"

    echo "Updating ExtensionSettings in $POLICY_FILE..."

    sudo jq '
      .policies.ExtensionSettings = (.policies.ExtensionSettings // {}) |
      .policies.ExtensionSettings["jid1-BoFifL9Vbdl2zQ@jetpack"] = {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/decentraleyes/latest.xpi",
        "installation_mode": "normal_installed"
      } |
      .policies.ExtensionSettings["idcac-pub@guus.ninja"] = {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/istilldontcareaboutcookies/latest.xpi",
        "installation_mode": "normal_installed"
      } |
      .policies.ExtensionSettings["uBlock0@raymondhill.net"] = {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "installation_mode": "normal_installed"
      } |
      .policies.ExtensionSettings["vim-vixen@i-beam.org"] = {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/vim-vixen/latest.xpi",
        "installation_mode": "normal_installed"
      }
    ' "$POLICY_FILE" | sudo tee "$POLICY_FILE.tmp" > /dev/null

    sudo mv "$POLICY_FILE.tmp" "$POLICY_FILE"
    echo "Extension policies updated."
fi

echo
echo "All done."
echo "- user.js hardened in: $PROFILE_PATH"
echo "- If policies.json existed, forced extensions are now configured."
echo "Restart LibreWolf, then check about:policies (Active) and about:addons."
