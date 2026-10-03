<p align="center">
  <img src="assets/github-header.svg" alt="Bully Starter Kit" width="100%" />
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-v0.4.0-F6C945?style=for-the-badge&labelColor=17191F" />
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-F6C945?style=for-the-badge&labelColor=17191F" />
  <img alt="Languages" src="https://img.shields.io/badge/UI-RU%20%7C%20EN-F6C945?style=for-the-badge&labelColor=17191F" />
  <img alt="Status" src="https://img.shields.io/badge/status-release-F6C945?style=for-the-badge&labelColor=17191F" />
  <img alt="License" src="https://img.shields.io/badge/installer-MIT-F6C945?style=for-the-badge&labelColor=17191F" />
</p>

<p align="center">
  <b>One launch. Vanilla+ feel. Modern fixes.</b><br/>
  A starter installer for <b>Bully: Scholarship Edition (PC)</b> with stability fixes, 60 FPS, mild visuals and optional Russian game localization.
</p>

<p align="center"><a href="README.md">🇷🇺 Русский</a> · <b>🇬🇧 English</b></p>

> [!IMPORTANT]
> **Bully Starter Kit is an unofficial community project.** It does not include Bully and does not mirror Nexus-hosted archives. Third-party mods are fetched from original sources with visible author/source credits.

> [!TIP]
> **The release has two Nexus download modes.** **Auto** uses the Nexus API and direct Premium downloads; **Slow Download** uses the official free Nexus browser flow with no required API key. You can switch modes directly in the UI.

## ✦ Included setup

| Component | Author | Purpose | Original source |
|---|---|---|---|
| **SilentPatch for Bully** | CookiePLMonster | Stability, memory/crash fixes, FPS limiter | [GitHub](https://github.com/CookiePLMonster/SilentPatchBully) |
| **Razc01na's Essential Fixes & Improvements** | Razc01na | Mission/softlock fixes and 60 FPS compatibility | [Nexus Mods](https://www.nexusmods.com/bullyscholarshipedition/mods/396) |
| **One Percent Better Project — Main** | SimonBestia | Mild vanilla-friendly lighting/shadow polish | [Nexus Mods](https://www.nexusmods.com/bullyscholarshipedition/mods/148) |
| **Russian for Bully** | built into the game | Russian UI/subtitles; English voice acting | [Details](docs/RUSSIAN_LANGUAGE_EN.md) |

Full third-party credits: **[THIRD_PARTY.md](THIRD_PARTY.md)**.

> [!NOTE]
> **Essential Fixes is now installed directly from its ZIP.** Starter Kit reads only `Main/To Scripts` and `Optional`, so unrelated archive layout no longer affects installation; `default.idb` is never copied.

> **One Percent Better is optional.** The installer only takes `gsa_info.dat` from its official Main ZIP and copies it to `Graphics`. If the visual mod fails, you can continue with the core stability/fix setup instead of rolling everything back.

## ✦ RU / EN interface

<p align="center"><img src="assets/app-preview.svg" alt="Bully Starter Kit UI preview" width="100%" /></p>

The app auto-selects Russian on a Russian Windows UI and provides a **RU / EN** switch. UI strings live in `locales/ru.json` and `locales/en.json`.

## ✦ Quick start

1. Install **Bully: Scholarship Edition (PC)**; version **1.200** is recommended for the classic PC build.
2. Extract the latest Starter Kit release.
3. Run **`Start_BullyStarterKit.bat`**.
4. The app normally auto-detects Steam/Rockstar installs, including extra Steam libraries. Otherwise select the folder containing **`Bully.exe`** manually.
5. Keep the recommended preset and click **INSTALL STARTER KIT**.
6. Choose **Auto** or **Slow Download**. In Slow mode, Starter Kit opens the official Nexus page and automatically picks up the ZIP after your click.
7. At the very end the installer asks whether to **enable Russian in Bully itself**. Choose Yes or No.
8. After a successful install, use **Launch Bully** on the completion screen.

> [!TIP]
> **60 FPS** is the recommended default. A timestamped backup is created before changes, and a failed installation attempt is rolled back automatically.

## ✦ Russian game localization

Starter Kit does **not** download or redistribute a third-party translation. For Steam it activates the game's built-in Russian localization through the language code used by the PC build. UI/subtitles become Russian while voice acting remains English. Other editions are handled conservatively and receive guidance instead of unsafe file edits.

See **[docs/RUSSIAN_LANGUAGE_EN.md](docs/RUSSIAN_LANGUAGE_EN.md)**.

## ✦ Safety and rollback

- Timestamped backup before file replacement.
- Newly added files tracked for clean rollback.
- Automatic rollback if installation fails.
- ZIP validation and retry logic for downloads.
- Unsafe archive paths are blocked before extraction, and destination paths are constrained to the selected Bully folder.
- SHA-256 recorded for downloaded archives.
- Optional Nexus key storage through Windows DPAPI for the current user.

## ✦ Two Nexus download modes

Starter Kit does not bypass Nexus restrictions and exposes two clear modes:

- **Auto** — Starter Kit resolves the current file through the Nexus API and downloads it directly. Direct downloads require Premium and an API key.
- **Slow Download** — the official free Nexus flow: the app opens the correct page, the user clicks **Manual Download → Slow Download**, and the ZIP is detected and validated automatically.
- If **Auto** receives `403` or no key is available, the UI smoothly switches to **Slow Download** and setup continues through the official website.
- Saved API keys are protected with Windows DPAPI for the current user.

See **[docs/NEXUS_PUBLIC_RELEASE_EN.md](docs/NEXUS_PUBLIC_RELEASE_EN.md)**.

## ✦ Validation

Windows CI validates PowerShell syntax, JSON files, matching RU/EN locale keys, project version consistency and required release files before packaging.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Project.ps1
```

## ✦ Repository layout

```text
Bully-Starter-Kit/
├─ assets/
├─ locales/
├─ docs/
├─ scripts/
├─ src/
├─ .github/
├─ mods.json
├─ Start_BullyStarterKit.bat
├─ README.md
├─ THIRD_PARTY.md
└─ LICENSE
```

Contributing: **[CONTRIBUTING.md](CONTRIBUTING.md)** / **[CONTRIBUTING_RU.md](CONTRIBUTING_RU.md)**.

---
<p align="center"><sub>Installer code is MIT licensed. Bully and third-party mods belong to their respective rights holders/authors.</sub></p>

## 🆓 Nexus Free and Premium

Starter Kit handles both account types:

- **Auto:** direct Nexus API flow, intended for Premium with a saved API key.
- **Slow Download:** official free browser flow with no required API key.
- **Free:** choosing Auto may return `403`; Starter Kit automatically switches to Slow Download and continues through the official website.

This intentionally does not bypass Nexus restrictions. See [`docs/NEXUS_FREE_ACCOUNTS_EN.md`](docs/NEXUS_FREE_ACCOUNTS_EN.md).
