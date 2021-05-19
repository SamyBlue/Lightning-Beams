

--[[
	PartCache V4.0 by Xan the Dragon // Eti the Spirit -- RBX 18406183
	Update V4.0 has added Luau Strong Type Enforcement.
	
	Creating parts is laggy, especially if they are supposed to be there for a split second and/or need to be made frequently.
	This module aims to resolve this lag by pre-creating the parts and CFraming them to a location far away and out of sight.
	When necessary, the user can get one of these parts and CFrame it to where they need, then return it to the cache when they are done with it.
	
	According to someone instrumental in Roblox's backend technology, zeuxcg (https://devforum.roblox.com/u/zeuxcg/summary)...
		>> CFrame is currently the only "fast" property in that you can change it every frame without really heavy code kicking in. Everything else is expensive.
		
		- https://devforum.roblox.com/t/event-that-fires-when-rendering-finishes/32954/19
	
	This alone should ensure the speed granted by this module.
		
		
	HOW TO USE THIS MODULE:
	
	Look at the bottom of my thread for an API! https://devforum.roblox.com/t/partcache-for-all-your-quick-part-creation-needs/246641
--]]
local table = require(script.Parent:WaitForChild("Table"))

-----------------------------------------------------------
-------------------- MODULE DEFINITION --------------------
-----------------------------------------------------------

local PartCacheStatic = {}
PartCacheStatic.__index = PartCacheStatic
PartCacheStatic.__type = "PartCache" -- For compatibility with TypeMarshaller

-- TYPE DEFINITION: Part Cache Instance
export type PartCache = {
	Open: {[number]: BasePart},
	InUse: {[number]: BasePart},
	CurrentCacheParent: Instance,
	Template: BasePart,
	ExpansionSize: number
}

-----------------------------------------------------------
----------------------- STATIC DATA -----------------------
-----------------------------------------------------------					

-- A CFrame that's really far away. Ideally. You are free to change this as needed.
local CF_REALLY_FAR_AWAY = CFrame.new(0, 10e8, 0)

-- Format params: methodName, ctorName
local ERR_NOT_INSTANCE = "Cannot statically invoke method '%s' - It is an instance method. Call it on an instance of this class created via %s"

-- Format params: paramName, expectedType, actualType
--local ERR_INVALID_TYPE = "Invalid type for parameter '%s' (Expected %s, got %s)"

-----------------------------------------------------------
------------------------ UTILITIES ------------------------
-----------------------------------------------------------

--Similar to assert but warns instead of errors.
local function assertwarn(requirement: boolean, messageIfNotMet: string)
	if requirement == false then
		warn(messageIfNotMet)
	end
end

--Dupes a part from the template.
local function MakeFromTemplate(template: BasePart, currentCacheParent: Instance): BasePart
	local part: BasePart = template:Clone()
	-- ^ Ignore W000 type mismatch between Instance and BasePart. False alert.
	
	part.CFrame = CF_REALLY_FAR_AWAY
	part.Anchored = true
	part.Parent = currentCacheParent
	return part
end

function PartCacheStatic.new(template: BasePart, numPrecreatedParts: number?, currentCacheParent: Instance?): PartCache
	local newNumPrecreatedParts: number = numPrecreatedParts or 5
	local newCurrentCacheParent: Instance = currentCacheParent or workspace
	
	--PrecreatedParts value.
	--Same thing. Ensure it's a number, ensure it's not negative, warn if it's really huge or 0.
	assert(numPrecreatedParts > 0, "PrecreatedParts can not be negative!")
	assertwarn(numPrecreatedParts ~= 0, "PrecreatedParts is 0! This may have adverse effects when initially using the cache.")
	assertwarn(template.Archivable, "The template's Archivable property has been set to false, which prevents it from being cloned. It will temporarily be set to true.")
	
	local oldArchivable = template.Archivable
	template.Archivable = true
	local newTemplate: BasePart = template:Clone()
	-- ^ Ignore W000 type mismatch between Instance and BasePart. False alert.
	
	template.Archivable = oldArchivable
	template = newTemplate
	
	local object: PartCache = {
		Open = {},
		InUse = {},
		CurrentCacheParent = newCurrentCacheParent,
		Template = template,
		ExpansionSize = 10
	}
	setmetatable(object, PartCacheStatic)
	
	-- Below: Ignore type mismatch nil | number and the nil | Instance mismatch on the table.insert line.
	for _ = 1, newNumPrecreatedParts do
		table.insert(object.Open, MakeFromTemplate(template, object.CurrentCacheParent))
	end
	object.Template.Parent = nil
	
	return object
	-- ^ Ignore mismatch here too
