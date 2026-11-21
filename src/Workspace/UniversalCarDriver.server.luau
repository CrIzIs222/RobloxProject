local car = script.Parent
local chassis = car:FindFirstChild("Chassis")
local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
local seatFR = chassis and chassis:FindFirstChild("SeatFR")
local constraints = car:FindFirstChild("Constraints")
local effects = car:FindFirstChild("Effects")
local body = car:FindFirstChild("Body")
local hl = body and body:FindFirstChild("headlights")
local tl = body and body:FindFirstChild("tail_light")
local beam = hl and hl:FindFirstChild("HeadlightBeam")

local promptLoc = seat and seat:FindFirstChild("PromptLocation")
local promptDriver = promptLoc and promptLoc:FindFirstChildOfClass("ProximityPrompt")

local promptLocFR = seatFR and seatFR:FindFirstChild("PromptLocation")
local promptPassenger = promptLocFR and promptLocFR:FindFirstChildOfClass("ProximityPrompt")

local remote = game:GetService("ReplicatedStorage"):WaitForChild("CarControlRemote")

if not seat or not constraints then return end

local motorFL = constraints:FindFirstChild("MotorFL")
local motorFR = constraints:FindFirstChild("MotorFR")
local motorRL = constraints:FindFirstChild("MotorRL")
local motorRR = constraints:FindFirstChild("MotorRR")
local steer = constraints:FindFirstChild("SteeringPrismatic")
local motors = {motorFL, motorFR, motorRL, motorRR}

-- Sounds
local sndStart = effects and effects:FindFirstChild("EngineStart")
local sndIdle = effects and effects:FindFirstChild("Idle")
local sndAccel = effects and effects:FindFirstChild("Accelerate")
local sndStop = effects and effects:FindFirstChild("EngineStop")
local sndDoor = effects and effects:FindFirstChild("OpenCloseDoor")
local sndSwitch = effects and effects:FindFirstChild("LightSwitchSound")
local sndTurnTick = effects and effects:FindFirstChild("TurnTickSound")

if sndIdle then sndIdle.Looped = true end
if sndAccel then sndAccel.Looped = true end

-- Drift Components (Rear Wheels & Smoke)
local srl = chassis and chassis:FindFirstChild("SuspensionRL")
local srr = chassis and chassis:FindFirstChild("SuspensionRR")
local rearWheelL = srl and srl:FindFirstChild("Wheel")
local rearWheelR = srr and srr:FindFirstChild("Wheel")
local smokeL = rearWheelL and rearWheelL:FindFirstChild("DriftSmoke")
local smokeR = rearWheelR and rearWheelR:FindFirstChild("DriftSmoke")

local isDrifting = false
local defaultRearFriction = 2.0
local driftRearFriction = 0.32

-- Handbrake (P key)
local isHandbrake = false

local maxForwardSpeed = 75
local maxReverseSpeed = 30
local currentVelocity = 0

local accelRate = 12
local brakeRate = 45
local coastRate = 10
local defaultSteer = 0.55
local driftSteer = 0.74

local currentDriver = nil
local currentPassenger = nil

local headlightsOn = false
local turnSignalMode = "None"
local blinkState = false
local blinkTimer = 0

-- Turn signal parts and lights embedded inside headlight and taillight housings
local partFL = car:FindFirstChild("TurnSignalFL", true)
local partFR = car:FindFirstChild("TurnSignalFR", true)
local partRL = car:FindFirstChild("TurnSignalRL", true)
local partRR = car:FindFirstChild("TurnSignalRR", true)

local lightFL = partFL and partFL:FindFirstChildWhichIsA("PointLight")
local lightFR = partFR and partFR:FindFirstChildWhichIsA("PointLight")
local lightRL = partRL and partRL:FindFirstChildWhichIsA("PointLight")
local lightRR = partRR and partRR:FindFirstChildWhichIsA("PointLight")

local amberOffColor = Color3.fromRGB(110, 55, 0)
local amberOnColor = Color3.fromRGB(255, 150, 0)

local function updateSingleSignal(part, light, active)
    if part then
        part.Material = active and Enum.Material.Neon or Enum.Material.SmoothPlastic
        part.Color = active and amberOnColor or amberOffColor
        part.Transparency = active and 0 or 0.5
    end
    if light then
        light.Enabled = active
    end
end

local function setHeadlights(on)
    headlightsOn = on
    if hl then
        hl.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
        hl.Color = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 85)
    end
    if beam then beam.Enabled = on end
    if tl then
        tl.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(150, 20, 20)
    end
    if sndSwitch then sndSwitch:Play() end
    
    local player = currentDriver and game:GetService("Players"):GetPlayerFromCharacter(currentDriver)
    if player then remote:FireClient(player, "Headlights", on) end
end

local function setSignalVisuals(leftOn, rightOn)
    updateSingleSignal(partFL, lightFL, leftOn)
    updateSingleSignal(partRL, lightRL, leftOn)
    updateSingleSignal(partFR, lightFR, rightOn)
    updateSingleSignal(partRR, lightRR, rightOn)
end

