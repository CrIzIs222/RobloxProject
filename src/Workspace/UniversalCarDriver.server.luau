local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local remote = ReplicatedStorage:WaitForChild("CarControlRemote")

if not seat or not constraints then return end

local motorFL = constraints:FindFirstChild("MotorFL")
local motorFR = constraints:FindFirstChild("MotorFR")
local motorRL = constraints:FindFirstChild("MotorRL")
local motorRR = constraints:FindFirstChild("MotorRR")
local steer = constraints:FindFirstChild("SteeringPrismatic")
local motors = {motorFL, motorFR, motorRL, motorRR}

-- Sounds (comfortably tuned, slightly quieter)
local sndStart = effects and effects:FindFirstChild("EngineStart")
local sndIdle = effects and effects:FindFirstChild("Idle")
local sndAccel = effects and effects:FindFirstChild("Accelerate")
local sndStop = effects and effects:FindFirstChild("EngineStop")
local sndDoor = effects and effects:FindFirstChild("OpenCloseDoor")
local sndSwitch = effects and effects:FindFirstChild("LightSwitchSound")
local sndTurnTick = effects and effects:FindFirstChild("TurnTickSound")
local sndCrash = effects and effects:FindFirstChild("CrashSound")

if sndIdle then sndIdle.Looped = true; sndIdle.Volume = 0.22 end
if sndAccel then sndAccel.Looped = true; sndAccel.Volume = 0.04 end
if sndStart then sndStart.Volume = 0.38 end
if sndStop then sndStop.Volume = 0.28 end
if sndDoor then sndDoor.Volume = 0.35 end
if sndSwitch then sndSwitch.Volume = 0.30 end
if sndTurnTick then sndTurnTick.Volume = 0.40 end
if sndCrash then sndCrash.Volume = 0.55 end

-- Drift & Skid Components (Rear Wheels, Smoke & Tire Trails)
local srl = chassis and chassis:FindFirstChild("SuspensionRL")
local srr = chassis and chassis:FindFirstChild("SuspensionRR")
local rearWheelL = srl and srl:FindFirstChild("Wheel")
local rearWheelR = srr and srr:FindFirstChild("Wheel")
local smokeL = rearWheelL and rearWheelL:FindFirstChild("DriftSmoke")
local smokeR = rearWheelR and rearWheelR:FindFirstChild("DriftSmoke")

-- Damage & Crash Particles + Flat Skid Trails (on non-spinning FloorPanel)
local floorPanel = chassis and chassis:FindFirstChild("FloorPanel")
local trailL = floorPanel and floorPanel:FindFirstChild("SkidTrailL")
local trailR = floorPanel and floorPanel:FindFirstChild("SkidTrailR")
local crashSparks = floorPanel and floorPanel:FindFirstChild("CrashSparks")
local crashDebris = floorPanel and floorPanel:FindFirstChild("CrashDebris")
local damageSmoke = floorPanel and floorPanel:FindFirstChild("EngineDamageSmoke")

local defaultRearFriction = 2.0
local driftRearFriction = 0.35

local maxForwardSpeed = 82
local isHandbrake = true
local isNeutral = false
local isDrifting = false
local maxHealth = 100
local health = 100

car:SetAttribute("Handbrake", true)
car:SetAttribute("Neutral", false)
car:SetAttribute("Health", maxHealth)
car:SetAttribute("MaxHealth", maxHealth)
car:SetAttribute("Broken", false)

local currentDriver = nil
local currentPassenger = nil

local headlightsOn = false
local turnSignalMode = "None"
local blinkState = false
local blinkTimer = 0
local lastSpeed = 0
local lastCrashTime = 0

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
        hl.Color = on and Color3.fromRGB(215, 225, 240) or Color3.fromRGB(75, 80, 90)
        for _, child in ipairs(hl:GetDescendants()) do
            if child:IsA("SpotLight") then
                child.Enabled = on
            end
        end
    end
    if beam then beam.Enabled = on end
    if tl then
        tl.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
        tl.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(110, 20, 20)
    end
    if sndSwitch then sndSwitch:Play() end
    
    local player = currentDriver and Players:GetPlayerFromCharacter(currentDriver)
    if player then remote:FireClient(player, "Headlights", on) end
end

local function setSignalVisuals(leftOn, rightOn)
    updateSingleSignal(partFL, lightFL, leftOn)
    updateSingleSignal(partRL, lightRL, leftOn)
    updateSingleSignal(partFR, lightFR, rightOn)
    updateSingleSignal(partRR, lightRR, rightOn)
end

local function setTireEffects(smokeOn, trailOn, lowFriction)
    local friction = lowFriction and driftRearFriction or defaultRearFriction
    if rearWheelL then
        rearWheelL.CustomPhysicalProperties = PhysicalProperties.new(2.0, friction, 0.1, 3.0, 100)
    end
    if rearWheelR then
        rearWheelR.CustomPhysicalProperties = PhysicalProperties.new(2.0, friction, 0.1, 3.0, 100)
    end
    if smokeL then smokeL.Enabled = smokeOn end
    if smokeR then smokeR.Enabled = smokeOn end
    if trailL then trailL.Enabled = trailOn end
    if trailR then trailR.Enabled = trailOn end
end

local function lockParkedWheels()
    for _, m in ipairs(motors) do
        if m then
            m.MotorMaxTorque = 120000
            m.AngularVelocity = 0
        end
    end
    if steer then steer.TargetPosition = 0 end
end

lockParkedWheels()

