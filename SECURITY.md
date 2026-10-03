# Security / Безопасность

## Сообщить об уязвимости

Не публикуйте в открытом Issue уязвимости, связанные с API-ключами, обходом путей, небезопасной распаковкой архивов или произвольной записью файлов. Если у репозитория настроен приватный канал Security Advisories, используйте его; иначе свяжитесь с владельцем репозитория приватно.

Никогда не прикладывайте к отчёту реальные Nexus API keys, токены, cookies или другие секреты.

## Credentials / Учётные данные

- В репозитории не должно быть пользовательских API-ключей.
- В beta-режиме ключ Nexus можно сохранить только локально через Windows DPAPI для текущего пользователя.
- Логи установщика не должны выводить сам ключ.
- Для публичного stable-релиза Nexus-авторизация должна соответствовать актуальным требованиям Nexus Mods.

## Downloads / Загрузки

- Сторонние компоненты загружаются только по HTTPS с их оригинальных источников.
- ZIP-файлы проверяются перед установкой.
- Распаковщик блокирует абсолютные пути и `../`/path-traversal за пределы временной папки.
- Запись файлов игры ограничена выбранной директорией Bully.
- При ошибке установщик пытается автоматически откатить изменения из созданного бэкапа.

---

## Reporting a security issue

Do not open a public issue for vulnerabilities involving credentials, path traversal, unsafe archive extraction, or arbitrary file writes. Use GitHub private security reporting if enabled, otherwise contact the repository maintainer privately.

Never include real Nexus API keys, tokens, cookies, or other secrets in a report.

## Credentials

Bully Starter Kit must never commit user credentials. Stable does not require a Nexus key in the public browser-assisted flow. If a user chooses the optional personal/testing API path, the key may be stored locally using Windows DPAPI for the current Windows user and must never be printed to logs.
