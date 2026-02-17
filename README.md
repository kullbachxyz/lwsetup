# LibreWolf Hardening Script

Simple script that:

-   Applies **arkenfox user.js** to LibreWolf
-   Appends **LARBS overrides** and dark mode tweaks
-   Forces install of privacy extensions via `policies.json`
-   Locks `resistFingerprinting=false` in `librewolf.cfg` (so dark mode works)
-   Backs up everything it overwrites

## Usage

``` bash
chmod +x librewolf-hardening.sh
./librewolf-hardening.sh
```

Requires `jq`.

## What it does

-   Kills any running LibreWolf instance before applying changes
-   Rebuilds `user.js` with arkenfox + LARBS overrides
-   Patches `librewolf.cfg` with `lockPref` so LibreWolf's own defaults can't re-enable `resistFingerprinting`
-   Updates `policies.json` with:
    -   Decentraleyes
    -   I Still Don't Care About Cookies
    -   uBlock Origin
    -   Vimium

Backups saved with timestamps.

## Notes

-   Don't run as root.
-   LibreWolf must be opened once first so it creates a real profile.
-   Safe to re-run on an existing profile — `user.js` and `policies.json` will be fully updated, and
    arkenfox's `prefsCleaner` will remove any stale prefs left over from previous runs. Bookmarks,
    passwords, extensions, and other profile data are never touched.
