---------------------------------------------------------------------------
-- SuaviUI Bags: bank window (character bank + Warband bank)
--
-- Built on the same Window class as the bag window (sui_bags.lua). Blizzard's
-- BankFrame is re-parented to a hidden frame while the module is active; the
-- interaction itself (BANKFRAME_OPENED / PLAYER_INTERACTION_MANAGER_FRAME_SHOW)
-- is left alone, we only draw our own view of the same containers.
--
-- Right click inside the bank:
--   * bag item  -> deposit into the bank type currently shown
--   * bank item -> withdraw into the bags
-- The stock buttons would route these through BankFrame:GetActiveBankType(),
-- which we cannot keep in sync without touching Blizzard's frame, so while the
-- bank is open the buttons ignore native right clicks and we call
-- C_Container.UseContainerItem with an explicit bank type instead.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = SuaviUI
local Bags = ns.Bags

local floor = math.floor
local GetDB = Bags.GetDB
local WHITE = "Interface\\Buttons\\WHITE8x8"

local BankType = Enum.BankType
local FIRST_BANK_TAB = (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) or 6

local Bank = {
    bankType = BankType.Character,
    selectedTab = nil,        -- nil = all tabs of the shown bank type
    tabData = {},             -- purchased tab data for bankType
    tabIDs = {},
}
Bags.Bank = Bank

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Say(msg)
    UIErrorsFrame:AddMessage(msg, 1, 0.3, 0.3)
end

local function IsWarbandOnly()
    return C_PlayerInteractionManager
        and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.AccountBanker)
        and true or false
end

local function CanViewType(bankType)
    return C_Bank.CanViewBank(bankType) and true or false
end

local function IsLocked(bankType)
    return C_Bank.FetchBankLockedReason(bankType) ~= nil
end

local function Gold(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper or 0)
end

---------------------------------------------------------------------------
-- Deposit / withdraw by right click
---------------------------------------------------------------------------
function Bags.OnItemMouseUp(btn, mouseButton)
    if mouseButton ~= "RightButton" then return end
    local win = Bags.bankWindow
    if not (win and win:IsShown()) then return end
    if InCombatLockdown() or IsModifiedClick() or CursorHasItem() then return end

    local bag, slot = btn:GetParent():GetID(), btn:GetID()
    if not bag or not slot then return end

    if bag >= FIRST_BANK_TAB then
        -- withdraw
        if C_Container.GetContainerItemInfo(bag, slot) then
            C_Container.UseContainerItem(bag, slot)
        end
        return
    end

    -- deposit from a carried bag
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not C_Item.DoesItemExist(loc) or C_Item.IsLocked(loc) then return end
    local bankType = Bank.bankType
    if IsLocked(bankType) then return end
    if not C_Bank.IsItemAllowedInBankType(bankType, loc) then
        Say(ERR_ITEM_CANT_BE_BANKED or "This item cannot be stored here.")
        return
    end
    if bankType == BankType.Account and C_Item.CanBeRefunded(loc) then
        Say("This item is still refundable. Deposit it from the default bank window.")
        return
    end
    C_Container.UseContainerItem(bag, slot, nil, bankType)
end

function Bags:SetBankMode(on)
    on = on and true or false
    if self.bankMode == on then return end
    self.bankMode = on
    if self.bagWindow then self.bagWindow:SetLeftClickOnly(on) end
end

