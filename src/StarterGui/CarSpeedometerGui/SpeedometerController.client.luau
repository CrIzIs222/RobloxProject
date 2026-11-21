local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("CarControlRemote")

local player = Players.LocalPlayer
local gui = script.Parent
local frame = gui:WaitForChild("SpeedometerFrame")
local speedLabel = frame:WaitForChild("SpeedValue")
local transFrame = frame:WaitForChild("TransModes")
local pLabel = transFrame:FindFirstChild("ModeP")
local rLabel = transFrame:WaitForChild("ModeR")
local nLabel = transFrame:WaitForChild("ModeN")
local dLabel = transFrame:WaitForChild("ModeD")
local barBg = frame:WaitForChild("BarBackground")
local barFill = barBg:WaitForChild("BarFill")

local dashIcons = frame:WaitForChild("DashIcons")
local leftArrow = dashIcons:WaitForChild("LeftArrow")
local rightArrow = dashIcons:WaitForChild("RightArrow")
local headIcon = dashIcons:WaitForChild("HeadlightIcon")
local tickSound = gui:WaitForChild("CabinRelayTick")

local currentSeat = nil
local maxSpeed = 140
local isDrifting = false
local isHandbrake = false

local dimColor = Color3.fromRGB(50, 55, 65)
local activeColor = Color3.fromRGB(250, 250, 255)
local redParkColor = Color3.fromRGB(255, 65, 65)
local greenColor = Color3.fromRGB(0, 255, 130)
local blueLightColor = Color3.fromRGB(0, 190, 255)

local currentSignal = "None"
local blinkState = false
local blinkTimer = 0

remote.OnClientEvent:Connect(function(action, value)
    if action == "Headlights" then
        headIcon.TextColor3 = value and blueLightColor or dimColor
    elseif action == "TurnSignal" then
        currentSignal = value
        blinkState = (currentSignal ~= "None")
        blinkTimer = 0
        if currentSignal == "None" then
            leftArrow.TextColor3 = dimColor
            rightArrow.TextColor3 = dimColor
        else
            if tickSound then
                tickSound.PlaybackSpeed = 1.15
                tickSound:Play()
            end
        end
    elseif action == "Handbrake" then
        isHandbrake = value
        if isHandbrake then
            if pLabel then pLabel.TextColor3 = redParkColor end
            rLabel.TextColor3 = dimColor
            nLabel.TextColor3 = dimColor
            dLabel.TextColor3 = dimColor
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not currentSeat then return end
    if UserInputService:GetFocusedTextBox() then return end
    
    if input.KeyCode == Enum.KeyCode.L then
        remote:FireServer("ToggleLights")
    elseif input.KeyCode == Enum.KeyCode.Q then
        remote:FireServer("SignalLeft")
    elseif input.KeyCode == Enum.KeyCode.E then
        remote:FireServer("SignalRight")
    elseif input.KeyCode == Enum.KeyCode.X then
        remote:FireServer("Hazard")
    elseif input.KeyCode == Enum.KeyCode.P then
        remote:FireServer("ToggleHandbrake")
    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        isDrifting = true
        remote:FireServer("Drift", true)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if not currentSeat then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if isDrifting then
            isDrifting = false
            remote:FireServer("Drift", false)
        end
    end
end)

local function setGear(mode)
    if pLabel then
        pLabel.TextColor3 = (mode == "P") and redParkColor or dimColor
    end
    rLabel.TextColor3 = (mode == "R") and activeColor or dimColor
    nLabel.TextColor3 = (mode == "N") and activeColor or dimColor
    dLabel.TextColor3 = (mode == "D") and activeColor or dimColor
end

local function onSeated(active, seat)
    if active and seat and seat:IsA("VehicleSeat") then
        currentSeat = seat
        isHandbrake = false
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
        currentSignal = "None"
        isDrifting = false
        isHandbrake = false
        leftArrow.TextColor3 = dimColor
        rightArrow.TextColor3 = dimColor
        headIcon.TextColor3 = dimColor
        if pLabel then pLabel.TextColor3 = dimColor end
        
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
    if currentSignal ~= "None" then
        blinkTimer = blinkTimer + dt
        if blinkTimer >= 0.42 then
            blinkTimer = 0
            blinkState = not blinkState
            
            if tickSound then
                tickSound.PlaybackSpeed = blinkState and 1.15 or 0.95
                tickSound:Play()
            end
            
            if currentSignal == "Left" then
                leftArrow.TextColor3 = blinkState and greenColor or dimColor
                rightArrow.TextColor3 = dimColor
            elseif currentSignal == "Right" then
                leftArrow.TextColor3 = dimColor
                rightArrow.TextColor3 = blinkState and greenColor or dimColor
            elseif currentSignal == "Hazard" then
                leftArrow.TextColor3 = blinkState and greenColor or dimColor
                rightArrow.TextColor3 = blinkState and greenColor or dimColor
            end
        end
    end
    
    if currentSeat and currentSeat.Parent then
        local velocity = currentSeat.AssemblyLinearVelocity
        local speedStudsPerSec = velocity.Magnitude
        local kmh = math.floor(speedStudsPerSec * 1.6)
        
        speedLabel.Text = tostring(kmh)
        
        local ratio = math.clamp(kmh / maxSpeed, 0, 1)
        barFill.Size = UDim2.new(ratio, 0, 1, 0)
        
        if isHandbrake then
            setGear("P")
        else
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
        end
    end
end)
