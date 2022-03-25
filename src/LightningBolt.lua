--[[
	Procedurally generated lightning effects in Roblox
	Documentation: https://github.com/SamyBlue/Lightning-Beams/blob/main/README.md --TODO: Update README when planned v2.0 features implemented successfully
	License: https://github.com/SamyBlue/Lightning-Beams/blob/main/LICENSE
	See Documentation for guide on how to use or scroll down to see all public properties and methods
--]]

local PARTS_IN_CACHE = 500 --Recommend setting higher if you intend to use LightningSparks
local storePartsWithin = game:GetService("Workspace").Terrain

local RunService = game:GetService("RunService")
local clock = RunService:IsRunning() and time or os.clock

--TODO: Seperate out into LightningCache module
--*Part Cache Setup
--New parts automatically get added to cache if more parts are requested for use where a warning is also thrown in the console
local BoltPart = Instance.new("Part") --Template that will be used to draw the geometry of LightningBolt
BoltPart.TopSurface, BoltPart.BottomSurface = 0, 0
BoltPart.Anchored, BoltPart.CanCollide = true, false
BoltPart.Locked, BoltPart.CastShadow = true, false
BoltPart.CanTouch, BoltPart.CanQuery = false, false
BoltPart.Shape = Enum.PartType.Cylinder
BoltPart.Name = "BoltPart"
BoltPart.Material = Enum.Material.Neon
BoltPart.Color = Color3.new(1, 1, 1)
BoltPart.Transparency = 1

local PartCache = require(script.Parent.PartCache:WaitForChild("PartCache")) --TODO: Create a dependency folder
local LightningCache = PartCache.new(BoltPart, PARTS_IN_CACHE)
LightningCache:SetCacheParent(storePartsWithin)

--TODO: Seperate out into MathUtils module
--*Math utilities
local function CubicBezier(PercentAlongBolt, p0, p1, p2, p3)
	return p0 * (1 - PercentAlongBolt) ^ 3
		+ p1 * 3 * PercentAlongBolt * (1 - PercentAlongBolt) ^ 2
		+ p2 * 3 * (1 - PercentAlongBolt) * PercentAlongBolt ^ 2
		+ p3 * PercentAlongBolt ^ 3
end

local function DiscretePulse(PercentAlongBolt, TimePassed, s, k, f, min, max) --See https://www.desmos.com/calculator/hg5h4fpfim for demonstration
	return math.clamp(k / (2 * f) - math.abs((PercentAlongBolt - TimePassed * s + 0.5 * k) / f), min, max)
end

local function ExtrudeCenter(PercentAlongBolt) --TODO: Rename to PinchedCornersCurve to make clearer what it looks like
	return math.exp(-5000 * (PercentAlongBolt - 0.5) ^ 10)
end

local function NoiseBetween(x, y, z, min, max)
	return min + (max - min) * (math.noise(x, y, z) + 0.5)
end

local xInverse = CFrame.lookAt(Vector3.new(), Vector3.new(1, 0, 0)):Inverse() --TODO: Rename to X_LOOKAT where "Helps for pointing RightVector towards point x when multiplied with CFrame.lookAt(_, x)"
local offsetAngle = math.cos(math.rad(90)) --TODO: Replace with 0 in relevant code and remove this variable

--*Class setup
local ActiveBranches = {} --Contains all instances of LightningBolt --TODO: Rename to LightningBoltInstances

local LightningBolt = {} --Define new class
LightningBolt.__index = LightningBolt