local function setDriftState(active)
    isDrifting = active
    local friction = active and driftRearFriction or defaultRearFriction
    local fWeight = 3.0
    if rearWheelL then
        rearWheelL.CustomPhysicalProperties = PhysicalProperties.new(2.0, friction, 0.1, fWeight, 100)
    end
    if rearWheelR then
        rearWheelR.CustomPhysicalProperties = PhysicalProperties.new(2.0, friction, 0.1, fWeight, 100)
    end
    if smokeL then smokeL.Enabled = active end
    if smokeR then smokeR.Enabled = active end
end

remote.OnServerEvent:Connect(function(player, action, value)
    if not currentDriver or game:GetService("Players"):GetPlayerFromCharacter(currentDriver) ~= player then
        return
    end
    
    if action == "ToggleLights" then
        setHeadlights(not headlightsOn)
    elseif action == "SignalLeft" then
        turnSignalMode = (turnSignalMode == "Left") and "None" or "Left"
        blinkState = (turnSignalMode == "Left")
        blinkTimer = 0
        setSignalVisuals(blinkState, false)
        if blinkState and sndTurnTick then
            sndTurnTick.PlaybackSpeed = 1.15
            sndTurnTick:Play()
        end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    elseif action == "SignalRight" then
        turnSignalMode = (turnSignalMode == "Right") and "None" or "Right"
        blinkState = (turnSignalMode == "Right")
        blinkTimer = 0
        setSignalVisuals(false, blinkState)
        if blinkState and sndTurnTick then
            sndTurnTick.PlaybackSpeed = 1.15
            sndTurnTick:Play()
        end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    elseif action == "Hazard" then
        turnSignalMode = (turnSignalMode == "Hazard") and "None" or "Hazard"
        blinkState = (turnSignalMode == "Hazard")
        blinkTimer = 0
        setSignalVisuals(blinkState, blinkState)
        if blinkState and sndTurnTick then
            sndTurnTick.PlaybackSpeed = 1.15
            sndTurnTick:Play()
        end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    elseif action == "Drift" then
        setDriftState(value == true)
    elseif action == "ToggleHandbrake" then
        isHandbrake = not isHandbrake
        if sndSwitch then sndSwitch:Play() end
        remote:FireClient(player, "Handbrake", isHandbrake)
        if isHandbrake then
            currentVelocity = 0
            for _, m in ipairs(motors) do
                if m then
                    m.MotorMaxTorque = 120000
                    m.AngularVelocity = 0
                end
            end
        end
    end
end)

-- Driver ProximityPrompt
if promptDriver then
    promptDriver.Triggered:Connect(function(player)
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and not seat.Occupant then
            seat:Sit(hum)
        end
    end)
end

-- Passenger ProximityPrompt
if promptPassenger and seatFR then
    promptPassenger.Triggered:Connect(function(player)
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and not seatFR.Occupant then
            seatFR:Sit(hum)
        end
    end)
end

-- Driver Seating
seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    local occupant = seat.Occupant
    if occupant and occupant:IsA("Humanoid") then
        local char = occupant.Parent
        currentDriver = char
        isHandbrake = false
        if promptDriver then promptDriver.Enabled = false end
        
        local player = game:GetService("Players"):GetPlayerFromCharacter(char)
        if player then
            remote:FireClient(player, "Handbrake", false)
            for _, part in ipairs(car:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    pcall(function() part:SetNetworkOwner(player) end)
                end
            end
        end
        
        if sndDoor then sndDoor:Play() end
        if sndStart then
            sndStart:Play()
            task.delay(0.4, function()
                if seat.Occupant and sndIdle then
                    sndIdle.Volume = 0.4
                    sndIdle:Play()
                end
                if seat.Occupant and sndAccel then
                    sndAccel.Volume = 0.05
                    sndAccel.PlaybackSpeed = 0.8
                    sndAccel:Play()
                end
            end)
        else
            if sndIdle then sndIdle.Volume = 0.4; sndIdle:Play() end
            if sndAccel then sndAccel.Volume = 0.05; sndAccel:Play() end
        end
    else
        local charToTeleport = currentDriver
        currentDriver = nil
        currentVelocity = 0
        turnSignalMode = "None"
        isHandbrake = true
        setSignalVisuals(false, false)
        setHeadlights(false)
        setDriftState(false)
        
        if sndIdle then sndIdle:Stop() end
        if sndAccel then sndAccel.Stop() end
        if sndStop then sndStop:Play() end
        if sndDoor then sndDoor:Play() end
        if promptDriver then promptDriver.Enabled = true end
        
        -- Lock wheels when parked
        for _, m in ipairs(motors) do
            if m then
                m.MotorMaxTorque = 120000
                m.AngularVelocity = 0
            end
        end
        if steer then steer.TargetPosition = 0 end
        
        -- Smooth and safe exit teleportation outside beside driver door
        if charToTeleport and charToTeleport:FindFirstChild("HumanoidRootPart") then
            task.delay(0.06, function()
                if charToTeleport and charToTeleport:FindFirstChild("HumanoidRootPart") then
                    local exitCFrame = seat.CFrame * CFrame.new(-5.5, 0.5, 0)
                    charToTeleport:PivotTo(exitCFrame)
                end
            end)
        end
    end
end)

