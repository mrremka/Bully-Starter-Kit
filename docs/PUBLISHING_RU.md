# Чек-лист публикации Bully Starter Kit

## Репозиторий

- [ ] Название, описание и topics заполнены.
- [ ] `assets/github-social-preview.png` загружен в **Settings → General → Social preview**.
- [ ] `README.md` открывается на русском; `README_EN.md` доступен одной ссылкой.
- [ ] Issues и Discussions включены по желанию.
- [ ] Указана MIT License для **кода установщика**, без утверждений о лицензировании сторонних модов.

## Перед каждым релизом

- [ ] Обновлён `packVersion` в `mods.json` и `$PackVersion` в `src/BullyStarterKit.ps1`.
- [ ] Запущен `scripts/Test-Project.ps1` без ошибок.
- [ ] Проверены чистая установка и Restore на Windows 10/11.
- [ ] Проверен сценарий неправильного Nexus API-ключа и обрыва загрузки.
- [ ] Проверены ответы **Да** и **Нет** на вопрос о русском языке Bully.
- [ ] Проверены официальные ссылки и имена авторов в `THIRD_PARTY.md`.
- [ ] Для stable public Nexus integration реализован/проверен SSO согласно `NEXUS_PUBLIC_RELEASE.md`.

## Релиз

Для Stable v0.4.0 публичный Nexus SSO не требуется: основной поток использует официальный browser-assisted Manual/Slow Download без API-ключа. Тег `v0.4.0` проходит релизную проверку и собирает `BullyStarterKit.zip` и `BullyStarterKit.sha256`. SSO понадобится только если позже будет добавлена полностью автоматическая публичная загрузка Nexus.
