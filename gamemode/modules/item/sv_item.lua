----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------
-- for mapconfig
function deadremains.item.mapSpawn(unique, position, model)
	local item = deadremains.item.get(unique)

	if (item) then
		local entity = ents.Create("deadremains_item")
		entity:SetPos(position)
		entity:SetModel(model)
		entity:Spawn()

		entity.item = item.unique
		entity:SetDRName(item.label)
	end
end

-- for concommand spawning
function deadremains.item.spawn(player, cmd, args)
	local item
	if (args ~= nil) then
		item = deadremains.item.get(args[1])
	else
		item = deadremains.item.get(cmd)
	end

	if (item) then
		local trace = player:eyeTrace(192)

		local entity = ents.Create("deadremains_item")
		entity:SetPos(trace.HitPos)
		entity:SetModel(item.model)
		entity:Spawn()

		entity.item = item.unique
		entity:SetDRName(item.label)
		entity.Use = function(self)
			deadremains.item.worldUse(player, self.Entity)
		end
	end
end
concommand.Add("dr_item_spawn", deadremains.item.spawn)

-- for spawning code
function deadremains.item.spawn_meta(player, unique, meta_data)
	local item = deadremains.item.get(unique)

	if (item) then
		local trace = player:eyeTrace(192)

		local entity = ents.Create("deadremains_item")
		entity:SetPos(trace.HitPos)
		entity:SetModel(item.model)
		entity:Spawn()

		entity.item = item.unique
		entity:SetDRName(item.label)
		entity.meta = table.Copy(meta_data)
	end
end

function deadremains.item.spawn_contains(player, unique, contains)
	local item = deadremains.item.get(unique)

	if (item) then
		local trace = player:eyeTrace(192)

		local entity = ents.Create("deadremains_item")
		entity:SetPos(trace.HitPos)
		entity:SetModel(item.model)
		entity:Spawn()

		entity.item = item.unique
		entity:SetDRName(item.label)
		entity.meta = {}
		entity.meta["contains"] = contains
	end
end

function deadremains.item.zombie_drop(name, position)
	local items = deadremains.item.getAll()

	for i=1,math.random(0,5) do
		if (math.random(0,100) > 50) then

			local entity = ents.Create("deadremains_item")
			entity:SetPos(position)
			entity:SetModel(item.model)
			entity:Spawn()

			entity.item = item.unique
			entity:SetDRName(item.label)
			entity.meta = {}

		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--	Find out whether the item provides inventory expansion.	
----------------------------------------------------------------------

function deadremains.item.isInventory(unique)
	local item = deadremains.item.get(unique)

	-- items which provide the space name.
	local inventory_uniques = {
		"hunting_backpack",
		"bike_armor"
	}

	for _, u in pairs(inventory_uniques) do
		if (u == item.unique) then
			return true
		end
	end

	return false
end