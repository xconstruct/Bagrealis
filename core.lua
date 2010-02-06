--[[
    Copyright (C) 2009  Constantin Schomburg

    This file is part of Bagrealis.

    Bagrealis is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    cargBags is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Bagrealis.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[*********************************
	0.	Table of Contents
	1.	Main routine
	2.	Button functions
***********************************]]


--[[*********************************
	1.	Main routine
***********************************]]

local addon, ns = ...

local Bagrealis = CreateFrame("Button", "Bagrealis", UIParent)
Bagrealis:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)

Bagrealis.DragDrop = ns.LDD.RegisterEnvironment(Bagrealis)

local protos, containers = {}, {}
Bagrealis.Containers = containers

local defaults = {__index={}}

local bags = setmetatable({}, {__index = function(self, id)
	local bag = CreateFrame("Frame", nil, Bagrealis)
	bag:SetID(id)
	self[id] = bag
	return bag end
})

function Bagrealis:Init()
	self:RegisterEvent"BAG_UPDATE"
	self:RegisterEvent"ITEM_LOCK_CHANGED"
	self:RegisterEvent"BAG_UPDATE_COOLDOWN"

	BagrealisDB = BagrealisDB or {}
	self.db = setmetatable(BagrealisDB, defaults)

	if(self.db.Container) then
		for ident in pairs(self.db.Container) do
			local container = self:GetPrototype("Container").Create()
			container.ident = ident
			containers[ident] = container
			container:RestoreState()
		end
	end

	Bagrealis:BAG_UPDATE()
end

local function getDB(self, save)
	local name, ident, db = self._name, self.ident, Bagrealis.db
	db[name] = db[name] or {}
	local dbS = db[name]
	if(save) then
		dbS[ident] = dbS[ident] or {}
	end
	return dbS[ident]
end

local function clearDB(self)
	local name, ident, db = self._name, self.ident, Bagrealis.db
	if(db[name] and db[name][ident]) then
		db[name][ident] = nil
	end
end

function Bagrealis:NewPrototype(name, embed)
	local proto = setmetatable({}, getmetatable(self))
	proto.__index, proto._name = proto, name
	proto.GetDB, proto.ClearDB = getDB, clearDB
	protos[name] = proto
	if(embed) then ns.LDD.EmbedGeometry(proto) end
	return proto
end

function Bagrealis:GetPrototype(name)
	return protos[name]
end

function Bagrealis:UpdateBag(bagID)
	local bag = bags[bagID]

	local num = GetContainerNumSlots(bagID)
	local old = bag.num or 0
	bag.num = num

	for slotID = 1, num do
		Bagrealis:UpdateSlot(bagID, slotID)
	end
	for slotID = num+1, old do
		Bagrealis:RemoveSlot(bagID, slotID)
	end
end

function Bagrealis:BAG_UPDATE(event, bagID, slotID)
	if(bagID and slotID) then
		Bagrealis:UpdateSlot(bagID, slotID)
	elseif(bagID) then
		Bagrealis:UpdateBag(bagID)
	else
		for bagID = -2, 11 do
			Bagrealis:UpdateBag(bagID)
		end
	end
end

Bagrealis.ITEM_LOCK_CHANGED = Bagrealis.BAG_UPDATE
Bagrealis.BAG_UPDATE_COOLDOWN = Bagrealis.BAG_UPDATE

--[[*********************************
	2. Button functions
***********************************]]

local recycled = {
	ContainerFrameItemButtonTemplate = {},
	BankItemButtonGenericTemplate = {},
}

local function getTemplateName(bagID)
	return bagID == -1 and "BankItemButtonGenericTemplate" or "ContainerFrameItemButtonTemplate"
end

function Bagrealis:GetButton(bagID, slotID)
	local bag = bags[bagID]

	local button = bag[slotID]
	if(button) then return button end

	local tpl = getTemplateName(bagID)
	local button = tremove(recycled[tpl]) or self:GetPrototype("ItemButton").Create(tpl)

	button.ident = bagID*100 + slotID
	bag[slotID] = button
	button:SetParent(bag)
	button:SetID(slotID)
	button:Show()
	button:RestoreState()

	return button
end

function Bagrealis:RemoveSlot(bagID, slotID)
	local button = bags[bagID][slotID]
	bags[bagID][slotID] = nil

	button:ClearDB()
	button.id = nil
	button.ident = nil

	button:Hide()

	local tpl = getTemplateName(bagID)
	tinsert(recycled[tpl], button)
end

function Bagrealis:UpdateSlot(bagID, slotID)
	local button = bags[bagID][slotID]

	local clink = GetContainerItemLink(bagID, slotID)
	local texture, count, locked, quality, readable = GetContainerItemInfo(bagID, slotID)
	local cdStart, cdFinish, cdEnable = GetContainerItemCooldown(bagID, slotID)
	local name, link, rarity, level, minLevel, type, subType, stackCount, equipLoc, texture, sellValue, id

	if(clink) then
		name, link, rarity, level, minLevel, type, subType, stackCount, equipLoc, texture, sellValue = GetItemInfo(clink)
		id = tonumber(link:match("item:(%d+)"))
	end

	if(not id) then
		if(button) then
			self:RemoveSlot(bagID, slotID)
		end
		return
	end
	if(not button) then button = Bagrealis:GetButton(bagID, slotID) end

	button.Icon:SetTexture(texture)

	if(rarity and rarity > 1) then
		button.Glow:SetVertexColor(GetItemQualityColor(rarity))
		button.Glow:Show()
	else
		button.Glow:Hide()
	end

	if(count and count > 1) then
		button.Count:SetText(count and count >= 1e3 and "*" or count)
		button.Count:Show()
	else
		button.Count:Hide()
	end

	button.Icon:SetDesaturated(locked)
	CooldownFrame_SetTimer(button.Cooldown, cdStart, cdFinish, cdEnable)
end