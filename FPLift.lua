FPLift = LibStub("AceAddon-3.0"):NewAddon("FPLift", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local lwin = LibStub("LibWindow-1.1")
if not FPLiftDB then
	FPLiftDB = {}
end

FPLiftSettings = {}
FPLiftSettings["DEBUG"] = false
FPLiftSettings["DEBUG_MODE"] = false
FPLiftSettings["ROLL_TIMEOUT"] = 120 --seconds
FPLiftSettings["GIVE_LOOT_TIMEOUT"] = 3 --seconds
FPLiftSettings["PRUNE_TIME"] = 60 * 5 --seconds
FPLiftSettings["RollTypes"] = {}
FPLiftSettings["RollTypeList"] = {}

FPLiftData = {}
FPLiftData["currentLootIDs"] = {}
FPLiftData["currentLoot"] = {}
FPLiftData["giveLootRequests"] = {}

local currentLootIDs = FPLiftData["currentLootIDs"]
local currentLoot = FPLiftData["currentLoot"]
local giveLootRequests = FPLiftData["giveLootRequests"]
local RollTypes = FPLiftSettings["RollTypes"]
local RollTypeList = FPLiftSettings["RollTypeList"]
local lootWindowOpen = false
local lootCache = {}

local RollType = nil

RollType = {}
RollType["order"] = 0
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\FPLift\Textures\Roll-Lift-Up]]
RollType["textureDown"] = [[Interface\AddOns\FPLift\Textures\Roll-Lift-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\FPLift\Textures\Roll-Lift-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Lift"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 1
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\FPLift\Textures\Roll-Main-Up]]
RollType["textureDown"] = [[Interface\AddOns\FPLift\Textures\Roll-Main-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\FPLift\Textures\Roll-Main-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Main Spec"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 2
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\FPLift\Textures\Roll-Offspec-Up]]
RollType["textureDown"] = [[Interface\AddOns\FPLift\Textures\Roll-Offspec-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\FPLift\Textures\Roll-Offspec-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Off Spec"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 3
RollType["button"] = true
RollType["textureUp"] = [[Interface\AddOns\FPLift\Textures\Roll-Transmog-Up]]
RollType["textureDown"] = [[Interface\AddOns\FPLift\Textures\Roll-Transmog-Down]]
RollType["textureHighlight"] = [[Interface\AddOns\FPLift\Textures\Roll-Transmog-Highlight]]
RollType["shouldRoll"] = true
RollType["type"] = "Transmog"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 4
RollType["button"] = true
RollType["textureUp"] = [[Interface\Buttons\UI-GroupLoot-Pass-Up]]
RollType["textureDown"] = [[Interface\Buttons\UI-GroupLoot-Pass-Down]]
RollType["textureHighlight"] = [[Interface\Buttons\UI-GroupLoot-Pass-Highlight]]
RollType["shouldRoll"] = false
RollType["type"] = "Pass"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

RollType = {}
RollType["order"] = 100
RollType["button"] = false
RollType["textureUp"] = [[Interface\AddOns\FPLift\Textures\Roll-Pending-Up]]
RollType["shouldRoll"] = false
RollType["type"] = "Pending"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)


RollType = {}
RollType["order"] = 101
RollType["button"] = false
RollType["textureUp"] = [[Interface\COMMON\icon-noloot]]
RollType["shouldRoll"] = false
RollType["type"] = "No response"
RollTypes[RollType["type"]] = RollType
table.insert(RollTypeList, RollType)

-- comm
local AceCommPrefix = "FPLift"
local nextCommMessageID = 1
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("FPLift", {
	type = "launcher",
	text = "FPLift",
	icon = [[Interface\Icons\inv_misc_dice_01]],
	OnClick = function(self, button)
		if button == "LeftButton" then
			if not FPLift:DidRollOnAllItems() then
				FPLift:CreatePendingRollsFrame()
			end
		elseif button == "RightButton" then
			if IsShiftKeyDown() then
				if FPLift_RollSummaryFrame then
					FPLift:GoToRollSummaryLoot(1)
					if FPLift_RollSummaryFrame:IsVisible() then
						FPLift_RollSummaryFrame:Hide()
					end
				end

				local player = GetUnitName("player", true)
				if not string.find(player, "-") then
					player = player.."-"..GetRealmName()
				end

				local toRemove = {}
				for lootID, lootObj in pairs(currentLoot) do
					local rollObj = lootObj["rolls"][player]
					if rollObj["type"] ~= "Pending" then
						table.insert(toRemove, lootObj)
					end
				end

				for _, lootObj in pairs(toRemove) do
					FPLift:RemoveLoot(lootObj)
				end
			else
				if next(currentLootIDs) ~= nil then
					FPLift:GoToFirstUnassigned()
					FPLift:CreateRollSummaryFrame()
				end
			end
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddLine("FPLift")
		tt:AddLine(" ")
		tt:AddLine("LMB: Pending Rolls")
		tt:AddLine("RMB: Roll Summary")
		tt:AddLine("Shift + RMB: Clear rolled on loot")
	end
})

local icon = LibStub("LibDBIcon-1.0")

-------
-- event handlers
-------

function FPLift:OnInitialize()
	self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
	self:RegisterBucketEvent("LOOT_READY", 0.25, "OnLootOpened")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
	self:RegisterEvent("LOOT_SLOT_CLEARED", "OnLootSlotCleared")
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")

	self:RegisterComm(AceCommPrefix)

	self:RegisterChatCommand("FPLift", "OnSlashCommand")
	self:RegisterChatCommand("FPL", "OnSlashCommand")

	self.db = LibStub("AceDB-3.0"):New("FPLiftDB", {
		profile = {
			minimap = {
				hide = false
			}
		}
	})

	icon:Register("FPLift", LDB, self.db.profile.minimap)
end

function FPLift:OnDisable()
	self:UnregisterAllEvents()
end

function FPLift:OnAddonLoaded(event, addon)
	if addon == "Aurora" then
		FPLift.AuroraF, FPLift.AuroraC = unpack(Aurora)
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function FPLift:OnSlashCommand(input)
end

function FPLift:OnLootOpened()
	lootWindowOpen = true
	if not self:IsMasterLooter() then
		return
	end
	lootCache = self:CacheLootSlots()

	local newLoot = {}
	local newLootIDs = {}

	local numLootItems = GetNumLootItems()
	local threshold = self:GetLootThreshold()
	for i = 1, numLootItems do
		local texture, item, quantity, quality, locked = GetLootSlotInfo(i)
		local lootSlotType = GetLootSlotType(i)

		if not locked and lootSlotType == 1 and quality >= threshold and quantity == 1 then
			local link = GetLootSlotLink(i)
			local corpseGUID = GetLootSourceInfo(i)
			local lootID = self:GetLootID(link, corpseGUID)

			if corpseGUID then
				if currentLoot[lootID] == nil then
					local lootObj = {}
					lootObj["link"] = link
					lootObj["lootID"] = lootID
					lootObj["quantity"] = 1

					local rolls = {}
					for _, player in pairs(self:GetLootEligiblePlayers(i)) do
						local rollObj = {}
						rollObj["player"] = player
						rollObj["type"] = "Pending"
						rolls[player] = rollObj
					end
					lootObj["rolls"] = rolls

					table.insert(currentLootIDs, lootID)
					currentLoot[lootID] = lootObj
					table.insert(newLoot, lootObj)
					table.insert(newLootIDs, lootID)
				elseif self:contains(newLootIDs, lootID) then
					lootObj = currentLoot[lootID]
					lootObj["quantity"] = lootObj["quantity"] + 1
				end
			end
		end
	end

	if next(newLoot) ~= nil then
		local sendObj = {}
		sendObj["loot"] = newLoot
		sendObj["timeout"] = FPLiftSettings["ROLL_TIMEOUT"]
		self:CommMessage("RollsRequest", sendObj, "RAID")
		for _, lootObj in pairs(newLoot) do
			lootObj["players"] = {}
			lootObj["timeoutStart"] = GetTime()
			lootObj["timeoutEnd"] = lootObj["timeoutStart"] + FPLiftSettings["ROLL_TIMEOUT"]
			lootObj["rollTimeoutTimer"] = self:ScheduleTimer(function()
				local updated = false
				for player, rollObj in pairs(lootObj["rolls"]) do
					if rollObj["type"] == "Pending" then
						rollObj["type"] = "No response"

						local sendObj = {}
						sendObj["lootID"] = lootObj["lootID"]
						sendObj["type"] = rollObj["type"]
						sendObj["player"] = player
						FPLift:CommMessage("Roll", sendObj, "RAID")
						updated = true
					end
				end
				if updated then
					FPLift:UpdatePendingRollsFrame(true)
					FPLift:UpdateRollSummaryFrame()
				end
			end, FPLiftSettings["ROLL_TIMEOUT"])
		end
		self:CreatePendingRollsFrame()
		self:UpdateRollSummaryFrame()
	end
end

function FPLift:OnLootClosed()
	lootWindowOpen = false
	if not self:IsMasterLooter() then
		return
	end
	lootCache = {}

	for _, obj in pairs(giveLootRequests) do
		self:CancelTimer(obj["timer"])
	end
	table.wipe(giveLootRequests)
end

function FPLift:OnLootSlotCleared(event, slotIndex)
	if not self:IsMasterLooter() then
		return
	end

	local obj = giveLootRequests[slotIndex]
	if obj then
		giveLootRequests[slotIndex] = nil
		self:GiveMasterLootItem_Callback(obj["player"], obj["lootObj"], obj["callback"], nil)
	else
		local lootID = lootCache[slotIndex]
		if lootID then
			local lootObj = currentLoot[lootID]
			if lootObj then
				local sendObj = {}
				sendObj["lootID"] = lootID
				self:CommMessage("LootGivenManually", sendObj, "RAID")

				if lootObj["quantity"] > 1 then
					lootObj["quantity"] = lootObj["quantity"] - 1
					self:UpdateRollSummaryFrame(lootID)
				else
					self:RemoveLoot(lootObj)
					self:UpdateRollSummaryFrame()
				end
				self:UpdatePendingRollsFrame(true)
			end
		end
	end

	lootCache = self:CacheLootSlots()
end

function FPLift:OnItemInfoReceived()
	self:UpdatePendingRollsFrame()
	self:UpdateRollSummaryFrame()
end

function FPLift:OnCommReceived(prefix, data, distribution, sender)
	local one = libCE:Decode(data)
	if not string.find(sender, "-") then
		sender = sender.."-"..GetRealmName()
	end

	local two, message = libC:Decompress(one)
	if not two then
		self:DebugPrint("OnCommReceived: Error decompressing: "..message)
		return
	end

	local success, final = libS:Deserialize(two)
	if not success then
		self:DebugPrint("OnCommReceived: Error deserializing: "..final)
		return
	end

	local player = GetUnitName("player", true)
	if not string.find(player, "-") then
		player = player.."-"..GetRealmName()
	end
	if sender == player then
		return
	end
	self:OnCommMessage(final["Type"], final["Body"], distribution, sender)
end

function FPLift:OnCommMessage(type, obj, distribution, sender)
	if type == "RollsRequest" then
		self:OnRollsRequestReceived(obj, sender)
	elseif type == "Roll" then
		self:OnRollReceived(obj, sender)
	elseif type == "RollResponse" then
		self:OnRollResponseReceived(obj, sender)
	elseif type == "GiveLoot" then
		self:OnGiveLootReceived(obj)
	elseif type == "LootGivenManually" then
		self:OnLootGivenManuallyReceived(obj)
	end
end

function FPLift:OnRollsRequestReceived(obj, sender)
	for _, lootObj in pairs(obj["loot"]) do
		local lootID = lootObj["lootID"]
		if currentLoot[lootID] then
			self:RemoveLoot(lootObj)
		end
		table.insert(currentLootIDs, lootID)
		currentLoot[lootID] = lootObj
		lootObj["players"] = {}
		lootObj["timeoutStart"] = GetTime()
		lootObj["timeoutEnd"] = lootObj["timeoutStart"] + obj["timeout"]
	end

	if not FPLift:DidRollOnAllItems() then
		self:CreatePendingRollsFrame()
	end
end

function FPLift:OnRollReceived(obj, sender)
	local lootObj = currentLoot[obj["lootID"]]
	if not lootObj then
		--self:DebugPrint("Received roll for loot "..obj["lootID"]..", but we don't know about this item.")
		return
	end

	if not obj["player"] then
		obj["player"] = sender
	end

	local rollObj = lootObj["rolls"][obj["player"]]
	rollObj["type"] = obj["type"]

	if self:IsMasterLooter() then
		if RollTypes[obj["type"]]["shouldRoll"] then
			rollObj["value"] = random(100)
			local obj2 = {}
			obj2["lootID"] = obj["lootID"]
			obj2["player"] = obj["player"]
			obj2["type"] = obj["type"]
			obj2["value"] = rollObj["value"]
			self:CommMessage("RollResponse", obj2, "RAID")
		end
	end

	self:UpdatePendingRollsFrame(true)
	self:UpdateRollSummaryFrameForLoot(obj["lootID"])
end

function FPLift:OnRollResponseReceived(obj, sender)
	local lootObj = currentLoot[obj["lootID"]]
	if not lootObj then
		--self:DebugPrint("Received roll response for loot "..obj["lootID"]..", but we don't know about this item.")
		return
	end

	local rollObj = lootObj["rolls"][obj["player"]]
	rollObj["type"] = obj["type"]
	rollObj["value"] = obj["value"]

	self:UpdatePendingRollsFrame(true)
	self:UpdateRollSummaryFrameForLoot(obj["lootID"])
end

function FPLift:OnGiveLootReceived(obj)
	local lootObj = currentLoot[obj["lootID"]]
	if lootObj == nil then
		self:DebugPrint("Tried to give loot "..obj["lootID"]..", but there is no info on this item.")
		return
	end

	table.insert(lootObj["players"], obj["player"])
	if #(lootObj["players"]) == lootObj["quantity"] then
		lootObj["pruneAt"] = GetTime() + FPLiftSettings["PRUNE_TIME"]
		self:ScheduleTimer(function()
			FPLift:RemoveLootIfUIHidden(lootObj)
		end, FPLiftSettings["PRUNE_TIME"])
	end
	self:UpdateRollSummaryFrameForLoot(obj["lootID"])
end

function FPLift:OnLootGivenManuallyReceived(obj)
	local lootObj = currentLoot[obj["lootID"]]
	if lootObj == nil then
		self:DebugPrint("Tried to give loot "..obj["lootID"]..", but there is no info on this item.")
		return
	end

	if lootObj["quantity"] > 1 then
		lootObj["quantity"] = lootObj["quantity"] - 1
		self:UpdateRollSummaryFrame(obj["lootID"])
	else
		self:RemoveLoot(lootObj)
		self:UpdateRollSummaryFrame()
	end
	self:UpdatePendingRollsFrame(true)
end

function FPLift:RemoveLootIfUIHidden(lootObj)
	if FPLift_RollSummaryFrame and FPLift_RollSummaryFrame:IsVisible() then
		local visibleLootObj = self:GetCurrentRollSummaryLoot()
		if visibleLootObj["lootID"] == lootObj["lootID"] then
			return
		end
	end
	self:RemoveLoot(lootObj)
end

function FPLift:RemoveLoot(lootObj)
	local lootID = lootObj["lootID"]
	if lootObj["rollTimeoutTimer"] then
		self:CancelTimer(lootObj["rollTimeoutTimer"])
	end
	currentLoot[lootID] = nil
	table.remove(currentLootIDs, self:keyOf(currentLootIDs, lootID))
end

-------
-- debug-mode-aware functions
-------

function FPLift:GetLootThreshold()
	if FPLiftSettings["DEBUG_MODE"] then
		return 0
	end

	return GetLootThreshold()
end

function FPLift:IsMasterLooter()
	if FPLiftSettings["DEBUG_MODE"] then
		return true
	end

	return self:IsMasterLooter_Real()
end

function FPLift:GetLootEligiblePlayers(slotIndex)
	if FPLiftSettings["DEBUG_MODE"] then
		local player = GetUnitName("player", true)
		if not string.find(player, "-") then
			player = player.."-"..GetRealmName()
		end
		return { player }
	end

	local players = {}
	for i = 1, 40 do
		local player = GetMasterLootCandidate(slotIndex, i)
		if player ~= nil then
			if not string.find(player, "-") then
				player = player.."-"..GetRealmName()
			end
			table.insert(players, player)
		end
	end
	return players
end

-------
-- helper functions
-------

function FPLift:CacheLootSlots()
	local cache = {}
	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		local lootSlotType = GetLootSlotType(i)
		if lootSlotType == 1 then
			local link = GetLootSlotLink(i)
			local corpseGUID = GetLootSourceInfo(i)
			if corpseGUID then
				local lootID = self:GetLootID(link, corpseGUID)
				cache[i] = lootID
			end
		end
	end
	return cache
end

function FPLift:FindLootSlotForLootObj(lootObj)
	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		local link = GetLootSlotLink(i)
		local corpseGUID = GetLootSourceInfo(i)
		if corpseGUID then
			local lootID = self:GetLootID(link, corpseGUID)
			if lootID == lootObj["lootID"] then
				return i
			end
		end
	end
	return false
end

function FPLift:FindLootCandidateIndexForPlayer(slotIndex, player)
	for i = 1, 40 do
		local candidate = GetMasterLootCandidate(slotIndex, i)
		if candidate ~= nil then
			if not string.find(candidate, "-") then
				candidate = candidate.."-"..GetRealmName()
			end
			if candidate == player then
				return i
			end
		end
	end
	return false
end

function FPLift:GiveMasterLootItem(player, lootObj, callback)
	if self:IsMasterLooter_Real() then
		local lootSlotIndex = self:FindLootSlotForLootObj(lootObj)
		if not lootSlotIndex then
			if lootWindowOpen then
				callback("Couldn't find the item.")
			else
				callback("Loot window has to be open.")
			end
			return
		end

		local candidateIndex = self:FindLootCandidateIndexForPlayer(lootSlotIndex, player)
		if not candidateIndex then
			callback(player.." is not eligible for this item.")
			return
		end

		local obj = {}
		obj["player"] = player
		obj["lootObj"] = lootObj
		obj["callback"] = callback
		obj["timer"] = self:ScheduleTimer(function()
			if giveLootRequests[lootSlotIndex] and giveLootRequests[lootSlotIndex]["lootObj"]["lootID"] == lootObj["lootID"] then
				giveLootRequests[lootSlotIndex] = nil
				callback("Error while giving out loot.")
			end
		end, FPLiftSettings["GIVE_LOOT_TIMEOUT"])
		giveLootRequests[lootSlotIndex] = obj
		GiveMasterLoot(lootSlotIndex, candidateIndex)
	else
		self:GiveMasterLootItem_Callback(player, lootObj, callback, nil)
	end
end

function FPLift:GiveMasterLootItem_Callback(player, lootObj, callback, message)
	if message then
		callback(message)
	else
		local obj = {}
		obj["lootID"] = lootObj["lootID"]
		obj["player"] = player
		self:CommMessage("GiveLoot", obj, "RAID")

		table.insert(lootObj["players"], player)
		if #(lootObj["players"]) == lootObj["quantity"] then
			lootObj["pruneAt"] = GetTime() + FPLiftSettings["PRUNE_TIME"]
			self:ScheduleTimer(function()
				FPLift:RemoveLootIfUIHidden(lootObj)
			end, FPLiftSettings["PRUNE_TIME"])
		end

		callback(nil)
	end
end

function FPLift:IsMasterLooter_Real()
	if not IsInRaid() then
		return false
	end

	local method, partyMaster, raidMaster = GetLootMethod()
	return method == "master" and partyMaster == 0
end

function FPLift:AmIOnRollListForItem(lootObj)
	local player = GetUnitName("player", true)
	if not string.find(player, "-") then
		player = player.."-"..GetRealmName()
	end
	for rollPlayer, rollObj in pairs(lootObj["rolls"]) do
		if rollPlayer == player then
			return true
		end
	end
	return false
end

function FPLift:DidRollOnItem(lootObj)
	local player = GetUnitName("player", true)
	if not string.find(player, "-") then
		player = player.."-"..GetRealmName()
	end
	local rollObj = lootObj["rolls"][player]
	if rollObj == nil then
		return false
	end

	return rollObj["type"] ~= "Pending"
end

function FPLift:DidRollOnAllItems()
	for lootID, lootObj in pairs(currentLoot) do
		local player = GetUnitName("player", true)
		if not string.find(player, "-") then
			player = player.."-"..GetRealmName()
		end
		local rollObj = lootObj["rolls"][player]
		if rollObj and rollObj["type"] == "Pending" then
			return false
		end
	end
	return true
end

function FPLift:DidEveryoneRollOnItem(lootObj)
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == "Pending" then
			return false
		end
	end

	return true
end

function FPLift:GetRollsOfType(lootObj, type)
	local rolls = {}
	for player, rollObj in pairs(lootObj["rolls"]) do
		if rollObj["type"] == type then
			table.insert(rolls, rollObj)
		end
	end
	return rolls
end

function FPLift:GetSortedRolls(lootObj)
	local rolls = {}
	for player, rollObj in pairs(lootObj["rolls"]) do
		table.insert(rolls, rollObj)
	end
	return self:SortRolls(rolls)
end

function FPLift:SortRolls(rolls)
	sort(rolls, function(a, b)
		local aTypeObj = RollTypes[a["type"]]
		local bTypeObj = RollTypes[b["type"]]
		if aTypeObj["order"] ~= bTypeObj["order"] then
			return aTypeObj["order"] < bTypeObj["order"]
		else
			if aTypeObj["shouldRoll"] then
				local aVal = a["value"] or 0
				local bVal = b["value"] or 0
				if aVal ~= vVal then
					return aVal > bVal
				else
					return a["player"] < b["player"]
				end
			else
				return a["player"] < b["player"]
			end
		end
	end)
	return rolls
end

function FPLift:GetCorpseID(corpseGUID)
	local _, _, _, _, _, mobID, spawnID = strsplit("-", corpseGUID);
	return mobID..":"..spawnID
end

function FPLift:GetLootID(link, corpseGUID)
	return self:GetCorpseID(corpseGUID)..":"..string.gsub(link, "%|h.*$", "")
end

function FPLift:RequestItemInfo(link)
	requestedItemInfo = true
	return GetItemInfo(link)
end

function FPLift:CommMessage(type, obj, distribution, target)
	local message = {}
	message["Type"] = type
	message["ID"] = nextCommMessageID
	message["Body"] = obj

	local one = libS:Serialize(message)
	local two = libC:CompressHuffman(one)
	local final = libCE:Encode(two)

	nextCommMessageID = nextCommMessageID + 1
	FPLift:SendCommMessage(AceCommPrefix, final, distribution, target, "NORMAL")
end

function FPLift:FindActiveChatEditbox()
	for i = 1, 10 do
		local frame = _G["ChatFrame"..i.."EditBox"]
		if frame:IsVisible() then
			return frame
		end
	end
	return nil
end

function FPLift:InsertInChatEditbox(text)
	local chatEditbox = self:FindActiveChatEditbox()
	if chatEditbox then
		chatEditbox:Insert(text)
	end
end

function FPLift:DebugPrint(message)
	if FPLiftSettings["DEBUG"] then
		if type(message) == "table" then
			print("FPLift:")
			self:tprint(message, 1)
		else
			print("FPLift: "..tostring(message))
		end
	end
end

function FPLift:tprint(tbl, indent)
	if not indent then
		indent = 0
	end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent)..k..": "
		if type(v) == "table" then
			print(formatting)
			self:tprint(v, indent + 1)
		elseif type(v) == 'boolean' then
			print(formatting..tostring(v))      
		else
			print(formatting..v)
		end
	end
end

function FPLift:sizeof(tbl)
	local count = 0
	for _, _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

function FPLift:keyOf(tbl, value)
	for k, v in pairs(tbl) do
		if v == value then
			return k
		end
	end
	return nil
end

function FPLift:contains(tbl, value)
	return self:keyOf(tbl, value) ~= nil
end

function FPLift:SetupWindowFrame(frame)
	lwin.RegisterConfig(frame, self.db.profile, {
		prefix = frame:GetName().."_"
	})
	lwin.RestorePosition(frame)
	lwin.MakeDraggable(frame)
end