# LibreWolf Hardening Script

Simple script that:

-   Applies **arkenfox user.js** to LibreWolf\
-   Appends **LARBS overrides**\
-   Adds UI/fingerprinting tweaks\
-   Forces install of privacy extensions\
-   Backs up everything it overwrites

## Usage

``` bash
chmod +x librewolf-hardening.sh
./librewolf-hardening.sh
```

Requires `jq`.

## What it does

-   Finds your LibreWolf `*.default-default` profile\

-   Rebuilds `user.js` with arkenfox + overrides\

-   Updates `policies.json` with:

    -   Decentraleyes\
    -   I Still Don't Care About Cookies\
    -   uBlock Origin\
    -   Vim Vixen

Backups saved with timestamps.

## Notes

-   Don't run as root.\
-   LibreWolf must be opened once before running.
