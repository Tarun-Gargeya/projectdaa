local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = workspace:WaitForChild("PlayerCube")
local plr = game:GetService("Players").LocalPlayer
local hum = plr.Character:WaitForChild("Humanoid")
hum.WalkSpeed = 0

-- Configuration
local cellSize = 6
local mirrorOffset = -40
local teleportCooldown = 1 -- seconds
local teleportOffset = Vector3.new(0, 0, 1.5) -- Small position nudge

-- State management
local debounce = false
local lastTeleportTime = 0
local currentMaze = "top" -- 'top' or 'bottom'

-- Shared block registry
local sharedBlockGrid = {}
for x = 1, 20 do  -- Adjust to your grid size
	sharedBlockGrid[x] = {}
	for y = 1, 20 do
		sharedBlockGrid[x][y] = false
	end
end

-- Register shared blocks from workspace
local function registerSharedBlocks()
	for _, block in ipairs(workspace.Maze:GetChildren()) do
		if block.Name == "SharedBlocks" then
			local primaryPart = block:FindFirstChildWhichIsA("BasePart") or block:GetChildren()[1]
			if primaryPart then
				local gridX = math.round(primaryPart.Position.X / cellSize)
				local gridY = math.round(primaryPart.Position.Z / cellSize)

				if gridX >= 1 and gridX <= 20 and gridY >= 1 and gridY <= 20 then
					sharedBlockGrid[gridX][gridY] = true
				end
			end
		end
	end
end

registerSharedBlocks() -- Initial registration

-- Check if player is on shared block
local mirrorOffset = -100 -- Distance to move the mirrored maze below

local function checkSharedBlockPosition()
	if time() - lastTeleportTime < teleportCooldown then return end

	local playerX = math.round(player.Position.X / cellSize)
	local playerY = math.round(player.Position.Z / cellSize)

	-- Validate grid bounds
	if playerX < 1 or playerX > 20 or playerY < 1 or playerY > 20 then
		return
	end

	if sharedBlockGrid[playerX][playerY] then
		lastTeleportTime = time()

		-- Calculate new Y position based on current maze
		local newY
		if currentMaze == "top" then
			-- Moving to bottom maze (mirror)
			newY = mirrorOffset + cellSize/2  -- Position at bottom maze height
		else
			-- Moving to top maze (normal)
			newY = 10 + cellSize/2  -- Position at top maze height
		end

		-- Calculate offset direction (away from block center)
		local offsetDirection
		if math.abs(player.Position.X % cellSize - cellSize/2) > math.abs(player.Position.Z % cellSize - cellSize/2) then
			-- Push more in Z direction
			offsetDirection = Vector3.new(
				0,
				0,
				teleportOffset.Z * (player.Position.Z % cellSize > cellSize/2 and 1 or -1)
			)
		else
			-- Push more in X direction
			offsetDirection = Vector3.new(
				teleportOffset.X * (player.Position.X % cellSize > cellSize/2 and 1 or -1),
				0,
				0
			)
		end

		-- Apply teleport with calculated offset
		player.Position = Vector3.new(
			player.Position.X + offsetDirection.X,
			newY,
			player.Position.Z + offsetDirection.Z
		)

		-- Toggle current maze
		currentMaze = currentMaze == "top" and "bottom" or "top"

		print("Teleported to", currentMaze, "maze at Y:", newY)
	end
end

-- Movement and collision detection
local function canMoveTo(direction)
	local origin = player.Position
	local targetPos = origin + direction * cellSize

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	local result = workspace:Raycast(origin, direction * cellSize, raycastParams)
	return not result or (result.Instance and result.Instance.Name == "SharedBlocks")
end

local function movePlayer(dirX, dirY)
	if debounce then return end
	debounce = true

	local direction = Vector3.new(dirX, 0, dirY)
	if canMoveTo(direction) then
		player.Position = player.Position + direction * cellSize
		checkSharedBlockPosition() -- Check after movement
	end

	task.wait(0.2)
	debounce = false
end

-- Input handling
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then movePlayer(0, -1) end
	if input.KeyCode == Enum.KeyCode.S then movePlayer(0, 1) end
	if input.KeyCode == Enum.KeyCode.A then movePlayer(-1, 0) end
	if input.KeyCode == Enum.KeyCode.D then movePlayer(1, 0) end
end)

-- Optional: Periodic position validation
RunService.Heartbeat:Connect(function()
	checkSharedBlockPosition()
end)