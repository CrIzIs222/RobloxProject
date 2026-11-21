local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local folder = workspace:WaitForChild("VelocitySportCars")
local remote = ReplicatedStorage:WaitForChild("VelocityCarRemote")

local WHITE = Color3.fromRGB(232, 245, 255)
local RED = Color3.fromRGB(255, 37, 59)
local AMBER = Color3.fromRGB(255, 170, 22)
local OFF = Color3.fromRGB(20, 24, 29)

local function getCarForPlayer(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
        local car = seat.Parent
        if car and car.Parent == folder and car:GetAttribute("VelocityCar") then
            return car
        end
    end
    return nil
end

local function illuminate(part, on, brightColor, offColor)
    if not part then return end
    part.Color = on and brightColor or offColor
    part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
    local lamp = part:FindFirstChild("Lamp")
    if lamp then lamp.Enabled = on end
end

local carState = {}

local function setupCar(car)
    local chassis = car:WaitForChild("PhysicsHull")
    local seat = car:WaitForChild("DriverSeat")
    local effects = car:FindFirstChild("Effects")
    local prompt = car:FindFirstChildWhichIsA("ProximityPrompt", true)

    local sndStart = effects and effects:FindFirstChild("EngineStart")
    local sndIdle = effects and effects:FindFirstChild("Idle")
    local sndAccel = effects and effects:FindFirstChild("Accelerate")
    local sndStop = effects and effects:FindFirstChild("EngineStop")
    local sndDoor = effects and effects:FindFirstChild("OpenCloseDoor")
    local sndSwitch = effects and effects:FindFirstChild("LightSwitchSound")
    local sndTick = effects and effects:FindFirstChild("TurnTickSound")

    if sndIdle then sndIdle.Looped = true end
    if sndAccel then sndAccel.Looped = true end

    carState[car] = {
        speed = 0,
        currentDriver = nil,
        sounds = {
            start = sndStart,
            idle = sndIdle,
            accel = sndAccel,
            stop = sndStop,
            door = sndDoor,
            sw = sndSwitch,
            tick = sndTick
        }
    }

    if prompt then
        prompt.Triggered:Connect(function(player)
            if seat.Occupant then return end
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                seat:Sit(hum)
            end
        end)
    end

    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        local occupant = seat.Occupant
        local state = carState[car]
        
        if occupant and occupant:IsA("Humanoid") then
            local char = occupant.Parent
            state.currentDriver = char
            if prompt then prompt.Enabled = false end

            if sndDoor then sndDoor:Play() end
            if sndStart then
                sndStart:Play()
                task.delay(0.35, function()
                    if seat.Occupant and sndIdle then
                        sndIdle.Volume = 0.4
                        sndIdle:Play()
                    end
                    if seat.Occupant and sndAccel then
                        sndAccel.Volume = 0.05
                        sndAccel.PlaybackSpeed = 0.75
                        sndAccel:Play()
                    end
                end)
            else
                if sndIdle then sndIdle.Volume = 0.4; sndIdle:Play() end
                if sndAccel then sndAccel.Volume = 0.05; sndAccel:Play() end
            end

            local player = Players:GetPlayerFromCharacter(char)
            if player then
                pcall(function() chassis:SetNetworkOwner(player) end)
            end
        else
            local charToExit = state.currentDriver
            state.currentDriver = nil
            state.speed = 0

            car:SetAttribute("LeftIndicator", false)
            car:SetAttribute("RightIndicator", false)
            car:SetAttribute("Hazards", false)

            if sndIdle then sndIdle:Stop() end
            if sndAccel then sndAccel:Stop() end
            if sndStop then sndStop:Play() end
            if sndDoor then sndDoor:Play() end
            if prompt then prompt.Enabled = true end

            pcall(function() chassis:SetNetworkOwner(nil) end)

            -- Safe exit teleportation outside beside driver door
            if charToExit and charToExit:FindFirstChild("HumanoidRootPart") then
                task.delay(0.06, function()
                    if charToExit and charToExit:FindFirstChild("HumanoidRootPart") then
                        local exitCFrame = seat.CFrame * CFrame.new(-4.5, 0.5, 0)
                        charToExit:PivotTo(exitCFrame)
                    end
                end)
            end
        end
    end)

    pcall(function() chassis:SetNetworkOwner(nil) end)
end

for _, car in ipairs(folder:GetChildren()) do
    setupCar(car)
end

folder.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child:GetAttribute("VelocityCar") then
        setupCar(child)
    end
end)

remote.OnServerEvent:Connect(function(player, action)
    if typeof(action) ~= "string" then return end
    local car = getCarForPlayer(player)
    if not car then return end
    local state = carState[car]
    local sounds = state and state.sounds

    if action == "Left" then
        local on = not car:GetAttribute("LeftIndicator")
        car:SetAttribute("LeftIndicator", on)
        car:SetAttribute("RightIndicator", false)
        car:SetAttribute("Hazards", false)
        if on and sounds and sounds.tick then
            sounds.tick.PlaybackSpeed = 1.15
            sounds.tick:Play()
        end
    elseif action == "Right" then
        local on = not car:GetAttribute("RightIndicator")
        car:SetAttribute("RightIndicator", on)
        car:SetAttribute("LeftIndicator", false)
        car:SetAttribute("Hazards", false)
        if on and sounds and sounds.tick then
            sounds.tick.PlaybackSpeed = 1.15
            sounds.tick:Play()
        end
    elseif action == "Hazard" then
        local on = not car:GetAttribute("Hazards")
        car:SetAttribute("Hazards", on)
        car:SetAttribute("LeftIndicator", false)
        car:SetAttribute("RightIndicator", false)
        if on and sounds and sounds.tick then
            sounds.tick.PlaybackSpeed = 1.15
            sounds.tick:Play()
        end
    elseif action == "Headlights" then
        local on = not car:GetAttribute("Headlights")
        car:SetAttribute("Headlights", on)
        if sounds and sounds.sw then
            sounds.sw:Play()
        end
    end
end)

