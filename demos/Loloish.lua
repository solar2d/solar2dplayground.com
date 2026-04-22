-- Sample project by Steven Johnson (aka Star Crunch or ggcrunchy)

-- This is based on the Adventures of Lolo / Eggerland series of games, or at least a
-- small slice of the mechanics: collecting hearts and then the jewel; pushing blocks;
-- and line-of-sight enemies, both stationary and moving.

-- There are MANY features left to implement, so it isn't a "true" clone. :)

-- Special thanks to Ernesto Lopez and Danny Glover for playing around with it and
-- helping to honor various Lolo minutiae. :D

--------------------
--
-- LEVELS
--
--------------------

local Levels = {
	{
		columns = 11, -- the original game was 11x11 (portable version 8x8)
		-- the gameplay should be fine with other dimensions,
		-- but the sidebar will need adjustment

		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X",
		"X", "_", "_", "_", "_", "X", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "X", "_", "_", "_", "_", "X",
		"X", "_", "B", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "J", "_", "X",
		"X", "_", "_", "P", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "D",
		"X", "_", "_", "_", "_", "_", "H", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "H", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X"
	},
	{
		columns = 11,

		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X",
		"X", "P", "B", "_", "X", "_", "_", "_", "_", "_", "X",
		"X", "B", "B", "_", "X", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "B", "_", "X", "_", "_", "_", "_", "X",
		"X", "X", "B", "_", "_", "_", "_", "_", "J", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "X", "_", "_", "_", "_", "_", "_", "_", "D",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "H", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X"
	},
	{
		columns = 11,

		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X",
		"X", "_", "_", "_", "_", "X", "_", "_", "M", "_", "X",
		"X", "_", "_", "_", "_", "X", "_", "_", "_", "_", "X",
		"X", "_", "B", "_", "B", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "J", "_", "X",
		"X", "_", "_", "P", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "D",
		"X", "_", "_", "_", "_", "_", "H", "_", "_", "_", "X",
		"X", "_", "B", "_", "_", "_", "H", "_", "G", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "_", "_", "_", "_", "_", "_", "_", "_", "_", "X",
		"X", "X", "X", "X", "X", "X", "X", "X", "X", "X", "X"
	}
}

--------------------
--
-- TILE IDS
--
--------------------

local None = 0
local WallID = 1
local DoorID = 2
local PlayerID = 3
local ChestID = 4
local JewelID = 5
local HarmfulID = 6
local BlocksID = 7
local HeartsID

local RangedIDs = BlocksID -- any ID from this point on is part of a range

--------------------
--
-- TILE UTILITIES
--
--------------------

local Columns, Rows, CellCount -- these are filled in when we load a level

local function Assign (object, row, col)
	object.crow, object.ccol = row, col
end

-- We move in discrete steps, but want to allow half-tile movement, so the occupancy grid
-- is (2 * width) x (2 * height) cells in size. Each object also maintains its occupancy
-- coordinates, namely the upper-left corner; at the moment all objects occupy a 2 x 2
-- region, i.e. one tile's worth of cells.

local OccupiedBy -- the `width` is populated when we load the level

local function GetCoordinate (row, col)
	return (row - 1) * OccupiedBy.width + col
end

local function AuxFill (index, value, id)
	local cur = OccupiedBy[index]

	if id and cur and cur ~= id then
		return
	end

	OccupiedBy[index] = value
end

local function Fill (object, value, id)
	local first = GetCoordinate(object.crow, object.ccol)
	local below = first + OccupiedBy.width

	AuxFill(first, value, id)
	AuxFill(first + 1, value, id)
	AuxFill(below, value, id)
	AuxFill(below + 1, value, id)
end

local PerCellID -- this is filled in when we load the level

local function Classify (value)
	if value < RangedIDs then -- normal value?
		return value
	else
		local offset = value - RangedIDs - 1 -- offset >= 0, since value = range ID + one-based index
		local range_id, index = RangedIDs + math.floor(offset / PerCellID) * PerCellID, offset % PerCellID + 1

		return range_id, index
	end
end

-- Per the occupancy, the surroundings of a 2 x 2 square are relevant when moving. More
-- specifically, in any given cardinal direction, we would enter two neighbors; these
-- are represented by { `DR`, `DC` } deltas. To land on a neighbor, traverse `DR` half-rows /
-- `DC` half-columns from the square's upper-left corner.
-- We can also resolve the corner to a cell; a whole-cell delta is also included.

