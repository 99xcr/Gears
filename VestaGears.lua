-- Vesta Gears (v3)
-- Real gears are preloaded in the background, so GIVE is instant and never lags.
-- If a model hasn't loaded yet, a built-in model is given at once and swapped for the real one when it arrives.
-- Menu: drag the title bar, "-" turns the menu into a gear icon (click the icon to open it again),
-- "X" closes the menu (gears stay), RightShift hides/shows.
-- Only the first 10 gears show on the hotbar. Press ` (backtick) to open the full inventory and see the rest.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- kind: carpet (fly) / speed / gravity / jump / melee / dryer / seabow / rocket
-- feet = true -> gear is placed under your feet and your arm does NOT stick out
-- Inventory/hotbar icon for the Dual Speed Coil (your two red coils picture).
-- Roblox needs the picture uploaded first: upload it at create.roblox.com as an Image, then paste its ID here,
-- for example "rbxassetid://123456789". Leave it empty to keep the normal coil icon.
local DUAL_COIL_ICON = ""

local GEARS = {
	{ name = "Rainbow Carpet",     kind = "carpet", id = 225921000,  speed = 90,  color = "rainbow", trail = "rainbow" },
	{ name = "Gold Carpet",        kind = "carpet", id = 1016183873, speed = 70,  color = Color3.fromRGB(255, 200, 40),
		trail = ColorSequence.new(Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 240, 150)) },
	{ name = "Black Magic Carpet", kind = "carpet", id = 402305186,  speed = 110, color = Color3.fromRGB(15, 15, 18),
		trail = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(30, 30, 30)), trailEmission = 0 },
	{ name = "Blow Dryer",         kind = "dryer",  id = 11719016 },
	{ name = "Sea Bow",            kind = "seabow", id = 236438668 },
	{ name = "Gravity Coil",       kind = "gravity", id = 16688968, lift = 0.75 },
	{ name = "Speed Coil",         kind = "speed",  id = 99119158, speed = 40 },
	{ name = "Rocket Launcher",    kind = "rocket", id = 32356064 },

	{ name = "Dual Speed Coil",    kind = "speed",  id = 99119158, speed = 110, dual = true, icon = DUAL_COIL_ICON },
	{ name = "Dual Gravity Coil",  kind = "gravity", id = 150366274, lift = 0.875 },

	{ name = "Flying Magic Carpet",          kind = "carpet", id = 71037028,  speed = 80 },
	{ name = "Sinister Flying Magic Carpet", kind = "carpet", id = 103235041, speed = 100 },
	{ name = "Flying Vacuum",                kind = "carpet", id = 313547087, speed = 85 },
	{ name = "Flying Reindeer",              kind = "carpet", id = 330296266, speed = 85 },
	{ name = "Broom",                        kind = "carpet", id = 36913601,  speed = 80 },
	{ name = "Flying Carpet of Books",       kind = "carpet", id = 498752764, speed = 80 },
	{ name = "Zoom Broom 5000",              kind = "carpet", id = 511930668, speed = 130 },
	{ name = "Ghost Ride",                   kind = "carpet", id = 179369627, speed = 90 },

	{ name = "Spring-loaded Jumping Stilts", kind = "jump", id = 226206639, power = 130 },
	{ name = "Vaulting Pole",                kind = "jump", id = 88143166,  power = 140 },

	{ name = "Bug Juice",                    kind = "speed", id = 57229313, speed = 60 },
	{ name = "Spec Alpha Biograft Energy Sword", kind = "melee", id = 11999235 },

	{ name = "Frost Potion",                 kind = "frost",    id = 42845896 },
	{ name = "Magical Rainbow Pony",         kind = "rainbow",  id = 26417031 },
	{ name = "Teleporting Gun",              kind = "wormhole", id = 34870758 },
	{ name = "Positronic Platform Producer", kind = "platform", id = 34898883 },
}

local SHOT_SOUND_ID = "rbxassetid://99204505"
local HIT_SOUND_ID = "rbxassetid://58274204"
local DRYER_SOUND_ID = "rbxassetid://11717967"
local ROCKET_SOUND_ID = "rbxassetid://12222095"   -- Rocket Launcher
local PLATFORM_SOUND_ID = "rbxassetid://11945266" -- Positronic Platform Producer

-- ===== helpers =====
local function getChar()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHandle(tool)
	return tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
end

local function rainbowSequence()
	local keys = {}
	for i = 0, 6 do
		keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 1, 1))
	end
	return ColorSequence.new(keys)
end

local function tintInstance(root, color)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") or d:IsA("Part") or d:IsA("UnionOperation") then
			d.Color = color
		elseif d:IsA("SpecialMesh") then
			d.VertexColor = Vector3.new(color.R, color.G, color.B)
		end
	end
end

local function addSound(parent, name, id, volume)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = parent
	return s
end

local Hooks = {}
local function say(msg)
	if Hooks.status then Hooks.status(msg) end
end

local function aimPoint(origin, ignore)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ignore }
		local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		return res and res.Position or (ray.Origin + ray.Direction * 1000)
	end
	return mouse.Hit.Position
end

-- only the tool's own Activated event is used: Roblox fires it for a real tap/click on the gear,
-- not when you drag the camera or use the joystick on mobile
local function onUse(tool, fn)
	tool.Activated:Connect(fn)
end

-- ===== loading: models are preloaded in the background, giving a gear never waits =====
local cache = {}   -- id -> Tool template, or false if it failed
local loading = {} -- id -> true while loading

local function stripScripts(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
end

local function preload(id, done)
	if not id or id == 0 or cache[id] ~= nil or loading[id] then return end
	loading[id] = true
	task.spawn(function()
		local template = false
		for attempt = 1, 4 do -- retry so every real model loads
			local ok, objs = pcall(function()
				return game:GetObjects("rbxassetid://" .. id)
			end)
			if ok and objs and objs[1] then
				local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
				if t then
					t.Parent = nil
					stripScripts(t)
					template = t
					break
				end
			end
			task.wait(0.5 * attempt)
		end
		cache[id] = template
		loading[id] = nil
		if done then done(id) end
	end)
end

local function fallbackTool(cfg)
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.CanCollide = false
	h.Material = Enum.Material.SmoothPlastic
	if cfg.kind == "carpet" then
		h.Size = Vector3.new(4, 0.3, 6)
		h.Color = (typeof(cfg.color) == "Color3") and cfg.color or Color3.new(1, 0, 0)
	elseif cfg.kind == "dryer" then
		h.Size = Vector3.new(0.8, 0.8, 1.8)
		h.Color = Color3.fromRGB(220, 60, 120)
	elseif cfg.kind == "rocket" then
		h.Size = Vector3.new(1, 1, 4)
		h.Color = Color3.fromRGB(70, 90, 70)
	elseif cfg.kind == "melee" then
		h.Size = Vector3.new(0.4, 0.4, 3.5)
		h.Color = Color3.fromRGB(80, 200, 255)
		h.Material = Enum.Material.Neon
	elseif cfg.kind == "speed" or cfg.kind == "gravity" then
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(1.4, 1.6, 1.6)
		h.Color = cfg.kind == "speed" and Color3.fromRGB(220, 30, 30) or Color3.fromRGB(60, 120, 255)
	else
		h.Size = Vector3.new(1, 1.4, 1)
	end
	h.Parent = tool
	return tool
end

-- returns tool, reason (reason is nil when the real model was used)
local function loadTool(cfg)
	local tool, reason
	local template = cfg.id and cache[cfg.id]
	if template then
		tool = template:Clone()
	else
		reason = (cfg.id and loading[cfg.id]) and "real model still loading, it will swap in" or "model could not load"
		tool = fallbackTool(cfg)
	end
	tool.Name = cfg.name
	tool.CanBeDropped = false
	tool.Enabled = true
	if cfg.icon and cfg.icon ~= "" then tool.TextureId = cfg.icon end
	if not getHandle(tool) then
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(1, 1, 1)
		h.CanCollide = false
		h.Parent = tool
	end
	tool:SetAttribute("Fallback", reason ~= nil)
	return tool, reason
end

-- ===== no arm sticking out + gear under the feet (carpets, brooms, stilts...) =====
local function setupFeet(tool, cfg)
	local conn
	local function release()
		if conn then conn:Disconnect() conn = nil end
	end
	tool.Equipped:Connect(function()
		release()
		local char = getChar()
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local function kill(track)
				local n = track.Animation and track.Animation.Name:lower() or ""
				if n:find("toolnone") then track:Stop(0) end
			end
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do kill(tr) end
			conn = animator.AnimationPlayed:Connect(kill)
		end
		-- put the gear under the feet instead of in the hand
		task.spawn(function()
			local grip
			for _ = 1, 20 do
				grip = char:FindFirstChild("RightGrip", true)
				if grip then break end
				task.wait(0.03)
			end
			if grip and hrp and tool.Parent == char then
				grip.Part0 = hrp
				grip.C0 = CFrame.new(0, cfg.drop or -3, 0)
				grip.C1 = CFrame.identity
			end
		end)
	end)
	tool.Unequipped:Connect(release)
	tool.Destroying:Connect(release)
end

-- ===== FLY =====
local controls
task.spawn(function()
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 3)):GetControls()
	end)
end)

local function getMove()
	if controls then
		local ok, v = pcall(function() return controls:GetMoveVector() end)
		if ok and v then return v end
	end
	local x = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
	local z = (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
	return Vector3.new(x, 0, z)
end

local function setupCarpet(tool, cfg)
	local handle = getHandle(tool)
	local bv, bg, loop, trail, a0, a1

	local function stop()
		if loop then loop:Disconnect() loop = nil end
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if trail then trail:Destroy() trail = nil end
		if a0 then a0:Destroy() a0 = nil end
		if a1 then a1:Destroy() a1 = nil end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false end
	end

	local function start()
		stop()
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum and handle) then return end

		local half = handle.Size * 0.45
		a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-half.X, 0, 0)
		a0.Parent = handle
		a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(half.X, 0, 0)
		a1.Parent = handle
		trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 1.2
		trail.LightEmission = cfg.trailEmission or 0.6
		trail.Transparency = NumberSequence.new(0.1, 1)
		if cfg.trail == "rainbow" then
			trail.Color = rainbowSequence()
		elseif cfg.trail then
			trail.Color = cfg.trail
		end
		trail.Parent = handle

		hum.PlatformStand = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.Velocity = Vector3.zero
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		bg.P = 9000
		bg.D = 600
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp

		local fallback = tool:GetAttribute("Fallback")
		local hue, tintT = 0, 0
		loop = RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent then return stop() end
			local cam = workspace.CurrentCamera.CFrame
			local mv = getMove()
			local dir = cam.RightVector * mv.X + cam.LookVector * -mv.Z
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
			bv.Velocity = (dir.Magnitude > 0.05) and (dir.Unit * cfg.speed) or Vector3.zero
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
			end
			if fallback and cfg.color == "rainbow" then
				hue = (hue + dt * 0.4) % 1
				tintT += dt
				if tintT > 0.1 then -- colour only 10x a second, no lag
					tintT = 0
					tintInstance(tool, Color3.fromHSV(hue, 1, 1))
				end
			end
		end)
	end

	tool.Equipped:Connect(start)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
end

-- ===== GRAVITY =====
local function setupGravity(tool, cfg)
	local force, loop
	local function stop()
		if loop then loop:Disconnect() loop = nil end
		if force then force:Destroy() force = nil end
	end
	tool.Equipped:Connect(function()
		stop()
		local hrp = getChar():FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		force = Instance.new("BodyForce")
		force.Parent = hrp
		local last = -1
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent then return stop() end
			local m = hrp.AssemblyMass
			if m ~= last then
				last = m
				force.Force = Vector3.new(0, m * workspace.Gravity * (cfg.lift or 0.75), 0)
			end
		end)
	end)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
end

-- ===== SPEED (+ Dual Speed Coil: a second coil in the left hand) =====
local function setupSpeed(tool, cfg)
	local old
	local leftCoil, leftWeld

	local function dropLeft()
		if leftWeld then leftWeld:Destroy() leftWeld = nil end
		if leftCoil then leftCoil:Destroy() leftCoil = nil end
	end

	local function makeLeft(char)
		dropLeft()
		local handle = getHandle(tool)
		local hand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
		if not (handle and hand) then return end
		leftCoil = handle:Clone()
		leftCoil.Name = "LeftCoil"
		for _, d in ipairs(leftCoil:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		leftCoil.Anchored = false
		leftCoil.CanCollide = false
		leftCoil.CanTouch = false
		leftCoil.CanQuery = false
		leftCoil.Massless = true
		local att = hand:FindFirstChild("LeftGripAttachment")
		leftWeld = Instance.new("Weld")
		leftWeld.Part0 = hand
		leftWeld.Part1 = leftCoil
		leftWeld.C0 = att and att.CFrame or (CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
		leftWeld.C1 = tool.Grip
		leftCoil.Parent = char
		leftWeld.Parent = leftCoil
	end

	local function restore()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and old then hum.WalkSpeed = old end
		old = nil
		dropLeft()
	end

	tool.Equipped:Connect(function()
		local char = getChar()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			old = old or hum.WalkSpeed
			hum.WalkSpeed = cfg.speed or 40
		end
		if cfg.dual then makeLeft(char) end
	end)
	tool.Unequipped:Connect(restore)
	tool.Destroying:Connect(restore)
end

-- ===== JUMP =====
local function setupJump(tool, cfg)
	local old
	local function restore()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and old then hum.UseJumpPower = true hum.JumpPower = old end
		old = nil
	end
	tool.Equipped:Connect(function()
		local hum = getChar():FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			old = old or hum.JumpPower
			hum.JumpPower = cfg.power or 130
		end
	end)
	tool.Unequipped:Connect(restore)
	tool.Destroying:Connect(restore)
end

-- ===== MELEE =====
local function setupMelee(tool)
	local ready = true
	onUse(tool, function()
		if not ready then return end
		ready = false
		local v = Instance.new("StringValue")
		v.Name = "toolanim"
		v.Value = "Slash"
		v.Parent = tool
		Debris:AddItem(v, 0.5)
		task.delay(0.5, function() ready = true end)
	end)
end

-- ===== BLOW DRYER =====
local function windPuff(origin, look)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(255, 225, 240)
	p.Transparency = 0.4
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Position = origin + look * 2
	p.Parent = workspace
	local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = origin + look * 34 + spread,
		Size = Vector3.new(7, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.6)
end

local function setupDryer(tool)
	local handle = getHandle(tool)
	local holding = false
	local loopConn

	local wind = addSound(handle, "Blow", DRYER_SOUND_ID, 0.7)
	wind.Looped = true

	local att = Instance.new("Attachment")
	att.Name = "WindOrigin"
	att.Parent = handle

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Wind"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(60, 80)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 225, 240))
	emitter.LightEmission = 0.4
	emitter.Parent = att

	local RANGE, PUSH = 34, 90
	local ACC, MAXSPEED, UP = 330, 100, 150

	local function stopBlowing()
		if not holding then return end
		holding = false
		emitter.Rate = 0
		wind:Stop()
		if loopConn then loopConn:Disconnect() loopConn = nil end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false end
	end

	local function startBlowing()
		if holding then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (char and hrp and tool.Parent == char) then return end
		holding = true
		emitter.Rate = 250
		wind:Play()
		say("Blow Dryer: blowing")
		if hum then hum.PlatformStand = true end

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }

		local acc, puffT = 0, 0
		loopConn = RunService.Heartbeat:Connect(function(dt)
			if not (holding and tool.Parent == char and handle.Parent and hrp.Parent) then return stopBlowing() end
			local origin = handle.Position
			local look = workspace.CurrentCamera.CFrame.LookVector
			att.WorldCFrame = CFrame.lookAt(origin, origin + look) * CFrame.Angles(-math.pi / 2, 0, 0)

			local v = hrp.AssemblyLinearVelocity - look * ACC * dt + Vector3.new(0, UP * dt, 0)
			if v.Magnitude > MAXSPEED then v = v.Unit * MAXSPEED end
			hrp.AssemblyLinearVelocity = v

			puffT += dt
			if puffT >= 0.07 then
				puffT = 0
				windPuff(origin, look)
			end

			acc += dt
			if acc >= 0.1 then
				acc = 0
				for _, p in ipairs(workspace:GetPartBoundsInRadius(origin + look * (RANGE / 2), RANGE / 2, params)) do
					if not p.Anchored then
						local to = p.Position - origin
						if to.Magnitude > 0.1 and to.Unit:Dot(look) > 0.7 then
							p.AssemblyLinearVelocity = p.AssemblyLinearVelocity + look * PUSH * 0.3
						end
					end
				end
			end
		end)
	end

	tool.Activated:Connect(startBlowing)
	tool.Deactivated:Connect(stopBlowing)
	tool.Unequipped:Connect(stopBlowing)
	tool.Destroying:Connect(stopBlowing)

	-- hold click / hold tap (original behaviour): works on PC and mobile
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local c1 = UserInputService.InputBegan:Connect(function(i, processed)
		if processed or not isPress(i) then return end
		if tool.Parent and tool.Parent == player.Character then startBlowing() end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(i)
		if isPress(i) then stopBlowing() end
	end)
	tool.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
end

-- ===== ROCKET LAUNCHER =====
local function setupRocket(tool)
	local handle = getHandle(tool)
	local ready = true
	addSound(handle, "Shot", ROCKET_SOUND_ID, 0.6)

	onUse(tool, function()
		if not ready then return end
		ready = false
		local char = getChar()
		handle.Shot.Pitch = math.random(90, 110) / 100
		handle.Shot:Play()

		local rocket = Instance.new("Part")
		rocket.Name = "Rocket"
		rocket.Size = Vector3.new(0.6, 0.6, 3)
		rocket.Color = Color3.fromRGB(200, 60, 40)
		rocket.Material = Enum.Material.Metal
		rocket.CanCollide = false
		rocket.CFrame = CFrame.new(handle.Position, aimPoint(handle.Position, char))
		rocket.Parent = workspace
		say("Rocket Launcher: fired")
		local bf = Instance.new("BodyForce")
		bf.Force = Vector3.new(0, rocket:GetMass() * workspace.Gravity, 0)
		bf.Parent = rocket
		rocket.AssemblyLinearVelocity = rocket.CFrame.LookVector * 140
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Parent = rocket
		addSound(rocket, "Hit", HIT_SOUND_ID, 1)

		local conn
		conn = rocket.Touched:Connect(function(part)
			if part:IsDescendantOf(char) or part:IsDescendantOf(tool) then return end
			conn:Disconnect()
			local pos = rocket.Position
			local ex = Instance.new("Explosion")
			ex.Position = pos
			ex.BlastRadius = 12
			ex.BlastPressure = 0
			ex.DestroyJointRadiusPercent = 0
			ex.Parent = workspace
			rocket.Hit:Play()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - pos
				if d.Magnitude < 14 and d.Magnitude > 0.01 then
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + d.Unit * (90 * (1 - d.Magnitude / 14) + 20)
				end
			end
			rocket.Transparency = 1
			rocket.Anchored = true
			fire.Enabled = false
		end)
		Debris:AddItem(rocket, 6)
		task.delay(1.5, function() ready = true end)
	end)
end

-- ===== SEA BOW =====
local function createWaterExplosion(point)
	local scale = 8 + (4 * math.random(1, 3))
	local terrain = workspace.Terrain
	terrain:FillBall(point, scale, Enum.Material.Water)
	task.delay(7, function()
		terrain:FillBall(point, scale, Enum.Material.Air)
	end)
end

local function createArrow()
	local arrow = Instance.new("Part")
	arrow.Name = "SeaArrow"
	arrow.Size = Vector3.new(0.2, 0.2, 2.5)
	arrow.Transparency = 0.25
	arrow.Reflectance = 0.5
	arrow.CanCollide = false
	arrow.Material = Enum.Material.SmoothPlastic
	arrow.BrickColor = BrickColor.new("Cyan")
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshId = "rbxassetid://235107348"
	mesh.TextureId = "rbxassetid://235107780"
	mesh.Parent = arrow
	addSound(arrow, "Hit", HIT_SOUND_ID, 1)
	return arrow
end

local function setupSeaBow(tool)
	local handle = getHandle(tool)
	addSound(handle, "Shot", SHOT_SOUND_ID, 0.5)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		local char = getChar()
		handle.Shot.Pitch = math.random(90, 110) / 100
		handle.Shot:Play()

		local arrow = createArrow()
		arrow.CFrame = CFrame.new(handle.Position, aimPoint(handle.Position, char))
		arrow.Velocity = arrow.CFrame.LookVector * 120
		arrow.Parent = workspace
		say("Sea Bow: fired")

		local conn
		conn = arrow.Touched:Connect(function(part)
			if part:IsDescendantOf(char) then return end
			createWaterExplosion(arrow.Position)
			arrow.Hit:Play()
			arrow.Anchored = true
			arrow.Transparency = 1
			conn:Disconnect()
		end)
		Debris:AddItem(arrow, 8)
		task.delay(1.2, function() ready = true end)
	end)
end

do
	local JUMP_POWER, BOOST_FRAMES = 78, 8
	UserInputService.JumpRequest:Connect(function()
		local char = player.Character
		if not (char and char:FindFirstChild("Sea Bow")) then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) then return end
		local st = hum:GetState()
		if st ~= Enum.HumanoidStateType.Swimming and st ~= Enum.HumanoidStateType.GettingUp then return end
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, JUMP_POWER, v.Z)
		task.spawn(function()
			for _ = 1, BOOST_FRAMES do
				if not root.Parent then break end
				if root.AssemblyLinearVelocity.Y < JUMP_POWER * 0.7 then
					local cur = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, JUMP_POWER * 0.85), cur.Z)
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end)
end

-- ===== FROST POTION: a solid block of ice around you =====
local function setupFrost(tool)
	local ready = true
	local current
	local LIFE = 8

	local function shatter()
		if current then current:Destroy() current = nil end
	end

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.6, function() ready = true end)

		-- tap again while frozen to break out
		if current and current.Parent then
			shatter()
			say("Frost Potion: ice shattered")
			return
		end

		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local c = hrp.Position

		-- hollow solid ice block: it collides with you, you stand inside it
		local model = Instance.new("Model")
		model.Name = "FrostBlock"
		local function wall(size, offset)
			local p = Instance.new("Part")
			p.Size = size
			p.Material = Enum.Material.Ice
			p.Color = Color3.fromRGB(150, 215, 255)
			p.Transparency = 0.35
			p.Anchored = true
			p.CanCollide = true
			p.CFrame = CFrame.new(c + offset)
			p.Parent = model
		end
		wall(Vector3.new(7, 1, 7), Vector3.new(0, -3.7, 0))   -- floor
		wall(Vector3.new(7, 1, 7), Vector3.new(0, 3.7, 0))    -- ceiling
		wall(Vector3.new(1, 8.4, 7), Vector3.new(3, 0, 0))    -- sides
		wall(Vector3.new(1, 8.4, 7), Vector3.new(-3, 0, 0))
		wall(Vector3.new(5, 8.4, 1), Vector3.new(0, 0, 3))
		wall(Vector3.new(5, 8.4, 1), Vector3.new(0, 0, -3))
		model.Parent = workspace
		current = model
		say("Frost Potion: you are frozen in ice (tap again to break out)")

		task.delay(LIFE, function()
			if current ~= model or not model.Parent then return end
			for _, p in ipairs(model:GetChildren()) do
				TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
			task.wait(1)
			if current == model then shatter() end
		end)
	end)

	tool.Destroying:Connect(shatter)
end

-- ===== MAGICAL RAINBOW PONY: rising rainbow platform under your feet =====
local function setupPony(tool)
	local ready = true
	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.8, function() ready = true end)
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local RISE_SPEED, RISE_TIME, LIFE = 16, 4, 9
		local plat = Instance.new("Part")
		plat.Name = "RainbowPlatform"
		plat.Size = Vector3.new(9, 1, 9)
		plat.Material = Enum.Material.Neon
		plat.Anchored = true
		plat.CanCollide = true
		plat.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.7, hrp.Position.Z)
		plat.Parent = workspace
		say("Magical Rainbow Pony: rainbow platform rising")

		local t, hue = 0, 0
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			t += dt
			if t >= LIFE or not plat.Parent then
				conn:Disconnect()
				plat:Destroy()
				return
			end
			hue = (hue + dt * 0.8) % 1
			plat.Color = Color3.fromHSV(hue, 1, 1)
			local rise = (t <= RISE_TIME) and RISE_SPEED or 0
			plat.AssemblyLinearVelocity = Vector3.new(0, rise, 0) -- carries you up with it
			plat.CFrame = plat.CFrame + Vector3.new(0, rise * dt, 0)
			if t > LIFE - 1 then plat.Transparency = t - (LIFE - 1) end
		end)
	end)
end

-- ===== TELEPORTING GUN: shoot two linked portals, walk into one to come out the other =====
local function setupWormhole(tool)
	local handle = getHandle(tool)
	addSound(handle, "Shot", PLATFORM_SOUND_ID, 0.6)
	local ready = true
	local portals = {}
	local nextIdx = 1
	local cooldown = 0
	local COLORS = { Color3.fromRGB(40, 140, 255), Color3.fromRGB(255, 140, 30) }

	local function clearPortal(i)
		if portals[i] then portals[i].part:Destroy() portals[i] = nil end
	end

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.35, function() ready = true end)
		local char = getChar()
		local origin = handle.Position
		local aim = aimPoint(origin, char)
		local diff = aim - origin
		if diff.Magnitude < 0.1 then return end
		handle.Shot.Pitch = math.random(90, 110) / 100
		handle.Shot:Play()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local res = workspace:Raycast(origin, diff.Unit * (diff.Magnitude + 5), params)
		if not res then
			say("Teleporting Gun: aim at a surface")
			return
		end
		local n = res.Normal
		local pos = res.Position + n * 0.2
		local idx = nextIdx
		nextIdx = (idx == 1) and 2 or 1
		clearPortal(idx)

		local p = Instance.new("Part")
		p.Name = "Portal" .. idx
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 7, 5)
		p.Material = Enum.Material.Neon
		p.Color = COLORS[idx]
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local up = (math.abs(n.Y) > 0.9) and Vector3.xAxis or Vector3.yAxis
		p.CFrame = CFrame.lookAt(pos, pos + n, up) * CFrame.Angles(0, math.pi / 2, 0)
		local light = Instance.new("PointLight")
		light.Color = COLORS[idx]
		light.Range = 10
		light.Parent = p
		p.Parent = workspace
		portals[idx] = { part = p, normal = n }
		say(idx == 1 and "Teleporting Gun: blue portal placed" or "Teleporting Gun: orange portal placed")
	end)

	local conn = RunService.Heartbeat:Connect(function()
		if not (portals[1] and portals[2]) then return end
		if os.clock() < cooldown then return end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		for i = 1, 2 do
			local a, b = portals[i], portals[3 - i]
			local rel = a.part.CFrame:PointToObjectSpace(hrp.Position)
			if math.abs(rel.X) < 3 and math.abs(rel.Y) < 4 and math.abs(rel.Z) < 3 then
				cooldown = os.clock() + 1.2
				local out = b.normal
				local dest = b.part.Position + out * 4
				local flat = Vector3.new(out.X, 0, out.Z)
				local speed = math.clamp(hrp.AssemblyLinearVelocity.Magnitude, 10, 60)
				if flat.Magnitude > 0.1 then
					hrp.CFrame = CFrame.lookAt(dest, dest + flat)
				else
					hrp.CFrame = CFrame.new(dest) * (hrp.CFrame - hrp.Position)
				end
				hrp.AssemblyLinearVelocity = out * speed
				break
			end
		end
	end)
	tool.Destroying:Connect(function()
		conn:Disconnect()
		clearPortal(1)
		clearPortal(2)
	end)
end

-- ===== POSITRONIC PLATFORM PRODUCER: beams that make temporary solid platforms =====
local function setupPlatformGun(tool)
	local handle = getHandle(tool)
	addSound(handle, "Shot", PLATFORM_SOUND_ID, 0.6)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.5, function() ready = true end)
		local char = getChar()
		local origin = handle.Position
		local aim = aimPoint(origin, char)
		local diff = aim - origin
		if diff.Magnitude < 0.1 then return end
		local dir = diff.Unit
		handle.Shot.Pitch = math.random(90, 110) / 100
		handle.Shot:Play()

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local res = workspace:Raycast(origin, dir * 300, params)
		local hit, n
		if res then
			hit, n = res.Position, res.Normal
		else
			hit, n = origin + dir * 60, Vector3.yAxis
		end

		-- the beam
		local len = (hit - origin).Magnitude
		local beam = Instance.new("Part")
		beam.Name = "PositronBeam"
		beam.Size = Vector3.new(0.25, 0.25, len)
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(0, 220, 255)
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CFrame = CFrame.lookAt(origin, hit) * CFrame.new(0, 0, -len / 2)
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 0.4)

		-- the platform: sits on floors, sticks out sideways from walls
		local pos
		if n.Y > 0.7 then
			pos = hit + Vector3.new(0, 0.5, 0)
		else
			pos = Vector3.new(hit.X + n.X * 5, hit.Y - 0.5, hit.Z + n.Z * 5)
		end
		local plat = Instance.new("Part")
		plat.Name = "PositronPlatform"
		plat.Size = Vector3.new(10, 1, 10)
		plat.Material = Enum.Material.Neon
		plat.Color = Color3.fromRGB(0, 200, 255)
		plat.Transparency = 0.3
		plat.Anchored = true
		plat.CanCollide = true
		plat.CFrame = CFrame.new(pos)
		plat.Parent = workspace
		say("Positronic Platform Producer: platform created")

		task.delay(7, function()
			if not plat.Parent then return end
			TweenService:Create(plat, TweenInfo.new(1), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(plat, 8)
	end)
end

-- ===== give / remove =====
local SETUP = {
	carpet = setupCarpet, dryer = setupDryer, seabow = setupSeaBow,
	gravity = setupGravity, speed = setupSpeed, jump = setupJump,
	rocket = setupRocket, melee = setupMelee,
	frost = setupFrost, rainbow = setupPony, wormhole = setupWormhole, platform = setupPlatformGun,
}

local HINTS = {
	carpet = " - move to fly toward the camera, Space = up",
	dryer = " - hold click/tap to blow",
	seabow = " - tap to shoot",
	rocket = " - tap to fire",
	gravity = " - low gravity is on",
	speed = " - you run faster",
	jump = " - you jump higher",
	melee = " - tap to swing",
	frost = " - tap to freeze yourself in a block of ice",
	rainbow = " - tap for a rising rainbow platform",
	wormhole = " - tap once for the blue portal, again for the orange one, then walk into one",
	platform = " - tap to shoot a beam that makes a platform",
}

local active = {} -- name -> tool
local wanted = {} -- name -> true (given again after respawn)

local function removeGear(cfg)
	wanted[cfg.name] = nil
	local t = active[cfg.name]
	if t then pcall(function() t:Destroy() end) end
	active[cfg.name] = nil
end

local function giveGear(cfg)
	removeGear(cfg)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return false, cfg.name .. " failed: no backpack" end

	local tool, reason = loadTool(cfg)
	-- into the inventory FIRST, so it always shows even if a setup step errors
	tool.Parent = backpack
	active[cfg.name] = tool
	wanted[cfg.name] = true

	local problems = {}
	local function try(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then problems[#problems + 1] = tostring(err) end
	end
	try(SETUP[cfg.kind], tool, cfg)
	-- carpets/brooms stay in the hand; only foot gears (stilts) go under the feet
	if cfg.feet then try(setupFeet, tool, cfg) end
	tool.Equipped:Connect(function()
		say(cfg.name .. " equipped" .. (HINTS[cfg.kind] or ""))
	end)

	if #problems > 0 then
		return true, cfg.name .. " given (a feature had an error: " .. problems[1] .. ")"
	end
	if reason then
		return true, cfg.name .. " given with built-in model (" .. reason .. ")"
	end
	return true, cfg.name .. " given - equip it from your hotbar"
end

-- start loading every real model in the background (same id is only loaded once)
local rows = {}
local function onLoaded(id)
	local bp = player:FindFirstChildOfClass("Backpack")
	for _, cfg in ipairs(GEARS) do
		if cfg.id == id then
			local t = active[cfg.name]
			-- swap built-in model for the real one, only if it is not being held right now
			if t and t:GetAttribute("Fallback") and cache[id] then
				local function swap()
					if active[cfg.name] == t and wanted[cfg.name] then
						giveGear(cfg)
						if rows[cfg.name] then rows[cfg.name].setOn(active[cfg.name] ~= nil) end
					end
				end
				if bp and t.Parent == bp then
					swap()
				else
					-- being held right now: swap as soon as it is put away
					local c
					c = t.Unequipped:Connect(function()
						c:Disconnect()
						task.defer(swap)
					end)
				end
			end
		end
	end
end
for _, cfg in ipairs(GEARS) do
	preload(cfg.id, onLoaded)
end

-- ===== MENU =====
local statusLabel
local function status(msg)
	if statusLabel then statusLabel.Text = msg end
end
Hooks.status = status

local FULL_SIZE = UDim2.new(0, 330, 0, 440)
local MINI_SIZE = UDim2.new(0, 46, 0, 46)

local function buildGui()
	local genv = (getgenv and getgenv()) or _G
	if genv.VestaGearsGui then pcall(function() genv.VestaGearsGui:Destroy() end) end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VestaGears"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	local okParent = pcall(function()
		gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if not okParent or not gui.Parent then
		gui.Parent = player:WaitForChild("PlayerGui")
	end
	genv.VestaGearsGui = gui

	local function mk(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do o[k] = v end
		o.Parent = parent
		return o
	end
	local function round(o, r)
		mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
	end

	local BG = Color3.fromRGB(14, 14, 20)
	local PANEL = Color3.fromRGB(26, 26, 38)
	local ACCENT = Color3.fromRGB(120, 90, 230)
	local OFF = Color3.fromRGB(46, 46, 64)

	local frame = mk("Frame", {
		Name = "Main", Size = FULL_SIZE, Position = UDim2.new(0.5, -165, 0.5, -220),
		BackgroundColor3 = BG, BorderSizePixel = 0, Active = true,
	}, gui)
	round(frame, 12)
	local stroke = mk("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.3 }, frame)

	local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = PANEL, BorderSizePixel = 0 }, frame)
	round(bar, 12)
	mk("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, Text = "Vesta Gears", TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bar)
	local minBtn = mk("TextButton", {
		Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -66, 0, 5), BackgroundColor3 = OFF,
		Font = Enum.Font.GothamBold, Text = "-", TextSize = 16, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, bar)
	round(minBtn, 6)
	local closeBtn = mk("TextButton", {
		Size = UDim2.new(0, 28, 0, 24), Position = UDim2.new(1, -34, 0, 5), BackgroundColor3 = Color3.fromRGB(125, 30, 30),
		Font = Enum.Font.GothamBold, Text = "X", TextSize = 14, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, bar)
	round(closeBtn, 6)

	-- gear icon shown when minimised
	local iconBtn = mk("TextButton", {
		Name = "GearIcon", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
		Font = Enum.Font.SourceSansBold, Text = utf8.char(0x2699), TextSize = 32, TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false, Visible = false, ZIndex = 5,
	}, frame)
	round(iconBtn, 12)

	local body = mk("Frame", { Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), BackgroundTransparency = 1 }, frame)

	local collapsed = false
	local function setCollapsed(c)
		collapsed = c
		bar.Visible = not c
		body.Visible = not c
		iconBtn.Visible = c
		frame.Size = c and MINI_SIZE or FULL_SIZE
		-- minimised gear icon: black background and black outline
		frame.BackgroundColor3 = c and Color3.new(0, 0, 0) or BG
		stroke.Color = c and Color3.new(0, 0, 0) or ACCENT
		stroke.Transparency = c and 0 or 0.3
	end

	-- dragging (title bar and gear icon). A tap on the icon without moving opens the menu.
	local dragging, dragStart, startPos, moved, dragSource
	local function beginDrag(src)
		src.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				moved = false
				dragSource = src
				dragStart = input.Position
				startPos = frame.Position
			end
		end)
	end
	beginDrag(bar)
	beginDrag(iconBtn)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if d.Magnitude > 4 then moved = true end
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging and not moved and dragSource == iconBtn and collapsed then
				setCollapsed(false)
			end
			dragging = false
		end
	end)

	local search = mk("TextBox", {
		Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 8), BackgroundColor3 = PANEL, BorderSizePixel = 0,
		Font = Enum.Font.Gotham, PlaceholderText = "Search gears...", PlaceholderColor3 = Color3.fromRGB(130, 130, 150),
		Text = "", TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, body)
	round(search, 8)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 10) }, search)

	local list = mk("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -128), Position = UDim2.new(0, 8, 0, 44), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	for i, cfg in ipairs(GEARS) do
		local row = mk("Frame", { Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = PANEL, BorderSizePixel = 0, LayoutOrder = i }, list)
		round(row, 8)
		mk("TextLabel", {
			Size = UDim2.new(0.68, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, Text = cfg.name, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		local btn = mk("TextButton", {
			Size = UDim2.new(0.28, 0, 0, 24), Position = UDim2.new(0.7, 0, 0, 5), BackgroundColor3 = OFF,
			Font = Enum.Font.GothamBold, Text = "GIVE", TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		}, row)
		round(btn, 6)

		local function setOn(on)
			btn.Text = on and "REMOVE" or "GIVE"
			btn.BackgroundColor3 = on and ACCENT or OFF
		end
		rows[cfg.name] = { setOn = setOn, frame = row }

		btn.MouseButton1Click:Connect(function()
			local t = active[cfg.name]
			if t and t.Parent then
				removeGear(cfg)
				setOn(false)
				status(cfg.name .. " removed")
			else
				local _, msg = giveGear(cfg)
				setOn(active[cfg.name] ~= nil)
				status(msg)
			end
		end)
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = search.Text:lower()
		for _, cfg in ipairs(GEARS) do
			rows[cfg.name].frame.Visible = (q == "") or (cfg.name:lower():find(q, 1, true) ~= nil)
		end
	end)

	local function footerButton(text, x, color)
		local b = mk("TextButton", {
			Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.new(x, x == 0 and 8 or 4, 1, -76), BackgroundColor3 = color,
			Font = Enum.Font.GothamBold, Text = text, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		}, body)
		round(b, 8)
		return b
	end
	local giveAllBtn = footerButton("GIVE ALL", 0, ACCENT)
	local removeAllBtn = footerButton("REMOVE ALL", 0.5, Color3.fromRGB(125, 30, 30))

	statusLabel = mk("TextLabel", {
		Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -40), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, Text = "Pick a gear. Hotbar shows 10, press ` for the full inventory.", TextSize = 11,
		TextColor3 = Color3.fromRGB(190, 190, 210), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, body)

	giveAllBtn.MouseButton1Click:Connect(function()
		local given = 0
		for i, cfg in ipairs(GEARS) do
			local ok = giveGear(cfg)
			rows[cfg.name].setOn(active[cfg.name] ~= nil)
			if ok then given += 1 end
			if i % 6 == 0 then task.wait() end -- tiny breather, no freeze
		end
		status(("%d gears given - press ` to see all of them"):format(given))
	end)
	removeAllBtn.MouseButton1Click:Connect(function()
		for _, cfg in ipairs(GEARS) do
			removeGear(cfg)
			rows[cfg.name].setOn(false)
		end
		status("All gears removed")
	end)

	minBtn.MouseButton1Click:Connect(function()
		setCollapsed(true)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		gui:Destroy()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightShift and gui.Parent then
			frame.Visible = not frame.Visible
		end
	end)
end

buildGui()

-- every gear is ready the moment the script runs (real models swap in as they finish loading)
do
	local given = 0
	for _, cfg in ipairs(GEARS) do
		local ok = giveGear(cfg)
		if rows[cfg.name] then rows[cfg.name].setOn(active[cfg.name] ~= nil) end
		if ok then given += 1 end
	end
	status(("%d gears ready - press ` to open your inventory"):format(given))
end

-- give the chosen gears again after every respawn
player.CharacterAdded:Connect(function()
	player:WaitForChild("Backpack")
	task.wait(0.3)
	local names = {}
	for _, cfg in ipairs(GEARS) do
		if wanted[cfg.name] then names[#names + 1] = cfg end
	end
	for i, cfg in ipairs(names) do
		giveGear(cfg)
		if rows[cfg.name] then rows[cfg.name].setOn(active[cfg.name] ~= nil) end
		if i % 6 == 0 then task.wait() end
	end
end)

print("Vesta Gears menu ready")
