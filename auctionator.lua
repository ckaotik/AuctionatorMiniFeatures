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

]]

-- "_"..sd.stackSize.."_"..sd.buyoutPrice.."_"..ownerCode..dataType
local showGlobalPriceChanges = true
local showPlayerPriceChanges = true


function addon:Auctionator_GetAuctionState(itemLink)
	local itemName = GetItemInfo(itemLink)
	local today = Atr_GetScanDay_Today()

	local auctionCount, referencePrice, isFreshData
	local data = Atr_FindScan(gAtrZC.ItemIDStrfromLink(itemLink), itemName)

	if data and data.whenScanned ~= 0 then
		referencePrice = data.yourWorstPrice
		auctionCount = data.numMatchesWithBuyout
		isFreshData = true
	else
		data = gAtr_ScanDB[itemName]
		referencePrice = data and data["H"..today]
		auctionCount = referencePrice and -1 or nil
	end

	local previousPrice
	for history = today-1, today - AUCTIONATOR_DB_MAXHIST_DAYS, -1 do
		previousPrice = data and data["H"..history]
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
		local newTextRight = "|cFF"..(available ~= 0 and "FFFFFF" or "FF0000")
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
	local up, down = " |TInterface\\BUTTONS\\Arrow-Up-Up:0|t", " |TInterface\\BUTTONS\\Arrow-Down-Up:0|t"
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

	addon:Auctionator_UpdateTooltip(tip, numAvailable, itemPrice, changeIndicator, append)
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
