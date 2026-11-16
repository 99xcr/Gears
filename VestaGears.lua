-- Vesta Gears (v4)
-- Real gears are preloaded in the background, so GIVE is instant and never lags.
-- If a model is still loading when you press GIVE, it waits a moment for the real one (no placeholder swap, so no flicker).
-- Menu: drag the title bar, "-" turns the menu into a gear icon (click the icon to open it again),
-- "X" closes the menu (gears stay), RightShift hides/shows.
-- Given gears go into your normal Roblox inventory / hotbar.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
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

	{ name = "Korblox Mage Staff",           kind = "staff",   id = 127506105 },
	{ name = "Frag Grenade",                 kind = "grenade", id = 11563251 },
	{ name = "Slingshot",                    kind = "sling",   id = 33382537 },
	{ name = "Blue Hyperlaser Gun",          kind = "laser",   id = 130113146,  color = Color3.fromRGB(60, 140, 255) },
	{ name = "Red Hyperlaser Gun",           kind = "laser",   id = 212296936,  color = Color3.fromRGB(255, 50, 50) },
	{ name = "Green Hyperlaser Gun",         kind = "laser",   id = 1427401206, color = Color3.fromRGB(60, 255, 90) },
	{ name = "Silver Ninja Star of the Brilliant Light", kind = "star", id = 11377306 },
}

local SHOT_SOUND_ID = "rbxassetid://99204505"
local HIT_SOUND_ID = "rbxassetid://58274204"
local DRYER_SOUND_ID = "rbxassetid://11717967"
local LASER_FIRE_ID = "rbxassetid://130113322"
local LASER_HIT_ID = "rbxassetid://130113415"
local SLING_SOUND_ID = "rbxassetid://12222103"
local GRENADE_THROW_ID = "rbxassetid://12222200"
local GRENADE_BOOM_ID = "rbxassetid://12221984"
local STAR_SOUND_ID = "rbxassetid://12222200"
local BOOM_SOUND_ID = "rbxasset://sounds/impact_explosion_03.mp3" -- Rocket Launcher explosion (swap for any boom ID)
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

-- phone: shots go exactly where you tap on the screen (no shiftlock / screen-centre aiming)
local lastTouch
UserInputService.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch then lastTouch = i.Position end
end)
UserInputService.TouchTap:Connect(function(positions)
	if positions and positions[1] then lastTouch = positions[1] end
end)

-- true while shiftlock (or any centre-locked camera) is on
local function isShiftLock()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return true end
	local ok, rt = pcall(function()
		return UserSettings():GetService("UserGameSettings").RotationType
	end)
	return ok and rt == Enum.RotationType.CameraRelative
end

-- shiftlock on: shoot where the shiftlock crosshair (screen centre) points
-- shiftlock off: shoot wherever you tap / click
local function aimPoint(origin, ignore)
	local shiftlock = isShiftLock()
	if shiftlock or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local p = Vector2.new(vp.X / 2, vp.Y / 2)
		if not shiftlock and lastTouch then p = lastTouch end
		local ray = cam:ViewportPointToRay(p.X, p.Y)
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

	-- Hold click (PC) or hold a finger anywhere on the screen except the joystick (phone, camera drag works too).
	local pressInput
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local c1 = UserInputService.InputBegan:Connect(function(i, processed)
		if processed or not isPress(i) then return end
		if i.UserInputType == Enum.UserInputType.Touch then
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize
			-- only the joystick zone (bottom-left) is ignored, the rest of the left side works
			if vp and i.Position.X < vp.X * 0.3 and i.Position.Y > vp.Y * 0.45 then return end
		end
		if tool.Parent and tool.Parent == player.Character then
			pressInput = i
			startBlowing()
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(i)
		if i == pressInput then
			pressInput = nil
			stopBlowing()
		end
	end)
	tool.Destroying:Connect(function() c1:Disconnect() c2:Disconnect() end)
	tool.Unequipped:Connect(stopBlowing)
	tool.Destroying:Connect(stopBlowing)
end

-- ===== ROCKET LAUNCHER =====
local function setupRocket(tool)
	local handle = getHandle(tool)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		local char = getChar()
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
		addSound(rocket, "Hit", BOOM_SOUND_ID, 1.5)

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

