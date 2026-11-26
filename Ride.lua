local M, A = MountGear, MountGear.API

-- Called only by a player-entered slash command or macro, never by an event/timer.
function M.Ride()
    if UnitOnTaxi and UnitOnTaxi("player") then M.Say("Wait until your taxi ride ends."); return end
    if A.mounted and A.mounted() then Dismount(); return end
    if A.Combat() then M.Say("You cannot summon a mount during combat."); return end
    if UnitIsDeadOrGhost("player") then M.Say("You must be alive to mount."); return end
    local choices = {}
    local journal = C_MountJournal
    if journal and journal.GetMountIDs and journal.GetMountInfoByID and journal.SummonByID then
        for _, id in ipairs(journal.GetMountIDs() or {}) do
            local _, _, _, _, usable, _, _, _, _, hidden, collected = journal.GetMountInfoByID(id)
            if collected and not hidden and usable then
                -- Client checks riding requirements and location restrictions; do not
                -- confuse owning a mount with having the skill needed to ride it.
                if journal.GetMountUsabilityByID then usable = journal.GetMountUsabilityByID(id, true) end
                if usable then choices[#choices + 1] = id end
            end
        end
        if #choices == 0 then M.Say("No learned mounts are currently usable with your riding skill and location."); return end
        local ok, err = pcall(journal.SummonByID, choices[math.random(#choices)])
        if not ok then M.Say("Client refused mount summon: " .. tostring(err)) end
    else
        M.Say("This client lacks the mount-journal APIs needed for skill-aware selection. Keep using your working mount macro and send /mountgear status.")
    end
end

function M.Help()
    M.Say("/mountgear - equipment window; /mountgear ride - random usable learned mount, or dismount.")
    M.Say("/mountgear status - diagnostics; /mountgear restore - restore previous gear; /mountgear help - commands.")
end
