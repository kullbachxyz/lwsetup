# librewolf-hardening

Applies a privacy-focused configuration to the default LibreWolf profile.

- [arkenfox user.js](https://github.com/arkenfox/user.js) as base, with [LARBS overrides](https://github.com/LukeSmithxyz/voidrice) appended
- Dark mode via `resistFingerprinting=false` locked in `librewolf.cfg`
- Privacy extensions force-installed via `policies.json`:
  - [uBlock Origin](https://addons.mozilla.org/firefox/addon/ublock-origin/)
  - [Decentraleyes](https://addons.mozilla.org/firefox/addon/decentraleyes/)
  - [I Still Don't Care About Cookies](https://addons.mozilla.org/firefox/addon/istilldontcareaboutcookies/)
  - [Vimium](https://addons.mozilla.org/firefox/addon/vimium-ff/)

## Usage

```sh
./librewolf-hardening.sh
```

Requires `jq`. Safe to re-run — creates a fresh profile if none exists, runs arkenfox's `prefsCleaner` on existing ones. Bookmarks, passwords, and extensions are never touched. Everything overwritten is backed up with a timestamp.

## Notes

- Do not run as root
- `resistFingerprinting=false` is locked via `lockPref` so LibreWolf's own defaults cannot override it
