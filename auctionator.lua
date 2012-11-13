local _, addon = ...
AuctionatorMiniFeatures = addon

-- ================================================
-- Auctionator Improvements
-- ================================================
--[[
1) To add Auctionator's data to the merchant item's tooltips, add this to the end of AuctionatorHints.lua:

Atr_ShowTipWithPricing = ShowTipWithPricing -- [CKAOTIK]

----------------------------------------------

2) To show seller names in the auction house, change this in Auctionator.lua around line ~3669:
	change this old code:

if (data.yours) then
	data.yours = "("..ZT("yours")..")"
elseif (data.altname) then
	data.yours = "("..data.altname..")"
end

	to this new code:

--[CKAOTIK]
lineEntry_text:SetText(entrytext);
local textWidth = lineEntry_text:GetStringWidth()
local spacing = textWidth < 130 and "|T"..""..":1:"..(130-textWidth).."|t" or " "

if (data.yours) then
	data.owner = "("..ZT("yours")..")"
elseif (data.altname) then
	data.owner = "("..data.altname..")"
end
entrytext = entrytext .. spacing .. (data.owner or "")
--[/CKAOTIK]

3) change this in AuctionatorScan.lua around line ~978:
	change this old code:

data.yours			= ownerCode == "y";

	to this new code:

data.yours			= ownerCode == "y";
data.owner			= sd.owner --[CKAOTIK]

4) To better integrate Battle Pets into the UI, you need to change Auctionator.lua line ~112:

local gCurrentPane;

	to this new code:

-- local gCurrentPane;

]]

local showGlobalPriceChanges = true
local showPlayerPriceChanges = true


-- battle pet fixes
local orig_Atr_GetBondType = Atr_GetBondType
Atr_GetBondType = function(itemID)
	if type(itemID) ~= "number" then
		return ATR_BINDTYPE_UNKNOWN
	end
	return orig_Atr_GetBondType(itemID)
end
local orig_Atr_SetTextureButton = Atr_SetTextureButton
Atr_SetTextureButton = function(elementName, count, itemlink)
	local texture = GetItemIcon (itemlink)
	if texture then
		Atr_SetTextureButtonByTexture(elementName, count, texture)
		return
	end

	if not itemLink and not gCurrentPane then
		orig_Atr_SetTextureButton(elementName, count, itemLink)
		return
	end
	itemLink = itemLink or gCurrentPane.activeScan.itemLink
	if not texture and itemLink and string.find(itemLink, "Hbattlepet") then
		local speciesID = gAtrZC.ItemIDfromLink(itemLink)
		_, texture = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
	end
	Atr_SetTextureButtonByTexture(elementName, count, texture)
end
AtrScan.UpdateItemLink = function(self, itemLink)
	if (itemLink and self.itemLink == nil) then
		local _, _, quality, iLevel, _, sType, sSubType = GetItemInfo(itemLink);
		if string.find(itemLink, "Hbattlepet") then
			local speciesID, itemData = gAtrZC.ItemIDfromLink(itemLink)
			iLevel = tonumber(string.sub(itemData, 1, 2))
			quality = tonumber(string.sub(itemData, 3, 4))

			_, _, sSubType = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
			sSubType = select(sSubType, GetAuctionItemSubClasses(11))
			sType = select(11, GetAuctionItemClasses())
		end

		self.itemLink 		= itemLink;
		self.itemQuality	= quality;
		self.itemLevel		= iLevel;
		self.itemClass		= Atr_ItemType2AuctionClass (sType);
		self.itemSubclass	= Atr_SubType2AuctionSubclass (self.itemClass, sSubType);
		self.itemTextColor = { 0.75, 0.75, 0.75 };

		if (quality == 0)	then	self.itemTextColor = { 0.6, 0.6, 0.6 };	end
		if (quality == 1)	then	self.itemTextColor = { 1.0, 1.0, 1.0 };	end
		if (quality == 2)	then	self.itemTextColor = { 0.2, 1.0, 0.0 };	end
		if (quality == 3)	then	self.itemTextColor = { 0.0, 0.5, 1.0 };	end
		if (quality == 4)	then	self.itemTextColor = { 0.7, 0.3, 1.0 };	end
	end
