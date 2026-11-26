# MountGear 0.1.0

Mount-related equipment swapping with a compact native WoW window. No Equipment Manager sets, external libraries, minimap button, or mount macro changes.

## Install

Exit WoW. Extract the ZIP and copy its **MountGear** folder into the **Interface/AddOns** folder belonging to the executable you actually launch:

- Private/legacy client: `<your WoW folder>/Interface/AddOns/MountGear/`
- A client with a `_forever_` product folder: `<World of Warcraft>/_forever_/Interface/AddOns/MountGear/`

The final path must contain `MountGear.toc` directly, not another nested MountGear folder. Enable MountGear on the character selection AddOns screen. The TOC defaults to interface 16001, based on publicly exported Forever documentation. If your private client calls it outdated, enable **Load out of date AddOns**. If needed, run `/dump select(4,GetBuildInfo())` and change only the TOC's Interface number to that value (30300 for an unmodified 3.3.5a client). Matching a TOC alone does not prove API compatibility.

## Configure and use

1. Put your mount-speed equipment in your bags and type `/mountgear` outside combat.
2. Click the green **+**, then select an owned item from the scrollable dropdown. Uncached items may need a second opening after the client loads their information.
3. Hover an icon for its standard item tooltip. Right-click to remove it. Drag the frame background to move the window; close it with X or Escape.
4. Mount using your existing macro or any other method. MountGear watches the character's mount state independently.
5. Dismount. MountGear restores the previous items, including originally empty slots. Combat, death, taxis, missing items, and equipment failures leave restoration pending.

Two trinkets occupy slots 13 and 14 in selection order. A third replaces the first slot's selection. Other slot conflicts replace the existing selection for that slot. Configuration is locked while a snapshot exists: dismount and restore first. Items already equipped elsewhere are never pulled out of unrelated slots.

Commands:

| Command | Action |
| --- | --- |
| `/mountgear` | Toggle the compact window outside combat |
| `/mountgear status` | Print build/interface, API family, identity method, configuration, pending phase and next slot |
| `/mountgear restore` | Queue restoration now; suppress mount gear until the next dismount |

After a failed operation, fix the cause and use `/mountgear restore` to retry restoration. Relevant bag changes/combat ending also wake the queue. A manual equipment change that satisfies the pending target is detected automatically.

## Restrictions and fallback

**This is a first release for in-game validation, not a claim of verified compatibility with your private client's executable.** Publicly available Forever exports currently describe a modern 1.60.1/interface 16001 client; that does not establish the build or restrictions of the private client in your request.

The automatic path uses ordinary item pickup/equipment APIs outside combat. It does not use protected combat actions or attempt to bypass client restrictions. Every change is checked against the actual equipped item after 0.6 seconds; an API returning without an error is not treated as success. A blocked/forbidden action event for MountGear disables automatic attempts for the remainder of that login/reload and preserves the snapshot.

When automatic actions are blocked, open the window outside combat. The **Equip slot N** button offers one secure `/equipslot` action per click. Click again for another pending slot, allowing time for confirmation between clicks. If the patched client also rejects secure macro attributes, or if the target says **Empty slot N manually**, move that item yourself using the character window. `/mountgear status` names the next desired item/empty slot. The queue observes manual placement and completes only after verification. No automatic fallback can honestly promise to overcome restrictions imposed by a particular client.

All equipment work is deferred in combat, including trinkets. The fallback does not try to change armor/trinkets in combat. Window configuration is available outside combat.

The snapshot is saved per character alongside selected items and window position. A reload/login restores an existing snapshot before starting another mount cycle. SavedVariables are flushed by WoW on logout/reload, so an application crash can lose changes made since the previous flush. Do not delete MountGearDB while it contains an unresolved snapshot.

Modern clients use item GUIDs to distinguish physical copies; legacy clients without GUID APIs use the complete item-string variant, including enchant/gem/random-property fields. Two copies with identical item strings cannot be physically distinguished on that legacy path. The secure macro fallback also cannot guarantee a particular physical copy when duplicates have identical links; place the exact original manually if GUID verification remains pending. Missing originals are never replaced by another item ID just to clear the queue.

## Recognized equipment

