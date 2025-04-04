local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Player cube reference
local playerCube = workspace:WaitForChild("PlayerCube")

-- Camera settings
local isTopDown = true
local cameraHeight = 50
local cameraDistance = 30
local transitionSpeed = 5
local rotationSpeed = 0.5  -- Speed for manual rotation
local currentRotation = 0  -- Current camera rotation around player
local isRotating = false  -- Flag for rotation mode

-- Camera modes
local cameraModes = {
	TopDown = {
		offset = Vector3.new(0, cameraHeight, 0),
		angle = CFrame.Angles(-math.pi/2, 0, 0)
	},
	Angled = {
		offset = Vector3.new(0, cameraHeight/2, -cameraDistance),
		angle = CFrame.Angles(-math.pi/4, 0, 0)
	},
	FirstPerson = {
		offset = Vector3.new(0, 3, 0),
		angle = CFrame.Angles(0, math.pi, 0)
	}
}

local currentMode = "TopDown"
local targetOffset = cameraModes.TopDown.offset
local currentOffset = targetOffset
local targetAngle = cameraModes.TopDown.angle
local currentAngle = targetAngle

-- Smooth camera transition function
local function updateCamera(deltaTime)
	if not playerCube or not playerCube.Parent then
		playerCube = workspace:FindFirstChild("PlayerCube")
		if not playerCube then return end
	end

	-- Smooth interpolation
	currentOffset = currentOffset:Lerp(targetOffset, deltaTime * transitionSpeed)
	currentAngle = currentAngle:Lerp(targetAngle, deltaTime * transitionSpeed)

	-- Calculate position based on current rotation
	local rotatedOffset = CFrame.Angles(0, currentRotation, 0) * currentOffset

	if currentMode == "FirstPerson" then
		-- First-person view (from cube's perspective)
		camera.CFrame = CFrame.new(playerCube.Position + rotatedOffset) * 
			currentAngle * 
			CFrame.Angles(0, math.pi, 0)  -- Face forward
	else
		-- Other views
		camera.CFrame = CFrame.new(playerCube.Position + rotatedOffset) * 
			currentAngle * 
			CFrame.Angles(0, currentRotation, 0)
	end
end

-- Toggle between camera modes
local function toggleCameraMode()
	if currentMode == "TopDown" then
		currentMode = "Angled"
	elseif currentMode == "Angled" then
		currentMode = "FirstPerson"
	else
		currentMode = "TopDown"
	end

	targetOffset = cameraModes[currentMode].offset
	targetAngle = cameraModes[currentMode].angle

	-- Small visual effect when changing modes
	local tween = TweenService:Create(camera, TweenInfo.new(0.3), {
		FieldOfView = currentMode == "FirstPerson" and 70 or 60
	})
	tween:Play()
end

-- Rotate camera around player
local function rotateCamera(direction)
	currentRotation = currentRotation + (direction * rotationSpeed)
end

-- Input handling
UserInputService.InputBegan:Connect(function(input)
	-- Toggle camera mode with F key
	if input.KeyCode == Enum.KeyCode.F then
		toggleCameraMode()
	end

	-- Hold right mouse button to rotate
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRotating = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		isRotating = false
	end
end)

-- Mouse movement for rotation
UserInputService.InputChanged:Connect(function(input)
	if isRotating and input.UserInputType == Enum.UserInputType.MouseMovement then
		rotateCamera(input.Delta.X * 0.01)
	end
end)

-- Zoom functionality
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if currentMode ~= "FirstPerson" then
			local zoomFactor = 1 + (input.Position.Z * 0.1)
			cameraHeight = math.clamp(cameraHeight * zoomFactor, 20, 100)
			cameraDistance = math.clamp(cameraDistance * zoomFactor, 15, 50)

			-- Update current mode settings
			cameraModes.TopDown.offset = Vector3.new(0, cameraHeight, 0)
			cameraModes.Angled.offset = Vector3.new(0, cameraHeight/2, -cameraDistance)

			if currentMode == "TopDown" then
				targetOffset = cameraModes.TopDown.offset
			elseif currentMode == "Angled" then
				targetOffset = cameraModes.Angled.offset
			end
		end
	end
end)

-- Smooth camera updates
RunService.Heartbeat:Connect(function(deltaTime)
	updateCamera(deltaTime)
end)

-- Initialize camera
camera.CameraType = Enum.CameraType.Scriptable
updateCamera(1)