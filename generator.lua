-- Maze Configuration
local gridSizeX = 20 -- Width of the maze
local gridSizeY = 20 -- Height of the maze
local chunkSize = 5  -- Defines how large a chunk is
local seed = 2   -- Random seed for consistent generation

game.Workspace.Baseplate:Destroy()
local cellSize = 6  -- Increased size to remove gaps
local wallThickness = 1  -- Extra thickness for seamless walls
local perimeterSize = 2  -- Adds a perimeter around the maze
local mirrorOffset = -100 -- Distance to move the mirrored maze below

local minEndDistance = math.floor((gridSizeX + gridSizeY) / 3) -- Ensures the end is not too close
local startX, startY, endX, endY

-- Randomize start and end points in different mazes
local function randomizeStartAndEnd()
	if math.random() > 0.5 then
		startX, startY = math.random(1, gridSizeX), math.random(1, gridSizeY // 2) -- Start in top maze
		endX, endY = math.random(1, gridSizeX), math.random(gridSizeY // 2 + 1, gridSizeY) -- End in bottom maze
	else
		startX, startY = math.random(1, gridSizeX), math.random(gridSizeY // 2 + 1, gridSizeY) -- Start in bottom maze
		endX, endY = math.random(1, gridSizeX), math.random(1, gridSizeY // 2) -- End in top maze
	end
end
randomizeStartAndEnd()

local player = Instance.new("Part")
player.Size = Vector3.new(cellSize, cellSize, cellSize) -- Same size as one grid cell
player.Position = Vector3.new(startX * cellSize, 10 + cellSize / 2, startY * cellSize) -- Place in top maze
player.Anchored = true
player.Color = Color3.fromRGB(0, 255, 255) -- Cyan cube
player.Parent = game.Workspace
player.Name = "PlayerCube"

local mazeParent = Instance.new("Folder")
mazeParent.Name = "Maze"
mazeParent.Parent = game.Workspace

math.randomseed(seed)

-- Get a random block (Model) from the folder
local function getRandomBlock(folderName)
	local folder = game.Workspace:FindFirstChild(folderName)
	if folder and #folder:GetChildren() > 0 then
		local model = folder:GetChildren()[math.random(1, #folder:GetChildren())]:Clone()
		if model.PrimaryPart then
			return model
		end
	end
	return nil
end

-- Directions for DFS (Right, Left, Down, Up)
local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

-- Grid setup
local grid = {}
for x = 1, gridSizeX do
	grid[x] = {}
	for y = 1, gridSizeY do
		grid[x][y] = false -- False means unvisited
	end
end

-- DFS Maze Generation
local function generateMaze(x, y)
	grid[x][y] = true

	-- Shuffle directions to ensure randomness
	for i = #directions, 2, -1 do
		local j = math.random(i)
		directions[i], directions[j] = directions[j], directions[i]
	end

	for _, dir in pairs(directions) do
		local nx, ny = x + dir[1] * 2, y + dir[2] * 2
		if nx > 0 and ny > 0 and nx <= gridSizeX and ny <= gridSizeY and not grid[nx][ny] then
			-- Remove wall between
			grid[x + dir[1]][y + dir[2]] = true
			generateMaze(nx, ny)
		end
	end
end

-- Start DFS at the designated starting point
generateMaze(startX, startY)

local sharedBlockCount = 0  -- Keep track of how many shared blocks have been placed
local maxSharedBlocks = 2  -- We only want a maximum of 2
local sharedBlockPositions = {}  -- Store valid positions

local function placeSharedBlock(gridX, gridY)
	if sharedBlockCount >= maxSharedBlocks then return end  -- Stop if we already placed 2

	-- 5% probability to place a shared block
	if math.random() < 0.05 then  
		local model = getRandomBlock("SharedBlocks")  
		if not model then return end

		-- Convert grid position to world coordinates
		local worldX = gridX * cellSize
		local worldZ = gridY * cellSize

		-- Remove any existing floor tile at this position (only in the correct maze)
		for _, child in pairs(mazeParent:GetChildren()) do
			if child:IsA("Model") or child:IsA("Part") then
				local pos = child:GetPrimaryPartCFrame().Position
				local expectedY = (gridY <= gridSizeY // 2) and 0 or mirrorOffset - 5  -- Expected Y for the correct maze

				-- Only remove the tile that matches the correct maze height
				if math.abs(pos.X - worldX) < 1 and math.abs(pos.Z - worldZ) < 1 and math.abs(pos.Y - expectedY) < 1 then
					child:Destroy() -- Remove the floor tile only in the correct maze
				end
			end
		end

		-- Adjust for alignment
		local size = model:GetExtentsSize()
		local bottomOffset = size.Y / 2

		-- Place shared block in both mazes
		local topShared = model:Clone()
		topShared:SetPrimaryPartCFrame(CFrame.new(worldX, 0, worldZ))
		topShared.Parent = mazeParent

		local bottomShared = model:Clone()
		bottomShared:SetPrimaryPartCFrame(CFrame.new(worldX, mirrorOffset - 5, worldZ))
		bottomShared.Parent = mazeParent

		-- Store this position for pathfinding validation
		table.insert(sharedBlockPositions, {x = gridX, y = gridY})

		sharedBlockCount = sharedBlockCount + 1
	end
end

local function isMazeSolvable()
	local queue = {{x = startX, y = startY}}  -- the palyers starting point
	local visited = {}  -- visisted nodes

	-- Convert grid to vis map
	for x = 1, gridSizeX do
		visited[x] = {}
		for y = 1, gridSizeY do
			visited[x][y] = false
		end
	end

	-- mark shared blocks as passable
	for _, block in pairs(sharedBlockPositions) do
		visited[block.x][block.y] = true
	end

	-- BFS loop
	while #queue > 0 do
		local node = table.remove(queue, 1)
		local x, y = node.x, node.y

		-- If we reach the end, the maze is solvable
		if x == endX and y == endY then
			return true
		end

		-- Explore neighbors using the direction vectors
		local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		for _, dir in pairs(directions) do
			local nx, ny = x + dir[1], y + dir[2]

			-- If the next position is valid and hasn't been visited, add it to the queue
			if nx > 0 and ny > 0 and nx <= gridSizeX and ny <= gridSizeY and not visited[nx][ny] and grid[nx][ny] then
				visited[nx][ny] = true
				table.insert(queue, {x = nx, y = ny})
			end
		end
	end

	return false  -- No valid path found
end

local function placePoint(folderName, gridX, gridY, targetY)
	local worldX = gridX * cellSize
	local worldZ = gridY * cellSize

	for _, child in pairs(mazeParent:GetChildren()) do
		if child:IsA("Model") or child:IsA("Part") then
			local pos = child:GetPrimaryPartCFrame().Position
			local expectedY = (gridY <= gridSizeY // 2) and 0 or mirrorOffset - 5  -- Expected Y for the correct maze

			-- Only remove the tile that matches the correct maze height
			if math.abs(pos.X - worldX) < 1 and math.abs(pos.Z - worldZ) < 1 and math.abs(pos.Y - expectedY) < 1 then
				child:Destroy() -- Remove the floor tile only in the correct maze
			end
		end
	end
	local model = getRandomBlock(folderName)  -- Fetch model from folder
	if not model then return end

	-- Position correctly in the grid
	local worldX = gridX * cellSize
	local worldZ = gridY * cellSize

	-- Adjust Y position so it aligns with the floor
	local size = model:GetExtentsSize()
	local bottomOffset = size.Y / 2  -- Ensure bottom aligns with targetY

	model:SetPrimaryPartCFrame(CFrame.new(worldX, targetY + bottomOffset, worldZ))
	model.Parent = mazeParent
end

-- Create shared perimeter walls for both mazes
local function createPerimeter()
	local perimeterParent = Instance.new("Folder")
	perimeterParent.Name = "Perimeter"
	perimeterParent.Parent = mazeParent

	for x = 0, gridSizeX + 1 do
		for y = 0, gridSizeY + 1 do
			if x == 0 or y == 0 or x == gridSizeX + 1 or y == gridSizeY + 1 then
				local topWall = getRandomBlock("WallBlocksTop")
				local bottomWall = getRandomBlock("WallBlocksBottom")
				if topWall then
					topWall:SetPrimaryPartCFrame(CFrame.new(x * cellSize, 10, y * cellSize))
					topWall.Parent = perimeterParent
				end
				if bottomWall then
					bottomWall:SetPrimaryPartCFrame(CFrame.new(x * cellSize, mirrorOffset, y * cellSize))
					bottomWall.Parent = perimeterParent
				end
			end
		end
	end
end
createPerimeter()

-- Generate visual representation of the maze with different floors
local function createMaze()
	-- First pass: Create all floor tiles
	for x = 1, gridSizeX do
		for y = 1, gridSizeY do
			-- Add floor blocks
			local topFloor = getRandomBlock("TopMirrorFloor")
			local bottomFloor = getRandomBlock("BottomMirrorFloor")
			if topFloor then
				topFloor:SetPrimaryPartCFrame(CFrame.new(x * cellSize, 0, y * cellSize))
				topFloor.Parent = mazeParent
				topFloor.Name = "Floor"
			end
			if bottomFloor then
				bottomFloor:SetPrimaryPartCFrame(CFrame.new(x * cellSize, mirrorOffset - 5, y * cellSize))
				bottomFloor.Parent = mazeParent
				bottomFloor.Name = "Floor"
			end
		end
	end

	-- Second pass: Create walls with proper mirroring
	for x = 1, gridSizeX do
		for y = 1, gridSizeY do
			-- For the top maze (original)
			if not grid[x][y] then
				local topWall = getRandomBlock("WallBlocksTop")
				if topWall then
					topWall:SetPrimaryPartCFrame(CFrame.new(x * cellSize, 10, y * cellSize))
					topWall.Parent = mazeParent
					topWall.Name = "Wallblock"
				end
			end

			-- For the bottom maze (mirrored - walls and paths should be inverted)
			if grid[x][y] then
				local bottomWall = getRandomBlock("WallBlocksBottom")
				if bottomWall then
					bottomWall:SetPrimaryPartCFrame(CFrame.new(x * cellSize, mirrorOffset, y * cellSize))
					bottomWall.Parent = mazeParent
					bottomWall.Name = "Wallblock"
				end
			end

			placeSharedBlock(x, y)
		end
	end

	placePoint("StartPoint", startX, startY, (startY <= gridSizeY // 2) and -6.7 or mirrorOffset - 12)
	placePoint("EndPoint", endX, endY, (endY > gridSizeY // 2) and mirrorOffset - 12 or -6.7)

	if not isMazeSolvable() then
		print("No valid path found! Placing an emergency shared block...")
		-- Find an empty space in the center to place a shared block
		local emergencyX = math.floor(gridSizeX / 2)
		local emergencyY = math.floor(gridSizeY / 2)
		placeSharedBlock(emergencyX, emergencyY)
	end
end
createMaze()