end
local orig_auctionator_ChatEdit_InsertLink = auctionator_ChatEdit_InsertLink
auctionator_ChatEdit_InsertLink = function(text)
	if (text and AuctionFrame:IsShown() and IsShiftKeyDown() and Atr_IsTabSelected(BUY_TAB)) then
		local item;
		if strfind(text, "battlepet", 1, true) then
			local speciesID = gAtrZC.ItemIDfromLink(text)
			item = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
		end
		if item then
			Atr_SetSearchText(item);
			Atr_Search_Onclick();
			return true;
		end
	end
	return orig_auctionator_ChatEdit_InsertLink(text);
end
Atr_GetSellItemInfo = function()
	local auctionItemName, auctionTexture, auctionCount = GetAuctionSellItemInfo()
	local auctionItemLink = nil
	if (auctionItemName == nil) then
		auctionItemName = ""
		auctionCount	= 0
	else
		local hasCooldown, speciesID, level, breedQuality, maxHealth, power, speed, name = AtrScanningTooltip:SetAuctionSellItem()
		if (speciesID and speciesID > 0) then
			auctionItemLink = string.format("%s\124Hbattlepet:%d:%d:%d:%d:%d:%d:%d\124h[%s]\124h\124r", ITEM_QUALITY_COLORS[breedQuality].hex, speciesID, level, breedQuality, maxHealth, power, speed, name, auctionItemName)
		else
			local name;
			name, auctionItemLink = AtrScanningTooltip:GetItem();
			if (auctionItemLink == nil) then
				return "",0,nil;
			end
		end
	end
	return auctionItemName, auctionCount, auctionItemLink;
end
Atr_GetAuctionBuyout = function(item)
	local sellval
	if (type(item) == "string") then
		sellval = Atr_GetAuctionPrice(item);
	end
	if (sellval == nil) then
		local name = GetItemInfo(item);
		if strfind(item, "battlepet", 1, true) then
			local speciesID = gAtrZC.ItemIDfromLink(item)
			name = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
		end
		if (name) then sellval = Atr_GetAuctionPrice(name) end
	end
	return sellval or (origGetAuctionBuyout and origGetAuctionBuyout(item)) or nil
end
gAtrZC.ItemIDfromLink = function(itemLink)
	if not itemLink then return 0,0,0 end
	local found, _, linkType, itemString = string.find(itemLink, "^|c%x+|H(.-):(.+)|h%[.*%]")
	local itemID, suffixID, uniqueID, level, quality
	if linkType == "item" then
		itemID, _, _, _, _, _, suffixID, uniqueID = strsplit(":", itemString)
		uniqueID = tonumber(uniqueID)
	else
		itemID, level, quality = strsplit(':', itemString)
		itemID = -1 * itemID
		suffixID = string.format("%02d%02d", level, quality)
		uniqueID = itemString
	end
	return tonumber(itemID), tonumber(suffixID), uniqueID;
end
Atr_GetNumItemInBags = function(theItemName)
	local numItems = 0;
	local itemLink, bagID, slotID;
	for bagID = 0, NUM_BAG_SLOTS do
		for slotID = 1, GetContainerNumSlots(bagID) or 0 do
			itemLink = GetContainerItemLink(bagID, slotID)
			if itemLink then
				if string.find(itemLink, "Hbattlepet") then
					local speciesID = gAtrZC.ItemIDfromLink(itemLink)
					itemName = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
				else
					itemName = GetItemInfo(itemLink)
				end

				local texture, itemCount = GetContainerItemInfo(bagID, slotID)
				if (itemName == theItemName) then
					numItems = numItems + itemCount
				end
			end
		end
	end
	return numItems;
end

local function ShowButtonTooltip(anchor, itemLink, num)
	if itemLink and string.find(itemLink, "Hbattlepet") then
		local _, _, itemData = gAtrZC.ItemIDfromLink(itemLink)
		local data = { strsplit(":", itemData) }
		for k,v in pairs(data) do
			data[k] = tonumber(v)
		end
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT", -280)
		BattlePetToolTip_Show(unpack(data))
	elseif itemLink then
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT", -280)
		GameTooltip:SetHyperlink(itemLink, num or 1)
	end
end
local function HideButtonTooltip()
	GameTooltip:Hide();
	BattlePetTooltip:Hide()
end

Atr_ShowLineTooltip = function(self)
	ShowButtonTooltip(self, self.itemLink)
end
Atr_HideLineTooltip = function()
	HideButtonTooltip()
