local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("SpeedometerFrame")
local speedLabel = frame:WaitForChild("SpeedValue")
local transFrame = frame:WaitForChild("TransModes")
local rLabel = transFrame:WaitForChild("ModeR")
local nLabel = transFrame:WaitForChild("ModeN")
local dLabel = transFrame:WaitForChild("ModeD")
local barBg = frame:WaitForChild("BarBackground")
local barFill = barBg:WaitForChild("BarFill")

local dashIcons = frame:WaitForChild("DashIcons")
local leftArrow = dashIcons:WaitForChild("LeftArrow")
local rightArrow = dashIcons:WaitForChild("RightArrow")
local headIcon = dashIcons:WaitForChild("HeadlightIcon")
local tickSound = gui:FindFirstChild("CabinRelayTick")

local currentSeat = nil
local currentCar = nil
local maxSpeed = 140

local dimColor = Color3.fromRGB(50, 55, 65)
local activeColor = Color3.fromRGB(250, 250, 255)
local greenColor = Color3.fromRGB(0, 255, 130)
local blueLightColor = Color3.fromRGB(0, 190, 255)

local blinkTimer = 0
local blinkState = false

local function setGear(mode)
    rLabel.TextColor3 = (mode == "R") and activeColor or dimColor
    nLabel.TextColor3 = (mode == "N") and activeColor or dimColor
    dLabel.TextColor3 = (mode == "D") and activeColor or dimColor
end

local function onSeated(active, seat)
    if active and seat and seat:IsA("VehicleSeat") then
        currentSeat = seat
        currentCar = seat.Parent
        maxSpeed = (currentCar and currentCar:GetAttribute("MaxSpeed")) or 140

        frame.Visible = true
        frame.Position = UDim2.new(0.5, 0, 1, -12)
        frame.BackgroundTransparency = 1
        speedLabel.TextTransparency = 1
        
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 1, -25),
            BackgroundTransparency = 0.38
        }):Play()
        TweenService:Create(speedLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
    else
        currentSeat = nil
        currentCar = nil
        leftArrow.TextColor3 = dimColor
        rightArrow.TextColor3 = dimColor
        headIcon.TextColor3 = dimColor
        
        TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 1, -12),
            BackgroundTransparency = 1
        }):Play()
        TweenService:Create(speedLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        task.delay(0.2, function()
            if not currentSeat then
                frame.Visible = false
            end
        end)
    end
end

local function hookCharacter(char)
    local humanoid = char:WaitForChild("Humanoid", 10)
    if humanoid then
        humanoid.Seated:Connect(function(active, seat)
            onSeated(active, seat)
        end)
        if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
            onSeated(true, humanoid.SeatPart)
        end
    end
end

if player.Character then
    hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

RunService.RenderStepped:Connect(function(dt)
    if not currentSeat or not currentSeat.Parent then return end

    -- Read velocity
    local velocity = currentSeat.AssemblyLinearVelocity
    if currentCar and currentCar.PrimaryPart then
        velocity = currentCar.PrimaryPart.AssemblyLinearVelocity
    end
    local speedStudsPerSec = velocity.Magnitude
    local kmh = math.floor(speedStudsPerSec * 1.6)

    speedLabel.Text = tostring(kmh)
    local ratio = math.clamp(kmh / maxSpeed, 0, 1)
    barFill.Size = UDim2.new(ratio, 0, 1, 0)

    -- Transmission indicator
    if currentSeat.Throttle > 0 then
        setGear("D")
    elseif currentSeat.Throttle < 0 then
        setGear("R")
    else
        if kmh > 3 then
            setGear("D")
        else
            setGear("N")
        end
    end

    -- Dashboard turn signals & headlights from Car attributes
    if currentCar and currentCar:GetAttribute("VelocityCar") then
        local leftSig = currentCar:GetAttribute("LeftIndicator")
        local rightSig = currentCar:GetAttribute("RightIndicator")
        local hazard = currentCar:GetAttribute("Hazards")
        local lights = currentCar:GetAttribute("Headlights")

        headIcon.TextColor3 = lights and blueLightColor or dimColor

        local anySignal = leftSig or rightSig or hazard
        if anySignal then
            blinkTimer = blinkTimer + dt
            if blinkTimer >= 0.42 then
                blinkTimer = 0
                blinkState = not blinkState
                if tickSound then
                    tickSound.PlaybackSpeed = blinkState and 1.15 or 0.95
                    tickSound:Play()
                end
            end
            
            local showLeft = (leftSig or hazard) and blinkState
            local showRight = (rightSig or hazard) and blinkState
            leftArrow.TextColor3 = showLeft and greenColor or dimColor
            rightArrow.TextColor3 = showRight and greenColor or dimColor
        else
            blinkTimer = 0
            blinkState = false
            leftArrow.TextColor3 = dimColor
            rightArrow.TextColor3 = dimColor
        end
    end
end)