local tickAccum = 0
local lastFlash = false

RunService.Heartbeat:Connect(function(dt)
    dt = math.min(dt, 0.08)
    tickAccum = tickAccum + dt
    local flash = (math.floor(os.clock() * 2.4) % 2 == 0)

    for car, state in pairs(carState) do
        if not car.Parent then continue end
        local chassis = car.PrimaryPart
        local seat = car:FindFirstChild("DriverSeat")
        if not chassis or not seat then continue end

        local driver = seat.Occupant
        local targetSpeed = driver and seat.ThrottleFloat * car:GetAttribute("MaxSpeed") or 0
        local speed = state.speed
        local accel = car:GetAttribute("Acceleration") or 72
        local step = accel * dt * (driver and 1 or 1.35)

        if speed < targetSpeed then
            speed = math.min(targetSpeed, speed + step)
        else
            speed = math.max(targetSpeed, speed - step)
        end
        state.speed = speed

        local look = chassis.CFrame.LookVector
        local vertical = chassis.AssemblyLinearVelocity.Y

        if driver or math.abs(speed) > 0.25 then
            chassis.AssemblyLinearVelocity = Vector3.new(look.X * speed, vertical, look.Z * speed)
            local steer = driver and seat.SteerFloat or 0
            local steerFactor = math.clamp(math.abs(speed) / 38, 0, 1)
            chassis.AssemblyAngularVelocity = Vector3.new(0, -steer * (car:GetAttribute("TurnRate") or 1.7) * steerFactor * (speed >= 0 and 1 or -1), 0)
        else
            chassis.AssemblyAngularVelocity = Vector3.zero
        end

        -- Dynamic Engine Sound modulation
        local sounds = state.sounds
        if sounds and sounds.accel and sounds.accel.IsPlaying then
            local absSpeed = math.abs(speed)
            local maxSpd = car:GetAttribute("MaxSpeed") or 100
            local ratio = math.clamp(absSpeed / maxSpd, 0, 1)
            local throttle = driver and math.abs(seat.ThrottleFloat) or 0

            local targetVol = 0.05
            local targetPitch = 0.75
            local idleVol = 0.35

            if throttle > 0.1 then
                targetVol = math.clamp(0.35 + ratio * 0.55, 0.35, 0.9)
                targetPitch = 0.75 + ratio * 0.9
                idleVol = math.clamp(0.35 - ratio * 0.2, 0.1, 0.35)
            else
                if absSpeed > 2 then
                    targetVol = 0.12 + ratio * 0.1
                    targetPitch = 0.75 + ratio * 0.3
                    idleVol = 0.35
                else
                    targetVol = 0
                    targetPitch = 0.75
                    idleVol = 0.4
                end
            end

            sounds.accel.Volume = sounds.accel.Volume + (targetVol - sounds.accel.Volume) * math.clamp(dt * 5, 0, 1)
            sounds.accel.PlaybackSpeed = sounds.accel.PlaybackSpeed + (targetPitch - sounds.accel.PlaybackSpeed) * math.clamp(dt * 4, 0, 1)
            if sounds.idle and sounds.idle.IsPlaying then
                sounds.idle.Volume = sounds.idle.Volume + (idleVol - sounds.idle.Volume) * math.clamp(dt * 4, 0, 1)
            end
        end

        if tickAccum < 0.07 then continue end

        local hazard = car:GetAttribute("Hazards")
        local left = (hazard or car:GetAttribute("LeftIndicator")) and flash
        local right = (hazard or car:GetAttribute("RightIndicator")) and flash

        illuminate(car:FindFirstChild("LeftTurnFront"), left, AMBER, OFF)
        illuminate(car:FindFirstChild("LeftTurnRear"), left, AMBER, OFF)
        illuminate(car:FindFirstChild("RightTurnFront"), right, AMBER, OFF)
        illuminate(car:FindFirstChild("RightTurnRear"), right, AMBER, OFF)

        -- Click relay audio during flash change
        if (left or right) and (flash ~= lastFlash) and sounds and sounds.tick then
            sounds.tick.PlaybackSpeed = flash and 1.15 or 0.95
            sounds.tick:Play()
        end

        local lights = car:GetAttribute("Headlights")
        illuminate(car:FindFirstChild("LeftHeadlight"), lights, WHITE, Color3.fromRGB(77, 91, 102))
        illuminate(car:FindFirstChild("RightHeadlight"), lights, WHITE, Color3.fromRGB(77, 91, 102))

        local braking = driver and seat.ThrottleFloat < -0.1 and speed > 2
        for _, side in ipairs({"Left", "Right"}) do
            local tail = car:FindFirstChild(side .. "TailLamp")
            if tail then
                local lamp = tail:FindFirstChild("Lamp")
                if lamp then lamp.Brightness = braking and 3.5 or 0.55 end
                tail.Color = braking and Color3.fromRGB(255, 110, 116) or RED
            end
        end
    end

    if tickAccum >= 0.07 then
        tickAccum = 0
        lastFlash = flash
    end
end)
