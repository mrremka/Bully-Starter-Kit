# Оформление GitHub-репозитория

## Рекомендуемое название

**Bully-Starter-Kit**

## Description

> Vanilla+ installer for Bully: Scholarship Edition — fixes, 60 FPS, mild visuals, backups and RU/EN support.

## Topics

`bully` · `bully-scholarship-edition` · `modding` · `installer` · `silentpatch` · `windows` · `powershell` · `vanilla-plus` · `russian` · `open-source`

## Social preview

Загрузите `assets/github-social-preview.png` через **Settings → General → Social preview**.

## Первый публичный релиз

Пока Nexus SSO не зарегистрирован, используйте prerelease-тег:

```text
v0.4.0
```

Рекомендуемый заголовок Release:

> Bully Starter Kit v0.4.0 — RU/EN Stable

Короткое описание:

> Первый публичный beta-релиз Bully Starter Kit: автоматическая установка SilentPatch, Essential Fixes и One Percent Better Main, резервные копии, RU/EN интерфейс и отдельный выбор русского языка Bully в конце установки.

## Перед публикацией

1. Запустите `scripts/Test-Project.ps1` на Windows.
2. Проверьте чистую установку на реальной Bully.
3. Проверьте Restore Backup.
4. Проверьте ответы Да/Нет на вопрос о русском языке.
5. Проверьте неправильный Nexus API key и обрыв сети.
6. Не коммитьте `downloads/last-download-manifest.json`, ключи, архивы Nexus или файлы игры.