---------------------------------------------------------------------------
-- Gold dialog (Warband bank)
---------------------------------------------------------------------------
local moneyDialog
local function ShowMoneyDialog(mode)
    if not moneyDialog then
        local d = CreateFrame("Frame", "SuaviUI_BankMoneyDialog", UIParent, "BackdropTemplate")
        d:SetSize(240, 110)
        d:SetPoint("CENTER")
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:EnableMouse(true)
        d:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        d:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
        local a = Bags.style.accent or { 0.2, 1, 0.6 }
        d:SetBackdropBorderColor(a[1], a[2], a[3], 1)
        d:Hide()
        local title = d:CreateFontString(nil, "OVERLAY")
        title:SetFont(Bags.style.font or STANDARD_TEXT_FONT, 13, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        d.title = title
        local eb = CreateFrame("EditBox", nil, d, "BackdropTemplate")
        eb:SetSize(140, 22)
        eb:SetPoint("TOP", title, "BOTTOM", 0, -10)
        eb:SetAutoFocus(true)
        eb:SetNumeric(true)
        eb:SetMaxLetters(9)
        eb:SetFont(Bags.style.font or STANDARD_TEXT_FONT, 12, "")
        eb:SetTextInsets(6, 6, 0, 0)
        eb:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        eb:SetBackdropColor(0.02, 0.02, 0.02, 1)
        eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        d.box = eb
        local gl = d:CreateFontString(nil, "OVERLAY")
        gl:SetFont(Bags.style.font or STANDARD_TEXT_FONT, 12, "")
        gl:SetPoint("LEFT", eb, "RIGHT", 6, 0)
        gl:SetText("gold")
        local function Accept()
            local gold = tonumber(eb:GetText()) or 0
            if gold > 0 then
                local copper = gold * 10000
                if d.mode == "deposit" then
                    C_Bank.DepositMoney(Bank.bankType, copper)
                else
                    C_Bank.WithdrawMoney(Bank.bankType, copper)
                end
            end
            d:Hide()
        end
        eb:SetScript("OnEnterPressed", Accept)
        eb:SetScript("OnEscapePressed", function() d:Hide() end)
        local ok = Bags.MakeTextButton(d, "OK", 70, Accept)
        ok:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 10)
        local cancel = Bags.MakeTextButton(d, "Cancel", 70, function() d:Hide() end)
        cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 10)
        moneyDialog = d
    end
    moneyDialog.mode = mode
    moneyDialog.title:SetText(mode == "deposit" and "Deposit gold" or "Withdraw gold")
    moneyDialog.box:SetText("")
    moneyDialog:Show()
    moneyDialog.box:SetFocus()
end

---------------------------------------------------------------------------
-- Deposit everything (auto deposit)
---------------------------------------------------------------------------
local function HasRefundableDeposit(bankType)
    if bankType ~= BankType.Account then return false end
    for bag = 0, 5 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if C_Item.DoesItemExist(loc) and C_Bank.IsItemAllowedInBankType(bankType, loc)
                and C_Item.CanBeRefunded(loc) then
                return true
            end
        end
    end
    return false
end

local function DepositAll()
    if InCombatLockdown() then return end
    local bankType = Bank.bankType
    if IsLocked(bankType) or not C_Bank.DoesBankTypeSupportAutoDeposit(bankType) then return end
    local function Go() C_Bank.AutoDepositItemsIntoBank(bankType) end
    if HasRefundableDeposit(bankType) then
        local GUI = SUI.GUI
        if GUI and GUI.ShowConfirmation then
            GUI:ShowConfirmation({
                title = "Deposit items?",
                message = "Some refundable items would be deposited into the Warband bank.",
                warningText = "Deposited items can no longer be refunded.",
                acceptText = "Deposit",
                cancelText = "Cancel",
                isDestructive = true,
                onAccept = Go,
            })
        else
            Say("Refundable items found. Deposit them from the default bank window.")
        end
        return
    end
    Go()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local bankWindow

local function SelectType(bankType)
    if Bank.bankType == bankType then return end
    Bank.bankType = bankType
    Bank.selectedTab = nil
    if bankWindow then bankWindow:RequestRefresh() end
end

