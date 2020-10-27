--Adds sparks effect to a Lightning Bolt
local LightningBolt = require(script.Parent)

local ActiveSparks = {}


local rng = Random.new()
local LightningSparks = {}
LightningSparks.__index = LightningSparks

function LightningSparks.new(LightningBolt, MaxSparkCount)
	local self = setmetatable({}, LightningSparks)
	
	--Main (default) properties--
	
		self.Enabled = true --Stops spawning sparks when false
		self.LightningBolt = LightningBolt --Bolt which sparks fly out of
		self.MaxSparkCount = MaxSparkCount or 10 --Max number of sparks visible at any given instance
		self.MinSpeed, self.MaxSpeed = 4, 6 --Min and max PulseSpeeds of sparks
		self.MinDistance, self.MaxDistance = 3, 6 --Governs how far sparks travel away from main bolt
		self.MinPartsPerSpark, self.MaxPartsPerSpark = 8, 10 --Adjustable
	
	--
	
	self.SparksN = 0
	self.SlotTable = {}
	self.RefIndex = #ActiveSparks + 1
	
	ActiveSparks[self.RefIndex] = self
	
	return self
end

function LightningSparks:Destroy()
	ActiveSparks[self.RefIndex] = nil
	
	for i, v in pairs(self.SlotTable) do
		if v.Parts[1].Parent == nil then
			self.SlotTable[i] = nil --Removes reference to prevent memory leak
		end
	end
	
	self = nil
end

function RandomVectorOffset(v, maxAngle) --returns uniformly-distributed random unit vector no more than maxAngle radians away from v
    return (CFrame.lookAt(Vector3.new(), v)*CFrame.Angles(0, 0, rng:NextNumber(0, 2*math.pi))*CFrame.Angles(math.acos(rng:NextNumber(math.cos(maxAngle), 1)), 0, 0)).LookVector
end 

game:GetService("RunService").Heartbeat:Connect(function ()
	
	for _, ThisSpark in pairs(ActiveSparks) do
		
		if ThisSpark.Enabled == true and ThisSpark.SparksN < ThisSpark.MaxSparkCount then
			
			local Bolt = ThisSpark.LightningBolt
			
			if Bolt.Parts[1].Parent == nil then
				ThisSpark:Destroy()
				return 
			end
			
			local BoltParts = Bolt.Parts
			local BoltPartsN = #BoltParts
				
			local opaque_parts = {}
			
			for part_i = 1, #BoltParts do --Fill opaque_parts table
				
				if BoltParts[part_i].Transparency < 0.3 then --minimum opacity required to be able to generate a spark there
					opaque_parts[#opaque_parts + 1] = (part_i - 0.5) / BoltPartsN
				end
				
			end
			
			local minSlot, maxSlot 
			
			if #opaque_parts ~= 0 then
				minSlot, maxSlot = math.ceil(opaque_parts[1]*ThisSpark.MaxSparkCount), math.ceil(opaque_parts[#opaque_parts]*ThisSpark.MaxSparkCount)
			end
			
			for _ = 1, rng:NextInteger(1, ThisSpark.MaxSparkCount - ThisSpark.SparksN) do
				
				if #opaque_parts == 0 then break end
				
				local available_slots = {}
				
				for slot_i = minSlot, maxSlot do --Fill available_slots table
					
					if ThisSpark.SlotTable[slot_i] == nil then --check slot doesn't have existing spark
						available_slots[#available_slots + 1] = slot_i
					end
					
				end
				
				if #available_slots ~= 0 then 
					
					local ChosenSlot = available_slots[rng:NextInteger(1, #available_slots)]
					local localTrng = rng:NextNumber(-0.5, 0.5)
					local ChosenT = (ChosenSlot - 0.5 + localTrng)/ThisSpark.MaxSparkCount
					
					local dist, ChosenPart = 10, 1
					
					for opaque_i = 1, #opaque_parts do
						local testdist = math.abs(opaque_parts[opaque_i] - ChosenT)
						if testdist < dist then
							dist, ChosenPart = testdist, math.floor((opaque_parts[opaque_i]*BoltPartsN + 0.5) + 0.5)
						end
					end
					
					local Part = BoltParts[ChosenPart]
					
					--Make new spark--
					
					local A1, A2 = {}, {}
					A1.WorldPosition = Part.Position + localTrng*Part.CFrame.RightVector*Part.Size.X
					A2.WorldPosition = A1.WorldPosition + RandomVectorOffset(Part.CFrame.RightVector, math.pi/4)*rng:NextNumber(ThisSpark.MinDistance, ThisSpark.MaxDistance)
					A1.WorldAxis = (A2.WorldPosition - A1.WorldPosition).Unit
					A2.WorldAxis = A1.WorldAxis
					local NewSpark = LightningBolt.new(A1, A2, rng:NextInteger(ThisSpark.MinPartsPerSpark, ThisSpark.MaxPartsPerSpark))
					
					--NewSpark.MaxAngleOffset = math.rad(70)
					NewSpark.MinRadius, NewSpark.MaxRadius = 0, 0.8
					NewSpark.AnimationSpeed = 0
					NewSpark.Thickness = Part.Size.Y / 2
					NewSpark.MinThicknessMultiplier, NewSpark.MaxThicknessMultiplier = 1, 1
					NewSpark.PulseLength = 0.5
					NewSpark.PulseSpeed = rng:NextNumber(ThisSpark.MinSpeed, ThisSpark.MaxSpeed)
					NewSpark.FadeLength = 0.25
					local cH, cS, cV = Color3.toHSV(Part.Color)
					NewSpark.Color = Color3.fromHSV(cH, 0.5, cV)
					
					ThisSpark.SlotTable[ChosenSlot] = NewSpark
					
					--
					
				end
				
			end
			
		end
		
		
		
		--Update SparksN--
		
		local slotsInUse = 0
		
		for i, v in pairs(ThisSpark.SlotTable) do
			if v.Parts[1].Parent ~= nil then
				slotsInUse = slotsInUse + 1
			else
				ThisSpark.SlotTable[i] = nil --Removes reference to prevent memory leak
			end
		end
		
		ThisSpark.SparksN = slotsInUse
		
		--
	end
	
end)

return LightningSparks