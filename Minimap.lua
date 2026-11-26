local M, A = MountGear, MountGear.API

function M.CreateMinimap()
    if M.minimap or not Minimap then return end
    local b = CreateFrame("Button", "MountGearMinimapButton", Minimap)
    M.minimap = b
    b:SetSize(32,32); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(Minimap:GetFrameLevel()+8)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp"); b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil,"ARTWORK")
    icon:SetSize(20,20); icon:SetPoint("CENTER",0,1)
    -- Resolve the unicorn icon from client data instead of an optional texture path.
    local texture
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(247402) -- Lucid Nightmare
        texture = info and info.iconID
    elseif GetSpellInfo then
        texture = select(3, GetSpellInfo(247402))
    end
    if not texture and C_Item and C_Item.GetItemIconByID then
        texture = C_Item.GetItemIconByID(151623) -- Lucid Nightmare reins
    end
    icon:SetTexture(texture or "Interface\\Icons\\Ability_Mount_RidingHorse")
    local border = b:CreateTexture(nil,"OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54,54); border:SetPoint("TOPLEFT")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight","ADD")
    local function position()
        local angle = math.rad(M.db.minimapAngle or 220)
        b:ClearAllPoints()
        b:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*(Minimap:GetWidth()/2+8),math.sin(angle)*(Minimap:GetHeight()/2+8))
    end
    local function drag()
        local x,y = GetCursorPosition()
        local cx,cy = Minimap:GetCenter()
        local scale = Minimap:GetEffectiveScale()
        M.db.minimapAngle = math.deg(math.atan2(y/scale-cy,x/scale-cx))
        position()
    end
    b:SetScript("OnDragStart",function(self) GameTooltip:Hide(); self:SetScript("OnUpdate",drag) end)
    b:SetScript("OnDragStop",function(self) self:SetScript("OnUpdate",nil) end)
    b:SetScript("OnClick",function(_,button)
        if button == "RightButton" then M.Ride()
        else SlashCmdList.MOUNTGEAR("") end
    end)
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:SetText("MountGear")
        GameTooltip:AddLine("Left-click: equipment window",1,1,1)
        GameTooltip:AddLine("Right-click: random mount / dismount",1,1,1)
        GameTooltip:AddLine("Drag: move around minimap",0.5,1,0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    position()
end
