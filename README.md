# Simple Weapon Swap

Save two weapon sets and switch between them with one click or keypress in **World of Warcraft: Forever**, in or out of combat. Any class can use it with weapons their character can equip. It’s especially handy for Feral Druids in PvP who switch from a damage two-hander to a healing staff or to a healing mace and an off-hand.

## Install

1. On GitHub, choose **Code → Download ZIP** and extract the archive.
2. Copy the `simple_weapon_swap` folder into `World of Warcraft/_forever_/Interface/AddOns`. The TOC should be at `Interface/AddOns/simple_weapon_swap/simple_weapon_swap.toc`.
3. Launch WoW Forever and enable **Simple Weapon Swap** in the AddOns list.

Targets WoW Forever 1.60.1 (addon interface 16001).

## Upgrade from Feral Weapon Swap

To keep your sets and keybind, close WoW and open your character’s `_forever_/WTF/Account/<account>/<realm>/<character>/SavedVariables` folder. If `simple_weapon_swap.lua` doesn’t exist there yet, copy `FeralWeaponSwap.lua` to `simple_weapon_swap.lua` in the same folder. Disable or remove the old **Feral Weapon Swap** addon before using **Simple Weapon Swap**. You can also start fresh with `/fws`.

## Set up and use

1. Type `/fws` in chat out of combat.
2. For each set, choose a two-hander or a one-hander with an eligible off-hand item from your bags or equipment, then click **Save selections**. You can also equip your weapons and click **Save equipped**.
3. To rename a set, edit its **Set name** field and press Enter or click away. Clear the field and save it to restore the default name, **Damage** or **Healing**.
4. To use a keyboard shortcut, click **Bind key** and press an available key or combination.

| Control | Action |
| --- | --- |
| Left-click or active swap key | Switch between the two sets |
| Right-click | Equip the second set (Healing by default) |
| Middle-click | Equip the first set (Damage by default) |
| Shift + left-drag | Move the display out of combat |
| `/fws` | Open setup |

The display reads your actual main-hand and off-hand slots. It shows **Other weapons** when they don’t match either set. Hover over it for your equipped items and control hints. Weapons, set names, the keybind, and the display position are saved per character.

## Use an existing action-bar key

1. In WoW's Key Bindings, restore or keep the key on its usual action-bar slot.
2. On the character that should swap weapons, open `/fws` out of combat and enable **Override an action-bar key on this character**.
3. Click **Bind key**, then press the same key. The addon saves the swap key and override setting for this character. WoW keeps the original action-bar binding.

For example, set **T** back to Action Bar 2, Slot 1 in WoW’s shared Key Bindings. On your druid, open the addon setup, enable the override, then click **Bind key** and press **T**. On your mage, put Polymorph in that slot and leave the addon swap key unassigned. **T** swaps weapons on the druid and casts Polymorph on the mage.

Enable **Pass through to the normal WoW binding** out of combat to release the override and use your regular binding on that character. Your saved swap key stays available. Disable pass-through to resume keyboard swapping. The on-screen swap button works in either mode.

## Combat swaps

Keep an ordinary bag slot free for the off-hand when switching to a two-hander. WoW applies its normal weapon-swap global cooldown. When both sets use the same weapon type and a swap gets rejected or you change weapons manually during combat, use right-click or middle-click to select the intended set directly.

The addon identifies weapons by item ID, so copies of the same item with different enchants or random stats share a single choice. If a swap fails, `/fws status` shows your game build and the saved and equipped item IDs.
