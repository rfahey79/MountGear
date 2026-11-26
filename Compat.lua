MountGear = { version = "0.1.5" }
local M = MountGear
local A = {}
M.API = A
local bags = C_Container or {}
local items = C_Item or {}
A.numSlots = bags.GetContainerNumSlots or GetContainerNumSlots
A.bagLink = bags.GetContainerItemLink or GetContainerItemLink
A.pickBag = bags.PickupContainerItem or PickupContainerItem
A.freeSlots = bags.GetContainerNumFreeSlots or GetContainerNumFreeSlots
A.info = items.GetItemInfo or GetItemInfo
A.pickInventory = items.PickupInventoryItem or PickupInventoryItem
A.equipCursor = items.EquipCursorItem or EquipCursorItem
A.mounted = IsMounted
function A.Combat() return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") end
function A.Identity(link)
    return link and link:match("(item:[^|]+)") or nil
end
function A.GUID(bag, slot)
    if items.GetItemGUID and ItemLocation then
        local loc = bag == nil and ItemLocation:CreateFromEquipmentSlot(slot) or ItemLocation:CreateFromBagAndSlot(bag, slot)
        if items.DoesItemExist and not items.DoesItemExist(loc) then return nil end
        return items.GetItemGUID(loc)
    end
end
function A.Record(bag, slot)
    local link
    if bag == nil then link = GetInventoryItemLink("player", slot) else link = A.bagLink(bag, slot) end
    if not link then return false end -- false is an intentionally empty slot
    return { link = link, key = A.Identity(link), guid = A.GUID(bag, slot), id = tonumber(link:match("item:(%d+)")) }
end
function A.Same(a, b)
    if not a or not b then return a == b end
    if a.guid and b.guid then return a.guid == b.guid end
    return a.key == b.key
end
function A.EachBag(fn)
    for bag = 0, 4 do -- equipment cannot live in the reagent bag
        for slot = 1, A.numSlots(bag) do
            local r = A.Record(bag, slot)
            if r then fn(r, bag, slot) end
        end
    end
end
function A.Find(wanted)
    local found
    A.EachBag(function(r, bag, slot)
        if not found and A.Same(wanted, r) then found = { bag = bag, slot = slot } end
    end)
    if found then return found end
    for slot = 1, 19 do
        if A.Same(wanted, A.Record(nil, slot)) then return { inventory = slot } end
    end
end
function A.EmptyBagSlot()
    for bag = 0, 4 do
        local _, family = A.freeSlots(bag)
        if family == 0 then
            for slot = 1, A.numSlots(bag) do
                if not A.bagLink(bag, slot) then return bag, slot end
            end
        end
    end
end
-- Never clear a player's cursor or destroy an item. Each operation is verified by Core.
function A.Apply(slot, wanted)
    if CursorHasItem() then return false, "Finish moving the item on your cursor." end
    if not wanted then
        local bag, pos = A.EmptyBagSlot()
        if not bag then return false, "Restoring an empty slot needs a free normal bag slot." end
        A.pickInventory(slot)
        if CursorHasItem() then A.pickBag(bag, pos) end
    else
        local src = A.Find(wanted)
        if not src then return false, "A required item is missing from your bags." end
        if src.inventory then A.pickInventory(src.inventory) else A.pickBag(src.bag, src.slot) end
        if not CursorHasItem() then return false, "Client refused item pickup; use the action button or move it manually." end
        A.equipCursor(slot)
        -- A successful swap leaves the displaced item on the cursor. Return it to source.
        if CursorHasItem() then
            if src.inventory then A.pickInventory(src.inventory) else A.pickBag(src.bag, src.slot) end
        end
    end
    if CursorHasItem() then return false, "An item remains on your cursor; place it in a normal bag." end
    return true
end
