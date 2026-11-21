local car = script.Parent
local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
local constraints = car:FindFirstChild("Constraints")
local effects = car:FindFirstChild("Effects")
local body = car:FindFirstChild("Body")
local hl = body and body:FindFirstChild("headlights")
local tl = body and body:FindFirstChild("tail_light")
local beam = hl and hl:FindFirstChild("HeadlightBeam")
local signalsFolder = car:FindFirstChild("TurnSignals")
local promptLoc = seat and seat:FindFirstChild("PromptLocation")
local prompt = promptLoc and promptLoc:FindFirstChildOfClass("ProximityPrompt")

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
local sndTick = effects and effects:FindFirstChild("TurnTickSound")

if sndIdle then sndIdle.Looped = true end
if sndAccel then sndAccel.Looped = true end

-- Speed Limiter & Reduced Realistic Acceleration
-- Max speed strictly capped at ~120 km/h (75 rad/s)
local maxForwardSpeed = 75
local maxReverseSpeed = 30
local currentVelocity = 0

-- Reduced acceleration rate (0-100 km/h in ~6.5 seconds)
local accelRate = 12
local brakeRate = 45
local coastRate = 10
local maxSteer = 0.55
local currentDriver = nil

-- Light States
local headlightsOn = false
local turnSignalMode = "None" -- "Left", "Right", "Hazard", "None"
local blinkState = false
local blinkTimer = 0

local function setHeadlights(on)
    headlightsOn = on
    if hl then
        hl.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
        hl.Color = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 85)
    end
    if beam then
        beam.Enabled = on
    end
    if tl then
        tl.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(150, 20, 20)
    end
    if sndSwitch then sndSwitch:Play() end
    
    local player = currentDriver and game:GetService("Players"):GetPlayerFromCharacter(currentDriver)
    if player then
        remote:FireClient(player, "Headlights", on)
    end
end

local function setSignalVisuals(leftOn, rightOn)
    if not signalsFolder then return end
    local fl = signalsFolder:FindFirstChild("FrontLeft")
    local rl = signalsFolder:FindFirstChild("RearLeft")
    local fr = signalsFolder:FindFirstChild("FrontRight")
    local rr = signalsFolder:FindFirstChild("RearRight")
    
    local amberOn = Color3.fromRGB(255, 175, 0)
    local amberOff = Color3.fromRGB(90, 60, 20)
    
    if fl and rl then
        fl.Material = leftOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        fl.Color = leftOn and amberOn or amberOff
        fl.BlinkLight.Enabled = leftOn
        
        rl.Material = leftOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        rl.Color = leftOn and amberOn or amberOff
        rl.BlinkLight.Enabled = leftOn
    end
    
    if fr and rr then
        fr.Material = rightOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        fr.Color = rightOn and amberOn or amberOff
        fr.BlinkLight.Enabled = rightOn
        
        rr.Material = rightOn and Enum.Material.Neon or Enum.Material.SmoothPlastic
        rr.Color = rightOn and amberOn or amberOff
        rr.BlinkLight.Enabled = rightOn
    end
end

-- Remote command listener for L, Q, E, X
remote.OnServerEvent:Connect(function(player, action)
    if not currentDriver or game:GetService("Players"):GetPlayerFromCharacter(currentDriver) ~= player then
        return
    end
    
    if action == "ToggleLights" then
        setHeadlights(not headlightsOn)
    elseif action == "SignalLeft" then
        turnSignalMode = (turnSignalMode == "Left") and "None" or "Left"
        blinkState = true
        blinkTimer = 0
        setSignalVisuals(turnSignalMode == "Left", false)
        if sndTick then sndTick:Play() end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    elseif action == "SignalRight" then
        turnSignalMode = (turnSignalMode == "Right") and "None" or "Right"
        blinkState = true
        blinkTimer = 0
        setSignalVisuals(false, turnSignalMode == "Right")
        if sndTick then sndTick:Play() end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    elseif action == "Hazard" then
        turnSignalMode = (turnSignalMode == "Hazard") and "None" or "Hazard"
        blinkState = true
        blinkTimer = 0
        setSignalVisuals(turnSignalMode == "Hazard", turnSignalMode == "Hazard")
        if sndTick then sndTick:Play() end
        remote:FireClient(player, "TurnSignal", turnSignalMode)
    end
end)

-- Seating
if prompt then
    prompt.Triggered:Connect(function(player)
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and not seat.Occupant then
            seat:Sit(hum)
        end
    end)
end

seat:GetPropertyChangedSignal("Occupant"):Connect(function()
    local occupant = seat.Occupant
    if occupant and occupant:IsA("Humanoid") then
        local char = occupant.Parent
        currentDriver = char
        if prompt then prompt.Enabled = false end
        
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
        
        local player = game:GetService("Players"):GetPlayerFromCharacter(char)
        if player then
            for _, part in ipairs(car:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    pcall(function() part:SetNetworkOwner(player) end)
                end
            end
        end
    else
        local charToTeleport = currentDriver
        currentDriver = nil
        currentVelocity = 0
        turnSignalMode = "None"
        setSignalVisuals(false, false)
        setHeadlights(false)
        
        if sndIdle then sndIdle:Stop() end
        if sndAccel then sndAccel:Stop() end
        if sndStop then sndStop:Play() end
        if sndDoor then sndDoor:Play() end
        if prompt then prompt.Enabled = true end
        
        for _, m in ipairs(motors) do
            if m then
                m.MotorMaxTorque = 30000
                m.AngularVelocity = 0
            end
        end
        if steer then steer.TargetPosition = 0 end
        
        -- Safe exit to the right of driver door
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

-- Main Physics and Blink Loop
game:GetService("RunService").Heartbeat:Connect(function(dt)
    -- Turn signal blinking timer
    if turnSignalMode ~= "None" then
        blinkTimer = blinkTimer + dt
        if blinkTimer >= 0.45 then
            blinkTimer = 0
            blinkState = not blinkState
            if sndTick and seat.Occupant then
                sndTick:Play()
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
        
        -- Steering (A=Left, D=Right)
        if steer then
            steer.TargetPosition = -steerFloat * maxSteer
        end
        
        -- Gradual Acceleration with strict speed limiter
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
        
        -- Apply to motors
        local torque = (throttle ~= 0) and 40000 or 15000
        for _, m in ipairs(motors) do
            if m then
                m.MotorMaxTorque = torque
                m.AngularVelocity = currentVelocity
            end
        end
        
        -- Audio Smooth Lerp
        local absSpeed = math.abs(currentVelocity)
        local ratio = math.clamp(absSpeed / maxForwardSpeed, 0, 1)
        
        local targetAccelVol = 0.05
        local targetAccelPitch = 0.75
        local targetIdleVol = 0.35
        
        if throttle ~= 0 then
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