local function BuildTabButton(row, index)
    local b = CreateFrame("Button", nil, row, "BackdropTemplate")
    b:SetSize(26, 26)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.04, 0.04, 0.045, 1)
    b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.tex = tex
    b:SetScript("OnClick", function(self)
        Bank.selectedTab = self.tabID
        if bankWindow then bankWindow:RequestRefresh() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tabName or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function SetupBankChrome(win)
    -- Row 1: bank type switch + actions
    local typeRow = CreateFrame("Frame", nil, win.frame)
    typeRow:Hide()
    win.typeRow = typeRow
    local bankBtn = Bags.MakeTextButton(typeRow, "Bank", 60, function() SelectType(BankType.Character) end)
    bankBtn:SetPoint("LEFT", typeRow, "LEFT", 0, 0)
    local warBtn = Bags.MakeTextButton(typeRow, "Warband", 70, function() SelectType(BankType.Account) end)
    warBtn:SetPoint("LEFT", bankBtn, "RIGHT", 4, 0)
    local wd = Bags.MakeTextButton(typeRow, "Withdraw", 62, function() ShowMoneyDialog("withdraw") end)
    wd:SetPoint("RIGHT", typeRow, "RIGHT", 0, 0)
    local dp = Bags.MakeTextButton(typeRow, "Deposit", 56, function() ShowMoneyDialog("deposit") end)
    dp:SetPoint("RIGHT", wd, "LEFT", -4, 0)
    dp.tipText = "Deposit gold"
    wd.tipText = "Withdraw gold"
    typeRow.bankBtn, typeRow.warBtn, typeRow.depositGold, typeRow.withdrawGold = bankBtn, warBtn, dp, wd
    win:AddRow(typeRow, 22)

    -- Row 2: tabs
    local tabRow = CreateFrame("Frame", nil, win.frame)
    tabRow:Hide()
    win.tabRow = tabRow
    tabRow.buttons = {}
    local allBtn = Bags.MakeTextButton(tabRow, "All", 30, function()
        Bank.selectedTab = nil
        win:RequestRefresh()
    end)
    allBtn:SetHeight(26)
    allBtn:SetPoint("LEFT", tabRow, "LEFT", 0, 0)
    tabRow.allBtn = allBtn
    -- Secure purchase button (Blizzard's own template handles the popup)
    local ok, buy = pcall(CreateFrame, "Button", nil, tabRow, "BankPanelPurchaseButtonScriptTemplate")
    if ok and buy then
        buy:SetSize(26, 26)
        local bd = CreateFrame("Frame", nil, buy, "BackdropTemplate")
        bd:SetAllPoints(buy)
        bd:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        bd:SetBackdropColor(0.04, 0.04, 0.045, 1)
        bd:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        bd:EnableMouse(false)
        local plus = bd:CreateFontString(nil, "OVERLAY")
        plus:SetFont(Bags.style.font or STANDARD_TEXT_FONT, 16, "OUTLINE")
        plus:SetPoint("CENTER")
        plus:SetText("+")
        buy:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(BANKSLOTPURCHASE or "Purchase tab", 1, 1, 1)
            GameTooltip:Show()
        end)
        buy:SetScript("OnLeave", function() GameTooltip:Hide() end)
        buy:Hide()
        tabRow.buy = buy
    end
    win:AddRow(tabRow, 26)

    -- Title bar actions
    win.sortBtn = win:AddTitleButton("Interface\\Icons\\INV_Pet_Broom", "Sort", function()
        if InCombatLockdown() or IsLocked(Bank.bankType) then return end
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        C_Container.SortBank(Bank.bankType)
    end)
    win.depositBtn = win:AddTitleButton("Interface\\Icons\\INV_Misc_Bag_10_Blue", "Deposit all eligible items", DepositAll)
end

local function UpdateBankChrome(win)
    local bankType = Bank.bankType
    local warbandOnly = IsWarbandOnly()
    local canBank = not warbandOnly and CanViewType(BankType.Character)
    local canWar = CanViewType(BankType.Account)

    -- keep the shown type valid
    if bankType == BankType.Character and not canBank and canWar then
        bankType = BankType.Account
        Bank.bankType = bankType
    elseif bankType == BankType.Account and not canWar and canBank then
        bankType = BankType.Character
        Bank.bankType = bankType
    end

    local tr = win.typeRow
    tr.bankBtn:SetShown(canBank)
    tr.warBtn:SetShown(canWar)
    tr.bankBtn:SetSelected(bankType == BankType.Character)
    tr.warBtn:SetSelected(bankType == BankType.Account)
    if not canBank then tr.warBtn:SetPoint("LEFT", tr, "LEFT", 0, 0) else tr.warBtn:SetPoint("LEFT", tr.bankBtn, "RIGHT", 4, 0) end
    local money = C_Bank.DoesBankTypeSupportMoneyTransfer(bankType)
    tr.depositGold:SetShown(money and true or false)
    tr.withdrawGold:SetShown(money and true or false)
    if money then
        local canDep = C_Bank.CanDepositMoney(bankType) and true or false
        local canWd = C_Bank.CanWithdrawMoney(bankType) and true or false
        tr.depositGold:SetEnabled(canDep)
        tr.depositGold:SetAlpha(canDep and 1 or 0.4)
        tr.withdrawGold:SetEnabled(canWd)
        tr.withdrawGold:SetAlpha(canWd and 1 or 0.4)
    end
    tr:Show()

    -- tabs
    local locked = IsLocked(bankType)
    Bank.tabData = (not locked and C_Bank.FetchPurchasedBankTabData(bankType)) or {}
    wipe(Bank.tabIDs)
    local valid = false
    for _, td in ipairs(Bank.tabData) do
        Bank.tabIDs[#Bank.tabIDs + 1] = td.ID
        if td.ID == Bank.selectedTab then valid = true end
    end
    if not valid then Bank.selectedTab = nil end

    local row = win.tabRow
    local prev = row.allBtn
    row.allBtn:SetSelected(Bank.selectedTab == nil)
    for i, td in ipairs(Bank.tabData) do
        local b = row.buttons[i]
        if not b then
            b = BuildTabButton(row, i)
            row.buttons[i] = b
        end
        b.tabID, b.tabName = td.ID, td.name
        b.tex:SetTexture(td.icon)
        b:ClearAllPoints()
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        if td.ID == Bank.selectedTab then
            local a = Bags.style.accent or { 0.2, 1, 0.6 }
            b:SetBackdropBorderColor(a[1], a[2], a[3], 1)
        else
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        b:Show()
        prev = b
    end
    for i = #Bank.tabData + 1, #row.buttons do row.buttons[i]:Hide() end
    if row.buy then
        local canBuy = not locked and C_Bank.CanPurchaseBankTab(bankType) and not C_Bank.HasMaxBankTabs(bankType)
        if canBuy then
            row.buy:SetAttribute("overrideBankType", bankType)
            row.buy:ClearAllPoints()
            row.buy:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            row.buy:Show()
        else
            row.buy:Hide()
        end
    end
    row:SetShown(not locked)

    -- title bar actions
    win.depositBtn:SetShown(C_Bank.DoesBankTypeSupportAutoDeposit(bankType) and not locked and true or false)
    win.sortBtn:SetShown(not locked and true or false)
end

local function UpdateBankFooter(win)
    local bankType = Bank.bankType
    if IsLocked(bankType) then
        win.freeText:SetText(bankType == BankType.Account and "|cffff6060Warband bank is locked|r" or "|cffff6060Bank is locked|r")
        win.goldText:SetText("")
        return
    end
    local free, total = 0, 0
    for _, id in ipairs(Bank.selectedTab and { Bank.selectedTab } or Bank.tabIDs) do
        total = total + C_Container.GetContainerNumSlots(id)
        free = free + (C_Container.GetContainerNumFreeSlots(id) or 0)
    end
    if #Bank.tabIDs == 0 then
        win.freeText:SetText("No tabs purchased")
    else
        win.freeText:SetText(("Free: %d/%d"):format(free, total))
    end
    if bankType == BankType.Account then
        win.goldText:SetText("Warband: " .. Gold(C_Bank.FetchDepositedMoney(bankType)))
    else
        win.goldText:SetText(Gold(GetMoney()))
    end
end

local function BankTitle()
    if Bank.bankType == BankType.Account then return "Warband Bank" end
    return (UnitName("player") or "") .. "'s Bank"
end

function Bags:CreateBankWindow()
    if bankWindow then return end
    bankWindow = Bags.NewWindow({
        name = "SuaviUI_BankFrame",
        kind = "bank",
        posKey = "bankPos",
        leftClickOnly = true,
        title = BankTitle,
        getBagList = function()
            if IsLocked(Bank.bankType) then return {} end
            if Bank.selectedTab then return { Bank.selectedTab } end
            return Bank.tabIDs
        end,
        getColumns = function(db) return db.bankColumns end,
        forceFlat = function() return Bank.selectedTab ~= nil end,
        setup = SetupBankChrome,
        updateChrome = UpdateBankChrome,
        updateFooter = UpdateBankFooter,
        onHide = function()
            if not Bank.closingFromEvent then
                C_Bank.CloseBankFrame()
            end
            Bags:SetBankMode(false)
            if moneyDialog then moneyDialog:Hide() end
            if Bank.bagsOpenedByBank then
                Bank.bagsOpenedByBank = false
                -- Blizzard's own close path: clears the "opened by BankFrame"
                -- marker and the open flags; our hook hides the bag window.
                Bank.closingBags = true
                if CloseAllBags then CloseAllBags(BankFrame) end
                local bw = Bags.bagWindow
                if bw and bw:IsShown() then bw:Hide() end
                Bank.closingBags = false
            end
        end,
    })
    Bags.bankWindow = bankWindow
end

---------------------------------------------------------------------------
-- Blizzard bank frame: hide while active
---------------------------------------------------------------------------
local bankHidden
local bankOrigParent

function Bags:HideBlizzardBank()
    if not BankFrame then return end
    bankHidden = bankHidden or CreateFrame("Frame")
    bankHidden:Hide()
    if not bankOrigParent then bankOrigParent = BankFrame:GetParent() end
    BankFrame:SetParent(bankHidden)
    -- ContainerFrame anchoring reads BankFrame:GetRight() whenever the frame's
    -- shown flag is set; a frame that never had points returns nil there.
    -- Normally the panel manager anchors it as soon as the bank opens; only
    -- seed a point if it somehow has none (never touch an existing layout).
    if BankFrame:GetNumPoints() == 0 then
        BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
end

function Bags:RestoreBlizzardBank()
    self:SetBankMode(false)
    if BankFrame and bankOrigParent then
        BankFrame:SetParent(bankOrigParent)
        bankOrigParent = nil
    end
end

---------------------------------------------------------------------------
-- Open / close from the bank interaction
---------------------------------------------------------------------------
local function DoOpenBank()
    if not Bags.active or not bankWindow then return end
    local warbandOnly = IsWarbandOnly()
    local wasShown = bankWindow:IsShown()
    if not wasShown then
        Bank.selectedTab = nil
        if warbandOnly or not CanViewType(BankType.Character) then
            Bank.bankType = BankType.Account
        else
            Bank.bankType = BankType.Character
        end
    elseif warbandOnly and Bank.bankType ~= BankType.Account then
        Bank.bankType = BankType.Account
    end
    Bags:SetBankMode(true)
    bankWindow:Show()
    -- bags open next to the bank (so items can be deposited). Go through
    -- Blizzard's open path so its open flags stay in step; our hook on
    -- OpenAllBags shows the bag window.
    local bw = Bags.bagWindow
    if bw and not bw:IsShown() then
        Bank.bagsOpenedByBank = true
        if OpenAllBags then OpenAllBags(BankFrame) end
        if not bw:IsShown() then bw:Show() end   -- Blizzard declined to open
    end
    bankWindow:RequestRefresh()
    -- slot data of the bank arrives a moment after the open event
    if not Bank.refreshTimer then
        Bank.refreshTimer = true
        C_Timer.After(0.3, function()
            Bank.refreshTimer = false
            if bankWindow:IsShown() then bankWindow:RequestRefresh() end
        end)
    end
end

-- BANKFRAME_OPENED and PLAYER_INTERACTION_MANAGER_FRAME_SHOW both announce the
-- same opening: collapse them into one open on the next frame.
local openPending = false
local function OpenBank()
    if openPending then return end
    openPending = true
    C_Timer.After(0, function()
        if not openPending then return end   -- closed in the meantime
        openPending = false
        DoOpenBank()
    end)
end

local function CloseBank()
    openPending = false
    if not bankWindow or not bankWindow:IsShown() then return end
    Bank.closingFromEvent = true
    bankWindow:Hide()
    Bank.closingFromEvent = false
end

local function IsBankInteraction(t)
    local PIT = Enum.PlayerInteractionType
    return t == PIT.Banker or t == PIT.CharacterBanker or t == PIT.AccountBanker
end

local handlers = Bags.handlers

handlers.BANKFRAME_OPENED = OpenBank
handlers.BANKFRAME_CLOSED = CloseBank
handlers.PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(t)
    if IsBankInteraction(t) then OpenBank() end
end
handlers.PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(t)
    if IsBankInteraction(t) then CloseBank() end
end

local function RefreshBank()
    if bankWindow and bankWindow:IsShown() then bankWindow:RequestRefresh() end
end
handlers.BANK_TABS_CHANGED = RefreshBank
handlers.BANK_TAB_SETTINGS_UPDATED = RefreshBank
handlers.PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = RefreshBank
handlers.PLAYERBANKSLOTS_CHANGED = RefreshBank
handlers.ACCOUNT_MONEY = function()
    if bankWindow and bankWindow:IsShown() then bankWindow:UpdateFooter() end
end