function LightningBolt.new(Attachment0, Attachment1, PartCount)
	local self = setmetatable({}, LightningBolt)
	PartCount = PartCount or 30

	--Bolt Appearance Properties --TODO: Seperate out into private method: _SetupDefaultAppearance() except for self.Attachment0, self.Attachment1 which should stay put within this constructor
	self.Enabled = true --Hides bolt without destroying any parts when false --TODO: Deprecate and remove functionality due to unintuitive interaction with bolt destruction being on a timer
	self.Attachment0, self.Attachment1 = Attachment0, Attachment1 --Attachment0 governs where the LightningBolt starts from. Attachment1 governs where the LightningBolt ends.
	self.CurveSize0, self.CurveSize1 = 0, 0 --Works similarly to Roblox's Beams. See https://dk135eecbplh9.cloudfront.net/assets/blt160ad3fdeadd4ff2/BeamCurve1.png for help understanding.
	self.MinRadius, self.MaxRadius = 0, 2.4 --Governs the min and max radial offset distance of points interpolated along the current SpaceCurveFunction --TODO: Write simpler description
	self.Frequency = 1 --Governs the perceived frequency of radial fluctuations
	self.AnimationSpeed = 7 --Governs how fast the LightningBolt oscillates over time. Set to 0 to have a static looking LightningBolt that doesn't change geometry over time.
	self.Thickness = 1 --Governs the thickness of the LightningBolt
	self.MinThicknessMultiplier, self.MaxThicknessMultiplier = 0.2, 1 --Multiplies perceived thickness by a fluctuating random value between MinThicknessMultiplier and MaxThicknessMultiplier along the Bolt

	--Bolt Kinetic Properties --TODO: Seperate out into private method: _SetupDefaultKinetics()
	--[[
		Governs how the LightningBolt moves from Attachment0 to Attachment1
		Recommend setting AnimationSpeed to 0 if using a LightningBolt visually as a moving projectile (for better aesthetics)
		Works by moving a travelling wave along the LightningBolt where the height of the wave represents visibility at a particular percentage point along the LightningBolt
		See https://www.desmos.com/calculator/hg5h4fpfim to help customise the shape of the travelling wave with the below properties
	--]]
	self.MinTransparency, self.MaxTransparency = 0, 1 --TODO: Deprecate (and make private version) due to future optimization of performing less updates on Transparent BoltParts
	self.PulseSpeed = 2 --Tip: Bolt first arrives at Attachment1 at [1 / PulseSpeed] seconds. Bolt gets destroyed at [(PulseLength + 1) / PulseSpeed] seconds
	self.PulseLength = 100
	self.FadeLength = 0.2
	self.ContractFrom = 0.5 --Parts shorten or grow once their Transparency exceeds this value. See https://imgur.com/OChA441

	--Bolt Color Properties 
	self.Color = Color3.new(1, 1, 1) --Can be a Color3 or ColorSequence --TODO: Deprecate and replace with new color-setting method
	self.ColorOffsetSpeed = 3 --Sets speed at which ColorSequence travels along Bolt --TODO: Deprecate and replace with new color-setting method

	--Advanced Properties
	--[[
		Allows you to pass a custom space curve for the LightningBolt to be defined along
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
		Example: self.SpaceCurveFunction = VivianiCurve(PercentAlongBolt)
	--]]
	self.SpaceCurveFunction = CubicBezier

	--[[
		Allows you to pass a custom opacity profile which controls the opacity along the LightningBolt
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
			-Second input passed must be a parameter representing TimePassed since instantiation 
		Example: self.OpacityProfileFunction = MovingSineWave(PercentAlongBolt, TimePassed)
		Note: You may want to set self.ContractFrom to a value above 1 if you pass a custom opacity profile as contraction was designed to work with DiscretePulse
	--]]
	self.OpacityProfileFunction = DiscretePulse --TODO: Deprecate due to future optimization of performing less updates on Transparent BoltParts which only works with DiscretePulse

	--[[
		Allows you to create a custom radial profile which multiplies with the radial offset distances --TODO: Write simpler description
		Constraints: 
			-First input passed must be a parameter representing PercentAlongBolt between values 0 and 1
	--]]
	self.RadialProfileFunction = ExtrudeCenter
	
	--Private variables
	--! Private variables are prefixed with an underscore (e.g. self._Parts) and should not be changed from outside this module
	self._Parts = {} --Stores all Parts which make up the Bolt

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