Known IDs: Carrot on a Stick (11122), Riding Crop (25653), Skybreaker Whip (32863). Presence in this table means the item is offered when owned; it does not guarantee its bonus is active at your level or stacks with another bonus on your server.

Additional equippable armor, rings, or trinkets are accepted when their English tooltip explicitly describes increased mounted speed. Generic run-speed bonuses, flight-form bonuses, weapons, and shields are excluded. Enchanted boots/gloves may be discovered by this scan. English tooltip scanning is deliberately conservative; unusual wording/localized/custom-server effects may need an explicit ID added to `MountGear.KnownItems` in `Items.lua`. Tooltips with an English `Use:` prefix or chance-to-trigger wording are excluded. Known IDs work independently of language. No bank, mail, reagent bag, or remote inventory is scanned.

Mount bonuses may be nonstacking, disabled above a level, or changed to permanent effects by your server. The addon manages equipment; it does not alter server bonus rules.

## Compatibility-sensitive files

- `Compat.lua`: modern `C_Container` versus legacy bag functions; GUID versus link identity; exact bag/inventory lookup; pickup, swap, and empty-slot operations.
- `Items.lua`: recognized IDs, English tooltip criteria, supported equipment-slot types.
- `Core.lua`: mount-state polling, transaction verification, combat/reload recovery, blocked-action handling.
- `UI.lua`: native templates, scrollable dropdown, and secure click fallback.

The addon polls `IsMounted()` twice per second (four times per second during a transaction) to cover dismounts without a dependable event. It does not scan bags on every aura event. It ignores taxi mount state. Equipment changes are serialized, with a snapshot taken before any operation. Rapid remounts complete pending restoration before recording a new snapshot.

## Research and verification boundary

Reviewed public client-exported API documentation and Blizzard UI source, accessed November 19, 2026:

- Client-exported reference metadata: https://atraeau.github.io/WoW-Addons/api.json (1.60.1, build 70790, interface 16001). This is a community export of a running client, not proof about your private build.
- Forever UI API definitions: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua (C_Item item APIs, equipment destination slot parameter).
- Secure equipment commands in Blizzard UI source: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua (comparison/reference, not a private-client guarantee).

Equipment Manager exists in some Forever clients, but MountGear does not call it. Its presence does not establish whether event-triggered individual swaps are permitted. The client export's API signatures do not prove automatic-action permissions; only testing your running executable can settle that point.

## In-game test checklist

- Enable `/console scriptErrors 1`, then `/reload`. Check `/mountgear status` and save the output if anything fails.
- Add a Carrot/Riding Crop; verify tooltip, dropdown, icon removal, wrapping, dragging, and window position after `/reload`.
- Wear distinct gear in both trinket slots and unrelated armor. Mount and dismount normally; verify each exact original returns and unrelated gear is unchanged.
- Repeat with an originally empty slot. Verify no item remains on the cursor.
- Dismount by attack, incoming combat, swimming, and taxi. In combat, verify restoration remains pending and completes after combat.
- Dismount and remount rapidly while restoration is deferred. Verify the first original snapshot survives.
- Reload while mounted or while restoration is pending. Verify the original snapshot is recovered.
- Remove a mount item before mounting; verify it is skipped. Remove an original from bags while mounted; dismount and verify the original remains pending, then return it and retry.
- Fill normal bags after equipping into an empty slot. Verify restoration waits for free normal bag space; free space and retry.
- Test two selected trinkets, a third-slot conflict, and mount-enchanted boots/gloves if available.
- If actions are blocked, test the secure Equip button outside combat, then manual placement. Ensure the snapshot clears only after the desired equipment is actually present.
- Log out/in; verify selected gear and window position persist.

Report the FIRST Lua error verbatim, `/mountgear status`, and the trigger. Client build/API diagnostics are more useful than changing the mount macro.

## Development tests

The ZIP includes `tests/test_mountgear.py`, a deterministic Lua 5.1 mock suite for equip/restore, empty slots, full bags, combat, remounts, reload recovery, missing originals, swap failures, slot conflicts, and cursor safety. Run with Python and `lupa` installed: `python tests/test_mountgear.py` from the extracted package root. These tests cannot validate WoW secure-action restrictions or native UI rendering.