end

-- Gets a part from the cache, or creates one if no more are available.
function PartCacheStatic:GetPart(): BasePart
	assert(getmetatable(self) == PartCacheStatic, ERR_NOT_INSTANCE:format("GetPart", "PartCache.new"))
	
	if #self.Open == 0 then
		warn("No parts available in the cache! Creating [" .. self.ExpansionSize .. "] new part instance(s) - this amount can be edited by changing the ExpansionSize property of the PartCache instance... (This cache now contains a grand total of " .. tostring(#self.Open + #self.InUse + self.ExpansionSize) .. " parts.)")
		for _ = 1, self.ExpansionSize, 1 do
			table.insert(self.Open, MakeFromTemplate(self.Template, self.CurrentCacheParent))
		end
	end
	local part = self.Open[#self.Open]
	self.Open[#self.Open] = nil
	table.insert(self.InUse, part)
	return part
end

-- Returns a part to the cache.
function PartCacheStatic:ReturnPart(part: BasePart)
	assert(getmetatable(self) == PartCacheStatic, ERR_NOT_INSTANCE:format("ReturnPart", "PartCache.new"))
	
	local index = table.indexOf(self.InUse, part)
	if index ~= nil then
		table.remove(self.InUse, index)
		table.insert(self.Open, part)
		part.CFrame = CF_REALLY_FAR_AWAY
		part.Anchored = true
	else
		error("Attempted to return part \"" .. part.Name .. "\" (" .. part:GetFullName() .. ") to the cache, but it's not in-use! Did you call this on the wrong part?")
	end
end

-- Sets the parent of all cached parts.
function PartCacheStatic:SetCacheParent(newParent: Instance)
	assert(getmetatable(self) == PartCacheStatic, ERR_NOT_INSTANCE:format("SetCacheParent", "PartCache.new"))
	assert(newParent:IsDescendantOf(workspace) or newParent == workspace, "Cache parent is not a descendant of Workspace! Parts should be kept where they will remain in the visible world.")
	
	self.CurrentCacheParent = newParent
	for i = 1, #self.Open do
		self.Open[i].Parent = newParent
	end
	for i = 1, #self.InUse do
		self.InUse[i].Parent = newParent
	end
end

-- Adds numParts more parts to the cache.
function PartCacheStatic:Expand(numParts: number): ()
	assert(getmetatable(self) == PartCacheStatic, ERR_NOT_INSTANCE:format("Expand", "PartCache.new"))
	if numParts == nil then
		numParts = self.ExpansionSize
	end
	
	for _ = 1, numParts do
		table.insert(self.Open, MakeFromTemplate(self.Template, self.CurrentCacheParent))
	end
end

-- Destroys this cache entirely. Use this when you don't need this cache object anymore.
function PartCacheStatic:Dispose()
	assert(getmetatable(self) == PartCacheStatic, ERR_NOT_INSTANCE:format("Dispose", "PartCache.new"))
	for i = 1, #self.Open do
		self.Open[i]:Destroy()
	end
	for i = 1, #self.InUse do
		self.InUse[i]:Destroy()
	end
	self.Template:Destroy()
	self.Open = {}
	self.InUse = {}
	self.CurrentCacheParent = nil
	
	self.GetPart = nil
	self.ReturnPart = nil
	self.SetCacheParent = nil
	self.Expand = nil
	self.Dispose = nil
end

return PartCacheStatic