local Deltas = {
	left = { -- expounding on the paragraph above (trying to move left):
		{ 0, -1 }, -- left of upper-left: same row, half a cell left
		{ 1, -1 }, -- left of lower-left: half a cell down, half a cell left
		0, -1 -- cell to left: same row, one cell left
	},
	right = { { 0, 2 }, { 1, 2 }, 0, 1 },
	up = { { -1, 0 }, { -1, 1 }, -1, 0 },
	down = { { 2, 0 }, { 2, 1 }, 1, 0 }
}

local function GetValueAt (row, col)
	return OccupiedBy[GetCoordinate(row, col)] or None
end

local function GetRowColumnWithDelta (row, col, delta)
	return row + delta[1], col + delta[2]
end

local function GetValueFromDelta (row, col, delta)
	return GetValueAt(GetRowColumnWithDelta(row, col, delta))
end

local function GetAdjacentValues (object, dir)
	local deltas, row, col = Deltas[dir], object.crow, object.ccol

	if deltas then
		return GetValueFromDelta(row, col, deltas[1]), GetValueFromDelta(row, col, deltas[2]), deltas[3], deltas[4]
	end
end

local function GetNextCoordinate (row, col, dir)
	local deltas = Deltas[dir]

	if deltas then
		row, col = GetRowColumnWithDelta(row, col, deltas[1])

		return row, col, deltas[3], deltas[4]
	end
end

local function Update (object, dr, dc)
	Assign(object, object.crow + dr, object.ccol + dc)
end

--------------------
--
-- OBJECT STATE
--
--------------------

local TileSize = 48
local HalfSize = TileSize / 2

local Factories = {}

--------------------
--
-- WALLS, DOOR
--
--------------------

local function MakeWallObject (groups, x, y, is_door)
	local image = is_door and "img/pushBlock2.png" or "img/pushBlock1.png"
	local wall = display.newImageRect(is_door and groups.level or groups.scenery, image, TileSize, TileSize)

	wall.x, wall.y = x, y

	return wall
end

local Door

function Factories.D (groups, x, y) -- door
	assert(not Door, "Door already exists")

	Door = MakeWallObject(groups, x, y, true)

	return Door, WallID
end

function Factories.X (groups, x, y) -- wall
	return MakeWallObject(groups, x, y), WallID
end

local function FadeOut (object)
	transition.to(object, { alpha = 0, time = 150 })
end

Runtime:addEventListener("init", function()
	Door = nil
end)

Runtime:addEventListener("got_jewel", function()
	Fill(Door, DoorID)
	FadeOut(Door)
end)

--------------------
--
-- BLOCKS
--
--------------------

local Blocks

