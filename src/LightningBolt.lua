--Procedural Lightning Module. By Quasiduck
--License: See GitHub ~ https://github.com/SamyBlue/Lightning-Beams/blob/main/LICENSE
--See README for guide on how to use or scroll down to see all properties in LightningBolt.new
--All properties update in real-time except PartCount which requires a new LightningBolt to change
--i.e. You can change a property at any time and it will still update the look of the bolt

local clock = os.clock
local ScreenGui, DummyPart, camera
local Players = game:GetService("Players")
local Player = Players.LocalPlayer



function DiscretePulse(input, s, k, f, t, min, max) --input should be between 0 and 1. See https://www.desmos.com/calculator/hg5h4fpfim for demonstration.
	return math.clamp( (k)/(2*f) - math.abs( (input - t*s + 0.5*(k)) / (f) ), min, max )
end

function NoiseBetween(x, y, z, min, max)
	return min + (max - min)*(math.noise(x, y, z) + 0.5)
end

function CubicBezier(p0, p1, p2, p3, t)
	return p0*(1 - t)^3 + p1*3*t*(1 - t)^2 + p2*3*(1 - t)*t^2 + p3*t^3
end

local BoltAdorn = Instance.new("ImageHandleAdornment")
BoltAdorn.Name = "BoltAdorn"
BoltAdorn.Image = "http://www.roblox.com/asset/?id=4955566540" --"http://www.roblox.com/asset/?id=457102813"
BoltAdorn.Transparency = 1
BoltAdorn.Color3 = Color3.new(1, 1, 1)
BoltAdorn.ZIndex = 0
BoltAdorn.Size = Vector2.new(0, 0)

local rng = Random.new()

local ActiveBranches = {}

local LightningBolt = {}
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
	
	--Main (default) Properties--
	
		--Bolt Appearance Properties--
			self.Enabled = true --Hides bolt without destroying any parts when false
			self.Attachment0, self.Attachment1 = Attachment0, Attachment1 --Bolt originates from Attachment0 and ends at Attachment1
			self.CurveSize0, self.CurveSize1 = 0, 0 --Works similarly to beams. See https://dk135eecbplh9.cloudfront.net/assets/blt160ad3fdeadd4ff2/BeamCurve1.png
			self.MinRadius, self.MaxRadius = 0, 2.4 --Governs the amplitude of fluctuations throughout the bolt
			self.Frequency = 1 --PartCount/40 --Governs the frequency of fluctuations throughout the bolt. Lower this to remove jittery-looking lightning
			self.AnimationSpeed = 7 --Governs how fast the bolt oscillates (i.e. how fast the fluctuating wave travels along bolt)
			self.Thickness = 2 --5 --The thickness of the bolt
			self.MinThicknessMultiplier, self.MaxThicknessMultiplier = 0.2, 1 --Multiplies Thickness value by a fluctuating random value between MinThicknessMultiplier and MaxThicknessMultiplier along the Bolt
	
		--Bolt Kinetic Properties--
			--Allows for fading in (or out) of the bolt with time. Can also create a "projectile" bolt
			--Recommend setting AnimationSpeed to 0 if used as projectile (for better aesthetics)
			--Works by passing a "wave" function which travels from left to right where the wave height represents opacity (opacity being 1 - Transparency)
			--See https://www.desmos.com/calculator/hg5h4fpfim to help customise the shape of the wave with the below properties
			self.MinTransparency, self.MaxTransparency = 0, 1 --See https://www.desmos.com/calculator/hg5h4fpfim
			self.PulseSpeed = 2 --Bolt arrives at Attachment1 1/PulseSpeed seconds later. See https://www.desmos.com/calculator/hg5h4fpfim
			self.PulseLength = 1000000 --See https://www.desmos.com/calculator/hg5h4fpfim
			self.FadeLength = 0.2 --See https://www.desmos.com/calculator/hg5h4fpfim
			self.ContractFrom = 0.5 --Parts shorten or grow once their Transparency exceeds this value. Set to a value above 1 to turn effect off. See https://imgur.com/OChA441
	
		--Bolt Color Properties--
			self.Color = Color3.new(1, 1, 1) --Can be a Color3 or ColorSequence
			self.ColorOffsetSpeed = 3 --Sets speed at which ColorSequence travels along Bolt
	
	--
	
	self.Parts = {} --The BoltParts which make up the Bolt
	
	camera = workspace.CurrentCamera
	
	if Player.PlayerGui:FindFirstChild("LightningBeams") == nil then
		ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Name = "LightningBeams"
		ScreenGui.ResetOnSpawn = false
		ScreenGui.Parent = Player.PlayerGui
		DummyPart = Instance.new("Part")
		DummyPart.Anchored, DummyPart.Locked, DummyPart.CanCollide = true, true, false
		DummyPart.CFrame = CFrame.new()
		DummyPart.Size = Vector3.new(0, 0, 0)
		DummyPart.Transparency = 1
		DummyPart.Parent = ScreenGui
		DummyPart.Name = "AdorneePart"
	end
	
	local a0, a1 = Attachment0, Attachment1
	local parent = ScreenGui
	local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition + a0.WorldAxis*self.CurveSize0, a1.WorldPosition - a1.WorldAxis*self.CurveSize1, a1.WorldPosition
	local PrevPoint, bezier0 = p0, p0
	local MainBranchN = PartCount or 30
	
	for i = 1, MainBranchN do
		local t1 = i/MainBranchN
		local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
		local NextPoint = i ~= MainBranchN and (CFrame.lookAt(bezier0, bezier1)).Position or bezier1
		local BAdorn = BoltAdorn:Clone()
		BAdorn.Parent = parent
		BAdorn.Adornee = DummyPart
		self.Parts[i] = BAdorn
		PrevPoint, bezier0 = NextPoint, bezier1
	end
	
	self.PartsHidden = false
	self.DisabledTransparency = 1
	self.StartT = clock()
	self.RanNum = math.random()*100
	self.RefIndex = #ActiveBranches + 1
	
	ActiveBranches[self.RefIndex] = self
	
	return self
