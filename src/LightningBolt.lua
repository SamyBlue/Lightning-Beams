--[[
	Procedural Lightning Effect Module. By Quasiduck
	License: https://github.com/SamyBlue/Lightning-Beams/blob/main/LICENSE
	See README for guide on how to use or scroll down to see all properties in LightningBolt.new
	All properties update in real-time except PartCount which requires a new LightningBolt to change
	i.e. You can change a property at any time after a LightningBolt instance is created and it will still update the look of the bolt
--]]

local PARTS_IN_CACHE = 1000 --Recommend setting higher if you intend to use LightningSparks
local clock = os.clock
local workspace = game:GetService("Workspace")
local parent = workspace.CurrentCamera

--*Part Cache Setup
--New parts automatically get added to cache if more parts are requested for use where a warning is thrown

local BoltPart = Instance.new("Part") --Template primitive that will make up the entire bolt
BoltPart.TopSurface, BoltPart.BottomSurface = 0, 0
BoltPart.Anchored, BoltPart.CanCollide = true, false
BoltPart.Locked, BoltPart.CastShadow = true, false
BoltPart.Shape = "Cylinder"
BoltPart.Name = "BoltPart"
BoltPart.Material = Enum.Material.Neon
BoltPart.Color = Color3.new(1, 1, 1)
BoltPart.Transparency = 1

local PartCache = require(script.Parent.PartCache:WaitForChild("PartCache"))
local LightningCache = PartCache.new(BoltPart, PARTS_IN_CACHE)
LightningCache:SetCacheParent(parent)

--*

local function CubicBezier(PercentAlongBolt, p0, p1, p2, p3)
	return p0 * (1 - PercentAlongBolt) ^ 3
		+ p1 * 3 * PercentAlongBolt * (1 - PercentAlongBolt) ^ 2
		+ p2 * 3 * (1 - PercentAlongBolt) * PercentAlongBolt ^ 2
		+ p3 * PercentAlongBolt ^ 3
end

local function DiscretePulse(PercentAlongBolt, TimePassed, s, k, f, min, max) --See https://www.desmos.com/calculator/hg5h4fpfim for demonstration
	return math.clamp(k / (2 * f) - math.abs((PercentAlongBolt - TimePassed * s + 0.5 * k) / f), min, max)
end

local function NoiseBetween(x, y, z, min, max)
	return min + (max - min) * (math.noise(x, y, z) + 0.5)
end

local xInverse = CFrame.lookAt(Vector3.new(), Vector3.new(1, 0, 0)):inverse()
local offsetAngle = math.cos(math.rad(90))

local ActiveBranches = {} --Contains all LightningBolt instances

local LightningBolt = {} --Define new class
LightningBolt.__type = "LightningBolt"
LightningBolt.__index = LightningBolt

--Small tip: You don't need to use actual Roblox Attachments below. You can also create "fake" ones as follows:
--[[
	local A1, A2 = {}, {}
	A1.WorldPosition, A1.WorldAxis = chosenPos1, chosenAxis1
	A2.WorldPosition, A2.WorldAxis = chosenPos2, chosenAxis2
	local NewBolt = LightningBolt.new(A1, A2, 40)
--]]