function Factories.B (groups, x, y)
	local block = display.newImageRect(groups.level, "img/spaceCrate.png", TileSize - 2, TileSize - 2)

	block.x, block.y = x, y

	Blocks[#Blocks + 1] = block

	return block, BlocksID + #Blocks
end

Runtime:addEventListener("init", function()
	Blocks = {}
end)

--------------------
--
-- CHEST AND JEWEL
--
--------------------

local Chest, Jewel

function Factories.J (groups, x, y) -- jewel chest
	local chest = display.newImageRect(groups.scenery, "img/credit.png", TileSize, TileSize)

	chest.x, chest.y = x, y

	Chest = chest

	return chest, ChestID
end

local function MakeJewelObject (group, x, y)
	local jewel = display.newImageRect(group, "img/gem.png", HalfSize + 3, HalfSize + 3)

	jewel.x, jewel.y = x, y

	return jewel
end

Runtime:addEventListener("init", function()
	Chest, Jewel = nil
end)

Runtime:addEventListener("got_jewel", function()
	Fill(Chest, ChestID)  -- we no longer want the spot to look like a jewel, but must
	-- still prevent blocks from being pushed over it; since all
	-- hearts have now been collected, we can just revert to the
	-- now-dormant chest state
	FadeOut(Jewel)
end)

local function OpenChest ()
	Jewel = MakeJewelObject(Chest.parent, Chest.x, Chest.y)

	Fill(Chest, JewelID)
end

--------------------
--
-- HEARTS
--
--------------------

local Hearts

function Factories.H (groups, x, y) -- heart
	local heart = display.newImageRect(groups.level, "img/heart.png", TileSize - 4, TileSize - 4)

	heart.x, heart.y = x, y

	Hearts[#Hearts + 1] = heart

	return heart, HeartsID + #Hearts
end

Runtime:addEventListener("init", function()
	Hearts = { collected = 0 }
end)

local function CollectHeart (index)
	local heart = Hearts[index]

	if not heart.was_collected then
		heart.was_collected = true

		Fill(heart, nil)
		FadeOut(heart)

		Hearts.collected = Hearts.collected + 1

		if Hearts.collected == #Hearts then
			OpenChest()
		end
	end
end

--------------------
--
-- PLAYER
--
--------------------

local Player

function Factories.P (groups, x, y) -- player
	assert(not Player, "Player already exists")

	local group = display.newGroup()
	local ball = display.newImageRect(group, "img/shapeBall.png", TileSize - 10, TileSize - 10)

	ball:setFillColor(0, 0, 1)

	local eye1 = display.newImageRect(group, "img/shapeBall.png", 8, 8)
	local eye2 = display.newImageRect(group, "img/shapeBall.png", 8, 8)

	local pupil1 = display.newImageRect(group, "img/shapeBall.png", 3, 3)
	local pupil2 = display.newImageRect(group, "img/shapeBall.png", 3, 3)

	pupil1:setFillColor(0)
	pupil2:setFillColor(0)

	group.anchorChildren = true
	group.x, group.y = x, y

	eye1.x, eye2.x = -7, 7
	eye1.y, eye2.y = -5, -5
	pupil1.x, pupil2.x = -7, 7
	pupil1.y, pupil2.y = -8, -8

	Player = group

	groups.level:insert(group)

	return group, PlayerID
end

Runtime:addEventListener("init", function()
	Player = nil
end)

local LoadLevel -- forward reference

local function PlayerBusy ()
	return Player.killed or Player.progressing
end

local function SpinAndReload ()
	transition.to(Player, {
		rotation = 360 * 5, time = 850,

		onComplete = function()
			timer.performWithDelay(1, LoadLevel)
		end
	})
end

local function KillPlayer ()
	if not PlayerBusy() then
		if not Player.defer then -- not still moving?
			SpinAndReload()
		end

		Player.killed = true
	end
end

--------------------
--
-- GORGON ENEMIES
--
--------------------

local Gorgons

local function MakeGorgonObject (groups, x, y)
	local gorgon = display.newImageRect(groups.level, "img/skeleton.png", TileSize - 3, TileSize - 3)

	gorgon.x, gorgon.y = x, y

	Gorgons[#Gorgons + 1] = gorgon

	return gorgon
end

function Factories.G (groups, x, y) -- normal gorgon
	return MakeGorgonObject(groups, x, y), HarmfulID
end

local MoveList = {}

local function AddToMoveList (object, dx, dy)
	local has_x = dx and dx ~= 0
	local has_y = dy and dy ~= 0

	if has_x and has_y then
		-- TODO? diagonal
	elseif has_x then
		MoveList[#MoveList + 1] = { object, "x", object.x, dx }
	elseif has_y then
		MoveList[#MoveList + 1] = { object, "y", object.y, dy }
	end
end

local function Step (gorgon)
	local v1, v2, dr, dc = GetAdjacentValues(gorgon, gorgon.dir)

	if (v1 == None or v1 == PlayerID) and (v2 == None or v2 == PlayerID) then -- next spot is open?
		if v1 == PlayerID or v2 == PlayerID then
			KillPlayer()

			Player.defer = true
		end

		Fill(gorgon, nil)
		Update(gorgon, dr, dc)
		Fill(gorgon, HarmfulID)
		AddToMoveList(gorgon, dc * HalfSize, 0)
	elseif gorgon.dir == "right" then
		gorgon.dir = "left"
	else
		gorgon.dir = "right"
	end
end

function Factories.M (groups, x, y) -- Mr. Gorgon
	local gorgon = MakeGorgonObject(groups, x, y)

	gorgon.dir = "right"
	gorgon.Step = Step -- make this a method to distinguish from basic gorgons

	return gorgon, HarmfulID
end

Runtime:addEventListener("init", function()
	Gorgons = {}
end)

Runtime:addEventListener("got_jewel", function()
	for _, gorgon in ipairs(Gorgons) do
		gorgon.isVisible = false

		Fill(gorgon, nil)
	end

	Gorgons = {}
end)

local CanSeeThrough = { [None] = true, [ChestID] = true, [JewelID] = true }

local function IsWayBlocked (row, col, rto, cto)
	local dr, dc, dir, rstep, cstep = 0, 0

	if row == rto then
		dir, dr = col < cto and "right" or "left", 1
	else
		dir, dc = row < rto and "down" or "up", 1
	end

	row, col, rstep, cstep = GetNextCoordinate(row, col, dir) -- move to the next position past the first object

	if dir == "left" then
		cto = cto + 1 -- want the right side of the second object...
	elseif dir == "up" then
		rto = rto + 1 -- ...or the bottom, to omit cells it occupies
	end

	while row ~= rto or col ~= cto do
		local v1, v2 = GetValueAt(row, col), GetValueAt(row + dr, col + dc)

		if not (CanSeeThrough[v1] and CanSeeThrough[v2]) then
			return true
		end

		row, col = row + rstep, col + cstep
	end

	return false, rstep, cstep
end

local function GetViewOfPlayer (gorgon)
	local row, col, rto, cto = gorgon.crow, gorgon.ccol, Player.crow, Player.ccol

	if row == rto or col == cto then -- lined up?
		local blocked, rstep, cstep = IsWayBlocked(row, col, rto, cto)

		if blocked then
			return "obscured"
		else
			return "visible", rstep, cstep
		end
	elseif math.abs(row - rto) == 1 or math.abs(col - cto) == 1 then -- halfway in gorgon's vision
		return "obscured"
	end -- otherwise nil
end

local function Stab (gorgon, rstep, cstep)
	-- shank! for extra credit, the garden-variety gorgon could have a different attack, e.g. beams
	local x1, y1, x2, y2 = gorgon.x, gorgon.y, Player.x, Player.y

	local angle

	if cstep < 0 then -- player to left?
		angle, x2 = -180, x2 + 10
	elseif cstep > 0 then -- or right...
		angle, x2 = 0, x2 - 10
	elseif rstep < 0 then -- ...above...
		angle, y2 = -90, y2 + 10
	else -- ...below
		angle, y2 = 90, y2 - 10
	end

	local n = 5 -- could adjust based on distance
	local group, dx, dy = display.newGroup(), x2 - x1, y2 - y1

	gorgon.parent:insert(group)

	for i = 1, n do
		local sword = display.newImageRect(group, "img/swordStroked.png", TileSize, TileSize)
		local t = i / n

		sword.x, sword.y = x1 + t * dx, y1 + t * dy
		sword.rotation = angle
		sword.alpha = .25 + t * .75
	end

	timer.performWithDelay(150, function()
		group:removeSelf()
	end)
end

local function UpdateGorgon (gorgon, defer)
	local stab, view, rstep, cstep = nil, GetViewOfPlayer(gorgon)

	if view == "visible" then
		if defer then
			Player.defer = { gorgon, rstep, cstep }
		else
			Stab(gorgon, rstep, cstep)
		end

		KillPlayer()
	end

	gorgon.in_view = view

	if gorgon.in_view then
		gorgon:setFillColor(1, .5, .5)
	else
		gorgon:setFillColor(1, 1, 1)
	end
end

--------------------
--
-- LEVEL LOADING
--
--------------------

local function SetRanges (per_cell_id)
	HeartsID = BlocksID + per_cell_id
end

local LevelID

local TopLevelGroup

local LastTime

function LoadLevel ()
	timer.cancelAll()
	transition.cancelAll()

	Runtime:dispatchEvent{ name = "init" } -- reset from sidebar or previous level

	display.remove(TopLevelGroup)

	--
	--
	--

	TopLevelGroup = display.newGroup()

	local groups = { level = TopLevelGroup, scenery = display.newGroup() }

	TopLevelGroup:insert(groups.scenery)

	--
	--
	--

	local level = Levels[LevelID]

	Columns, CellCount = level.columns, #level
	Rows = CellCount / Columns

	OccupiedBy = { width = Columns * 2 }

	PerCellID = CellCount + 1 -- ID for range itself, then one for each cell

	assert(PerCellID > CellCount, "Too few IDs to account for all positions")

	SetRanges(PerCellID)

	--
	--
	--

	local y, index = 8 + HalfSize, 1

	for row = 1, Rows do
		local x = 8 + HalfSize

		for col = 1, Columns do
			local value = level[index]
			local factory = Factories[value]
			local add_floor = true

			if factory then
				local ccol, crow = col * 2 - 1, row * 2 - 1
				local object, id = factory(groups, x, y)

				add_floor = object.parent ~= groups.scenery -- if we'll never see it, don't add a floor

				Assign(object, crow, ccol)
				Fill(object, id)
			end

			if add_floor then
				local floor = display.newRect(groups.scenery, x, y, TileSize, TileSize)

				floor:setFillColor(.7)
			end

			index, x = index + 1, x + TileSize
		end

		y = y + TileSize
	end

	LastTime = system.getTimer()
end

--------------------
--
-- UPDATE
--
--------------------

local function IsOn (object)
	return object and Player.crow == object.crow and Player.ccol == object.ccol
end

local Key

local Timeout = 100

local function UpdateMoveList (t)
	for i = 1, #MoveList do
		local object, component, v0, dv = unpack(MoveList[i])

		object[component] = v0 + t * dv
	end
end

local function WipeMoveList ()
	for i = #MoveList, 1, -1 do
		MoveList[i] = nil
	end
end

Runtime:addEventListener("enterFrame", function(event)
	local now, elapsed = event.time
	local dt, t = now - LastTime, 1

	if dt >= Timeout then
		dt, elapsed = dt % Timeout, true
		LastTime = now - dt
	else
		t = dt / Timeout
	end

	-- This is like a stripped-down transition. We want fine control over what cells our
	-- objects cover, so we update their positions manually. Every so often these movements
	-- (including the player's, from key input) are scheduled all at once.
	UpdateMoveList(t)

	if elapsed then
		WipeMoveList()

		for _, gorgon in ipairs(Gorgons) do -- "normal" update (see below)
			if Player.killed then
				break
			else
				UpdateGorgon(gorgon)
			end
		end

		if Player.defer then -- killed while moving?
			if type(Player.defer) == "table" then
				Stab(unpack(Player.defer))
			end

			SpinAndReload()
		end
	end

	local can_move, dx, dy

	if Key and Key ~= "s" and elapsed and not PlayerBusy() then
		-- n.b. assumes walls all around, so no edge checks yet...
		local v1, v2, dr, dc = GetAdjacentValues(Player, Key)
		local id1, index1 = Classify(v1)
		local id2, index2 = Classify(v2)

		if id2 == WallID then
			id1 = WallID
		elseif id2 == BlocksID then
			if id1 == BlocksID and index1 ~= index2 then
				id1 = WallID -- we can push one block, but not two
			end
		end

		if id1 ~= WallID then
			local bindex

			if id1 == BlocksID then -- trying to push a block?
				bindex = index1
			elseif id2 == BlocksID then
				bindex = index2
			end

			can_move = true

			if bindex then
				local v1, v2 = GetAdjacentValues(Blocks[bindex], Key)

				can_move = v1 == None and v2 == None -- nothing in the way?
			end

			if can_move and not Player.killed then
				Fill(Player, nil, PlayerID) -- guard against clearing heart and chest / jewel

				dx, dy = dc * HalfSize, dr * HalfSize

				local h1, h2, jewel, door = id1 == HeartsID, id2 == HeartsID, id1 == JewelID or id2 == JewelID, id1 == DoorID or id2 == DoorID

				if bindex then
					local block = Blocks[bindex]

					Fill(block, nil)
					Update(block, dr, dc)
					Fill(block, BlocksID + bindex)
					AddToMoveList(block, dx, dy)
				end

				Update(Player, dr, dc)

				if id1 == HarmfulID or id2 == HarmfulID then
					Player.harmed = true
				elseif h1 and IsOn(Hearts[index1]) then
					CollectHeart(index1)
				elseif h2 and IsOn(Hearts[index2]) then
					CollectHeart(index2)
				elseif jewel and IsOn(Chest) then
					Runtime:dispatchEvent{ name = "got_jewel" }
				elseif door and IsOn(Door) then
					LevelID = LevelID < #Levels and LevelID + 1 or 1

					transition.to(Player, {
						xScale = 3, yScale = 3, time = 1500,

						onComplete = function()
							LoadLevel()
						end
					})

					Player.progressing = true
				end
			end
		end
	end

	if can_move and not PlayerBusy() then
		Fill(Player, PlayerID, PlayerID) -- guard against overwriting heart or chest / jewel
		AddToMoveList(Player, dx, dy)

		if Player.harmed then -- ran into enemy?
			KillPlayer()

			Player.defer = true
		end
	end

	-- The player will often be half a cell into the gorgon's line of sight, safe from harm.
	-- If the latter moves, however, player might suddenly be in full view.
	-- There is a further wrinkle here if the player also moves. If the gorgon could see the
	-- player's right half, for instance, then the gorgon goes left and the player right, it
	-- will suddenly be seeing the left half of the player. But obviously between those two
	-- states, the player should have been fully visible, obstacles aside.
	-- To account for this, another sight check is performed if the player has moved. If the
	-- player still remains unseen, the moving gorgons' next moves are scheduled.
	if elapsed and not Player.killed then
		if can_move then
			for _, gorgon in ipairs(Gorgons) do
				if gorgon.Step then
					UpdateGorgon(gorgon, true)

					if Player.killed then
						return -- or break, if more stuff handled below
					end
				end
			end
		end

		-- Player still unseen, so advance.
		for _, gorgon in ipairs(Gorgons) do
			if gorgon.Step then
				gorgon:Step()
			end
		end
	end
end)

--------------------
--
-- MOVEMENT CONTROLS
--
--------------------

local Rotation = { left = -90, up = 0, right = 90, down = 180 }

Runtime:addEventListener("key", function(event)
	local key = event.keyName

	if event.phase == "down" then
		if key == "left" or key == "up"  or key == "right" or key == "down" then
			Key = key

			if not PlayerBusy() then -- key itself already ignored, cf. enterFrame
				Player.rotation = Rotation[key]
			end
		elseif key == "s" then
			Key = "s"
		end
	elseif event.phase == "up" then
		if key == Key then
			Key = nil

			if key == "s" then
				KillPlayer()
			end
		end
	end
end)

--------------------
--
-- SIDEBAR
--
--------------------

do -- one-time load
	Runtime:dispatchEvent{ name = "init" }

	SetRanges(1) -- provisional values

	local group = display.newGroup()
	local groups = { level = group, scenery = group }

	local function RelativeText (object, str, anchor)
		local text = display.newText(str, 0, object.y, native.systemFontBold, 15)
		local bounds = object.contentBounds

		text.anchorX = anchor

		if anchor == 0 then
			text.x = bounds.xMax + 15
		else
			text.x = bounds.xMin - 15
		end
	end

	local player = Factories.P(groups, 575, 50)

	RelativeText(player, "Use the cursor keys to move the player", 0)

	local wall = Factories.X(groups, 900, 100)

	RelativeText(wall, "Walls will block your movement", 1)

	local chest = Factories.J(groups, 575, 150)

	RelativeText(chest, "Each level has a chest", 0)

	local heart = Factories.H(groups, 900, 200)

	RelativeText(heart, "Gather all the hearts...", 1)

	local jewel = MakeJewelObject(groups.level, 575, 250)

	RelativeText(jewel, "...to open the chest and reveal the jewel", 0)

	local door = Factories.D(groups, 900, 300)

	RelativeText(door, "Claim the jewel to open the exit", 1)

	local gorgon = Factories.G(groups, 575, 350)

	RelativeText(gorgon, "Don't let Mr. Gorgon and his goons see you!", 0)

	local block = Factories.B(groups, 900, 400)

	RelativeText(block, "Push blocks to hinder foes or clear the way", 1)

	local dummy = display.newCircle(groups.level, 575 - 40, 450, 5)

	dummy.isVisible = false

	RelativeText(dummy, "Press the 's' key if you find yourself stuck", 0)
end

--------------------
--
-- SYSTEM EVENT
--
--------------------

Runtime:addEventListener("system", function(event)
	if event.type == "applicationSuspend" then
		timer.pauseAll()
		transition.pauseAll()
	elseif event.type == "applicationResume" then
		timer.resumeAll()
		transition.resumeAll()
	end
end)

--------------------
--
-- INITIALIZE
--
--------------------

LevelID = 1

LoadLevel()