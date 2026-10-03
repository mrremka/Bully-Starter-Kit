# Nexus Mods and the public release

Bully Starter Kit v0.4.0 exposes two Nexus download modes directly in the UI.

## Auto

- uses the Nexus API to resolve the current file;
- downloads directly when Nexus permits it;
- intended for Premium + API key;
- if Nexus returns `403` or no key is available, Starter Kit automatically switches to Slow Download.

## Slow Download

- requires no API key;
- opens the official Nexus page for the required mod;
- the user clicks **Manual Download → Slow Download**;
- Starter Kit watches Downloads, validates the ZIP, and continues setup.

Both modes use official sources only. The project does not bypass Nexus restrictions and does not mirror third-party mod archives in GitHub Releases.
