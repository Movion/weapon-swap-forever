# Weapon Swap Forever

A lightweight addon for World of Warcraft: Forever 1.60.1 (interface 16001). It helps rogues and warriors maintain weapon swap macros as they acquire new gear. It uses Blizzard windows and character macros and runs without external libraries or background polling.

This addon was developed with AI assistance.

## Installation

Download the installation ZIP from [GitHub Releases](https://github.com/Movion/weapon-swap-forever/releases/latest) and extract it into `World of Warcraft\_forever_\Interface\AddOns`. The resulting folder should contain `WeaponSwapForever\WeaponSwapForever.toc`. Restart WoW and enable **Weapon Swap Forever** in the AddOns list.

Run `/wsf sync` once out of combat after upgrading from an earlier version or switching client languages. Earlier rogue macros are renamed in place, and saved weapon assignments carry over.

## New gear

When you equip an unsaved main-hand weapon, a Blizzard dialog asks whether to update your macros. Rogues also get a prompt for a new off-hand dagger that can be equipped in the main hand. Warriors with a shield equipped can choose **Offense** or **Defense** for a new one-handed weapon. **Defense** saves the shield as well. You can also save a new shield on its own.

Switching between saved weapons does not prompt you. For a swap made in combat, the prompt appears after combat if the new item is still equipped. Your macros are updated after you confirm.

## Weapons by ability

Click the sword-and-dagger icon in the minimap's AddOn Compartment, run `/wsf`, or choose **Menu** in the equipment prompt. Equip a weapon in your main hand and click **Set Weapon** next to an ability. For example, you can use different daggers for Ambush and Backstab. **Default** switches that ability back to its shared weapon.

To add another learned active ability, equip the weapon first, enter the ability name or spell ID, and click **Add**. Click **Macro** to pick up the macro, then place it on your action bar. You can also drag it from `/macro`. Drag the menu by its title bar. The scrollbar appears when the list exceeds the visible area.

## Rogue

1. Equip your regular main-hand weapon and confirm the prompt or run `/wsf main`.
2. Equip your dagger and confirm the prompt or run `/wsf dagger` with the dagger in your main hand.
3. Add **WSF Sinister**, **WSF Ambush**, **WSF Backstab**, and optionally **WSF Main Hand** to your action bar. Assign any keybinds you like.

**WSF Sinister** equips your regular main-hand weapon and attempts Riposte, then Sinister Strike. **WSF Ambush** and **WSF Backstab** equip a dagger and attempt the corresponding ability. If the swap triggers the global cooldown, press the macro again once it ends. **WSF Main Hand** equips your regular weapon.

Saving a new dagger updates the macros using the shared dagger. Saving a new regular main-hand weapon updates the macros using that weapon. To use a dagger as your regular weapon, save it with `/wsf main`.

## Warrior

1. Equip your offensive weapon and run `/wsf offense`.
2. Equip your defensive weapon and shield and run `/wsf defense`.
3. Add **WSF Offense** and **WSF Defense** to your action bar.

**WSF Offense** attempts Battle Stance and equips the offensive weapon in slot 16. A shield may remain equipped if the offensive weapon is one-handed. **WSF Defense** attempts Defensive Stance and equips the defensive weapon and shield in slots 16 and 17. If a cooldown blocks the swap, press the macro again when it ends. Run `/wsf shield` to save just a new shield.

## Macro management

- Use `/wsf status` to see saved items and `/wsf sync` to update or recreate your macros out of combat.
- Keep the managed macro names and the `# WeaponSwapForever` marker so the addon can find and update those macros. If a macro of your own uses the same name, rename it and run `/wsf sync`.
- Carry the items you want to swap between. The macros identify items by item ID, so two copies with the same ID are treated as the same item.

## Languages

English is the default. German clients use the German menu and messages. Macro spell names come from WoW in the client language, while the managed macro names stay the same across languages. Addon text lives in [`Localization.lua`](WeaponSwapForever/Localization.lua).
