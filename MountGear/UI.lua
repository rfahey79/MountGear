local M, A = MountGear, MountGear.API
local icons, menuRows = {}, {}
local tooltip
local function itemTooltip(owner, link, anchor)
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "MountGearItemTooltip", UIParent, "GameTooltipTemplate")
        tooltip:EnableMouse(false)
        tooltip:SetClampedToScreen(true)
    end
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 12, 0)
    tooltip:SetHyperlink(link)
    tooltip:EnableMouse(false)
    return tooltip
end
local function hideTooltip() if tooltip then tooltip:Hide() end end
local function backdrop(f)
    f:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=24, insets={left=6,right=6,top=6,bottom=6} })
end
function M.DrawAction()
    if not M.action or A.Combat() then return end
    local slot, target = M.Next()
    M.action:SetAttribute("type", nil)
    M.action:SetAttribute("macrotext", nil)
    if slot then
        M.action:Show()
        if target then
            M.action:SetText("Equip slot " .. slot)
            -- Secure hardware-click fallback. Link identifies the full variant, not just ID.
            -- Exact indistinguishable copies need manual placement on clients without GUID actions.
            M.action:SetAttribute("type", "macro")
            M.action:SetAttribute("macrotext", "/equipslot " .. slot .. " " .. target.link)
        else M.action:SetText("Empty slot " .. slot .. " manually") end
    else M.action:Hide() end
end
function M.Draw()
    local f = M.window
    local n = #M.db.items + 1
    local cols = math.min(n, 6)
    f:SetSize(math.max(190, 28 + cols*40), 88 + math.ceil(n/6)*40)
    for _, b in ipairs(icons) do b:Hide() end
    for i, c in ipairs(M.db.items) do
        local b = icons[i]
        if not b then
            b = CreateFrame("Button", "MountGearItem" .. i, f, "ItemButtonTemplate")
            b:SetSize(32,32); b:RegisterForClicks("RightButtonUp")
            b:SetScript("OnClick", function(self)
                if A.Combat() then M.Say("Configure mount items after combat."); return end
                if M.db.session then M.Say("Restore previous gear before editing mount items."); return end
                hideTooltip(); table.remove(M.db.items, self.index); M.Draw()
            end)
            b:SetScript("OnEnter", function(self)
                local tip = itemTooltip(self, self.item.link, M.window)
                tip:AddLine("Slot " .. self.slot .. " - Right-click to remove", 0.5,1,0.5)
                if not A.Find(self.item) then tip:AddLine("Missing from bags/equipment",1,0.3,0.3) end
                tip:Show()
            end)
            b:SetScript("OnLeave", hideTooltip)
            icons[i] = b
        end
        local _,_,_,_,_,_,_,_,_, texture = A.info(c.item.link)
        SetItemButtonTexture(b, texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.index=i; b.item=c.item; b.slot=c.slot
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",14+((i-1)%6)*40,-34-math.floor((i-1)/6)*40); b:Show()
    end
    M.plus:ClearAllPoints(); M.plus:SetPoint("TOPLEFT",14+((n-1)%6)*40,-34-math.floor((n-1)/6)*40)
    M.DrawAction()
end
function M.ShowMenu()
    local menu = M.menu
    if menu:IsShown() then menu:Hide(); return end
    local candidates = M.Candidates()
    for _, row in ipairs(menuRows) do row:Hide() end
    local total = math.max(1,#candidates)
    M.menuContent:SetSize(300,total*24)
    for i=1,total do
        local row = menuRows[i]
        if not row then
            row = CreateFrame("Button",nil,M.menuContent)
            row:SetSize(300,24); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.label:SetPoint("LEFT",29,0)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(20,20); row.icon:SetPoint("LEFT",5,0)
            row.label:SetWidth(266); row.label:SetJustifyH("LEFT")
            row:SetScript("OnClick",function(self) hideTooltip(); if self.item then M.Add(self.item) end; menu:Hide() end)
            row:SetScript("OnEnter",function(self) if self.item then local tip=itemTooltip(self,self.item.link,menu); tip:Show() end end)
            row:SetScript("OnLeave",hideTooltip)
            menuRows[i]=row
        end
        row.item=candidates[i]; row.label:SetText(row.item and row.item.link or "No recognized mount equipment in bags")
        local texture
        if row.item then texture = select(10, A.info(row.item.link)) end
        row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        if row.item then row.icon:Show() else row.icon:Hide() end
        row:SetPoint("TOPLEFT",0,-(i-1)*24); row:Show()
    end
    menu:SetHeight(math.min(8,total)*24+24); menu:Show()
end
function M.CreateUI()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f=CreateFrame("Frame","MountGearWindow",UIParent,template); M.window=f
    backdrop(f); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local p,_,rp,x,y=self:GetPoint(); M.db.position={p,rp,x,y}
    end)
    local p=M.db.position
    if p then f:SetPoint(p[1],UIParent,p[2],p[3],p[4]) else f:SetPoint("CENTER") end
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",14,-13); title:SetText("MountGear")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",0,0)
    local plus=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); M.plus=plus; plus:SetSize(32,32); plus:SetText("+")
    plus:GetFontString():SetTextColor(0.1,1,0.1); plus:GetFontString():SetFontObject("GameFontNormalLarge")
    plus:SetScript("OnClick", M.ShowMenu)
    local action=CreateFrame("Button","MountGearActionButton",f,"SecureActionButtonTemplate,UIPanelButtonTemplate")
    M.action=action; action:SetSize(166,22); action:SetPoint("BOTTOM",0,12)
    action:RegisterForClicks("AnyUp","AnyDown")
    action:SetScript("PostClick",function() M.Wake() end)
    local menu=CreateFrame("Frame",nil,f,template); M.menu=menu; backdrop(menu)
    menu:SetFrameStrata("TOOLTIP"); menu:SetPoint("TOPLEFT",plus,"BOTTOMLEFT",-8,-2); menu:SetWidth(336); menu:EnableMouse(true)
    local scroll=CreateFrame("ScrollFrame","MountGearMenuScroll",menu,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",10,-12); scroll:SetPoint("BOTTOMRIGHT",-30,12)
    M.menuContent=CreateFrame("Frame",nil,scroll); scroll:SetScrollChild(M.menuContent)
    menu:SetScript("OnHide",hideTooltip)
    menu:Hide(); f:SetScript("OnHide",function() hideTooltip(); menu:Hide() end)
    UISpecialFrames[#UISpecialFrames+1]="MountGearWindow"
    M.Draw(); f:Hide()
end
