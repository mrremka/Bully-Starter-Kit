# Contributing to Bully Starter Kit

Thanks for helping improve the project.

## Before opening a pull request

- Keep the default preset close to the original Bully experience.
- Do not commit or mirror third-party mod archives unless their license/author explicitly permits redistribution.
- Add official source and author information for every new third-party component.
- Preserve automatic backup/rollback behavior for every file the installer changes.
- Avoid storing API keys, cookies, tokens or credentials in code, logs, screenshots or fixtures.

## Code changes

The installer targets Windows PowerShell 5.1+ and WPF. Try to keep new code compatible with Windows 10 and Windows 11.

For installer changes, test at least these paths when possible:

1. Clean install.
2. Install over an existing Starter Kit setup.
3. Failed download / invalid Nexus credentials.
4. Restore latest backup.

## Visual changes

Use the existing graphite + school-yellow identity. Keep contrast high, spacing consistent and the main install path obvious.
