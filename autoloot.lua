-- Idk this gave me the most frustration out of any API I've used from blizzard
-- a lot of inconsistencies and use of semi-colons even though Lua doesn't require them
-- I just got so fed up wiping out all the code and starting from zero again that I went on auto pilot
-- uses bangs from whispers to save a players color preference !color red
-- uses SavedVariables so change that if you use this.
-- hardcoded realm name "-Herod", because playernames are either PLAYERNAME or PLAYERNAME-REALM depending on what API is used
-- (What is continuity?), although if I stopped to think about it I could probably logically see where and why
-- due to cross-realm battlegrounds.

GlimmAUTOLOOT = true; --on/off

local Session = CreateFrame("FRAME");
Session.Items = {};

Session.MountColors = {
	"RED",
	"GREEN",
	"YELLOW",
	"BLUE",
};

Session.SpecialItems = {
  ["RESONATING CRYSTAL"] = true, --mounts
  ["COFFER KEY"] = false,
  ["SPIDER"] = false, --debug item
};

Session.enabled = false;


function Session:t_shuffle(table)
	local _tmp = {}
	for i = #table, 1, -1 do
		local j = math.random(i)
		table[i], table[j] = table[j], table[i]
		tinsert(_tmp, table[i])
	end
	return _tmp
end


function Session:RandomMountLoot(color)
	local _tmp = {}
	local tbl = GlimmUI_Character.GuildRequests
	for k,v in pairs(tbl) do
    k = strsplit("-", k)
		if v.Mount[color] and UnitInRaid(k) then
      tinsert(_tmp, k)
    end
	end

  local k={} --Yates shuffle.
  if _tmp[1] then k = self:t_shuffle(_tmp) end

	return k[1]
end


function Session:GetSpecialLoot(iname)
	local winner, color = nil, nil;

  for k,v in pairs(self.SpecialItems) do
    if iname:upper():match(k) and v then
      color = strsplit(" ", iname:upper())
      winner = self:RandomMountLoot(color)
      break
    end
  end

	if winner ~= nil then
		--print("Removing: "..tostring(winner).." from "..tostring(color).." pool")
		GlimmUI_Character.GuildRequests[winner.."-Herod"].Mount[color] = nil;
	end

	if not winner and color then
		return "ENDOFTHEROADBYBOYZIIMEN"
	else
  	return winner
	end
end


function Session:AwardItem(index, announce)
	local loot = self.Items[index]

	if loot.winner == "ENDOFTHEROADBYBOYZIIMEN" then
		print("Ignoring mount.");
		loot.looted = true;
		self:Clear(index, loot.name, false);
		self:AwardSlot(nil,nil,nil,"AwardItem");
		MasterLooterFrame:Hide()
		return;
	end

	for k, v in pairs(MasterLooterFrame) do
		 if tostring(k):match("player") then
			 if v.Name:GetText() == loot.winner then
				 if loot.special then
					 SendChatMessage(string.format("[IncisionRaid]: %s won %s", loot.winner, tostring(loot.link)--[[tostring(MasterLooterFrame.Item.ItemName:GetText())]]), "RAID")
				 elseif announce then
					 SendChatMessage(string.format("[IncisionRaid]: Storing %s for bidding later.", tostring(loot.link)), "RAID")
				 end

				 v:Click();
				 break;
			 end
			 --print(string.format("Widget[%s] Name: %s - id[%s]", tostring(k), tostring(v.Name:GetText()), tostring(v.id)))
		end
	end
end


function Session:Clear(index, name, all)
	if all then
		--print("Deleting all entries.")
		for k, v in pairs(self.Items) do
			if k ~= nil then self.Items[k] = nil end
		end
	else
		for k, v in pairs(self.Items) do
			if k == index and v.name == name then
				--print(string.format("Deleting id[%s] - Name[%s]", tostring(index), tostring(v.name)))
				self.Items[k] = nil;
				break;
			end
		end
	end