-- ===== NEW GEARS: Korblox Mage Staff, Frag Grenade, Slingshot, Hyperlasers, Ninja Star =====
local function burst(pos, color, radius)
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.CanTouch = false
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Transparency = 0.2
	b.Size = Vector3.new(2, 2, 2)
	b.Position = pos
	b.Parent = workspace
	TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(b, 0.5)
end

-- returns char, origin, direction (or nil if there is nothing to aim at)
local function aimFrom(handle)
	local char = getChar()
	local origin = handle.Position
	local diff = aimPoint(origin, char) - origin
	if diff.Magnitude < 0.1 then return end
	return char, origin, diff.Unit
end

-- KORBLOX MAGE STAFF: shoots a magic orb that bursts on impact
local function setupStaff(tool)
	local handle = getHandle(tool)
	local ready = true
	local PURPLE = Color3.fromRGB(170, 80, 255)

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.6, function() ready = true end)
		local char, origin, dir = aimFrom(handle)
		if not char then return end

		local orb = Instance.new("Part")
		orb.Name = "MagicOrb"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(1.6, 1.6, 1.6)
		orb.Material = Enum.Material.Neon
		orb.Color = PURPLE
		orb.CanCollide = false
		orb.CFrame = CFrame.new(origin + dir * 3)
		orb.Parent = workspace
		local bf = Instance.new("BodyForce")
		bf.Force = Vector3.new(0, orb:GetMass() * workspace.Gravity, 0)
		bf.Parent = orb
		orb.AssemblyLinearVelocity = dir * 130
		local light = Instance.new("PointLight")
		light.Color = PURPLE
		light.Range = 12
		light.Parent = orb
		say("Korblox Mage Staff: fired")

		local conn
		conn = orb.Touched:Connect(function(part)
			if part:IsDescendantOf(char) or part:IsDescendantOf(tool) then return end
			conn:Disconnect()
			burst(orb.Position, PURPLE, 14)
			orb:Destroy()
		end)
		Debris:AddItem(orb, 6)
	end)
end

-- FRAG GRENADE: throw it, it explodes after a short fuse
local function setupGrenade(tool)
	local handle = getHandle(tool)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(1.2, function() ready = true end)
		local char, origin, dir = aimFrom(handle)
		if not char then return end

		local nade = Instance.new("Part")
		nade.Name = "FragGrenade"
		nade.Shape = Enum.PartType.Ball
		nade.Size = Vector3.new(1.3, 1.3, 1.3)
		nade.Material = Enum.Material.Metal
		nade.Color = Color3.fromRGB(35, 35, 35)
		nade.CFrame = CFrame.new(origin + dir * 2.5)
		nade.Parent = workspace
		nade.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 25, 0)
		local throw = addSound(nade, "Throw", GRENADE_THROW_ID, 0.7)
		local boom = addSound(nade, "Boom", GRENADE_BOOM_ID, 1.5)
		throw:Play()
		say("Frag Grenade: thrown")

		task.delay(2.5, function()
			if not nade.Parent then return end
			local pos = nade.Position
			local ex = Instance.new("Explosion")
			ex.Position = pos
			ex.BlastRadius = 14
			ex.BlastPressure = 0
			ex.DestroyJointRadiusPercent = 0
			ex.Parent = workspace
			burst(pos, Color3.fromRGB(255, 150, 40), 14)
			boom:Play()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = hrp.Position - pos
				if d.Magnitude < 16 and d.Magnitude > 0.01 then
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + d.Unit * (80 * (1 - d.Magnitude / 16) + 15)
				end
			end
			nade.Transparency = 1
			nade.Anchored = true
		end)
		Debris:AddItem(nade, 6)
	end)
end

