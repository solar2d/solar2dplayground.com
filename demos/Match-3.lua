-- Sample code by Kan.

local rnd = math.random
local abs = math.abs

local board = display.newGroup() -- Group of board game
board.anchorChildren = true
board.x, board.y = 320, 130 -- Center screen

local directions = {
	{row = -1, col = 0}, -- up
	{row = 1, col = 0}, -- down
	{row = 0, col = 1}, -- right
	{row = 0, col = -1}, --left
}

local colors = {
	{.5, .7, .3},
	{1, .5, 0},
	{.8, .8, 0},
	{0, .8, 0},
	{.2, .6, .5}
}

local pieces = {}

local margin = 5

local cols = 8
local rows = 8
local radius = 25
local x = 0
local y = 0

-- Create board
for r = 1, rows do
	for c = 1, cols do
		local _index = #pieces + 1 -- New piece
		pieces[_index] = display.newCircle(board, x, y, radius)
		local piece = pieces[_index]
		x = x + piece.contentWidth + margin
		piece.col = c
		piece.row = r
		piece.value = rnd(1, #colors) -- Random color
		piece:setFillColor(unpack(colors[piece.value]))

		function piece:touch( event )
			if event.phase == "began" then
				local oldTarget

				for i = 1, #pieces do
					if pieces[i].isTarget then
						oldTarget = pieces[i]
					end
				end

				if oldTarget then
					local isNeighbor = isNeighbor(oldTarget, self)
					if isNeighbor then
						transition.cancel(oldTarget)
						oldTarget.alpha = 1
						oldTarget.xScale = 1
						oldTarget.yScale = 1
						oldTarget.isTarget = false

						-- swap
						oldTarget.col, self.col = self.col, oldTarget.col
						oldTarget.row, self.row = self.row, oldTarget.row

						transition.to(oldTarget, {time = 100, x = self.x, y = self.y, onComplete = function()

						end})

						transition.to(self, {time = 100, x = oldTarget.x, y = oldTarget.y, onComplete = function()
							local isMatch = false

							for i = 1, #pieces do
								if matched(pieces[i]) then
									isMatch = true
								end
							end
							if not isMatch then
								-- swap
								oldTarget.col, self.col = self.col, oldTarget.col
								oldTarget.row, self.row = self.row, oldTarget.row
								transition.to(oldTarget, {delay = 100, time = 100, x = self.x, y = self.y, onComplete = function()

								end})
								transition.to(self, {delay = 100, time = 100, x = oldTarget.x, y = oldTarget.y, onComplete = function()

								end})
							else
								cleanMatched()
							end

						end})
					else
						transition.cancel(oldTarget)
						oldTarget.alpha = 1
						oldTarget.xScale = 1
						oldTarget.yScale = 1
						oldTarget.isTarget = false

						self.xScale = 1.1
						self.yScale = 1.1
						transition.blink(self, {time = 1000})
						self.isTarget = true
					end
				else
					self.xScale = 1.1
					self.yScale = 1.1
					transition.blink(self, {time = 1000})
					self.isTarget = true

				end
			end
			return true
		end
		piece:addEventListener("touch")
	end
	x = 0 -- move to left
	y = y + radius*2 + margin
end

function isNeighbor(cur, next)
	local offsetCol = abs(cur.col - next.col)
	local offsetRow = abs(cur.row - next.row)

	if (offsetCol == 1 and offsetRow == 0) or (offsetCol == 0 and offsetRow == 1) then
		return true
	end

	return false
end

function matched(item)
	local isMatched = false

	--- Check for direction
	for i = 1, #directions do
		local dir = directions[i]
		local matched = 0

		local tempList = {}
		local currentPiece = item
		tempList[1] = currentPiece

		while true do
			local row = currentPiece.row + dir.row
			local col = currentPiece.col + dir.col

			if row >= rows+1 or row <= 0 or col >= cols+1 or col <= 0 then
				break
			end

			local nextPiece = findPiece(col, row)

			if not nextPiece then print("not find position", row, col) break end
			if currentPiece.value == nextPiece.value then
				matched = matched + 1
				tempList[#tempList+1] = nextPiece
				currentPiece = nextPiece
			else
				tempList = nil
				currentPiece = nil
				break
			end

			if matched > 1 then
				isMatched = true
				for i = 1, #tempList do
					tempList[i].isMatched = true
				end
			end
		end
	end
	return isMatched
end

function cleanMatched()
	for i = 1, #pieces do
		local piece = pieces[i]
		if piece.isMatched then
			piece.isMatched = false
			piece.isRepulish = true
			transition.to(piece, {time = 50, xScale = 0.01, yScale = 0.01, onComplete = function()
				piece.value = rnd(1,#colors)
				piece:setFillColor(unpack(colors[piece.value]))
			end})
		end
	end

	for i = 1, #pieces do
		local piece = pieces[i]
		if piece.isRepulish then
			piece.isRepulish = false
			transition.to(piece, {delay = 200, time = 300, xScale = 1, yScale = 1, onComplete = function()
			end})
		end
	end

	timer.performWithDelay(501, function()
		local isMatched
		for i = 1, #pieces do
			if matched(pieces[i]) then
				isMatched = true
			end
		end
		if isMatched then
			cleanMatched()
		end
	end, 1)
end

function findPiece(col, row)
	if pieces == nil then return false end

	for i = 1, #pieces do
		local piece = pieces[i]
		if piece.col == col and piece.row == row then
			return piece
		end
	end

	return false
end

function verify(p)
	local isMatched = false

	--- Check for direction
	for i = 1, #directions do
		local dir = directions[i]
		local matched = 0

		local currentPiece = p

		while true do

			local row = currentPiece.row + dir.row
			local col = currentPiece.col + dir.col

			if row >= rows+1 or row <= 0 or col >= cols+1 or col <= 0 then
				break
			end

			local nextPiece = findPiece(col, row)

			if not nextPiece then print("not find position", row, col) break end
			if currentPiece.value == nextPiece.value then
				matched = matched + 1
				currentPiece = nextPiece
			else
				break
			end

			if matched > 1 then
				isMatched = true
				return isMatched
			end
		end
	end

	-- Check in middle
	for i = 1, 2 do
		local dirs = {directions[i], directions[i+2]}
		local matched = 0

		local currentPiece = p

		local row1 = currentPiece.row + dirs[1].row
		local col1 = currentPiece.col + dirs[1].col

		local row2 = currentPiece.row + dirs[2].row
		local col2 = currentPiece.col + dirs[2].col

		if row1 >= rows+1 or row1 <= 0 or col1 >= cols+1 or col1 <= 0 then
			break
		end

		if row2 >= rows+1 or row2 <= 0 or col2 >= cols+1 or col2 <= 0 then
			break
		end

		local twoSidesPieces = {
			findPiece(col1, row1),
			findPiece(col2, row2)
		}

		for i, _piece in ipairs(twoSidesPieces) do

			if not _piece then print("not find position") break end
			if currentPiece.value == _piece.value then
				matched = matched + 1
			end
		end

		if matched > 1 then
			isMatched = true
			return isMatched
		end
	end

	-- Check for 2x2
	for i = 1, 4 do
		local matched = 0
		local next = i + 1
		if next >= 5 then
			next = next - 4
		end
		local r1 = p.row + directions[i].row
		local c1 = p.col + directions[i].col
		local r2 = p.row + directions[next].row
		local c2 = p.col + directions[next].col
		local r3 = p.row + (directions[i].row + directions[next].row)
		local c3 = p.col + (directions[i].col + directions[next].col)

		if r1 >= rows+1 or r1 <= 0 or c1 >= cols+1 or c1 <= 0 then
			break
		end

		if r2 >= rows+1 or r2 <= 0 or c2 >= cols+1 or c2 <= 0 then
			break
		end

		if r3 >= rows+1 or r3 <= 0 or c3 >= cols+1 or c3 <= 0 then
			break
		end
		local neighborsPieces = {
			findPiece(c1, r1),
			findPiece(c2, r2),
			findPiece(c3, r3)
		}

		for i, _piece in ipairs(neighborsPieces) do
			if not _piece then print("not find position") break end
			if p.value == _piece.value then
				matched = matched + 1
			end
		end

		if matched > 2 then
			isMatched = true
			return isMatched
		end
	end
end

-- Clean match piece
local idx = 0

while idx < #pieces do
	idx = idx + 1

	if not pieces[idx] then print("Item is not exist.") break end

	local isMatched = verify(pieces[idx])
	if isMatched then
		while true do
			local newValue = math.random(1, #colors)
			if pieces[idx].value ~= newValue then
				pieces[idx]:setFillColor(unpack(colors[newValue]))
				pieces[idx].value = newValue
				idx = 0
				break
			end
		end
	end
end