function LightningBolt.new(Attachment0, Attachment1, PartCount)
	local self = setmetatable({}, LightningBolt)
	PartCount = PartCount or 30

	--*Main (default) Properties--

	--Bolt Appearance Properties

	self.Enabled = true --Hides bolt without removing any parts when false
	self.Attachment0, self.Attachment1 = Attachment0, Attachment1 --Bolt originates from Attachment0 and ends at Attachment1
	self.CurveSize0, self.CurveSize1 = 0, 0 --Works similarly to roblox beams. See https://dk135eecbplh9.cloudfront.net/assets/blt160ad3fdeadd4ff2/BeamCurve1.png
	self.MinRadius, self.MaxRadius = 0, 2.4 --Governs the amplitude of fluctuations throughout the bolt
	self.Frequency = 1 --Governs the frequency of fluctuations throughout the bolt. Lower this to remove jittery-looking lightning
	self.AnimationSpeed = 7 --Governs how fast the bolt oscillates (i.e. how fast the fluctuating wave travels along bolt)
	self.Thickness = 1 --The thickness of the bolt
	self.MinThicknessMultiplier, self.MaxThicknessMultiplier = 0.2, 1 --Multiplies Thickness value by a fluctuating random value between MinThicknessMultiplier and MaxThicknessMultiplier along the Bolt

	--Bolt Kinetic Properties

	--[[
		Allows for fading in (or out) of the bolt with time. Can also create a "projectile" bolt
		Recommend setting AnimationSpeed to 0 if used as projectile (for better aesthetics)
		Works by passing a "wave" function which travels from left to right where the wave height represents opacity (opacity being 1 - Transparency)
		See https://www.desmos.com/calculator/hg5h4fpfim to help customise the shape of the wave with the below properties
	--]]
	self.MinTransparency, self.MaxTransparency = 0, 1
	self.PulseSpeed = 2 --Bolt arrives at Attachment1 1/PulseSpeed seconds later
	self.PulseLength = 1000000
	self.FadeLength = 0.2
	self.ContractFrom = 0.5 --Parts shorten or grow once their Transparency exceeds this value. Set to a value above 1 to turn effect off. See https://imgur.com/OChA441

	--Bolt Color Properties

	self.Color = Color3.new(1, 1, 1) --Can be a Color3 or ColorSequence
	self.ColorOffsetSpeed = 3 --Sets speed at which ColorSequence travels along Bolt

	--*

	--*Advanced Properties--

	--[[
		Allows you to pass a custom space curve for the bolt to be defined along
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
		Example: self.SpaceCurveFunction = VivianiCurve(PercentAlongBolt)
	--]]
	self.SpaceCurveFunction = CubicBezier

	--[[
		Allows you to pass a custom opacity profile which controls the opacity along the bolt
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
			-Second input passed must be a parameter representing TimePassed since instantiation 
		Example: self.OpacityProfileFunction = MovingSineWave(PercentAlongBolt, TimePassed)
		Note: You may want to set self.ContractFrom to a value above 1 if you pass a custom opacity profile as contraction was designed to work with DiscretePulse
	--]]
	self.OpacityProfileFunction = DiscretePulse

	--[[
		Allows you to pass a custom radial profile which controls the radius of control points along the bolt
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
	--]]
	self.RadialProfileFunction = function(PercentAlongBolt)
		return math.exp(-5000 * (PercentAlongBolt - 0.5) ^ 10)
	end
	--*

	--! Private vars are prefixed with an underscore (e.g. self._Parts) and should not be changed manually

	self._Parts = {} --The BoltParts which make up the Bolt

	for i = 1, PartCount do
		self._Parts[i] = LightningCache:GetPart()
	end

	self._PartsHidden = false
	self._DisabledTransparency = 1
	self._StartT = clock()
	self._RanNum = math.random() * 100
	self._RefIndex = #ActiveBranches + 1

	ActiveBranches[self._RefIndex] = self

	return self
end

function LightningBolt:Destroy()
	ActiveBranches[self._RefIndex] = nil

	for i = 1, #self._Parts do
		LightningCache:ReturnPart(self._Parts[i])
	end

	self = nil
end

function LightningBolt:_UpdateGeometry(
	BPart,
	PercentAlongBolt,
	TimePassed,
	ThicknessNoiseMultiplier,
	PrevPoint,
	NextPoint
)
	--Compute opacity for this particular section
	local MinOpa, MaxOpa = 1 - self.MaxTransparency, 1 - self.MinTransparency
	local Opacity = self.OpacityProfileFunction(
		PercentAlongBolt,
		TimePassed,
		self.PulseSpeed,
		self.PulseLength,
		self.FadeLength,
		MinOpa,
		MaxOpa
	)

	--Compute thickness for this particular section
	local Thickness = self.Thickness * ThicknessNoiseMultiplier * Opacity

	--Compute + update sizing and orientation of this particular section
	local contractf = 1 - self.ContractFrom
	local PartsN = #self._Parts
	if Opacity > contractf then
		BPart.Size = Vector3.new((NextPoint - PrevPoint).Magnitude, Thickness, Thickness)
		BPart.CFrame = CFrame.lookAt((PrevPoint + NextPoint) * 0.5, NextPoint) * xInverse
		BPart.Transparency = 1 - Opacity
	elseif Opacity > contractf - 1 / (PartsN * self.FadeLength) then
		local interp = (1 - (Opacity - (contractf - 1 / (PartsN * self.FadeLength))) * PartsN * self.FadeLength)
			* (PercentAlongBolt < TimePassed * self.PulseSpeed - 0.5 * self.PulseLength and 1 or -1)
		BPart.Size = Vector3.new((1 - math.abs(interp)) * (NextPoint - PrevPoint).Magnitude, Thickness, Thickness)
		BPart.CFrame = CFrame.lookAt(
				PrevPoint + (NextPoint - PrevPoint) * (math.max(0, interp) + 0.5 * (1 - math.abs(interp))),
				NextPoint
			)
			* xInverse
		BPart.Transparency = 1 - Opacity
	else
		BPart.Transparency = 1
	end
end