remote.OnServerEvent:Connect(function(player, action, value)
    if not currentDriver or Players:GetPlayerFromCharacter(currentDriver) ~= player then
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
        isDrifting = (value == true)
    elseif action == "ToggleHandbrake" then
        isHandbrake = not isHandbrake
        if isHandbrake then isNeutral = false end
        car:SetAttribute("Handbrake", isHandbrake)
        car:SetAttribute("Neutral", isNeutral)
        if sndSwitch then sndSwitch:Play() end
        remote:FireClient(player, "Handbrake", isHandbrake)
    elseif action == "ToggleNeutral" then
        isNeutral = not isNeutral
        if isNeutral then isHandbrake = false end
        car:SetAttribute("Neutral", isNeutral)
        car:SetAttribute("Handbrake", isHandbrake)
        if sndSwitch then sndSwitch:Play() end
        remote:FireClient(player, "Neutral", isNeutral)
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
        isNeutral = false
        lastSpeed = 0
        car:SetAttribute("Handbrake", false)
        car:SetAttribute("Neutral", false)
        if promptDriver then promptDriver.Enabled = false end
        
        local player = Players:GetPlayerFromCharacter(char)
        if player then
            remote:FireClient(player, "Handbrake", false)
            remote:FireClient(player, "Neutral", false)
            for _, part in ipairs(car:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    pcall(function() part:SetNetworkOwner(player) end)
                end
            end
        end
        
        if sndDoor then sndDoor:Play() end
        if health > 0 then
            if sndStart then
                sndStart:Play()
                task.delay(0.4, function()
                    if seat.Occupant and sndIdle and health > 0 then
                        sndIdle.Volume = 0.22
                        sndIdle:Play()
                    end
                    if seat.Occupant and sndAccel and health > 0 then
                        sndAccel.Volume = 0.04
                        sndAccel.PlaybackSpeed = 0.8
                        sndAccel:Play()
                    end
                end)
            else
                if sndIdle then sndIdle.Volume = 0.22; sndIdle:Play() end
                if sndAccel then sndAccel.Volume = 0.04; sndAccel:Play() end
            end
        end
    else
        local charToTeleport = currentDriver
        currentDriver = nil
        turnSignalMode = "None"
        isHandbrake = true
        isNeutral = false
        isDrifting = false
        car:SetAttribute("Handbrake", true)
        car:SetAttribute("Neutral", false)
        setSignalVisuals(false, false)
        setHeadlights(false)
        setTireEffects(false, false, false)
        
        if sndIdle then sndIdle:Stop() end
        if sndAccel then sndAccel:Stop() end
        if sndStop then sndStop:Play() end
        if sndDoor then sndDoor:Play() end
        if promptDriver then promptDriver.Enabled = true end
        
        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                pcall(function() part:SetNetworkOwner(nil) end)
            end
        end
        lockParkedWheels()
        
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

RunService.Heartbeat:Connect(function(dt)
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
        local absSpeed = seat.AssemblyLinearVelocity.Magnitude
        local ratio = math.clamp(absSpeed / maxForwardSpeed, 0, 1)
        local throttle = seat.ThrottleFloat

        -- 1. Crash Detection (sudden impact deceleration)
        local speedDrop = lastSpeed - absSpeed
        if speedDrop > 22 and (os.clock() - lastCrashTime) > 0.65 then
            lastCrashTime = os.clock()
            if sndCrash then sndCrash:Play() end

            -- Slight realistic bounce back
            local look = seat.CFrame.LookVector
            local bounceSpeed = math.clamp(speedDrop * 0.35, 6, 18)
            seat.AssemblyLinearVelocity = -look * bounceSpeed + Vector3.new(0, 4.5, 0)

            -- Sparks & broken parts debris burst
            if crashSparks then crashSparks:Emit(20) end
            if crashDebris then crashDebris:Emit(12) end

            -- Reduce car HP
            local dmg = math.floor((speedDrop - 15) * 0.75)
            if dmg > 0 then
                health = math.max(0, health - dmg)
                car:SetAttribute("Health", health)
                if damageSmoke then
                    damageSmoke.Enabled = (health <= 35)
                end
                if health <= 0 then
                    car:SetAttribute("Broken", true)
                    if sndIdle then sndIdle:Stop() end
                    if sndAccel then sndAccel:Stop() end
                end
            end
        end
        lastSpeed = absSpeed

        -- 2. Tire Smoke & Skid Marks (on drift or hard braking at speed)
        local isHardBraking = (throttle < -0.5) and (absSpeed > 22) and not isNeutral and not isHandbrake
        local showSmoke = (isDrifting and absSpeed > 8) or isHardBraking
        local showTrail = (isDrifting and absSpeed > 6) or isHardBraking
        setTireEffects(showSmoke, showTrail, isDrifting)
        
        -- 3. Quieter, Balanced Engine Sound Modulation
        if health > 0 then
            local targetAccelVol = 0.02
            local targetAccelPitch = 0.75
            local targetIdleVol = 0.20
            
            if math.abs(throttle) > 0.05 and not isHandbrake then
                if isNeutral then
                    -- Revving engine in neutral
                    targetAccelVol = 0.32
                    targetAccelPitch = 1.25
                    targetIdleVol = 0.14
                else
                    targetAccelVol = math.clamp(0.22 + ratio * 0.26, 0.22, 0.48)
                    targetAccelPitch = 0.75 + (ratio * 0.9)
                    targetIdleVol = math.clamp(0.20 - (ratio * 0.12), 0.08, 0.20)
                end
            else
                if absSpeed > 2 then
                    targetAccelVol = math.clamp(0.06 + ratio * 0.08, 0.05, 0.14)
                    targetAccelPitch = 0.75 + (ratio * 0.35)
                    targetIdleVol = 0.20
                else
                    targetAccelVol = 0
                    targetAccelPitch = 0.75
                    targetIdleVol = 0.22
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
    else
        lastSpeed = 0
    end
end)
