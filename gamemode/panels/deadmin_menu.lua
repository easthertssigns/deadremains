deadremains.deadmin = {}
deadremains.deadmin.itemcount = {}


deadremains.netrequest.create("load_deadmin_items", function(data)
	print("Clientside called")
	if (data) then
		for k,v in pairs(data) do
			deadremains.deadmin.itemcount[v.unique] = {
				count = v.count,
				type = v.type
			}
		end

		ShowDeadmin()
	end
end)

concommand.Add("show_deadmin", function()
	deadremains.netrequest.trigger("load_deadmin_items")
end)

function ShowDeadmin()
	local itemcount = deadremains.deadmin.itemcount

	deadremains.deadmin.main = vgui.Create('DFrame')
	deadremains.deadmin.main:SetSize(ScrW() * 0.61, ScrH() * 0.609)
	deadremains.deadmin.main:SetPos(ScrW() * -0.002, ScrH() * 0.002)
	deadremains.deadmin.main:SetTitle('Deadmin v1.0.0')
	deadremains.deadmin.main:SetSizable(true)
	deadremains.deadmin.main:SetDeleteOnClose(false)
	deadremains.deadmin.main:MakePopup()

	local sheet = vgui.Create("DPropertySheet", deadremains.deadmin.main)
	sheet:Dock(FILL)

	-- Spawning panel
	local spawning_panel = vgui.Create("DPanel", sheet)
	local cat_height = deadremains.deadmin.main:GetTall() / 4
	
	-- Consumables
	local consumable_cat = vgui.Create("DCollapsibleCategory", spawning_panel)
	consumable_cat:Dock(FILL)
	consumable_cat:SizeToChildren(false, true)
	consumable_cat:SetLabel("Consumables")

	local item_list = vgui.Create("DListView", spawning_panel)
	item_list:SetMultiSelect(false)
	item_list:AddColumn("Name")
	item_list:AddColumn("Type")
	item_list:AddColumn("Map Count")
	consumable_cat:SetContents(item_list)

	-- populate the list.
	for k,v in pairs(itemcount) do
		if v.type == item_type_consumable then
			item_list:AddLine(k, type_to_string(v.type), v.count)
		end
	end

	sheet:AddSheet("Spawning", spawning_panel, "icon16/wand.png")
end