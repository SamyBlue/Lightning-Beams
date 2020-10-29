--Properties do not update in realtime here
--i.e. You can't change explosion properties at any time beyond the initial function execution
local LightningBolt = require(script.Parent)
local LightningSparks = require(script.Parent.LightningSparks)

local rng_v = Random.new()
local clock = os.clock

function RandomVectorOffsetBetween(v, minAngle, maxAngle) --returns uniformly-distributed random unit vector no more than maxAngle radians away from v and no less than minAngle radians
    return (CFrame.lookAt(Vector3.new(), v)*CFrame.Angles(0, 0, rng_v:NextNumber(0, 2*math.pi))*CFrame.Angles(math.acos(rng_v:NextNumber(math.cos(maxAngle), math.cos(minAngle))), 0, 0)).LookVector
end


local ActiveExplosions = {}


local LightningExplosion = {}
LightningExplosion.__index = LightningExplosion

function LightningExplosion.new(Position, Size, NumBolts, Color, BoltColor, UpVector)
	local self = setmetatable({}, LightningExplosion)
	
	--Main (default) Properties--
	
		self.Size = Size or 1 --Value between 0 and 1 (1 for largest)
		self.NumBolts = NumBolts or 14 --Number of lightning bolts shot out from explosion
		self.Color = Color or ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)) --Can be a Color3 or ColorSequence
		self.BoltColor = BoltColor or Color3.new(0.3, 0.3, 1) --Can be a Color3 or ColorSequence
		self.UpVector = UpVector or Vector3.new(0, 1, 0) --Can be used to "rotate" the explosion
	
	--
	
	local parent = workspace.CurrentCamera
	
	local part = Instance.new("Part")
	part.Name = "LightningExplosion"
	part.Anchored = true
	part.CanCollide = false
	part.Locked = true
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.CFrame = CFrame.lookAt(Position + Vector3.new(0, 0.5, 0), Position + Vector3.new(0, 0.5, 0) + self.UpVector)*CFrame.lookAt(Vector3.new(), Vector3.new(0, 1, 0)):inverse()
	part.Parent = parent
	
	local attach = Instance.new("Attachment")
	attach.Parent = part
	attach.CFrame = CFrame.new()
	
	local partEmit1 = script.ExplosionBrightspot:Clone()
	local partEmit2 = script.GlareEmitter:Clone()
	local partEmit3 = script.PlasmaEmitter:Clone()
	
	local size = math.clamp(self.Size, 0, 1)
	
	partEmit2.Size = NumberSequence.new(30*size)
	partEmit3.Size = NumberSequence.new(18*size)
	partEmit3.Speed = NumberRange.new(100*size)
	
	partEmit1.Parent = attach
	partEmit2.Parent = attach
	partEmit3.Parent = attach
	
	local color = self.Color
	
	if typeof(color) == "Color3" then
		partEmit2.Color, partEmit3.Color = ColorSequence.new(color), ColorSequence.new(color)
		local cH, cS, cV = Color3.toHSV(color)
		partEmit1.Color = ColorSequence.new(Color3.fromHSV(cH, 0.5, cV))
	else --ColorSequence
		partEmit2.Color, partEmit3.Color = color, color
		local keypoints = color.Keypoints 
		for i = 1, #keypoints do
			local cH, cS, cV = Color3.toHSV(keypoints[i].Value)
			keypoints[i] = ColorSequenceKeypoint.new(keypoints[i].Time, Color3.fromHSV(cH, 0.5, cV))
		end
		partEmit1.Color = ColorSequence.new(keypoints)
	end
	
	partEmit1.Enabled, partEmit2.Enabled, partEmit3.Enabled = true, true, true
	
	local bolts = {}
	
	for i = 1, self.NumBolts do
		local A1, A2 = {}, {}

		A1.WorldPosition, A1.WorldAxis = attach.WorldPosition, RandomVectorOffsetBetween(self.UpVector, math.rad(65), math.rad(80))
		A2.WorldPosition, A2.WorldAxis = attach.WorldPosition + A1.WorldAxis*rng_v:NextNumber(20, 40)*1.4*size, RandomVectorOffsetBetween(-self.UpVector, math.rad(70), math.rad(110))
		--local curve0, curve1 = rng_v:NextNumber(0, 10)*size, rng_v:NextNumber(0, 10)*size
		local NewBolt = LightningBolt.new(A1, A2, 10)
		NewBolt.AnimationSpeed = 0
--		NewBolt.Thickness = 1 --*size
		NewBolt.Color = self.BoltColor
		NewBolt.PulseLength = 0.8
		NewBolt.ColorOffsetSpeed = 20
		NewBolt.Frequency = 3
		NewBolt.MinRadius, NewBolt.MaxRadius = 0, 4*size
		NewBolt.FadeLength = 0.4
		NewBolt.PulseSpeed = 5
		NewBolt.MinThicknessMultiplier, NewBolt.MaxThicknessMultiplier = 0.7, 1

		local NewSparks = LightningSparks.new(NewBolt)
		NewSparks.MinDistance, NewSparks.MaxDistance = 7.5, 10
		
		NewBolt.Velocity = (A2.WorldPosition - A1.WorldPosition).Unit*0.1*size
		--NewBolt.v0, NewBolt.v1 = rng_v:NextNumber(0, 5)*size, rng_v:NextNumber(0, 5)*size
		
		bolts[#bolts + 1] = NewBolt
	end
	
	self.Bolts = bolts
	self.Attachment = attach
	self.Part = part
	self.StartT = clock()
	self.RefIndex = #ActiveExplosions + 1

	ActiveExplosions[self.RefIndex] = self

	return self
end

function LightningExplosion:Destroy()
	ActiveExplosions[self.RefIndex] = nil
	self.Part:Destroy()
	
	for i = 1, #self.Bolts do
		self.Bolts[i] = nil
	end
	
	self = nil
end

game:GetService("RunService").Heartbeat:Connect(function ()
	
	for _, ThisExplosion in pairs(ActiveExplosions) do
		
		local timePassed = clock() - ThisExplosion.StartT
		local attach = ThisExplosion.Attachment
		
		if timePassed < 0.7 then 
			
			if timePassed > 0.2 then
				attach.ExplosionBrightspot.Enabled, attach.GlareEmitter.Enabled, attach.PlasmaEmitter.Enabled = false, false, false
			end
			
			for i = 1, #ThisExplosion.Bolts do 
				
				local currBolt = ThisExplosion.Bolts[i]
				currBolt.Attachment1.WorldPosition = currBolt.Attachment1.WorldPosition + currBolt.Velocity
				--currBolt.CurveSize0, currBolt.CurveSize1 = currBolt.CurveSize0 + currBolt.v0, currBolt.CurveSize1 + currBolt.v1
				
			end
			
		else
			
			ThisExplosion:Destroy()
			
		end
		
	end
	
end)




return LightningExplosion