end


function Session:AwardSlot(index, name, quality, sender)
	if not sender then sender = "idk" end

	local Threshold = GetLootThreshold()
	for k, v in pairs(self.Items) do
		if v.name and not v.looted and v.quality >= Threshold and LootSlotHasItem(k) then
			index = k;
			name = v.name;
			quality = v.quality;
			self.Items[k].looted = true
			break;
		elseif v.name and v.looted and v.quality >= Threshold and LootSlotHasItem(k) then
			--print("Double loot attempt probably double fire double bubble.", sender);
			self:Clear(k, v.name, false) return;
		elseif v.name and not v.looted and not LootSlotHasItem(k) then
			--print(":::oh well", sender)
			self:Clear(k, v.name);
			self:AwardSlot(nil, nil, nil, "AwardSlot");
			return;
		elseif v.quality < Threshold and LootSlotHasItem(k) then
			--print(":::sigh", sender) --Can be an uncaught exception (INVENTORY FULL)
			LootSlot(k);
			return;
		elseif v.quality < Threshold and not LootSlotHasItem(k) then
			print("IF THIS EVER GETS CALLED CHECK IT OUT :: ", sender)
			return;
		end
	end

	if not index then return end --Due to rapid firing of events I caught a index=nil one time, not sure.

	local SpecialCondition = self:GetSpecialLoot(name)
	local loot = self.Items[index];

	if SpecialCondition ~= nil then
		loot.special = true;
		loot.winner = SpecialCondition;
	else
		loot.winner = UnitName("PLAYER");
	end
	if _G["LootButton"..index] then
		_G["LootButton"..index]:Click("RightButton");
	else
		-- I think this is another rapid fire bug, or just a FFA uncaught exception, found when looting a coffer chest in AQ40 attempt to call lootbutton nil.
		self:AwardSlot(nil, nil, nil, "LOOT_SLOT_CLEARED");
	end
end


function Session:NumItems(table)
	local count = 0;
	for k, v in pairs(table) do
		if k ~= nil then count = count + 1; end
	end

	return count;
end


function Session:AcceptLootAssignment()
	--Are you sure you want to loot [] to PlayerX? ASDFASDFSDAFASFSDAFSDA
	--if StaticPopup1Text and StaticPopup1Text ~= nil then
		--if string.match(StaticPopup1Text:GetText(), "You wish to assign") then
			--if StaticPopup1Button1:GetText() == "Accept" then StaticPopup1Button1:Click() end
		--end
	--end
end


Session:RegisterEvent("CHAT_MSG_WHISPER")
Session:RegisterEvent("LOOT_OPENED")
Session:RegisterEvent("OPEN_MASTER_LOOT_LIST")
Session:RegisterEvent("LOOT_SLOT_CLEARED") --arg1 is the index
Session:RegisterEvent("LOOT_CLOSED") --arg1 is the index

