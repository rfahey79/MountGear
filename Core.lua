local M, A = MountGear, MountGear.API
local frame = CreateFrame("Frame")
M.frame = frame
local initialized, lastMounted, suppress, pending, attempts, elapsed, poll = false, nil, false, nil, 0, 0, 0
local blocked, reason, announced = false, "Ready", nil
function M.Say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff66dd66MountGear:|r " .. tostring(msg)) end
function M.Reason(msg)
    reason = msg
    if announced ~= msg then M.Say(msg); announced = msg end
end
function M.Next()
    local s = M.db and M.db.session
    if not s then return end
    local targets = s.phase == "restore" and s.before or s.targets
    for _, slot in ipairs(s.order) do
        if not A.Same(A.Record(nil, slot), targets[slot]) then return slot, targets[slot] end
    end
end
function M.Start()
    if M.db.session or suppress or A.Combat() or (UnitOnTaxi and UnitOnTaxi("player")) then return end
    local s = { before = {}, targets = {}, order = {}, phase = "equip" }
    for _, c in ipairs(M.db.items) do
        local src = A.Find(c.item)
        if src then
            -- Do not move an item out of a slot this configuration does not own.
            local allowed = not src.inventory or src.inventory == c.slot
            if src.inventory and not allowed then
                for _, other in ipairs(M.db.items) do if other.slot == src.inventory then allowed = true end end
            end
            if allowed then
                s.before[c.slot] = A.Record(nil, c.slot)
                s.targets[c.slot] = c.item
                s.order[#s.order+1] = c.slot
            else M.Reason("Mount item is equipped in an unrelated slot; skipped.") end
        else M.Reason("A configured mount item is missing; skipped.") end
    end
    if #s.order > 0 then M.db.session = s; attempts = 0; announced = nil end
end
function M.Restore(manual)
    if manual then suppress = true end
    if M.db.session then M.db.session.phase = "restore" end
    attempts = 0; announced = nil
end
function M.Wake() attempts = 0 end
function M.Tick()
    if not initialized then return end
    local mounted = A.mounted and A.mounted() or false
    if UnitOnTaxi and UnitOnTaxi("player") then mounted = false end
    if mounted ~= lastMounted then
        lastMounted = mounted
        if not mounted then suppress = false; M.Restore(false)
        elseif not M.db.session then M.Start() end
    end
    if not M.db.session and mounted and not suppress then M.Start() end
    local s = M.db.session
    if not s then return end
    if pending then
        if GetTime() < pending.untilTime then return end
        if A.Same(A.Record(nil, pending.slot), pending.item) then attempts = 0 end
        pending = nil
    end
    local slot, target = M.Next()
    if not slot then
        if s.phase == "restore" then
            M.db.session = nil; attempts = 0; reason = "Previous equipment restored"; announced = nil
        else reason = "Mount equipment equipped" end
        if M.DrawAction then M.DrawAction() end
        return
    end
    if A.Combat() then reason = "Waiting for combat to end"; return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then reason = "Waiting until alive"; return end
    if UnitOnTaxi and UnitOnTaxi("player") then reason = "Waiting until taxi ends"; return end
    if blocked then M.Reason("Automatic equipment actions blocked. Open /mountgear for the next action."); return end
    if attempts >= 3 then M.Reason("Equipment change pending: " .. reason .. " Use /mountgear restore or move the item manually."); return end
    attempts = attempts + 1
    local ok, success, err = pcall(A.Apply, slot, target)
    if not ok then reason = tostring(success)
    elseif not success then reason = err or "Client refused equipment change"
    else reason = "Waiting for equipment confirmation" end
    pending = { slot = slot, item = target, untilTime = GetTime() + 0.6 }
    if M.DrawAction then M.DrawAction() end
end
function M.Status()
    local version, build, _, interface = GetBuildInfo()
    M.Say("v" .. M.version .. "; client " .. tostring(version) .. " build " .. tostring(build) .. "; interface " .. tostring(interface))
    M.Say("Bags: " .. (C_Container and "C_Container" or "legacy") .. "; identity: " .. (C_Item and C_Item.GetItemGUID and "GUID" or "item link (identical copies indistinguishable)") .. "; mounted: " .. tostring(A.mounted and A.mounted()))
    M.Say("Session: " .. (M.db.session and M.db.session.phase or "none") .. "; automatic actions: " .. (blocked and "blocked" or "not known blocked") .. "; " .. reason)
    local slot, target = M.Next()
    if slot then M.Say("Next slot " .. slot .. ": " .. (target and target.link or "empty")) end
    for _, c in ipairs(M.db.items) do M.Say("Slot " .. c.slot .. ": " .. c.item.link .. (A.Find(c.item) and "" or " (missing)")) end
end
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "MountGear" then return end
        MountGearDB = MountGearDB or { schema = 1, items = {} }
        M.db = MountGearDB; M.db.items = M.db.items or {}
        initialized = true
        -- A reload/login always restores the durable snapshot before making a new one.
        if M.db.session then M.Restore(false) end
        M.CreateUI()
        M.CreateMinimap()
        return
    end
    if not initialized then return end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if arg1 == "MountGear" then blocked = true; M.Reason("Client blocked an equipment action; snapshot retained."); if not A.Combat() then M.window:Show() end end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then M.Wake()
    elseif event == "BAG_UPDATE_DELAYED" then if not pending then M.Wake() end
    elseif event == "UNIT_AURA" and arg1 ~= "player" then return end
    if M.DrawAction and not A.Combat() then M.DrawAction() end
end)
-- UNIT_AURA/events provide notifications; a 0.5s IsMounted check covers unannounced dismounts.
-- Inventory scans occur only during an active transaction, never on every aura event.
frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt; poll = poll + dt
    if (elapsed >= 0.25 and M.db and M.db.session) or poll >= 0.5 then
        elapsed = 0; poll = 0; M.Tick()
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED", "UNIT_AURA", "PLAYER_MOUNT_DISPLAY_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}) do
    pcall(frame.RegisterEvent, frame, event) -- patched clients may not expose every event
end
SLASH_MOUNTGEAR1 = "/mountgear"
SLASH_MOUNTGEAR2 = "/mg"
SlashCmdList.MOUNTGEAR = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "ride" then M.Ride()
    elseif msg == "help" then M.Help()
    elseif msg == "status" then M.Status()
    elseif msg == "restore" then M.Restore(true); M.Tick()
    elseif msg ~= "" then M.Help()
    else
        if A.Combat() then M.Say("Open the configuration window after combat."); return end
        if M.window:IsShown() then M.window:Hide() else M.Draw(); M.window:Show() end
    end
end