-- SLINGSHOT: fires a pebble in an arc
local function setupSling(tool)
	local handle = getHandle(tool)
	addSound(handle, "Fire", SLING_SOUND_ID, 0.7)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.4, function() ready = true end)
		local char, origin, dir = aimFrom(handle)
		if not char then return end
		handle.Fire.Pitch = math.random(90, 110) / 100
		handle.Fire:Play()

		local pebble = Instance.new("Part")
		pebble.Name = "Pebble"
		pebble.Shape = Enum.PartType.Ball
		pebble.Size = Vector3.new(0.7, 0.7, 0.7)
		pebble.Material = Enum.Material.Slate
		pebble.Color = Color3.fromRGB(120, 120, 125)
		pebble.CanCollide = false
		pebble.CFrame = CFrame.new(origin + dir * 2)
		pebble.Parent = workspace
		pebble.AssemblyLinearVelocity = dir * 150
		say("Slingshot: fired")

		local conn
		conn = pebble.Touched:Connect(function(part)
			if part:IsDescendantOf(char) or part:IsDescendantOf(tool) then return end
			conn:Disconnect()
			burst(pebble.Position, Color3.fromRGB(200, 200, 200), 3)
			pebble:Destroy()
		end)
		Debris:AddItem(pebble, 6)
	end)
end

-- HYPERLASER GUNS (blue / red / green): instant laser beam
local function setupLaser(tool, cfg)
	local handle = getHandle(tool)
	addSound(handle, "Fire", LASER_FIRE_ID, 0.7)
	local ready = true
	local color = cfg.color or Color3.fromRGB(60, 140, 255)

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.25, function() ready = true end)
		local char, origin, dir = aimFrom(handle)
		if not char then return end
		handle.Fire.Pitch = math.random(95, 105) / 100
		handle.Fire:Play()

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local res = workspace:Raycast(origin, dir * 500, params)
		local hit = res and res.Position or (origin + dir * 500)

		local len = (hit - origin).Magnitude
		local beam = Instance.new("Part")
		beam.Name = "LaserBeam"
		beam.Size = Vector3.new(0.3, 0.3, len)
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CFrame = CFrame.lookAt(origin, hit) * CFrame.new(0, 0, -len / 2)
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		Debris:AddItem(beam, 0.3)

		if res then
			burst(hit, color, 4)
			local snd = Instance.new("Part")
			snd.Transparency = 1
			snd.Anchored = true
			snd.CanCollide = false
			snd.CanQuery = false
			snd.CanTouch = false
			snd.Size = Vector3.new(0.2, 0.2, 0.2)
			snd.Position = hit
			snd.Parent = workspace
			addSound(snd, "Hit", LASER_HIT_ID, 0.8):Play()
			Debris:AddItem(snd, 2)
		end
	end)
end

-- SILVER NINJA STAR OF THE BRILLIANT LIGHT: throws a glowing spinning star
local function setupStar(tool)
	local handle = getHandle(tool)
	addSound(handle, "Swoosh", STAR_SOUND_ID, 0.7)
	local ready = true

	onUse(tool, function()
		if not ready then return end
		ready = false
		task.delay(0.4, function() ready = true end)
		local char, origin, dir = aimFrom(handle)
		if not char then return end
		handle.Swoosh.Pitch = math.random(95, 110) / 100
		handle.Swoosh:Play()

		local cf = CFrame.lookAt(origin + dir * 2.5, origin + dir * 10)
		local star = Instance.new("Part")
		star.Name = "NinjaStar"
		star.Size = Vector3.new(1.6, 0.15, 1.6)
		star.Material = Enum.Material.Metal
		star.Color = Color3.fromRGB(200, 205, 215)
		star.CanCollide = false
		star.CFrame = cf
		star.Parent = workspace
		local star2 = star:Clone()
		star2.CFrame = cf * CFrame.Angles(0, math.rad(45), 0)
		star2.Parent = star
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = star
		weld.Part1 = star2
		weld.Parent = star
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Brightness = 3
		light.Range = 14
		light.Parent = star
		local bf = Instance.new("BodyForce")
		bf.Force = Vector3.new(0, star.AssemblyMass * workspace.Gravity, 0)
		bf.Parent = star
		star.AssemblyLinearVelocity = dir * 160
		star.AssemblyAngularVelocity = cf.UpVector * 40
		say("Silver Ninja Star: thrown")

		local done = false
		local function onHit(part)
			if done then return end
			if part:IsDescendantOf(char) or part:IsDescendantOf(tool) or part:IsDescendantOf(star) then return end
			done = true
			burst(star.Position, Color3.fromRGB(255, 255, 255), 5)
			star:Destroy()
		end
		star.Touched:Connect(onHit)
		star2.Touched:Connect(onHit)
		Debris:AddItem(star, 6)
	end)