-- Passenger Seating
if seatFR then
    seatFR:GetPropertyChangedSignal("Occupant"):Connect(function()
        local occupant = seatFR.Occupant
        if occupant and occupant:IsA("Humanoid") then
            local char = occupant.Parent
            currentPassenger = char
            if promptPassenger then promptPassenger.Enabled = false end
            if sndDoor then sndDoor:Play() end
        else
            local charToExit = currentPassenger
            currentPassenger = nil
            if promptPassenger then promptPassenger.Enabled = true end
            if sndDoor then sndDoor:Play() end
            
            -- Smooth and safe exit teleportation outside beside passenger door
            if charToExit and charToExit:FindFirstChild("HumanoidRootPart") then
                task.delay(0.06, function()
                    if charToExit and charToExit:FindFirstChild("HumanoidRootPart") then
                        local exitCFrame = seatFR.CFrame * CFrame.new(5.5, 0.5, 0)
                        charToExit:PivotTo(exitCFrame)
                    end
                end)
            end
        end
    end)
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
    if turnSignalMode ~= "None" then
        blinkTimer = blinkTimer + dt
        if blinkTimer >= 0.42 then
            blinkTimer = 0
            blinkState = not blinkState
            if sndTurnTick then
                sndTurnTick.PlaybackSpeed = blinkState and 1.15 or 0.95
                sndTurnTick:Play()
            end
            if turnSignalMode == "Left" then
                setSignalVisuals(blinkState, false)
            elseif turnSignalMode == "Right" then
                setSignalVisuals(false, blinkState)
            elseif turnSignalMode == "Hazard" then
                setSignalVisuals(blinkState, blinkState)
            end
        end
    else
        setSignalVisuals(false, false)
    end
    
    if seat.Occupant then
        local throttle = seat.ThrottleFloat
        local steerFloat = seat.SteerFloat
        
        -- Steering angle (boosted during drift for counter-steering)
        local activeMaxSteer = isDrifting and driftSteer or defaultSteer
        if steer then
            steer.TargetPosition = -steerFloat * activeMaxSteer
        end
        
        if isHandbrake then
            -- Handbrake engaged: locked in place
            currentVelocity = 0
            for _, m in ipairs(motors) do
                if m then
                    m.MotorMaxTorque = 120000
                    m.AngularVelocity = 0
                end
            end
        else
            -- Normal driving
            if throttle > 0 then
                if currentVelocity < 0 then
                    currentVelocity = math.min(currentVelocity + brakeRate * dt, 0)
                else
                    currentVelocity = math.min(currentVelocity + accelRate * dt, maxForwardSpeed)
                end
            elseif throttle < 0 then
                if currentVelocity > 0 then
                    currentVelocity = math.max(currentVelocity - brakeRate * dt, 0)
                else
                    currentVelocity = math.max(currentVelocity - (accelRate * 0.7) * dt, -maxReverseSpeed)
                end
            else
                if currentVelocity > 0 then
                    currentVelocity = math.max(currentVelocity - coastRate * dt, 0)
                elseif currentVelocity < 0 then
                    currentVelocity = math.min(currentVelocity + coastRate * dt, 0)
                end
            end
            
            local torque = (throttle ~= 0) and 40000 or 15000
            for _, m in ipairs(motors) do
                if m then
                    m.MotorMaxTorque = torque
                    m.AngularVelocity = currentVelocity
                end
            end
        end
        
        local absSpeed = math.abs(currentVelocity)
        local ratio = math.clamp(absSpeed / maxForwardSpeed, 0, 1)
        
        -- Dynamic Engine Sound modulation
        local targetAccelVol = 0.05
        local targetAccelPitch = 0.75
        local targetIdleVol = 0.35
        
        if throttle ~= 0 and not isHandbrake then
            targetAccelVol = math.clamp(0.4 + ratio * 0.55, 0.4, 0.95)
            targetAccelPitch = 0.75 + (ratio * 0.9)
            targetIdleVol = math.clamp(0.35 - (ratio * 0.25), 0.1, 0.35)
        else
            if absSpeed > 2 then
                targetAccelVol = math.clamp(0.1 + ratio * 0.12, 0.08, 0.22)
                targetAccelPitch = 0.75 + (ratio * 0.35)
                targetIdleVol = 0.35
            else
                targetAccelVol = 0
                targetAccelPitch = 0.75
                targetIdleVol = 0.45
            end
        end
        
        if sndAccel and sndAccel.IsPlaying then
            sndAccel.Volume = sndAccel.Volume + (targetAccelVol - sndAccel.Volume) * math.clamp(dt * 5, 0, 1)
            sndAccel.PlaybackSpeed = sndAccel.PlaybackSpeed + (targetAccelPitch - sndAccel.PlaybackSpeed) * math.clamp(dt * 4, 0, 1)
        end
        if sndIdle and sndIdle.IsPlaying then
            sndIdle.Volume = sndIdle.Volume + (targetIdleVol - sndIdle.Volume) * math.clamp(dt * 4, 0, 1)
        end
    end
end)
