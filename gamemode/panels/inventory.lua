surface.CreateFont("deadremains.inventory", {font = "Bebas Neue", size = 25, weight = 400})

local panel = {}

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:Init()
	self.name = ""
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:setInventory(inventory_index, data)
	self.slots = self:Add("deadremains.slots")
	self.slots:SetPos(0, 32 * STORE_SCALE_Y)
	self.slots:createSlots(data.slots_horizontal, data.slots_vertical)
	self.slots:setInventoryID(data.unique)
	self.slots:setInventoryIndex(inventory_index)

	self:setName(data.name)
	self:InvalidateLayout(true)
	self:SizeToChildren(true, true)

	local inventory = deadremains.inventory.getc(inventory_index)

	inventory:setPanel(self.slots)

	self.slots:rebuild()
end

function panel:rebuild()
	print("Rebuilding main inv")
	self.slots:rebuild()
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:setExternal(bool)
	self.external = bool

	self.slots:SetPos(0, (32 +25)*STORE_SCALE_Y)

	self:InvalidateLayout(true)
	self:SizeToChildren(true, true)

	self.top = self:Add("Panel")
	self.top:SetTall(36 * STORE_SCALE_Y)
	self.top:SetCursor("hand")

	function self.top:OnMousePressed()
		local parent = self:GetParent()

		if (self.retracted) then
			parent:SetTall(parent.old_height)
		else
			if (!parent.old_height) then
				parent.old_height = parent:GetTall()
			end

			parent:SetTall(36 * STORE_SCALE_Y)
		end

		self.retracted = !self.retracted
	end
	
	function self.top:Paint(w, h)
		if (self.retracted) then
			draw.SimpleText("+", "deadremains.inventory.external", w -(34 * STORE_SCALE_Y), 0, panel_color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		else
			draw.SimpleText("-", "deadremains.inventory.external", w -(32 * STORE_SCALE_Y), 0, panel_color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:setName(name)
	self.name = tostring(name)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:PerformLayout()
	if (self.external) then
		local w = self:GetWide()
		local width = self.slots:GetWide()

		self.slots:SetPos(w *0.5 -width *0.5, self.slots.y)

		if (IsValid(self.top)) then
			self.top:SetWide(w)
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:Paint(w, h)
	if (self.external) then
		draw.SimpleText(self.name, "deadremains.inventory.external", w *0.5, 0, panel_color_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	else
		draw.SimpleText(self.name, "deadremains.inventory", 0, 0, panel_color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end
end

vgui.Register("deadremains.inventory", panel, "EditablePanel")






----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

surface.CreateFont("deadremains.inventory.external", {font = "Bebas Neue", size = 36, weight = 400})

local panel = {}

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:Init()
	self:SetWide(0)
	self:DockPadding(0, 25 * STORE_SCALE_X, 0, 25 * STORE_SCALE_Y)

	self.name = ""

	self.list = self:Add("DScrollPanel")
	self.list:Dock(FILL)

	util.ReplaceScrollbar(self.list)

	timer.Simple(0.1, function()
		self:rebuild()
	end)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:setInventory(inventory_index, data)
	local inventory = self.list:Add("deadremains.inventory")
	inventory:Dock(TOP)
	inventory:DockMargin(0, 0, 0, 25 * STORE_SCALE_Y)
	inventory:setInventory(inventory_index, data)
	inventory:setExternal(true)

	local width = data.slots_horizontal * slot_size

	if (width > self:GetWide()) then
		self:SetWide(width +2)

		nextFrame(function()
			main_menu:InvalidateLayout(true)
			main_menu:SizeToChildren(true, false)
		end)
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:rebuild()
	print("Rebuilding external inv")
	self.list:Clear()

	local inventories = deadremains.inventory.getStoredC()

	for index, data in pairs(inventories) do
		local inventory_data = deadremains.inventory.get(data.unique)

		if (inventory_data.external) then
			self:setInventory(data.inventory_index, inventory_data)
		end
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:resize()
	local canvas = self.list:GetCanvas()

	canvas:InvalidateLayout(true)

	nextFrame(function()
		if (#canvas:GetChildren() <= 0) then
			self:SetWide(0)
		end
		
		main_menu:InvalidateLayout(true)
		main_menu:SizeToChildren(true, false)
	end)
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:Think()
	local panel = main_menu:getPanel("character_panel"):GetParent()

	if (!panel:IsVisible()) then
		self:SetVisible(false)
	end
end

----------------------------------------------------------------------
-- Purpose:
--		
----------------------------------------------------------------------

function panel:Paint(w, h)
	draw.RoundedBox(2, 0, 0, w, h, panel_color_background)
end

vgui.Register("deadremains.inventory.external", panel, "EditablePanel")