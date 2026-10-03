# Russian language in Bully

Bully Starter Kit does not redistribute a third-party translation archive.

## How the option works

After the selected mods finish installing, the app asks a separate question: **Enable Russian in Bully?**

- **No** — no language files/configuration are changed.
- **Yes** — on a supported Steam PC installation, Starter Kit finds `12200_install.vdf`, backs it up, and changes the built-in language code to `1049`.
- Game UI/subtitles become Russian; voice acting remains English.
- If the expected file or language entry cannot be identified safely, Starter Kit does not guess or patch arbitrary files. The mod installation remains intact and the user gets an explanatory message.

## Steam

After activation, keep Bully set to **English** in Steam properties so Steam does not replace the configuration used by the language-code method. Enable subtitles in the in-game settings if desired.

## Rockstar / retail

If `12200_install.vdf` is absent, Starter Kit currently avoids automatic registry edits. Language availability differs by build/edition; follow the official edition-specific method instead of forcing an unknown configuration.

## Rollback

The language change uses the same backup system as the mods. **Restore Backup** restores the previous `12200_install.vdf`.

## References

- Steam Community language-code guide: https://steamcommunity.com/sharedfiles/filedetails/?id=3576278360
- PCGamingWiki Bully page: https://www.pcgamingwiki.com/wiki/Bully:_Scholarship_Edition