end

function LightningBolt:Destroy()
	ActiveBranches[self.RefIndex] = nil
	
	for i = 1, #self.Parts do
		self.Parts[i]:Destroy()
		
		if i%100 == 0 then wait() end
	end
	
	self = nil
end

local cross = Vector3.new().Cross
local offsetAngle = math.cos(math.rad(90))

game:GetService("RunService").Heartbeat:Connect(function ()
	
	for _, ThisBranch in pairs(ActiveBranches) do
		if ThisBranch.Enabled == true then
			ThisBranch.PartsHidden = false
			local MinOpa, MaxOpa = 1 - ThisBranch.MaxTransparency, 1 - ThisBranch.MinTransparency
			local MinRadius, MaxRadius = ThisBranch.MinRadius, ThisBranch.MaxRadius
			local thickness = ThisBranch.Thickness
			local Parts = ThisBranch.Parts
			local PartsN = #Parts
			local RanNum = ThisBranch.RanNum
			local StartT = ThisBranch.StartT
			local spd = ThisBranch.AnimationSpeed
			local freq = ThisBranch.Frequency
			local MinThick, MaxThick = ThisBranch.MinThicknessMultiplier, ThisBranch.MaxThicknessMultiplier
			local a0, a1, CurveSize0, CurveSize1 = ThisBranch.Attachment0, ThisBranch.Attachment1, ThisBranch.CurveSize0, ThisBranch.CurveSize1
			local p0, p1, p2, p3 = a0.WorldPosition, a0.WorldPosition + a0.WorldAxis*CurveSize0, a1.WorldPosition - a1.WorldAxis*CurveSize1, a1.WorldPosition
			local timePassed = clock() - StartT
			local PulseLength, PulseSpeed, FadeLength = ThisBranch.PulseLength, ThisBranch.PulseSpeed, ThisBranch.FadeLength
			local Color = ThisBranch.Color
			local ColorOffsetSpeed = ThisBranch.ColorOffsetSpeed
			local contractf = 1 - ThisBranch.ContractFrom
			local PrevPoint, bezier0 = p0, p0
			
			if timePassed < (PulseLength + 1) / PulseSpeed then
				
				for i = 1, PartsN do
					--local spd = NoiseBetween(i/PartsN, 1.5, 0.1*i/PartsN, -MinAnimationSpeed, MaxAnimationSpeed) --Can enable to have an alternative animation which doesn't shift the noisy lightning "Texture" along the bolt
					local BPart = Parts[i]
					local t1 = i/PartsN
					local Opacity = DiscretePulse(t1, PulseSpeed, PulseLength, FadeLength, timePassed, MinOpa, MaxOpa)
					local bezier1 = CubicBezier(p0, p1, p2, p3, t1)
					local time = -timePassed --minus to ensure bolt waves travel from a0 to a1
					local input, input2 = (spd*time) + freq*10*t1 - 0.2 + RanNum*4, 5*((spd*0.01*time) / 10 + freq*t1) + RanNum*4
					local noise0 = NoiseBetween(5*input, 1.5, 5*0.2*input2, 0, 0.1*2*math.pi) + NoiseBetween(0.5*input, 1.5, 0.5*0.2*input2, 0, 0.9*2*math.pi)
					local noise1 = NoiseBetween(3.4, input2, input, MinRadius, MaxRadius)*math.exp(-5000*(t1 - 0.5)^10)
					local thicknessNoise = NoiseBetween(2.3, input2, input, MinThick, MaxThick)
					local NextPoint = i ~= PartsN and (CFrame.new(bezier0, bezier1)*CFrame.Angles(0, 0, noise0)*CFrame.Angles(math.acos(math.clamp(NoiseBetween(input2, input, 2.7, offsetAngle, 1), -1, 1)), 0, 0)*CFrame.new(0, 0, -noise1)).Position or bezier1
					
					local diff = NextPoint - PrevPoint
					
					if Opacity > contractf then
						--BPart.Size = Vector3.new((NextPoint - PrevPoint).Magnitude, thickness*thicknessNoise*Opacity, thickness*thicknessNoise*Opacity)
						--BPart.CFrame = CFrame.lookAt(0.5*(PrevPoint + NextPoint), NextPoint)*xInverse
						
						BPart.Size = Vector2.new(thickness*thicknessNoise*Opacity, diff.Magnitude + thickness*thicknessNoise*Opacity*0.2)
						local po = 0.5*(PrevPoint + NextPoint)
						local uv = diff.Unit
						local rv = cross(camera.CFrame.Position - po, uv).Unit
						BPart.CFrame = CFrame.fromMatrix(po, rv, uv)
						
						BPart.Transparency = 1 - Opacity
					elseif Opacity > contractf - 1/(PartsN*FadeLength) then
						local interp = (1 - (Opacity - (contractf - 1/(PartsN*FadeLength)))*PartsN*FadeLength)*(t1 < timePassed*PulseSpeed - 0.5*PulseLength and 1 or -1)		
						--BPart.Size = Vector3.new((1 - math.abs(interp))*(NextPoint - PrevPoint).Magnitude, thickness*thicknessNoise*Opacity, thickness*thicknessNoise*Opacity)
						--BPart.CFrame = CFrame.lookAt(PrevPoint + (NextPoint - PrevPoint)*(math.max(0, interp) + 0.5*(1 - math.abs(interp))), NextPoint)*xInverse
						
						BPart.Size = Vector2.new(thickness*thicknessNoise*Opacity, (1 - math.abs(interp))*diff.Magnitude + thickness*thicknessNoise*Opacity*0.2)
						local po = PrevPoint + (NextPoint - PrevPoint)*(math.max(0, interp) + 0.5*(1 - math.abs(interp)))
						local uv = diff.Unit
						local rv = cross(camera.CFrame.Position - po, uv).Unit
						BPart.CFrame = CFrame.fromMatrix(po, rv, uv)
						
						BPart.Transparency = 1 - Opacity
					else
						BPart.Transparency = 1
					end
					
					if typeof(Color) == "Color3" then
						BPart.Color3 = Color
					else --ColorSequence
						t1 = (RanNum + t1 - timePassed*ColorOffsetSpeed)%1
						local keypoints = Color.Keypoints 
						for i = 1, #keypoints - 1 do --convert colorsequence onto lightning
							if keypoints[i].Time < t1 and t1 < keypoints[i+1].Time then
								BPart.Color3 = keypoints[i].Value:lerp(keypoints[i+1].Value, (t1 - keypoints[i].Time)/(keypoints[i+1].Time - keypoints[i].Time))
								break
							end
						end
					end
					
					PrevPoint, bezier0 = NextPoint, bezier1
				end
				
			else
				
				ThisBranch:Destroy()
				
			end
			
		else --Enabled = false
			
			if ThisBranch.PartsHidden == false then
				ThisBranch.PartsHidden = true
				local datr = ThisBranch.DisabledTransparency
				for i = 1, #ThisBranch.Parts do
					ThisBranch.Parts[i].Transparency = datr
				end
			end
			
		end
	end
	
end)

return LightningBolt