function LightningBolt:_UpdateColor(BPart, PercentAlongBolt, TimePassed)
	if typeof(self.Color) == "Color3" then
		BPart.Color = self.Color
	else --ColorSequence
		local t1 = (self._RanNum + PercentAlongBolt - TimePassed * self.ColorOffsetSpeed) % 1
		local keypoints = self.Color.Keypoints
		for i = 1, #keypoints - 1 do
			if keypoints[i].Time < t1 and t1 < keypoints[i + 1].Time then
				BPart.Color = keypoints[i].Value:lerp(
					keypoints[i + 1].Value,
					(t1 - keypoints[i].Time) / (keypoints[i + 1].Time - keypoints[i].Time)
				)
				break
			end
		end
	end
end

function LightningBolt:_Disable()
	self.Enabled = false
	for _, BPart in ipairs(self._Parts) do
		BPart.Transparency = self._DisabledTransparency
	end
end

game:GetService("RunService").Heartbeat:Connect(function()
	debug.profilebegin("LightningBolt") --Create performance profile

	for _, ThisBranch in pairs(ActiveBranches) do
		if ThisBranch.Enabled == true then
			ThisBranch._PartsHidden = false

			--Extract important variables
			local MinRadius, MaxRadius = ThisBranch.MinRadius, ThisBranch.MaxRadius
			local Parts = ThisBranch._Parts
			local PartsN = #Parts
			local RanNum = ThisBranch._RanNum
			local spd = ThisBranch.AnimationSpeed
			local freq = ThisBranch.Frequency
			local MinThick, MaxThick = ThisBranch.MinThicknessMultiplier, ThisBranch.MaxThicknessMultiplier
			local TimePassed = clock() - ThisBranch._StartT
			local SpaceCurveFunction, RadialProfileFunction =
				ThisBranch.SpaceCurveFunction, ThisBranch.RadialProfileFunction
			local Lifetime = (ThisBranch.PulseLength + 1) / ThisBranch.PulseSpeed

			--Extract control points
			local a0, a1, CurveSize0, CurveSize1 =
				ThisBranch.Attachment0, ThisBranch.Attachment1, ThisBranch.CurveSize0, ThisBranch.CurveSize1
			local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition
				+ a0.WorldAxis * CurveSize0, a1.WorldPosition
				- a1.WorldAxis * CurveSize1, a1.WorldPosition

			--Initialise iterative scheme for generating points along space curve
			local init = SpaceCurveFunction(0, p0, p1, p2, p3)
			local PrevPoint, bezier0 = init, init

			--Update
			if TimePassed < Lifetime then
				for i = 1, PartsN do
					local BPart = Parts[i]
					local PercentAlongBolt = i / PartsN

					--Compute noisy inputs
					local input, input2 = (spd * -TimePassed)
						+ freq * 10 * PercentAlongBolt
						- 0.2
						+ RanNum * 4, 5 * ((spd * 0.01 * -TimePassed) / 10 + freq * PercentAlongBolt)
						+ RanNum * 4
					local noise0 = NoiseBetween(5 * input, 1.5, 5 * 0.2 * input2, 0, 0.1 * 2 * math.pi)
						+ NoiseBetween(0.5 * input, 1.5, 0.5 * 0.2 * input2, 0, 0.9 * 2 * math.pi)
					local noise1 = NoiseBetween(3.4, input2, input, MinRadius, MaxRadius)
						* RadialProfileFunction(PercentAlongBolt)
					local thicknessNoise = NoiseBetween(2.3, input2, input, MinThick, MaxThick)

					--Find next point along space curve
					local bezier1 = SpaceCurveFunction(PercentAlongBolt, p0, p1, p2, p3)

					--Find next point along bolt
					local NextPoint = i ~= PartsN
							and (CFrame.new(bezier0, bezier1) * CFrame.Angles(0, 0, noise0) * CFrame.Angles(
							math.acos(math.clamp(NoiseBetween(input2, input, 2.7, offsetAngle, 1), -1, 1)),
							0,
							0
						) * CFrame.new(0, 0, -noise1)).Position
						or bezier1

					ThisBranch:_UpdateGeometry(BPart, PercentAlongBolt, TimePassed, thicknessNoise, PrevPoint, NextPoint)

					ThisBranch:_UpdateColor(BPart, PercentAlongBolt, TimePassed)

					PrevPoint, bezier0 = NextPoint, bezier1
				end
			else
				ThisBranch:Destroy()
			end
		else --Enabled = false
			if ThisBranch._PartsHidden == false then
				ThisBranch._PartsHidden = true
				ThisBranch:_Disable()
			end
		end
	end

	debug.profileend()
end)

return LightningBolt