Session:SetScript("OnEvent", function(self, event, ...)
arg1,arg2,arg3 = ...

  if event == "LOOT_CLOSED" then
		if not self.enabled then return; end
		self.enabled = false;
		self:Clear(nil, nil, true);
  end

  if event == "LOOT_SLOT_CLEARED" then
    if self.enabled and GetLootMethod() == "master" and IsMasterLooter() then
			--Let's use that double bubble fire to try and clear StaticPopup1.
			self:AcceptLootAssignment();
			if self.Items[arg1] then --Double Check if item exist because LOOT_SLOT_CLEARED can fire multiple times for the same slot.
				self:Clear(arg1, self.Items[arg1].name)
			end

			local count = self:NumItems(self.Items)

			self:AwardSlot(nil, nil, nil, "LOOT_SLOT_CLEARED")

			if count < 1 then
				self.enabled = false
				--I want to call CloseLoot() here but I know it'll critical error most likely and I don't want to create any chance of that.
				--print("----------------------------------")
				--print("---- Loot session has ended   ----")
				--print("----------------------------------")
			end
    end
  end

  if event == "LOOT_OPENED" then
		--A lot of conditions to meet before we do anything.
    if not GlimmAUTOLOOT or not IsInRaid() or GetLootMethod() ~= "master" or not IsMasterLooter() then return end

    local sessionhasloot = false

    for i=1, GetNumLootItems() do
			if LootSlotHasItem(i) then
      	local _,itemName,coins,_,iQuality = GetLootSlotInfo(i)
				local itemLink = GetLootSlotLink(i)
      	if itemName and coins ~= 0 then
					self.Items[i] = { ['name']=itemName,['quality']=iQuality,['looted']=false,['link']=itemLink,['winner']=nil,['special']=false }
        	sessionhasloot = true
      	elseif coins == 0 then
					self.Items[i] = { ['name']="coin",['quality']=0,['looted']=false,['link']=nil,['winner']=nil,['special']=false }
      	end
			end
    end

		if sessionhasloot then
			--print("----------------------------------")
			--print("---  Loot session has started  ---")
			--print("----------------------------------")
			self.enabled = true
			local count = self:NumItems(self.Items)

			--for k,v in pairs(self.Items) do
				--print(string.format("[%s] = { [name]=%s, [quality]=%s }", tostring(k), tostring(v.name), tostring(v.quality)))
				--if GetLootThreshold() < v.quality then print("Looting coins||junk."); LootSlot(k); return;--[[self:Clear(k, v.name);]] end
			--end
				self:AwardSlot(nil, nil, nil, "LOOT_OPENED")
				self:AcceptLootAssignment()
		end
  end

  if event == "OPEN_MASTER_LOOT_LIST" then
		if not self.enabled or not GlimmAUTOLOOT then return; end
    if MasterLooterFrame:IsVisible() then
			for k, v in pairs(self.Items) do
				if v.winner ~= nil then
					self:AwardItem(k, v.quality > 3 and true or false);
					break;
				end
			end
			self:AcceptLootAssignment()
    end
  end





--[[

ALL IS GOOD

--]]





  if event == "CHAT_MSG_WHISPER" then
    arg1 = string.upper(arg1)
    if string.match(arg1, "!COLOR") then
      local tt,color = strsplit(" ", arg1)

      if not GlimmUI_Character.GuildRequests then GlimmUI_Character.GuildRequests = {} end

      if not GlimmUI_Character.GuildRequests[arg2] then
        GlimmUI_Character.GuildRequests[arg2] = {}
        GlimmUI_Character.GuildRequests[arg2].Mount = {}
      end

      local _tmp = nil
      for k,v in pairs(self.MountColors) do
        _tmp = string.match(color, v)
        if _tmp ~= nil then break end
      end

      if _tmp ~= nil then
        if GlimmUI_Character.GuildRequests[arg2].Mount[_tmp] then
          SendChatMessage("You already have this color set.", "WHISPER", "COMMON", arg2)
          return
        else
          GlimmUI_Character.GuildRequests[arg2].Mount[_tmp] = true
          SendChatMessage("Mount preference set: ".._tmp.." (!unsetcolor color to undo)", "WHISPER", "COMMON", arg2)
        end
      else
        SendChatMessage("Invalid color selection (Blue, Yellow, Red, Green)", "WHISPER", "COMMON", arg2)
      end
    elseif string.match(arg1, "!UNSETCOLOR") then
      local tt,color = strsplit(" ", arg1)
      if GlimmUI_Character.GuildRequests[arg2].Mount[color] then
        GlimmUI_Character.GuildRequests[arg2].Mount[color] = nil
        SendChatMessage("You have been removed from the "..color.." pool.", "WHISPER", "COMMON", arg2)
      else
        SendChatMessage("You do not have "..color.." set. (Nothing happens.)", "WHISPER", "COMMON", arg2)
        end
      end
    end
end)
