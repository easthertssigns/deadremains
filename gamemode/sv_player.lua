----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:getHunger()
	return self.dr_character.needs.hunger
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:setHunger(hunger)
	self.dr_character.needs.hunger = hunger

	self:SetNWInt("dr_hunger", self.dr_character.needs.hunger)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:increaseHunger(amount)
	self.dr_character.needs.hunger = math.max(100, self.dr_character.needs.hunger +amount)

	self:SetNWInt("dr_hunger", self.dr_character.needs.hunger)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:decreaseHunger(amount)
	self.dr_character.needs.hunger = math.max(0, self.dr_character.needs.hunger -amount)

	self:SetNWInt("dr_hunger", self.dr_character.needs.hunger)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:getThirst()
	return self.dr_character.needs.thirst
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:setThirst(thirst)
	self.dr_character.needs.thirst = thirst

	self:SetNWInt("dr_thirst", self.dr_character.needs.thirst)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:increaseThirst(amount)
	self.dr_character.needs.thirst = math.max(100, self.dr_character.needs.thirst +amount)

	self:SetNWInt("dr_thirst", self.dr_character.needs.thirst)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:decreaseThirst(amount)
	self.dr_character.needs.thirst = math.max(0, self.dr_character.needs.thirst -amount)

	self:SetNWInt("dr_thirst", self.dr_character.needs.thirst)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.getskill")

