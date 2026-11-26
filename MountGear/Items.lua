local M, A = MountGear, MountGear.API
-- Extend this table with server-specific IDs after confirming an EQUIPPED mount bonus.
M.KnownItems = { [11122] = true, [25653] = true, [32863] = true }
-- Carrot on a Stick, Riding Crop, Skybreaker Whip; not flight-form items.
local slots = { INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_BODY={4},
    INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7}, INVTYPE_FEET={8},
    INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11,12}, INVTYPE_TRINKET={13,14},
    INVTYPE_CLOAK={15}, INVTYPE_TABARD={19} }
local scan
local function mountLine(text)
    text = text:lower()
    if text:find("use:", 1, true) or text:find("chance", 1, true) then return false end
    -- Explicit mount/riding-speed wording, never generic movement speed.
    return text:find("mount") and text:find("speed") and
        (text:find("increase") or text:find("riding speed") or text:find("mounted movement speed") or
         (text:find("mount speed") and text:find("%%")))
end
function M.ItemSlots(r)
    local _, _, _, _, _, _, _, _, loc = A.info(r.link)
    return slots[loc]
end
function M.Recognized(r, bag, slot)
    if not M.ItemSlots(r) then return false end
    if M.KnownItems[r.id] then return true end
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                if line.leftText and mountLine(line.leftText) then return true end
            end
        end
    else
        if not scan then scan = CreateFrame("GameTooltip", "MountGearScanTooltip", UIParent, "GameTooltipTemplate") end
        scan:SetOwner(UIParent, "ANCHOR_NONE"); scan:ClearLines(); scan:SetBagItem(bag, slot)
        for i = 2, scan:NumLines() do
            local font = _G["MountGearScanTooltipTextLeft" .. i]
            if font and font:GetText() and mountLine(font:GetText()) then scan:Hide(); return true end
        end
        scan:Hide()
    end
    return false
end
function M.Candidates()
    local list = {}
    A.EachBag(function(r, bag, slot)
        if M.Recognized(r, bag, slot) then
            local selected = false
            for _, c in ipairs(M.db.items) do if A.Same(c.item, r) then selected = true end end
            if not selected then list[#list+1] = r end
        end
    end)
    table.sort(list, function(a,b) return a.link < b.link end)
    return list
end
function M.Add(r)
    if A.Combat() then M.Say("Configure mount items after combat."); return end
    if M.db.session then M.Say("Restore your previous gear before editing mount items."); return end
    local choices = M.ItemSlots(r)
    if not choices then return end
    local chosen = choices[1]
    for _, slot in ipairs(choices) do
        local used = false
        for _, c in ipairs(M.db.items) do if c.slot == slot then used = true end end
        if not used then chosen = slot; break end
    end
    -- Two trinkets fit; a third replaces the first. Other slot conflicts replace that slot.
    for i = #M.db.items, 1, -1 do
        if M.db.items[i].slot == chosen then table.remove(M.db.items, i) end
    end
    M.db.items[#M.db.items+1] = { slot = chosen, item = r }
    M.Draw()
end