end
local orig_Atr_ShowRecTooltip = Atr_ShowRecTooltip
Atr_ShowRecTooltip = function()
	if not gCurrentPane then orig_Atr_ShowRecTooltip() return end

	local link = gCurrentPane.activeScan.itemLink;
	local num  = Atr_StackSize();
	if (not link) then
		link = gJustPosted.ItemLink;
		num  = gJustPosted.StackSize;
	end
	if (link) then
		if (num < 1) then num = 1; end;
		gCurrentPane.tooltipvisible = true;
		ShowButtonTooltip(Atr_RecommendItem_Tex, link, num)
	end
end
local orig_Atr_HideRecTooltip = Atr_HideRecTooltip
Atr_HideRecTooltip = function()
	if not gCurrentPane then orig_Atr_HideRecTooltip() return end

	gCurrentPane.tooltipvisible = nil;
	HideButtonTooltip()
end

-- /////////////

function addon:Auctionator_GetAuctionState(itemLink)
	local itemName = GetItemInfo(itemLink)
	if string.find(itemLink, "Hbattlepet") then
		local speciesID = gAtrZC.ItemIDfromLink(itemLink)
		itemName = C_PetJournal.GetPetInfoBySpeciesID(-1*speciesID)
	end

	local today = Atr_GetScanDay_Today()

	local auctionCount, referencePrice, isFreshData
	local data = Atr_FindScan(gAtrZC.ItemIDStrfromLink(itemLink), itemName)

	if data and data.whenScanned ~= 0 then
		referencePrice = data.yourWorstPrice
		auctionCount = data.numMatchesWithBuyout
		isFreshData = true
	else
		data = gAtr_ScanDB[itemName]
		referencePrice = data and (data["L"..today] or data["H"..today])
		auctionCount = referencePrice and -1 or nil
	end

	local previousPrice
	for history = today-1, today - AUCTIONATOR_DB_MAXHIST_DAYS, -1 do
		previousPrice = data and (data["L"..today] or data["H"..history])
		if previousPrice then
			break
		end
	end

	return previousPrice, referencePrice, auctionCount, isFreshData
end

function addon:Auctionator_UpdateTooltip(tooltip, available, itemPrice, changeIndicator, append)
	if IsModifierKeyDown() then return end

	local tip = tooltip:GetName()
	local left, right, textLeft, textRight, found, count

	for i = 1, tooltip:NumLines() do
		left, right = _G[tip.."TextLeft"..i], _G[tip.."TextRight"..i]
		textLeft, textRight = left:GetText(), right:GetText()

		local isAuctionLine = textLeft and textLeft == ZT("Auction")
		if isAuctionLine then
			if textRight and string.match(textRight, "^|cFFFFFFFF.*") then
				found = true
				break
			end
		end
	end

	if found then
		local newTextRight = "|cFF"..((available and available ~= 0) and "FFFFFF" or "FF0000")
			.. (itemPrice and gAtrZC.priceToMoneyString(itemPrice) or ZT("unknown")) .. "|r"
			.. changeIndicator

		if append then
			right:SetText(textRight .. newTextRight)
		else
			right:SetText(newTextRight)
		end
	end
end

function addon:Auctionator_GetCompareValue(itemLink)
	local itemName = GetItemInfo(itemLink)
	if Atr_HasHistoricalData(itemName) then
		local historyData = {}
		for tag, hist in pairs(AUCTIONATOR_PRICING_HISTORY[itemName]) do
			if (tag ~= "is") then
				local when, type, price = ParseHist(tag, hist);
				local entry = {};

				entry.itemPrice		= price
				entry.when			= when

				table.insert(historyData, entry)
			end
		end
		table.sort(historyData, Atr_SortHistoryData)

		return historyData[1] and historyData[1].itemPrice
	end
end

