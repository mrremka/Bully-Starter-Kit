# Changelog

## 0.4.0

- Promoted the tested beta.10 installation core to the first stable release.
- Redesigned the main WPF interface into a cleaner two-column Bullworth dashboard with stronger hierarchy, compact mod cards, clearer install state and a dedicated stable badge.
- Added a polished post-install success window with a one-click **Launch Bully** action.
- Nexus API keys are no longer required for the public flow: Stable defaults to the official Nexus browser-assisted Manual/Slow Download workflow and validates each selected ZIP before installation.
- Personal Nexus API keys remain available only as an optional advanced/testing path.
- Preserved the working direct-ZIP installers for Essential Fixes and One Percent Better from beta.10.
- Refreshed RU/EN copy, GitHub branding, release documentation and stable release validation.

## 0.4.0-beta.10

- Essential Fixes no longer depends on the literal `To Scripts` folder name. Folder labels are normalized, so spaces, underscores, dashes, wrapper names and recommendation suffixes are supported.
- Added a conservative fallback that detects installable `.lur` files directly while excluding `Compiled`, `Source` and `Optional` copies.
- Improved Essential Fixes diagnostics: unknown layouts log up to 30 archive entries instead of failing with a misleading folder-only error.
- Updated RU/EN error text to describe the actual missing script files.

## 0.4.0-beta.9

- Essential Fixes now uses a dedicated direct-ZIP installer instead of the generic extraction pipeline.
- Only files beneath `Main/To Scripts` are written to `Scripts`; `Optional` is written to the game root and `default.idb` is always excluded.
- Wrapper folders inside the Nexus archive are supported automatically.
- Added per-component install counts to the log and hardened directory creation with .NET APIs.

## v0.4.0

### Release UI polish
- Исправлена типографика: Segoe UI, ClearType, без синтетического Black weight.
- Добавлен анимированный переключатель **Auto / Slow Download**.
- Auto использует Nexus API/Premium; Slow Download использует официальный бесплатный поток.
- При 403 или отсутствующем ключе Auto безопасно переключается на Slow Download.
-beta.8

- One Percent Better now uses a dedicated installer path: the Main ZIP is opened directly and only `gsa_info.dat` is copied to `Graphics`, matching the mod author's documented installation method.
- The graphics mod no longer uses the generic ZIP extraction pipeline.
- One Percent Better is now treated as an optional component: download/install failures can be skipped without rolling back SilentPatch and Essential Fixes.
- Install manifest records One Percent Better only when it was actually installed.
- Fixed release metadata/version drift and added stronger version consistency checks.


## 0.4.0-beta.7

- Fixed Windows PowerShell 5.1 extraction crash caused by invalid `New-Item -LiteralPath` usage.
- Directory creation during ZIP extraction now uses `System.IO.Directory.CreateDirectory`, which handles literal paths safely without PowerShell wildcard parsing.
- Added regression check forbidding `New-Item ... -LiteralPath` in the installer.

## v0.4.0-beta.7

- Исправлен сбой `GetFullPath(...): Данный формат пути не поддерживается` при распаковке некоторых официальных Nexus ZIP.
- ZIP-пути теперь сначала нормализуются и проверяются по сегментам, а только потом передаются Windows Path API.
- Абсолютные пути, `..` и попытки выхода из временной папки по-прежнему жёстко блокируются.
- Файлы с именами, которые Windows физически не может создать (например, с запрещёнными символами, зарезервированными именами или завершающей точкой/пробелом), безопасно пропускаются с записью в журнал вместо падения всей установки.
- Добавлена обработка `ArgumentException`, `NotSupportedException` и `PathTooLongException` на уровне отдельной записи ZIP.
- Усилена релизная проверка ZIP-extraction guard, чтобы регрессия не вернулась.

## v0.4.0-beta.5

- Исправлена ложная ошибка «ZIP не похож на нужный архив» для официального архива Essential Fixes.
- Проверка Nexus ZIP теперь учитывает несколько вариантов структуры архива и официальный Nexus-суффикс mod ID в имени файла.
- Установка Essential Fixes теперь распознаёт `To Scripts` и совместимые варианты `Scripts`, не завязываясь на одно точное имя папки.
- При неизвестной структуре установщик пишет в журнал образец файлов архива, чтобы следующий несовместимый релиз можно было диагностировать без гаданий.
- Сохранена строгая проверка ZIP и защита от path traversal.