local function default(self)
	local needs = deadremains.settings.get("needs")
	
	for unique, data in pairs (needs) do
		if (unique == "health") then
			self.dr_character.needs[unique] = data.default
		else
			self["set" .. string.capitalize(unique)](self, data.default)
		end
	end

	timer.Create("dr.thirst." .. self:UniqueID(), 15, 100, function()
		self:decreaseThirst(1)
	end)

	timer.Create("dr.hunger." .. self:UniqueID(), 30, 100, function()
		self:decreaseHunger(1)
	end)

	local characteristics = deadremains.settings.get("characteristics")
	
	for unique, data in pairs (characteristics) do
		self.dr_character.characteristics[unique] = data.default
	end

	local inventories = deadremains.settings.get("default_inventories")

	for _, info in pairs(inventories) do
		local data = deadremains.inventory.get(info.unique)

		if (data) then
			self:createInventory(data.unique, data.horizontal, data.vertical, info.inventory_index)
		end
	end

	local skill_types = deadremains.settings.get("skill_types")
	local randomized = {}

	for _, type in pairs(skill_types) do
		local sorted = deadremains.getSkillByType(type)

		table.insert(randomized, sorted[math.random(1, #sorted)])
	end

	for i = 1, #randomized do
		local data = randomized[i]

		self.dr_character.skills[data.unique] = true
	end

	net.Start("deadremains.getskill")
		net.WriteUInt(#randomized, 8)

		for i = 1, #randomized do
			net.WriteString(randomized[i].unique)
		end
	net.Send(self)

	self.dr_character.max_weight = 20
end

function player_meta:reset()
	self.dr_character = {}

	self.dr_character.needs = {}
	self.dr_character.skills = {}
	self.dr_character.inventory = {}
	self.dr_character.characteristics = {}

	default(self)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:initializeCharacter()
	local steam_id = deadremains.sql.escape(database_main, self:SteamID())

	self.dr_character = {}

	self.dr_character.needs = {}
	self.dr_character.skills = {}
	self.dr_character.inventory = {}
	self.dr_character.characteristics = {}

	default(self)

	local needs = deadremains.settings.get("needs")
	local characteristics = deadremains.settings.get("characteristics")

	deadremains.sql.query(database_main, "SELECT * FROM `users` WHERE `steam_id` = " .. steam_id, function(data, affected, last_id)
		if (data and data[1]) then
			data = data[1]

			for unique, _ in pairs (needs) do
				local info = data["need_" .. unique]

				if (info) then
					self.dr_character.needs[unique] = info
				end
			end

			for unique, _ in pairs (characteristics) do
				local info = data["characteristic_" .. unique]

				if (info) then
					self.dr_character.characteristics[unique] = info
				end
			end

		-- No data, let's create a new profile.
		else
			local query = "INSERT INTO users(steam_id, "

			for unique, value in pairs(self.dr_character.needs) do
				query = query .. "need_" .. unique .. ", "
			end

			for unique, value in pairs(self.dr_character.characteristics) do
				query = query .. "characteristic_" .. unique .. ", "
			end

			query = string.sub(query, 0, #query -2) .. ", gender) VALUES(".. steam_id .. ", "
			
			for unique, value in pairs(self.dr_character.needs) do
				query = query .. value .. ", "
			end

			for unique, value in pairs(self.dr_character.characteristics) do
				query = query .. value .. ", "
			end

			query = string.sub(query, 0, #query -2) .. ", 1)"

			deadremains.sql.query(database_main, query)
		end
	end)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.player.initalize")

net.Receive("deadremains.player.initalize", function(bits, player)
	if (!player.dr_loaded) then
		player:initializeCharacter()

		player.dr_loaded = true
	end
end)

----------------------------------------------------------------------
-- Purpose:
--		Finds a suitable inventory to use for the item.
----------------------------------------------------------------------

function player_meta:findSuitableInventory(unique)
	local item = deadremains.item.get(unique)

	if (item) then
		if (item.equip_slot) then
			local success, message

			for _, data in pairs(self.dr_character.inventory) do
				if (bit.band(bit.lshift(1, data.inventory_index), item.equip_slot) != 0 and #data.slots <= 0) then
					success, message = self:addItem(data.inventory_index, unique)

					if (success) then
						return true
					end
				end
			end

			if (success == false and message) then
				return success, message
			end

			if (!success) then
				return false, "Could not find any suitable inventory."
			end
		else
			local success, message

			if (#self.dr_character.inventory > inventory_equip_maximum) then
				for inventory_index = inventory_equip_maximum +1, #self.dr_character.inventory do
					success, message = self:addItem(inventory_index, unique)
	
					if (success) then
						return true
					end
				end
	
				if (success == false and message) then
					return success, message
				end
			end
			
			if (!success) then
				return false, "Could not find any suitable inventory."
			end
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.createinventory")

function player_meta:createInventory(unique, slots_horizontal, slots_vertical, index)
	local index = index

	if (index) then
		self.dr_character.inventory[index] = self.dr_character.inventory[index] or {unique = unique, slots_horizontal = slots_horizontal, slots_vertical = slots_vertical, slots = {}}
	else
		index = table.insert(self.dr_character.inventory, {unique = unique, slots_horizontal = slots_horizontal, slots_vertical = slots_vertical, slots = {}})
	end

	self.dr_character.inventory[index].inventory_index = index

	net.Start("deadremains.createinventory")
		net.WriteUInt(index, 8)
		net.WriteString(unique)
	net.Send(self)

	return index
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.removeinventory")

function player_meta:removeInventory(inventory_index, remove_contents)
	if (remove_contents) then
		self.dr_character.inventory[inventory_index] = nil
	end

	net.Start("deadremains.removeinventory")
		net.WriteUInt(inventory_index, 8)
	net.Send(self)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.networkinventory")

function player_meta:networkInventory(inventory_index)
	local inventory = self.dr_character.inventory[inventory_index]

	net.Start("deadremains.networkinventory")
		net.WriteUInt(inventory_index, 8)
		net.WriteString(inventory.unique)

		net.WriteUInt(#inventory.slots, 8)

		-- This might result in too much data...use a streaming module?
		for i = 1, #inventory.slots do
			local slot = inventory.slots[i]

			net.WriteString(slot.unique)
			net.WriteUInt(slot.x, 32)
			net.WriteUInt(slot.y, 32)
		end
	net.Send(self)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:getItemsAtArea(inventory, start_x, start_y, end_x, end_y, return_one)
	local result = {}

	for i = 1, #inventory.slots do
		local slot = inventory.slots[i]

		if (slot) then
			local item = deadremains.item.get(slot.unique)
			local slot_x, slot_y = slot.x, slot.y
			local width, height = item.slots_horizontal *slot_size, item.slots_vertical *slot_size
			
			if (start_x > slot_x +width) then continue end
			if (start_y > slot_y +height) then continue end
			if (slot_x > end_x) then continue end
			if (slot_y > end_y) then continue end
	
			if (return_one) then
				return slot
			else
				table.insert(result, slot)
			end
		end
	end

	return !return_one and result
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:canEquipItem(inventory_data, item)
	local inventory_data = deadremains.inventory.get(inventory_data.unique)
	local is_equip_slot = inventory_data:isEquipInventory()

	-- We're equipping something.
	if (is_equip_slot) then
		local can_equip, message = inventory_data:canEquip(self, item)

		if (!can_equip) then
			return can_equip, message
		end

		return true
	end

	-- Need to return true here if it isn't an equip slot (?)
	return true, "noequip" -- lol
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:equipItem(inventory_data, item)
	local item_data = deadremains.item.get(item.unique)
	local can_equip, message = self:canEquipItem(inventory_data, item_data)

	if (can_equip) then
		inventory_data:equip(self, item)

		return true
	else
		return can_equip, message
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------


function player_meta:unEquipItem(inventory_data, item, dropped_item)
	inventory_data:unEquip(self, item, dropped_item)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.getitem")

function player_meta:addItem(inventory_index, unique, x, y, move_item_data)
	local inventory = self.dr_character.inventory[inventory_index]

	if (inventory) then
		local item = deadremains.item.get(unique)

		if (item) then
			local inventory_data = deadremains.inventory.get(inventory.unique)

			if (inventory_data) then
				if (x and y) then
					if (x +item.slots_horizontal *slot_size -2 <=inventory_data.slots_horizontal *slot_size and y +item.slots_vertical *slot_size -2 <= inventory_data.slots_vertical *slot_size) then
						local items = self:getItemsAtArea(inventory, x +1, y +1, x +item.slots_horizontal *slot_size -2, y +item.slots_vertical *slot_size -2)
						
						if (#items <= 0) then
							local can_equip, message = self:canEquipItem(inventory_data, item)

							if (!can_equip) then
								return can_equip, message
							else

								-- Clamp it to the closest slot.
								for y2 = 1, inventory_data.slots_vertical do
									for x2 = 1, inventory_data.slots_horizontal do
										local slot_x, slot_y = x2 *slot_size -slot_size, y2 *slot_size -slot_size
						
										if (x +1 > slot_x +slot_size) then continue end
										if (y +1 > slot_y +slot_size) then continue end
										if (slot_x > x +1) then continue end
										if (slot_y > y +1) then continue end
										
										local item_data

										if (move_item_data) then

											-- Maybe reuse the item table??
											item_data = table.Copy(move_item_data)
											item_data.x = slot_x
											item_data.y = slot_y
										else
											item_data = {unique = unique, x = slot_x, y = slot_y}
										end

										table.insert(inventory.slots, item_data)

										if (can_equip and message != "noequip") then
											self:equipItem(inventory_data, item_data)
										end
										
										net.Start("deadremains.getitem")
											net.WriteUInt(inventory.inventory_index, 8)
											net.WriteString(unique)
											net.WriteUInt(slot_x, 32)
											net.WriteUInt(slot_y, 32)
										net.Send(self)
										
										return true
									end
								end
							end
						else
							return false, "Can't put that there."
						end
					end
				else
					for y = 1, inventory_data.slots_vertical do
						for x = 1, inventory_data.slots_horizontal do
							local start_x, start_y = x *slot_size -slot_size +1, y *slot_size -slot_size +1
							local end_x, end_y = start_x +item.slots_horizontal *slot_size -2, start_y +item.slots_vertical *slot_size -2
						
							-- Don't search outside the inventory bounds.
							if (end_x <= inventory_data.slots_horizontal *slot_size and end_y <= inventory_data.slots_vertical *slot_size) then
								local slots = self:getItemsAtArea(inventory, start_x, start_y, end_x, end_y)

								if (#slots <= 0) then
									local can_equip, message = self:canEquipItem(inventory_data, item)

									if (!can_equip) then
										return can_equip, message
									else

										-- We search 1 pixel inside the slot, reset that.
										start_x, start_y = start_x -1, start_y -1
										
										local item_data

										if (move_item_data) then

											-- Maybe reuse the item table??
											item_data = table.Copy(move_item_data)
											item_data.x = start_x
											item_data.y = start_y
										else
											item_data = {unique = unique, x = start_x, y = start_y}
										end
										
										table.insert(inventory.slots, item_data)
										
										if (can_equip and message != "noequip") then
											self:equipItem(inventory_data, item_data)
										end

										net.Start("deadremains.getitem")
											net.WriteUInt(inventory.inventory_index, 8)
											net.WriteString(unique)
											net.WriteUInt(start_x, 32)
											net.WriteUInt(start_y, 32)
										net.Send(self)
									
										return true
									end
								--else
									--return false, "Can't fit that there."
								end
							end
						end
					end
	
					return false, "Can't fit that item into any inventory."
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.removeitem")

function player_meta:removeItem(inventory_index, unique, x, y, dropped_item)
	local inventory = self.dr_character.inventory[inventory_index]

	if (inventory) then
		local item = deadremains.item.get(unique)

		if (item) then
			for i = 1, #inventory.slots do
				local slot = inventory.slots[i]
				
				if (slot.unique == item.unique and slot.x == x and slot.y == y) then
					local inventory_data = deadremains.inventory.get(inventory.unique)

					if (inventory_data) then
						local is_equip_slot = inventory_data:isEquipInventory()
	
						-- We're unequipping something.
						if (is_equip_slot) then
							self:unEquipItem(inventory_data, slot, dropped_item)
						end
					end
					
					-- Remove the inventory.
					if (dropped_item) then
						if (slot.inventory_index) then
							self:removeInventory(slot.inventory_index, true)
						end

						
					end
					
					table.remove(inventory.slots, i)

					net.Start("deadremains.removeitem")
						net.WriteUInt(inventory.inventory_index, 8)
						net.WriteString(unique)
						net.WriteUInt(x, 32)
						net.WriteUInt(y, 32)
					net.Send(self)

					break
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:moveItem(new_inventory_id, inventory_id, unique, x, y, move_x, move_y)
	local inventory = self.dr_character.inventory[inventory_id]
	local new_inventory = self.dr_character.inventory[new_inventory_id]

	local inventory_data = deadremains.inventory.get(inventory.unique)
	local inventory_data_new = deadremains.inventory.get(new_inventory.unique)

	if (inventory and new_inventory) then
		local item = deadremains.item.get(unique)

		if (item) then

			-- The slot where we want to move our moving slot to.
			local slot = self:getItemsAtArea(new_inventory, move_x +1, move_y +1, move_x +item.slots_horizontal *slot_size -2, move_y +item.slots_vertical *slot_size -2, true)
			
			-- The slot that we are moving.
			local move_slot = self:getItemsAtArea(inventory, x +1, y +1, x +item.slots_horizontal *slot_size -2, y +item.slots_vertical *slot_size -2, true)
		
			if (slot) then

				-- We don't want to do anything if we're moving to our current position.
				if (slot != move_slot) then
					local slot_item = deadremains.item.get(slot.unique)
	
					if (slot_item) then
	
						-- Let's see if we can swap the positions of the slots.
						if (item.slots_horizontal == slot_item.slots_horizontal and item.slots_vertical == slot_item.slots_vertical) then
							local can_equip, message = self:canEquipItem(inventory_data, slot_item)

							if (!can_equip) then
								return can_equip, "You can't swap these items."
							end
							
							local can_equip, message = self:canEquipItem(inventory_data_new, item)
							
							if (!can_equip) then
								return can_equip, message
							else
	
								-- Remove the item that we are moving from.
								self:removeItem(inventory_id, unique, x, y)
		
								-- Add the item that we are moving to, to the moving slots position.
								self:addItem(inventory_id, slot.unique, x, y, slot)
								
								-- Remove the item that we are moving to.
								self:removeItem(new_inventory_id, slot.unique, move_x, move_y)
		
								-- Add the item that we are moving to that slot.
								self:addItem(new_inventory_id, unique, move_x, move_y, move_slot)
		
								return true
							end
						else
							return false, "Can't swap these items."
						end
					end

				-- Do nothing.
				else
					return true
				end
				
			-- We are moving to an empty area.	
			else
				local can_equip, message = self:canEquipItem(inventory_data_new, item)

				if (!can_equip) then
					return can_equip, message
				else
					self:removeItem(inventory_id, unique, x, y)
					self:addItem(new_inventory_id, unique, move_x, move_y, move_slot)

					return true
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:dropItem(inventory_index, unique, x, y)
	local inventory = self.dr_character.inventory[inventory_index]

	if (inventory) then
		local item = deadremains.item.get(unique)
		local slot = self:getItemsAtArea(inventory, x +1, y +1, x +item.slots_horizontal *slot_size -2, y +item.slots_vertical *slot_size -2, true)

		if (slot) then
			self:removeItem(inventory_index, unique, x, y, true)

			-- apply item data and stuff
			deadremains.item.spawn(self, unique)
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:destroyItem(inventory_index, unique, x, y)
	local inventory = self.dr_character.inventory[inventory_index]

	if (inventory) then
		local item = deadremains.item.get(unique)
		local slot = self:getItemsAtArea(inventory, x +1, y +1, x +item.slots_horizontal *slot_size -2, y +item.slots_vertical *slot_size -2, true)

		if (slot) then
			self:removeItem(inventory_index, unique, x, y, true)
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function player_meta:useItem(inventory_index, unique, x, y)
	local inventory = self.dr_character.inventory[inventory_index]

	if (inventory) then
		local item = deadremains.item.get(unique)
		local slot = self:getItemsAtArea(inventory, x +1, y +1, x +item.slots_horizontal *slot_size -2, y +item.slots_vertical *slot_size -2, true)

		if (slot) then
			if (item.use) then
				item:use(self)
			end
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.moveitem")

net.Receive("deadremains.moveitem", function(bits, player)
	local new_inventory_id = net.ReadUInt(8) -- In what inventory we want to put this item.
	local inventory_index = net.ReadUInt(8) -- In what inventory we are currently.
	local unique = net.ReadString()
	local x = net.ReadUInt(32) -- Where the item comes from.
	local y = net.ReadUInt(32) -- Where the item comes from.
	local move_x = net.ReadUInt(32) -- Where we want to move the item.
	local move_y = net.ReadUInt(32) -- Where we want to move the item.

	local success, message = player:moveItem(new_inventory_id, inventory_index, unique, x, y, move_x, move_y)

	if (!success) then
		player:ChatPrint(message)
	end
end)

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

util.AddNetworkString("deadremains.itemaction")

net.Receive("deadremains.itemaction", function(bits, player)
	local inventory_index = net.ReadUInt(8)
	local unique = net.ReadString()
	local x = net.ReadUInt(32)
	local y = net.ReadUInt(32)
	local action = net.ReadUInt(8)

	if (action == item_action_use) then
		player:useItem(inventory_index, unique, x, y)
	elseif (action == item_action_drop) then
		player:dropItem(inventory_index, unique, x, y)
	elseif (action == item_action_destroy) then
		player:destroyItem(inventory_index, unique, x, y)
	end
end)