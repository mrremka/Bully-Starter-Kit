# Сторонние компоненты и авторы / Third-party credits

Bully Starter Kit — установщик/загрузчик. Он не присваивает себе сторонние моды и по умолчанию не хранит их архивы в репозитории.

## SilentPatch for Bully

- Автор / Author: **CookiePLMonster**
- Оригинальный проект / Project: https://github.com/CookiePLMonster/SilentPatchBully
- В Starter Kit: скачивается во время установки из официального GitHub Release.

## Razc01na's Essential Fixes & Improvements

- Автор оригинала / Original creator: **Razc01na**
- Uploader сохранённой версии на Nexus: **mrnickson01**
- Страница мода: https://www.nexusmods.com/bullyscholarshipedition/mods/396
- Профиль uploader: https://www.nexusmods.com/profile/mrnickson01
- В Starter Kit: актуальный архив определяется и скачивается с официальной Nexus-страницы; в репозиторий не коммитится.
- Установка Starter Kit следует рекомендованной структуре мода: `Main/To Scripts` → `Scripts`, содержимое `Optional` → корень игры, `default.idb` исключается.

## One Percent Better Project

- Автор / Author: **SimonBestia**
- Страница мода: https://www.nexusmods.com/bullyscholarshipedition/mods/148
- Профиль автора: https://www.nexusmods.com/profile/SimonBestia
- В Starter Kit: скачивается с оригинальной Nexus-страницы; архив не зеркалируется в GitHub Releases.
- По умолчанию используется только **One Percent Better Mod Main** — лёгкая правка освещения, максимально близкая к vanilla.
- Установщик не распаковывает весь архив: он читает только `gsa_info.dat` из официального Main ZIP и копирует его в `Graphics`, в соответствии с инструкцией автора.
- Компонент считается необязательным: его сбой не обязан откатывать основные фиксы.
- Starter Kit намеренно не включает Optional-пакет с крупными заменами текстур/моделей в стартовый пресет.

## Русский язык Bully / Russian localization

Starter Kit не распространяет отдельный сторонний перевод. Для поддерживаемой Steam PC-версии он может активировать уже встроенную русскую локализацию изменением языкового кода в `12200_install.vdf` с обязательным бэкапом.

Подробнее: `docs/RUSSIAN_LANGUAGE.md` / `docs/RUSSIAN_LANGUAGE_EN.md`.

## Bully: Scholarship Edition

Bully и её игровые ресурсы принадлежат соответствующим правообладателям. Bully Starter Kit — неофициальный проект сообщества и не связан с Rockstar Games, Nexus Mods или авторами перечисленных модов.

Bully and its assets belong to their respective rights holders. Bully Starter Kit is an unofficial community project and is not affiliated with or endorsed by Rockstar Games, Nexus Mods, or the third-party mod authors.