end

-- ===== give / remove =====
local SETUP = {
	carpet = setupCarpet, dryer = setupDryer, seabow = setupSeaBow,
	gravity = setupGravity, speed = setupSpeed, jump = setupJump,
	rocket = setupRocket, melee = setupMelee,
	frost = setupFrost, rainbow = setupPony, wormhole = setupWormhole, platform = setupPlatformGun,
	staff = setupStaff, grenade = setupGrenade, sling = setupSling, laser = setupLaser, star = setupStar,
}

local HINTS = {
	carpet = " - move to fly toward the camera, Space = up",
	dryer = " - hold click, or hold a finger on the screen (not on the joystick)",
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
	staff = " - tap to shoot a magic orb",
	grenade = " - tap to throw, it explodes after a moment",
	sling = " - tap to fire a pebble",
	laser = " - tap to fire a laser",
	star = " - tap to throw the star",
}

local active = {} -- name -> tool
local wanted = {} -- name -> true (given again after respawn)

local function removeGear(cfg)
	wanted[cfg.name] = nil
	local t = active[cfg.name]
	if t then pcall(function() t:Destroy() end) end
	active[cfg.name] = nil
end

-- if the game takes a gear out of the backpack, it is put straight back in the same frame (no flicker).
-- If the game destroys it, it is rebuilt - but only a few times, so a game that keeps deleting it can't cause flickering.
local strikes = {}
local function guardTool(cfg, tool)
	tool.AncestryChanged:Connect(function(_, parent)
		if active[cfg.name] ~= tool or not wanted[cfg.name] then return end
		local bp = player:FindFirstChildOfClass("Backpack")
		if parent == bp or parent == player.Character then return end
		task.defer(function()
			if active[cfg.name] ~= tool or not wanted[cfg.name] then return end
			local bp2 = player:FindFirstChildOfClass("Backpack")
			local back = bp2 and pcall(function() tool.Parent = bp2 end) and tool.Parent == bp2
			if back then
				if os.clock() - (strikes.movedAt or 0) > 5 then
					say("The game moved " .. cfg.name .. " out of your inventory - put it back")
				end
				strikes.movedAt = os.clock()
			elseif Hooks.onRemoved then
				Hooks.onRemoved(cfg)
			end
		end)
	end)
end

-- wait (briefly) for the real model instead of giving a placeholder and swapping it later:
-- the swap destroyed and rebuilt the tool, which is what made the hotbar slot flicker.
-- Only waits when the model is still loading; already-loaded gears are still instant.
local function waitForModel(cfg, maxWait)
	if not cfg.id or cache[cfg.id] ~= nil or not loading[cfg.id] then return end
	say(cfg.name .. " loading...")
	local t0 = os.clock()
	while cache[cfg.id] == nil and loading[cfg.id] and os.clock() - t0 < maxWait do
		task.wait(0.05)
	end
end

local function giveGear(cfg)
	waitForModel(cfg, 6)
	removeGear(cfg)
	-- at game start the character may still be spawning (spawning wipes the backpack), so wait for it
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("Humanoid", 10)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return false, cfg.name .. " failed: no backpack" end

	local tool = loadTool(cfg)
	-- into the inventory FIRST, so it always shows even if a setup step errors
	tool.Parent = backpack
	active[cfg.name] = tool
	wanted[cfg.name] = true
	guardTool(cfg, tool)

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
		warn("[VestaGears] " .. cfg.name .. ": " .. problems[1])
	end
	return true, cfg.name .. " given"
end

-- start loading every real model in the background (same id is only loaded once)
local rows = {}
Hooks.onRemoved = function(cfg)
	local st = strikes[cfg.name]
	if not st then
		st = { n = 0, t = 0, busy = false }
		strikes[cfg.name] = st
	end
	if st.busy or not wanted[cfg.name] then return end
	st.busy = true
	if os.clock() - st.t > 10 then st.n = 0 end
	st.n += 1
	st.t = os.clock()
	if st.n >= 3 then
		-- the game keeps deleting it: stop, so nothing flickers
		wanted[cfg.name] = nil
		active[cfg.name] = nil
		if rows[cfg.name] then rows[cfg.name].setOn(false) end
		say(cfg.name .. " keeps getting removed by this game")
	else
		task.wait(0.15)
		if wanted[cfg.name] then
			giveGear(cfg)
			if rows[cfg.name] then rows[cfg.name].setOn(active[cfg.name] ~= nil) end
		end
	end
	st.busy = false