local up, down = " |TInterface\\BUTTONS\\Arrow-Up-Up:0|t", " |TInterface\\BUTTONS\\Arrow-Down-Up:0|t"
function addon:UpdateAuctionatorTooltip(tip, itemLink)
	if not (tip and itemLink) or AUCTIONATOR_A_TIPS ~= 1 then return end

	-- we don't care about unsellable items
	local itemID = tonumber( (gAtrZC.ItemIDfromLink(itemLink)) )
	local bonding = Atr_GetBondType(itemID)
	if not (bonding == ATR_CAN_BE_AUCTIONED or bonding == ATR_BINDTYPE_UNKNOWN)then return end

	-- historyData = the price we asked for this item the last time
	-- prevPrice = the price seen in previous scans
	local prevPrice, price, numAvailable, freshData = addon:Auctionator_GetAuctionState(itemLink)
	local itemPrice = price or Atr_GetAuctionBuyout(itemLink)
	local historyData = addon:Auctionator_GetCompareValue(itemLink)

	if not itemPrice then return end

	local changeIndicator = ""
	-- global pricing changes
	if showGlobalPriceChanges then
		if prevPrice and itemPrice > prevPrice then
			changeIndicator = changeIndicator .. up
		elseif prevPrice and itemPrice < prevPrice then
			changeIndicator = changeIndicator .. down
		end
	end

	-- player pricing changes
	if showPlayerPriceChanges then
		if historyData and itemPrice > historyData then
			changeIndicator = changeIndicator .. up
		elseif historyData and itemPrice < historyData then
			changeIndicator = changeIndicator .. down
		end
	end

	if tip.AddLine then
		addon:Auctionator_UpdateTooltip(tip, numAvailable, itemPrice, changeIndicator, append)
	elseif tip.value then
		tip.value:SetText("|cFF"..((numAvailable and numAvailable ~= 0) and "FFFFFF" or "FF0000")
			.. (itemPrice and gAtrZC.priceToMoneyString(itemPrice) or ZT("unknown")) .. "|r"
			.. changeIndicator)
	end
end

-- bunch of tooltip hooks
hooksecurefunc(GameTooltip, "SetMerchantItem", function(tip, merchantID)
	if Atr_ShowTipWithPricing then
		local itemLink = GetMerchantItemLink(merchantID)
		local _, _, _, num = GetMerchantItemInfo(merchantID)
		Atr_ShowTipWithPricing(tip, itemLink, num)
		AuctionatorMiniFeatures:UpdateAuctionatorTooltip(tip, itemLink)
	end
end)

hooksecurefunc(GameTooltip, "SetBagItem", function(tip, bag, slot)
	local link = GetContainerItemLink(bag, slot)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetAuctionItem", function (tip, type, index)
	local link = GetAuctionItemLink(type, index)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetAuctionSellItem", function (tip)
	local name, _, count = GetAuctionSellItemInfo()
	local __, link = GetItemInfo(name)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetLootItem", function (tip, slot)
	if LootSlotHasItem(slot) then
		local link, _, num = GetLootSlotLink(slot)
		addon:UpdateAuctionatorTooltip(tip, link)
	end
end)
hooksecurefunc (GameTooltip, "SetLootRollItem", function (tip, slot)
	local link = GetLootRollItemLink(slot)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetInventoryItem", function (tip, unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetGuildBankItem", function (tip, tab, slot)
	local link = GetGuildBankItemLink(tab, slot)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetTradeSkillItem", function (tip, skill, id)
	local link = id and GetTradeSkillReagentItemLink(skill, id) or GetTradeSkillItemLink(skill)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetTradePlayerItem", function (tip, id)
	local link = GetTradePlayerItemLink(id)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetTradeTargetItem", function (tip, id)
	local link = GetTradeTargetItemLink(id)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetQuestItem", function (tip, type, index)
	local link = GetQuestItemLink(type, index)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetQuestLogItem", function (tip, type, index)
	local link = GetQuestLogItemLink(type, index)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetInboxItem", function (tip, index, attachIndex)
	local link = GetInboxItemLink(index, attachIndex)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetSendMailItem", function (tip, id)
	local name, _, num = GetSendMailItem(id)
	local name, link = GetItemInfo(name)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (GameTooltip, "SetHyperlink", function (tip, itemstring, num)
	local name, link = GetItemInfo (itemstring)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc (ItemRefTooltip, "SetHyperlink", function (tip, itemstring)
	local name, link = GetItemInfo (itemstring)
	addon:UpdateAuctionatorTooltip(tip, link)
end)
hooksecurefunc("BattlePetTooltipTemplate_SetBattlePet", function(tip, data)
	local link = string.format("%s\124Hbattlepet:%d:%d:%d:%d:%d:%d:%d\124h[%s]\124h\124r", ITEM_QUALITY_COLORS[data.breedQuality].hex, data.speciesID, data.level, data.breedQuality, data.maxHealth, data.power, data.speed, data.name, data.name)

	if not tip.value then
		local value = tip:CreateFontString(nil, "ARTWORK", "GameTooltipText")
		tip.value = value
	end
	if tip:GetName() == "FloatingBattlePetTooltip" then
		tip.value:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -12, 36)
	else
		tip.value:SetPoint("BOTTOMRIGHT", tip, "BOTTOMRIGHT", -12, 8)
	end
	addon:UpdateAuctionatorTooltip(tip, link)
end)
