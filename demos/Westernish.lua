-- Sample project by Steven Johnson (aka Star Crunch or ggcrunchy)

-- This is a prototype for some game mechanics. At the moment it's endless, with no
-- way either to fail or progress, etc. The collision does recognize height, but it
-- hasn't been developed much.

-- Gameplay "challenges" alternate between a wave of enemies and randomly generated
-- pits, to be shot down or jumped.

-- This test is sort of a shmup, a bit like Dino Riki on the NES.
-- Other influences include Legend of Valkryie and some of the Goemon titles.

-- See, for instance:
-- http://www.hardcoregaming101.net/adventures-of-dino-riki-the/
-- http://www.hardcoregaming101.net/legend-of-valkyrie/
-- http://www.hardcoregaming101.net/legend-of-the-mystical-ninja/

--
--
--

local MasterGroup = display.newGroup() -- everything!

--
--
--

local BelowGroup = display.newGroup() -- water, etc. exposed by gaps or masks in GroundGroup

MasterGroup:insert(BelowGroup)

--
--
--

local GroundGroup = display.newGroup() -- terrain

MasterGroup:insert(GroundGroup)

local Terrain1 = display.newGroup()
local Terrain2 = display.newGroup()
local Terrain3 = display.newGroup()

GroundGroup:insert(Terrain1)
GroundGroup:insert(Terrain2)
GroundGroup:insert(Terrain3)

local LeftEdge, RightEdge = 0, display.contentWidth
local TopEdge, BottomEdge = 0, display.contentHeight

local VerticalExtra = math.ceil(display.contentHeight / 4)

local HalfHeight = math.ceil((BottomEdge - TopEdge) / 2) + VerticalExtra
local FullHeight = 2 * HalfHeight

local function PopulateTerrain (group)
	local w, h = RightEdge - LeftEdge, FullHeight
	local ground = display.newRect(group, w / 2, h / 2, w, h)

	ground:setFillColor(.2, .175, .05)

	for _ = 1, 60 do
		local rock = display.newCircle(group, math.random(10, ground.width - 10), math.random(10, ground.height - 10), math.random(5, 15))

		rock:setFillColor(.2 + math.random() * .3)
	end
end

-- We cycle between these as we scroll: either #2 might be fully in view; otherwise either
-- #1 (above) or #3 (below) is also partially showing.
PopulateTerrain(Terrain1)
PopulateTerrain(Terrain2)
PopulateTerrain(Terrain3)

--
--
--

local ScrollOffset = 0

local function StackTerrains (y)
	local mid_y = math.round(y)

	Terrain1.y = mid_y - FullHeight
	Terrain2.y = mid_y
	Terrain3.y = mid_y + FullHeight
end

StackTerrains(0)

local function UpdateScroll (delta)
	ScrollOffset = ScrollOffset + delta

	if ScrollOffset > FullHeight then -- #3 went out of view?
		Terrain1, Terrain2, Terrain3 = Terrain3, Terrain1, Terrain2

		ScrollOffset = ScrollOffset % FullHeight
	elseif ScrollOffset < 0 then -- #1 went out of view?
		Terrain1, Terrain2, Terrain3 = Terrain2, Terrain3, Terrain1

		ScrollOffset = ScrollOffset % FullHeight
	end

	StackTerrains(ScrollOffset)
end

--
--
--

local AboveGroup = display.newGroup() -- objects + shadows

MasterGroup:insert(AboveGroup)

--
--
--

local ObjectGroup = display.newGroup()
local ShadowGroup = display.newGroup()

AboveGroup:insert(ShadowGroup)
AboveGroup:insert(ObjectGroup)

--
--
--

local _object = {}

local function GetObject (combo)
	return combo[_object]
end

local _shadow = {}

local function GetShadow (combo)
	return combo[_shadow]
end

local _yoffset = {}

local function SetY (combo, y, offset)
	GetObject(combo).y = y + offset
	GetShadow(combo).y = y
end

local function SetObjectYOffset (combo, y)
	combo[_yoffset] = y

	SetY(combo, GetShadow(combo).y, y)
end

--
--
--

local Props = { x = true, y = true, alpha = true, isVisible = true }

local MT = {}

function MT:__index (k)
	if Props[k] then
		return GetShadow(self)[k]
	else
		return rawget(self, k)
	end
end

function MT:__newindex (k, v)
	if k == "y" then
		SetY(self, v, self[_yoffset] or 0)
	elseif Props[k] then
		GetObject(self)[k] = v
		GetShadow(self)[k] = v
	else
		rawset(self, k, v)
	end
end

--
--
--

local function SetShadowScales (combo, xScale, yScale)
	local shadow = GetShadow(combo)

	shadow.xScale, shadow.yScale = xScale, yScale
end

