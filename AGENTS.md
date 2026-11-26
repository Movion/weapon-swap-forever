# Repository conventions

- Write GitHub release titles, release notes, and changelogs in English.
- Put addon UI strings in `WeaponSwapForever/Localization.lua`. Add new keys to the English `VALUES` table first. Other locales inherit missing entries from English.
- Use the WoW client to resolve spell names in macros. Keep slash commands and managed macro names stable across client languages.
