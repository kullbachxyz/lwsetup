#!/usr/bin/env bash
#
# librewolf-hardening.sh
# - Apply arkenfox user.js to the default LibreWolf profile
# - Append LARBS overrides and extra tweaks
# - Enforce privacy extensions via policies.json
# - Lock resistFingerprinting=false in librewolf.cfg for dark mode

set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Do not run as root. Uses sudo only where needed." >&2
  exit 1
fi

if ! command -v librewolf >/dev/null 2>&1; then
  echo "LibreWolf not found in PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not found. Install it and rerun." >&2
  exit 1
fi

# -------------------------------
# Helpers
# -------------------------------

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*"
}

# -------------------------------
# Profile setup
# -------------------------------

ARKENFOX_URL="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
PREFS_CLEANER_URL="https://raw.githubusercontent.com/arkenfox/user.js/master/prefsCleaner.sh"
LARBS_URL="https://raw.githubusercontent.com/LukeSmithxyz/voidrice/refs/heads/master/.config/firefox/larbs.js"

PROFILES_DIR="$HOME/.librewolf"
PROFILES_INI="$PROFILES_DIR/profiles.ini"

if [[ ! -f "$PROFILES_INI" ]]; then
  echo "profiles.ini not found at $PROFILES_INI" >&2
  echo "Start LibreWolf once so it creates a profile, then rerun this script." >&2
  exit 1
fi

PROFILE_REL="$(sed -n 's/^Path=\(.*\.default-default\)$/\1/p' "$PROFILES_INI" | head -n 1)"

if [[ -z "$PROFILE_REL" ]]; then
  echo "Could not determine LibreWolf profile (no .default-default path found)." >&2
  exit 1
fi

PROFILE_PATH="$PROFILES_DIR/$PROFILE_REL"

if [[ ! -d "$PROFILE_PATH" ]]; then
  echo "Detected profile path does not exist: $PROFILE_PATH" >&2
  exit 1
fi

log "Using LibreWolf profile: $PROFILE_PATH"

# Kill LibreWolf so changes aren't overwritten on exit
pkill -u "$USER" librewolf >/dev/null 2>&1 && log "Killed running LibreWolf instance." || true

# -------------------------------
# Arkenfox + LARBS user.js setup
# -------------------------------

if [[ -f "$PROFILE_PATH/user.js" ]]; then
  log "Backing up existing user.js..."
  mv "$PROFILE_PATH/user.js" "$PROFILE_PATH/user.js.bak_$(date +%F_%T)"
fi

log "Downloading arkenfox user.js..."
if ! curl -fsSL "$ARKENFOX_URL" -o "$PROFILE_PATH/user.js"; then
  echo "Failed to download arkenfox user.js." >&2
  exit 1
fi

log "Downloading LARBS overrides..."
TMP_LARBS="$(mktemp)"
if curl -fsSL "$LARBS_URL" -o "$TMP_LARBS"; then
  cp "$TMP_LARBS" "$PROFILE_PATH/larbs.js"
  printf '\n\n// ===== LARBS OVERRIDES (appended after arkenfox) =====\n\n' >> "$PROFILE_PATH/user.js"
  cat "$TMP_LARBS" >> "$PROFILE_PATH/user.js"
  log "LARBS overrides appended."
else
  log "Warning: failed to download LARBS overrides; skipping."
fi
rm -f "$TMP_LARBS"

cat >> "$PROFILE_PATH/user.js" << 'EOF'

// ===== DARK MODE / FINGERPRINTING TWEAKS =====
// Allow sites to see prefers-color-scheme while keeping FPP
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.fingerprintingProtection.overrides", "+AllTargets,-CSSPrefersColorScheme");

// ===== UI TWEAKS =====
user_pref("browser.sessionstore.resume_from_crash", true);
user_pref("browser.sessionstore.restore_on_demand", false);
user_pref("browser.sessionstore.restore_tabs_lazily", false);

EOF

log "user.js written to $PROFILE_PATH"

# -------------------------------
# Clean stale prefs from prefs.js (arkenfox prefsCleaner)
# -------------------------------

log "Running arkenfox prefsCleaner to remove stale prefs..."
CLEANER="$PROFILE_PATH/prefsCleaner.sh"
if curl -fsSL "$PREFS_CLEANER_URL" -o "$CLEANER"; then
  chmod +x "$CLEANER"
  # prefsCleaner uses dirname $0 to locate prefs.js, so it must live in the profile dir
  (cd "$PROFILE_PATH" && bash "$CLEANER" -s)
  rm -f "$CLEANER"
  log "prefsCleaner done."
else
  log "Warning: failed to download prefsCleaner.sh; skipping stale pref cleanup."
  rm -f "$CLEANER"
fi

# -------------------------------
# Lock resistFingerprinting in librewolf.cfg
# (user.js can be overridden by LibreWolf defaults; lockPref cannot)
# -------------------------------

LW_CFG="/usr/lib/librewolf/librewolf.cfg"
if [[ -f "$LW_CFG" ]]; then
  if ! grep -q 'lockPref("privacy.resistFingerprinting"' "$LW_CFG" 2>/dev/null; then
    log "Locking resistFingerprinting=false in librewolf.cfg..."
    if grep -q 'defaultPref("privacy.resistFingerprinting"' "$LW_CFG" 2>/dev/null; then
      sudo sed -i 's/defaultPref("privacy.resistFingerprinting".*/lockPref("privacy.resistFingerprinting", false);/' "$LW_CFG"
    else
      printf '\n// Allow dark mode detection\nlockPref("privacy.resistFingerprinting", false);\n' | sudo tee -a "$LW_CFG" >/dev/null
    fi
    log "librewolf.cfg updated."
  else
    log "librewolf.cfg already has lockPref for resistFingerprinting; skipping."
  fi
else
  log "librewolf.cfg not found at $LW_CFG; skipping."
fi

# -------------------------------
# Extension policies
# -------------------------------

POLICY_FILE="/usr/lib/librewolf/distribution/policies.json"

if [[ ! -f "$POLICY_FILE" ]]; then
  log "policies.json not found at $POLICY_FILE; skipping extension policies."
else
  log "Backing up policies.json..."
  sudo cp "$POLICY_FILE" "${POLICY_FILE}.bak_$(date +%F_%T)"

  log "Updating ExtensionSettings in $POLICY_FILE..."
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
    .policies.ExtensionSettings["{d7742d87-e61d-4b78-b8a1-b469842139fa}"] = {
      "install_url": "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi",
      "installation_mode": "normal_installed"
    }
  ' "$POLICY_FILE" | sudo tee "$POLICY_FILE.tmp" >/dev/null
  sudo mv "$POLICY_FILE.tmp" "$POLICY_FILE"
  log "Extension policies updated."
fi

log "Done."
log "  user.js: $PROFILE_PATH/user.js"
log "  Restart LibreWolf, then check about:policies and about:addons."