end
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

local FULL_SIZE = UDim2.new(0, 330, 0, 466)
local MINI_SIZE = UDim2.new(0, 132, 0, 38)

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
		return mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
	end
	local function tween(o, t, props)
		TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end
	-- smooth hover colour; the two functions let it follow a button's current state (GIVE / REMOVE)
	local function hover(o, getNormal, getOver)
		o.MouseEnter:Connect(function() tween(o, 0.12, { BackgroundColor3 = getOver() }) end)
		o.MouseLeave:Connect(function() tween(o, 0.12, { BackgroundColor3 = getNormal() }) end)
	end

	-- palette: deep charcoal with one violet accent
	local BG = Color3.fromRGB(12, 12, 17)
	local ROW = Color3.fromRGB(22, 22, 30)
	local ROW_HOVER = Color3.fromRGB(30, 30, 42)
	local LINE = Color3.fromRGB(38, 38, 52)
	local OFF = Color3.fromRGB(38, 38, 50)
	local OFF_HOVER = Color3.fromRGB(54, 54, 70)
	local ACCENT = Color3.fromRGB(124, 92, 255)
	local ACCENT_HOVER = Color3.fromRGB(150, 122, 255)
	local DANGER = Color3.fromRGB(140, 42, 54)
	local DANGER_HOVER = Color3.fromRGB(176, 56, 70)
	local WHITE = Color3.new(1, 1, 1)

	local frame = mk("Frame", {
		Name = "Main", Size = FULL_SIZE, Position = UDim2.new(0.5, -165, 0.5, -233),
		BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
	}, gui)
	local frameCorner = round(frame, 14)

	-- thin violet outline with a slow, soft glow travelling around it
	local stroke = mk("UIStroke", { Color = WHITE, Thickness = 1.5 }, frame)
	local strokeGrad = mk("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, ACCENT),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 40, 60)),
			ColorSequenceKeypoint.new(1, ACCENT),
		}),
		Rotation = 0,
	}, stroke)

	-- title bar
	local bar = mk("Frame", { Name = "Bar", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 }, frame)
	local dot = mk("Frame", {
		Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 14, 0.5, -4), BackgroundColor3 = ACCENT, BorderSizePixel = 0,
	}, bar)
	round(dot, 4)
	mk("TextLabel", {
		Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold, Text = "VESTA GEARS", TextSize = 14, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bar)
	mk("Frame", {
		Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 1, -1), BackgroundColor3 = LINE, BorderSizePixel = 0,
	}, bar)

	local minBtn = mk("TextButton", {
		Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -62, 0.5, -12), BackgroundColor3 = OFF,
		Font = Enum.Font.GothamBold, Text = "–", TextSize = 14, TextColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false,
	}, bar)
	round(minBtn, 12)
	hover(minBtn, function() return OFF end, function() return OFF_HOVER end)
	local closeBtn = mk("TextButton", {
		Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -34, 0.5, -12), BackgroundColor3 = OFF,
		Font = Enum.Font.GothamBold, Text = "×", TextSize = 16, TextColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false,
	}, bar)
	round(closeBtn, 12)
	hover(closeBtn, function() return OFF end, function() return DANGER_HOVER end)

	-- minimised: a small pill that opens the menu again
	local iconBtn = mk("TextButton", {
		Name = "GearIcon", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = BG, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, Text = "VESTA GEARS", TextSize = 12, TextColor3 = WHITE,
		AutoButtonColor = false, Visible = false, ZIndex = 5,
	}, frame)
	round(iconBtn, 19)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 18) }, iconBtn)
	local iconDot = mk("Frame", {
		Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, -2, 0.5, -4), BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, ZIndex = 6,
	}, iconBtn)
	round(iconDot, 4)
	hover(iconBtn, function() return BG end, function() return ROW end)

	local body = mk("Frame", { Name = "Body", Size = UDim2.new(1, 0, 1, -38), Position = UDim2.new(0, 0, 0, 38), BackgroundTransparency = 1 }, frame)

	local collapsed = false
	local function setCollapsed(c)
		collapsed = c
		bar.Visible = not c
		body.Visible = not c
		iconBtn.Visible = c
		tween(frame, 0.2, { Size = c and MINI_SIZE or FULL_SIZE })
		tween(frameCorner, 0.2, { CornerRadius = UDim.new(0, c and 19 or 14) })
	end

	-- the only animation: the outline glow drifts slowly; the minimised pill breathes very gently
	local t0 = os.clock()
	local anim = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		strokeGrad.Rotation = (t * 36) % 360
		stroke.Transparency = collapsed and (0.3 + 0.25 * math.sin(t * 2.4)) or 0.1
	end)
	gui.Destroying:Connect(function() anim:Disconnect() end)

	-- dragging (title bar and pill). Only the finger/mouse that started the drag moves the menu,
	-- so the joystick or another finger can never move it. A tap on the pill opens the menu.
	local dragging, dragInput, dragStart, startPos, moved, dragSource
	local function beginDrag(src)
		src.InputBegan:Connect(function(input)
			if dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				moved = false
				dragInput = input
				dragSource = src
				dragStart = input.Position
				startPos = frame.Position
			end
		end)
	end
	beginDrag(bar)
	beginDrag(iconBtn)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			if input ~= dragInput then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local d = input.Position - dragStart
		if d.Magnitude > 4 then moved = true end
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not dragging then return end
		local ends
		if dragInput.UserInputType == Enum.UserInputType.Touch then
			ends = (input == dragInput)
		else
			ends = (input.UserInputType == Enum.UserInputType.MouseButton1)
		end
		if not ends then return end
		if not moved and dragSource == iconBtn and collapsed then
			setCollapsed(false)
		end
		dragging = false
		dragInput = nil
	end)

	mk("TextLabel", {
		Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 0, 4), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, Text = "Script is client sided:\nWill not affect others in game",
		TextSize = 11, TextColor3 = Color3.fromRGB(135, 135, 160), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	}, body)

	local search = mk("TextBox", {
		Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 40), BackgroundColor3 = ROW, BorderSizePixel = 0,
		Font = Enum.Font.Gotham, PlaceholderText = "Search gears...", PlaceholderColor3 = Color3.fromRGB(115, 115, 140),
		Text = "", TextSize = 13, TextColor3 = WHITE, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, body)
	round(search, 10)
	mk("UIPadding", { PaddingLeft = UDim.new(0, 12) }, search)
	local searchStroke = mk("UIStroke", { Color = LINE, Thickness = 1 }, search)
	search.Focused:Connect(function() tween(searchStroke, 0.15, { Color = ACCENT }) end)
	search.FocusLost:Connect(function() tween(searchStroke, 0.15, { Color = LINE }) end)

	local list = mk("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -178), Position = UDim2.new(0, 8, 0, 76), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENT, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	for i, cfg in ipairs(GEARS) do
		local row = mk("Frame", { Size = UDim2.new(1, -6, 0, 36), BackgroundColor3 = ROW, BorderSizePixel = 0, LayoutOrder = i }, list)
		round(row, 10)
		local rowStroke = mk("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1 }, row)
		hover(row, function() return ROW end, function() return ROW_HOVER end)
		mk("TextLabel", {
			Size = UDim2.new(0.64, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, Text = cfg.name, TextSize = 12, TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		local btn = mk("TextButton", {
			Size = UDim2.new(0.28, 0, 0, 24), Position = UDim2.new(0.7, 0, 0.5, -12), BackgroundColor3 = OFF,
			Font = Enum.Font.GothamBold, Text = "GIVE", TextSize = 11, TextColor3 = WHITE, BorderSizePixel = 0,
			AutoButtonColor = false,
		}, row)
		round(btn, 12)

		local isOn = false
		local function setOn(on)
			isOn = on
			btn.Text = on and "REMOVE" or "GIVE"
			tween(btn, 0.15, { BackgroundColor3 = on and ACCENT or OFF })
			tween(rowStroke, 0.15, { Transparency = on and 0.5 or 1 })
		end
		hover(btn, function() return isOn and ACCENT or OFF end, function() return isOn and ACCENT_HOVER or OFF_HOVER end)
		rows[cfg.name] = { setOn = setOn, frame = row }

		btn.MouseButton1Click:Connect(function()
			local t = active[cfg.name]
			if t and t.Parent then
				removeGear(cfg)
				setOn(false)
				status(cfg.name .. " removed")
			else
				strikes[cfg.name] = nil
				local _, msg = giveGear(cfg)
				setOn(active[cfg.name] ~= nil)
				status(msg)
				-- put it in your hand straight away (same as the Crossbow script), so it shows even if the hotbar is hidden
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local t = active[cfg.name]
				if hum and t and t.Parent then pcall(function() hum:EquipTool(t) end) end
			end
		end)
	end

	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = search.Text:lower()
		for _, cfg in ipairs(GEARS) do
			rows[cfg.name].frame.Visible = (q == "") or (cfg.name:lower():find(q, 1, true) ~= nil)
		end
	end)

	local function footerButton(text, x, color, colorHover)
		local b = mk("TextButton", {
			Size = UDim2.new(0.5, -12, 0, 28), Position = UDim2.new(x, x == 0 and 8 or 4, 1, -92), BackgroundColor3 = color,
			Font = Enum.Font.GothamBold, Text = text, TextSize = 12, TextColor3 = WHITE, BorderSizePixel = 0,
			AutoButtonColor = false,
		}, body)
		round(b, 10)
		hover(b, function() return color end, function() return colorHover end)
		return b
	end
	local giveAllBtn = footerButton("GIVE ALL", 0, ACCENT, ACCENT_HOVER)
	local removeAllBtn = footerButton("REMOVE ALL", 0.5, DANGER, DANGER_HOVER)

	statusLabel = mk("TextLabel", {
		Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0, 8, 1, -58), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, Text = "", TextSize = 11,
		TextColor3 = Color3.fromRGB(165, 165, 190), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, body)

	mk("TextLabel", {
		Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 1, -20), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, Text = "Made by FearVesta", TextSize = 11,
		TextColor3 = Color3.fromRGB(105, 105, 130),
	}, body)

	giveAllBtn.MouseButton1Click:Connect(function()
		local given = 0
		for i, cfg in ipairs(GEARS) do
			strikes[cfg.name] = nil
			local ok = giveGear(cfg)
			rows[cfg.name].setOn(active[cfg.name] ~= nil)
			if ok then given += 1 end
			if i % 6 == 0 then task.wait() end -- tiny breather, no freeze
		end
		status(("%d gears given"):format(given))
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

-- ===== keep the gears in the inventory all the time (any game mode / role) =====
-- When a game wipes or swaps the backpack (new round, role given, respawn), the SAME gear tool is put back
-- instead of being rebuilt, so nothing flickers. A new copy is only made if the old one was destroyed.
local restoring = false
local function restoreGears()
	if restoring then return end
	restoring = true
	local char = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")
	if char and bp then
		for _, cfg in ipairs(GEARS) do
			if wanted[cfg.name] then
				local t = active[cfg.name]
				if not t or (t.Parent ~= bp and t.Parent ~= char) then
					local back = false
					if t then
						back = pcall(function() t.Parent = bp end) and t.Parent == bp
					end
					if not back then
						Hooks.onRemoved(cfg)
					end
					if rows[cfg.name] then rows[cfg.name].setOn(active[cfg.name] ~= nil) end
				end
			end
		end
	end
	restoring = false
end

player.CharacterAdded:Connect(function()
	player:WaitForChild("Backpack")
	task.wait(0.3)
	for k in pairs(strikes) do strikes[k] = nil end -- a new life is not the game deleting your gears
	restoreGears()
end)

task.spawn(function()
	while true do
		task.wait(1)
		-- gently switch the Roblox inventory back on (once a second, not every frame, so the hotbar can fill in)
		if next(wanted) then
			local ok, enabled = pcall(function()
				return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
			end)
			if ok and not enabled then
				pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) end)
			end
		end
		restoreGears()
	end
end)

print("Vesta Gears menu ready")