## v0.4.0-beta.4

- Исправлена ошибка `403 Forbidden` для бесплатных аккаунтов Nexus Mods.
- Premium/доступные direct-download запросы по-прежнему скачиваются автоматически.
- Для Nexus Free добавлен официальный assisted flow: открывается конкретная страница файла, пользователь нажимает Slow Download, Starter Kit автоматически подхватывает ZIP из «Загрузок».
- Добавлена ручная кнопка выбора ZIP, если браузер сохраняет в другую папку.
- Перед установкой архив проверяется по содержимому, чтобы случайно не выбрать другой ZIP.
- Ошибка 403 больше не запускает бессмысленный rollback до изменения файлов игры.
- Добавлена документация RU/EN по ограничениям Nexus Free.

## v0.4.0-beta.3

- Fixed Windows 10 CMD launcher parsing by shipping `Start_BullyStarterKit.bat` as strict ASCII with CRLF line endings.
- Removed `chcp 65001` and all non-ASCII text from the launcher.
- Launcher now calls Windows PowerShell 5.1 using its absolute System32 path.
- Language-switch restart now calls the current Windows PowerShell executable via `$PSHOME`.
- Added release validation for BAT encoding/line endings and forbidden non-ASCII launcher bytes.
- Added `.gitattributes` so Git/GitHub preserve CRLF for Windows launch scripts.
- CI now executes the batch launcher in `--launcher-test` mode using real `cmd.exe`.


## 0.4.0-beta.2

- Fixed startup crash in localized string formatting caused by the PowerShell automatic `$Args` variable / `String.Format` overload binding.
- Routed all localized formatted strings through one safe `LF` helper using PowerShell's `-f` operator.
- Preserved the outer install exception when rollback itself throws.
- Fixed RU/EN launcher console encoding (`UTF-8`) and preserved the real installer exit code.
- Fixed UI language relaunch when the project path contains spaces or Cyrillic characters.
- Added localization format-string validation to CI so malformed `{0}` / `{1}` placeholders fail validation before release.


## 0.4.0-beta.1

- Added complete **Russian / English localization** for the installer through `locales/ru.json` and `locales/en.json`.
- Russian Windows UI is detected automatically; RU/EN can also be switched manually.
- Added a separate final prompt asking whether the user wants to enable **Russian in Bully itself**.
- Steam localization activation uses the game's built-in language data (`12200_install.vdf`, language code `1049`) and is included in backup/rollback.
- Added Russian-first GitHub documentation with an English mirror (`README.md` / `README_EN.md`).
- Added Russian publishing and localization documentation.
- Improved Steam library auto-detection, including additional Steam library folders.
- Hardened archive extraction against ZIP path traversal.
- Hardened file writes and rollback so installer-managed paths stay inside the selected Bully directory.
- Download metadata is now stored in the user's app-data folder rather than the repository working tree.
- Added validation for RU/EN locale key parity and installer locale references.
- Stable GitHub release tags are intentionally blocked until public Nexus authentication is configured; beta/RC tags remain available for testing.
- Refreshed the RU interface preview and versioned branding assets.

## 0.3.0

- Completely redesigned the WPF interface with Bully Starter Kit branding.
- Added step-based setup cards, mod cards, install progress and a collapsible log.
- Added application icon and GitHub branding assets.
- Rebuilt README with a hero banner, UI preview, badges and clearer project documentation.
- Added GitHub social-preview artwork.
- Added contribution, security, issue and pull-request templates.
- Release workflow now packages branding assets and publishes a SHA-256 checksum.

## 0.2.0

- Added automatic Nexus Mods downloads through the official Nexus API v3.
- Added one-click **DOWNLOAD + INSTALL** workflow.
- Added encrypted local storage for a testing/personal Nexus API key using Windows DPAPI.
- Removed the old manual ZIP-selection workflow from the default path.
- Added automatic resolution of the latest active Nexus file/version.
- Added explicit author/source credits in README and THIRD_PARTY.
- Added public-release Nexus registration guide.
- Kept automatic backups and clean rollback tracking.
- Kept default FPS limit at 60 and mild vanilla+ graphics philosophy.

## 0.1.0

- Initial GitHub-ready installer prototype.