local function MakeObjectWithShadow (object, params)
	local shadow = display.newCircle(0, 0, params.shadow_radius)

	if type(params.shadow_tint) == "table" then
		shadow:setFillColor(unpack(params.shadow_tint))
	else
		shadow:setFillColor(params.shadow_tint)
	end

	shadow.xScale, shadow.yScale = params.xScale, params.yScale

	object.x, object.y = shadow.x, shadow.y

	local combo = {
		[_object] = object,
		[_shadow] = shadow,
		z = 0, radius = params.collision_radius
	}

	return setmetatable(combo, MT)
end

local function Intersect (combo1, combo2)
	return (combo1.x - combo2.x)^2 + (combo1.y - combo2.y)^2 + (combo1.z - combo2.z)^2 <= (combo1.radius + combo2.radius)^2
end

local function Show (combo, promote)
	local object, shadow = GetObject(combo), GetShadow(combo)

	ObjectGroup:insert(object)
	ShadowGroup:insert(shadow)

	if promote then
		object:toBack()
		shadow:toBack()
	end
end

local function Hide (combo, pool)
	local object, shadow = GetObject(combo), GetShadow(combo)
	local into = pool.stash

	into:insert(object)
	into:insert(shadow)

	pool[#pool + 1] = combo
end

--
--
--

local function MakeTimer (action, def)
	local last

	return function(now)
		local result = def

		if last then
			result = action(now - last)
		end

		last = now

		return result
	end
end

local function MakeLapseInSeconds ()
	return MakeTimer(function(dt)
		return dt / 1000
	end, 0)
end

local function MakeTimeoutCheck (duration)
	local acc = 0

	return MakeTimer(function(dt)
		acc = acc + dt

		local done = acc >= duration

		if done then
			acc = 0 -- or acc % duration
		end

		return done
	end, true)
end

--
--
--

local Radius = 25
local ShadowScaleMaxX, ShadowScaleMaxY = 1.15, .65

local PlayerParams = {
	shadow_radius = 28,
	shadow_tint = { .7, .4 },
	xScale = ShadowScaleMaxX, yScale = ShadowScaleMaxY,
	collision_radius = Radius
}

local Player = MakeObjectWithShadow(display.newImageRect("img/stand.png", 2 * Radius, 2 * Radius), PlayerParams)

Show(Player)

Player.x, Player.y = display.contentCenterX, display.contentHeight - 100

local ShadowDeltaY = 25

SetObjectYOffset(Player, ShadowDeltaY)

Player.check_fire = MakeTimeoutCheck(300)

--
--
--

local DX, DY = 0, 0
local WantsToJump, WantsToFire

local Deltas = { left = -1, right = 1, up = -1, down = 1 }
local KeysDown = {}

Runtime:addEventListener("key", function(event)
	local name, key_up = event.keyName, event.phase == "up"

	-- Prevent repeats.
	if key_up then
		KeysDown[name] = false
	elseif KeysDown[name] then
		return true
	else
		KeysDown[name] = true
	end

	-- Movement.
	local delta = Deltas[name]

	if delta then
		if key_up then
			delta = -delta
		end

		if name == "left" or name == "right" then
			DX = DX + delta
		else
			DY = DY + delta
		end

		-- Jumping.
	elseif name == "space" then
		WantsToJump = not key_up

		-- Firing.
	elseif name == "s" then
		WantsToFire = not key_up
	end

	return true
end)

--
--
--

local HeightBins = 4

local HalfJumpTime = 400
local JumpTime = 2 * HalfJumpTime

local JumpHeight = 150
local ShadowScaleMinX, ShadowScaleMinY = .6, .5

local JumpHeightBin = JumpHeight / HeightBins

local function UpdateJump (elapsed)
	if elapsed > JumpTime then
		Player.started_jump, Player.z = false, 0

		SetShadowScales(Player, ShadowScaleMaxX, ShadowScaleMaxY)

		return 0
		-- TODO: on(landed)... e.g. dirt, water splashes, etc.
	else
		local s = math.abs(elapsed - HalfJumpTime) / HalfJumpTime
		local t = 1 - s

		SetShadowScales(Player, s * ShadowScaleMaxX + t * ShadowScaleMinX, s * ShadowScaleMaxY + t * ShadowScaleMinY)

		local height = JumpHeight * t
		local bin = math.floor(height / JumpHeightBin)

		Player.z = JumpHeightBin * (bin + .5)

		return height
	end
end

--
--
--

local Bullets = {}
local BulletSpeed = 1600
local Offscreen = -100

local Pool = { stash = display.newGroup() }

Pool.stash.isVisible = false

local BulletParams = {
	shadow_radius = 9,
	shadow_tint = .4,
	xScale = 1.05, yScale = .7,
	collision_radius = 7
}

local function FireBullet (player, y_delta)
	local bullet = table.remove(Pool) or MakeObjectWithShadow(display.newCircle(0, 0, 10), BulletParams)

	Show(bullet, true) -- put behind player when first fired

	bullet.x, bullet.y = player.x, player.y - 40
	bullet.z = player.z

	SetObjectYOffset(bullet, -y_delta)

	Bullets[#Bullets + 1] = bullet
end

local function PoolBullet (bullet, i, n)
	Hide(bullet, Pool)

	-- backfill
	Bullets[i] = Bullets[n]
	Bullets[n] = nil

	return n - 1
end

local function UpdateBulletPositions (dt)
	local dy, n = BulletSpeed * dt, #Bullets

	for i = n, 1, -1 do
		local bullet = Bullets[i]

		if bullet.y < Offscreen then
			n = PoolBullet(bullet, i, n)
		else
			bullet.y = bullet.y - dy
		end
	end
end

--
--
--

local function ClipCoordinate (value, edge1, edge2)
	if value - Radius < edge1 then
		return edge1 + Radius
	elseif value + Radius > edge2 then
		return edge2 - Radius
	else
		return value
	end
end

local MovementSpeed = 950
local ScrollSpeed = 350

local FrameLapse = MakeLapseInSeconds()

local Scrollables = {}

Runtime:addEventListener("enterFrame", function(event)
	local now = event.time
	local dt = FrameLapse(now)
	local scroll_diff = ScrollSpeed * dt

	UpdateScroll(scroll_diff)

	for object, func in pairs(Scrollables) do
		if not func(object, scroll_diff) then
			Scrollables[object] = nil
		end
	end

	local y_delta = ShadowDeltaY

	if WantsToJump or Player.started_jump then
		Player.started_jump = Player.started_jump or event.time

		y_delta = y_delta + UpdateJump(now - Player.started_jump)
	end

	local diff = MovementSpeed * dt

	Player.x = ClipCoordinate(Player.x + DX * diff, LeftEdge, RightEdge)
	Player.y = ClipCoordinate(Player.y + DY * diff, TopEdge, BottomEdge)

	SetObjectYOffset(Player, -y_delta)

	-- update any scrolling; if grounded, do any terrain effects (dust, wet feet, rustle grass, etc.)

	UpdateBulletPositions(dt)

	if WantsToFire and Player.check_fire(now) then
		FireBullet(Player, y_delta)
	end
end)

--
--
--

local Events = {}

--
--
--

local function MakePingPongUpdater (speed, pos_key, inc_key)
	return function(object, dt, limit1, limit2)
		local pos, incrementing = object[pos_key], object[inc_key]
		local delta, hit_limit = speed * dt

		if incrementing then
			pos = pos - delta
			hit_limit = pos < limit1
		else
			pos = pos + delta
			hit_limit = pos > limit2
		end

		object[pos_key] = pos

		if hit_limit then
			object[inc_key] = not incrementing
		end
	end
end

local UpdateX = MakePingPongUpdater(450, "x", "xinc")
local UpdateYOffset = MakePingPongUpdater(100, "y_offset", "yinc")

local function UpdateEnemy (enemy)
	local lapse = MakeLapseInSeconds()

	return timer.performWithDelay(50, function(event)
		local dt = lapse(event.time)

		UpdateX(enemy, dt, 100, display.contentWidth - 100)
		UpdateYOffset(enemy, dt, -100, 100)

		enemy.y = enemy.y0 + enemy.y_offset
	end, 0)
end

local function InitializeEnemy (enemy)
	enemy.hit_points = 3
	enemy.xinc, enemy.yinc = true, true
	enemy.y0, enemy.y_offset = enemy.y, 0
	enemy.update = UpdateEnemy(enemy)
end

local function RespawnEnemy (enemy)
	enemy.x, enemy.y = enemy.x0, -200
	enemy.isVisible = true

	transition.to(enemy, {
		y = 200,

		time = 1500, transition = easing.inOutCubic,
		onComplete = InitializeEnemy
	})
end

local EnemyParams = {
	shadow_radius = 45,
	shadow_tint = { .5, .3 },
	xScale = 1.125, yScale = .8,
	collision_radius = 65
}

local Enemies, EnemyCount, LeftToSpawn

function Events.LaunchWave ()
	Enemies, EnemyCount = {}, 5
	LeftToSpawn = EnemyCount

	for _, xoffset in ipairs{ -150, 150 } do
		local enemy = MakeObjectWithShadow(display.newImageRect("img/skeleton.png", 100, 100), EnemyParams)

		Show(enemy)

		enemy.isVisible = false
		enemy.x0 = display.contentCenterX + xoffset

		SetObjectYOffset(enemy, -35)
		RespawnEnemy(enemy)

		LeftToSpawn = LeftToSpawn - 1
		Enemies[#Enemies + 1] = enemy
	end
end

--
--
--

local FadeOutParams = {
	alpha = 0,

	onComplete = function(enemy)
		timer.cancel(enemy.update)

		enemy.isVisible, enemy.alpha = false, 1

		EnemyCount = EnemyCount - 1

		if LeftToSpawn > 0 then
			LeftToSpawn = LeftToSpawn - 1

			timer.performWithDelay(3000, function()
				RespawnEnemy(enemy)
			end)
		elseif EnemyCount == 0 then
			Events.SpawnPits()
		end
	end
}

local Hits = {}

timer.performWithDelay(75, function()
	local n = #Bullets

	for i = n, 1, -1 do
		local bullet, was_hit = Bullets[i]

		for _, enemy in ipairs(Enemies) do
			local hp = enemy.hit_points

			if hp and hp > 0 and Intersect(bullet, enemy) then
				Hits[enemy], was_hit = true, true
			end
		end

		if was_hit then -- do outside enemy loop, at most once
			n = PoolBullet(bullet, i, n)
		end
	end

	for enemy in pairs(Hits) do -- likewise for any enemies
		enemy.hit_points = enemy.hit_points - 1

		if enemy.hit_points == 0 then
			transition.to(enemy, FadeOutParams)
		end

		Hits[enemy] = nil
	end
end, 0)

--
--
--

local function Iterate (layout, w, h)
	local col, phase = 1, 1
	local y1, y2 = math.random(2, h - 1)

	repeat
		if phase == 1 then -- go right, doing one row
			local step = math.random(1, 3)
			local col2 = math.min(col + step, w)

			for i = col, col2 do
				layout[y1][i] = "x"
			end

			col = col2 + 1
		elseif phase == 2 then -- separate, up and down
			local row1 = math.max(1, y1 - math.random(1, 3))
			local row2 = math.min(h, y1 + math.random(1, 3))

			for y = row1, y1 do
				layout[y][col] = "x"
			end

			for y = y1, row2 do
				layout[y][col] = "x"
			end

			y1, y2, col = row1, row2, col + 1
		elseif phase == 3 then -- go right, doing two rows
			local step = math.random(1, 3)
			local col2 = math.min(col + step, w)

			for i = col, col2 do
				layout[y1][i] = "x"
				layout[y2][i] = "x"
			end

			col = col2 + 1
		else -- merge again, up and down
			local mid = math.random(y1 + 1, y2 - 1)

			for y = y1, mid do
				layout[y][col] = "x"
			end

			for y = mid + 1, y2 do
				layout[y][col] = "x"
			end

			y1, col = mid, col + 1
		end

		phase = phase % 4 + 1
	until col > w
end

local function MakeLayout (w, h)
	local layout = {}

	for _ = 1, h do
		local row = {} -- as characters for easy visualization; in practice might use bitwise ops

		for _ = 1, w do
			row[#row + 1] = "."
		end

		layout[#layout + 1] = row
	end

	for _ = 1, 3 do -- layer a few patterns for more interesting results
		Iterate(layout, w, h)
	end

	-- Uncomment to visualize the layout:

	--[[
  print("")

  for y = 1, h do
    print(table.concat(layout[y]))
  end
--]]

	return layout
end

local TileColumns, TileRows = 8, 9
local TileW, TileH = display.contentWidth / TileColumns, .75 * display.contentHeight / TileRows

local function InPit (group)
	if not Player.started_jump then
		local x, y = math.floor(Player.x / TileW) + 1, math.floor((Player.y - group.y) / TileH) + 1
		local row = group.layout[y]

		return row and row[x] == "x"
	end
end

local function ScrollGroup (group, delta)
	local inside = group.y < display.contentHeight

	if inside then
		group.y = group.y + delta
	else
		group:removeSelf()

		Events.LaunchWave()
	end

	if inside and InPit(group) then
		GetObject(Player):setFillColor(1, 0, 0) -- "damaged"
	else
		GetObject(Player):setFillColor(1, 1, 1) -- "safe"
	end

	return inside
end

function Events.SpawnPits ()
	local layout = MakeLayout(TileColumns, TileRows)
	local pgroup = display.newGroup()

	pgroup.layout = layout

	GroundGroup:insert(pgroup)

	local y = 0

	for _, row in ipairs(layout) do
		local x = 1

		repeat
			while row[x] == "." do
				x = x + 1
			end

			local x1 = x

			while row[x] == "x" do
				x = x + 1
			end

			if x1 ~= x then
				-- The rectangular look is a bit harsh; it could be fancied up with some effort.
				local w = (x - x1) * TileW
				local pit = display.newRect(pgroup, (x1 - 1) * TileW + w / 2, y + TileH / 2, w, TileH)

				pit:setFillColor(0)
			end
		until x1 == x

		y = y + TileH
	end

	pgroup.y = -pgroup.height
	Scrollables[pgroup] = ScrollGroup
end

--

Events.LaunchWave()