--Calls Destroy() after TimeLength seconds where a dissipating effect takes place in the meantime --TODO: Replace with simpler and more aesthetic thickness frequency method in plan
function LightningBolt:DestroyDissipate(TimeLength, Strength)
	TimeLength = TimeLength or 0.2
	Strength = Strength or 0.5
	local DissipateStartT = clock()
	local start, mid, goal = self.MinTransparency, self.ContractFrom, self.ContractFrom
		+ 1 / (#self._Parts * self.FadeLength)
	local StartRadius = self.MaxRadius
	local StartMinThick = self.MinThicknessMultiplier
	local DissipateLoop

	DissipateLoop = RunService.Heartbeat:Connect(function()
		local TimeSinceDissipate = clock() - DissipateStartT
		self.MinThicknessMultiplier = StartMinThick + (-2 - StartMinThick) * TimeSinceDissipate / TimeLength

		if TimeSinceDissipate < TimeLength * 0.4 then
			local interp = (TimeSinceDissipate / (TimeLength * 0.4))
			self.MinTransparency = start + (mid - start) * interp
		elseif TimeSinceDissipate < TimeLength then
			local interp = ((TimeSinceDissipate - TimeLength * 0.4) / (TimeLength * 0.6))
			self.MinTransparency = mid + (goal - mid) * interp
			self.MaxRadius = StartRadius * (1 + Strength * interp)
			self.MinRadius = self.MinRadius + (self.MaxRadius - self.MinRadius) * interp
		else
			--Destroy Bolt
			local TimePassed = clock() - self._StartT
			local Lifetime = (self.PulseLength + 1) / self.PulseSpeed

			if TimePassed < Lifetime then --prevents Destroy()ing twice
				self:Destroy()
			end

			--Disconnect Loop
			DissipateLoop:Disconnect()
			DissipateLoop = nil
		end
	end)
end

function LightningBolt:_UpdateGeometry(
	BPart,
	PercentAlongBolt,
	TimePassed,
	ThicknessNoiseMultiplier, --TODO: Refactor with a private property storing array of thickness data
	PrevPoint,
	NextPoint
)
	--Compute opacity for this particular section --TODO: Seperate out into separate private method which updates a private property storing array of opacities
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

	--Compute thickness for this particular section --TODO: Seperate out into separate private method which updates a private property storing array of thickness data
	local Thickness = self.Thickness * ThicknessNoiseMultiplier * Opacity
	Opacity = Thickness > 0 and Opacity or 0

	--Compute + update sizing and orientation of this particular section
	local contractf = 1 - self.ContractFrom --TODO: Would be nice in future to refactor this section to make the math formulas here more intuitive
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

function LightningBolt:_UpdateColor(BPart, PercentAlongBolt, TimePassed) --TODO: Refactor with new color updating methods
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

--TODO: Refactor into RunService.Heartbeat:Connect(UpdateAllLightningBolts)
RunService.Heartbeat:Connect(function () --TODO: Refactor below variables with more descriptive variable names that are camelCase and refactor more into single-purpose utility methods
	debug.profilebegin("LightningBolt") --Create performance profile of all LightningBolt instances

	for _, ThisBranch in pairs(ActiveBranches) do
		if ThisBranch.Enabled == true then
			ThisBranch._PartsHidden = false

			--Extract important variables
			local MinRadius, MaxRadius = ThisBranch.MinRadius, ThisBranch.MaxRadius
			local Parts = ThisBranch._Parts
			local PartsN = #Parts --TODO: Create a private variable for this as it will basically never change
			local RanNum = ThisBranch._RanNum
			local spd = ThisBranch.AnimationSpeed
			local freq = ThisBranch.Frequency
			local MinThick, MaxThick = ThisBranch.MinThicknessMultiplier, ThisBranch.MaxThicknessMultiplier
			local TimePassed = clock() - ThisBranch._StartT --TODO: Convert to public function: SetTimePassed(clock() - ThisBranch._StartT)
			local SpaceCurveFunction, RadialProfileFunction =
				ThisBranch.SpaceCurveFunction, ThisBranch.RadialProfileFunction
			local Lifetime = (ThisBranch.PulseLength + 1) / ThisBranch.PulseSpeed --TODO: Convert to private function: _GetLifetime()

			--TODO: Create a function which outputs the min and max index to iterate through for changes (i.e. the planned transparency optimization)

			--Extract control points --TODO: Refactor into function which updates a private property holding a table of SpaceCurve points (which potentially utilizes memoization?)
			local a0, a1, CurveSize0, CurveSize1 =
				ThisBranch.Attachment0, ThisBranch.Attachment1, ThisBranch.CurveSize0, ThisBranch.CurveSize1
			local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition
				+ a0.WorldAxis * CurveSize0, a1.WorldPosition
				- a1.WorldAxis * CurveSize1, a1.WorldPosition

			--Initialise iterative scheme for generating points along space curve
			local init = SpaceCurveFunction(0, p0, p1, p2, p3)
			local PrevPoint, bezier0 = init, init --TODO: Replace with more general purpose name given that the SpaceCurveFunction may not be CubicBezier

			--Update
			if TimePassed < Lifetime then --TODO: Refactor into guard expression that goes at the top with a continue statement if true
				for i = 1, PartsN do --TODO: Seperate out for loop into separate loops that execute within single-purpose utility methods
					local BPart = Parts[i]
					local PercentAlongBolt = i / PartsN --TODO: Create private property storing array of percent points

					--Compute noisy inputs --TODO: Give more descriptive names indicating where each noise value is used and clean up the math a little + Put in relevant private methods
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
					local bezier1 = SpaceCurveFunction(PercentAlongBolt, p0, p1, p2, p3) --TODO: Refactor into function which updates a private property holding a table of SpaceCurve points

					--Find next point along LightningBolt --TODO: Refactor into function that computes the noisy inputs within it as well as all LightningBolt points which updates a private property holding a table of all of them
					local NextPoint = i ~= PartsN
							and (CFrame.new(bezier0, bezier1) * CFrame.Angles(0, 0, noise0) * CFrame.Angles(
							math.acos(math.clamp(NoiseBetween(input2, input, 2.7, offsetAngle, 1), -1, 1)),
							0,
							0
						) * CFrame.new(0, 0, -noise1)).Position
						or bezier1 --TODO: Replace .new(bezier0, bezier1) with .lookAt(bezier0, bezier1) + Seperate out into math utility "VectorWithinSemisphere"?

					ThisBranch:_UpdateGeometry(BPart, PercentAlongBolt, TimePassed, thicknessNoise, PrevPoint, NextPoint) --TODO: Refactor to use private methods and vars

					ThisBranch:_UpdateColor(BPart, PercentAlongBolt, TimePassed) --TODO: Refactor to use private methods and vars

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
