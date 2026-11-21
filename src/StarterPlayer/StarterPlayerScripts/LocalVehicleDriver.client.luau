local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("CarControlRemote")
local player = Players.LocalPlayer

local WHEEL_RADIUS = 1.5
local MAX_FORWARD_SPEED = 82 -- studs/s (~131 km/h)
local MAX_REVERSE_SPEED = 26 -- studs/s (~42 km/h)
local ACCEL_RATE = 23.0 -- studs/s^2 (~2.7 sec 0-100 km/h)
local REVERSE_ACCEL_RATE = 13.0

local currentSeat = nil
local currentCar = nil
local currentHumanoid = nil
local motors = {}
local steerPrismatic = nil
local currentSteer = 0
local currentTargetSpeed = 0
local wasSpaceBraking = false

local function clearVehicle()
    if currentHumanoid then
        currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
    currentSeat = nil
    currentCar = nil
    motors = {}
    steerPrismatic = nil
    currentSteer = 0
    currentTargetSpeed = 0
    wasSpaceBraking = false
end

local function bindVehicle(seat, humanoid)
    clearVehicle()
    if not seat then return end

    currentHumanoid = humanoid
    if currentHumanoid then
        -- Disable Spacebar jumping out of the car; F is used to exit
        currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    end

    if not seat:IsA("VehicleSeat") then
        -- Passenger seat: only F-to-exit & jump-disable needed
        currentSeat = seat
        return
    end

    local chassis = seat.Parent
    local car = chassis and chassis.Parent
    local constraints = car and car:FindFirstChild("Constraints")
    if not constraints then return end

    currentSeat = seat
    currentCar = car
    steerPrismatic = constraints:FindFirstChild("SteeringPrismatic")
    motors = {
        constraints:FindFirstChild("MotorFL"),
        constraints:FindFirstChild("MotorFR"),
        constraints:FindFirstChild("MotorRL"),
        constraints:FindFirstChild("MotorRR"),
    }

    for _, m in ipairs(motors) do
        if m then
            m.MotorMaxAngularAcceleration = 38
        end
    end
    if steerPrismatic then
        steerPrismatic.Speed = 12
        steerPrismatic.ServoMaxForce = 250000
    end
end

local function hookCharacter(char)
    clearVehicle()
    local humanoid = char:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    currentHumanoid = humanoid

    humanoid.Seated:Connect(function(active, seat)
        if active and seat and (seat:IsA("VehicleSeat") or seat.Name == "SeatFR") then
            bindVehicle(seat, humanoid)
        else
            clearVehicle()
        end
    end)

    if humanoid.SeatPart and (humanoid.SeatPart:IsA("VehicleSeat") or humanoid.SeatPart.Name == "SeatFR") then
        bindVehicle(humanoid.SeatPart, humanoid)
    end
end

if player.Character then
    hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

-- Exit car on F key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not currentSeat then return end
    if UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.F then
        if currentHumanoid then
            currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
        remote:FireServer("ExitCar")
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if not currentSeat or not currentSeat.Parent or not currentCar then return end
    dt = math.min(dt, 0.05)

    local velocity = currentSeat.AssemblyLinearVelocity
    local look = currentSeat.CFrame.LookVector
    local forwardSpeed = look:Dot(velocity)
    local absSpeed = math.abs(forwardSpeed)
    local speedRatio = math.clamp(absSpeed / MAX_FORWARD_SPEED, 0, 1)

    local isHandbrake = currentCar:GetAttribute("Handbrake") == true
    local isNeutral = currentCar:GetAttribute("Neutral") == true
    local isBroken = currentCar:GetAttribute("Broken") == true
    local isSpaceBraking = UserInputService:IsKeyDown(Enum.KeyCode.Space)
    local isDrifting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    if isSpaceBraking ~= wasSpaceBraking then
        wasSpaceBraking = isSpaceBraking
        remote:FireServer("SpaceBrake", isSpaceBraking)
    end

    -- 1. Smooth Speed-Sensitive Steering
    local rawSteer = currentSeat.SteerFloat
    local steerRate = (math.abs(rawSteer) > 0.05) and 7.5 or 11.0
    currentSteer = currentSteer + (rawSteer - currentSteer) * math.clamp(dt * steerRate, 0, 1)

    local maxSteerAngle = isDrifting and 0.55 or (0.55 - speedRatio * 0.27)
    if steerPrismatic then
        steerPrismatic.TargetPosition = -currentSteer * maxSteerAngle
    end

    -- 2. Realistic Progressive Acceleration, Smooth Space Braking, Reverse & Natural Coasting
    local throttle = currentSeat.ThrottleFloat
    local targetAngularVel = 0
    local targetTorque = 350

    if isHandbrake or isBroken then
        currentTargetSpeed = 0
        targetAngularVel = 0
        targetTorque = 120000
    elseif isSpaceBraking then
        -- Smooth progressive brake on Spacebar
        currentTargetSpeed = forwardSpeed
        targetAngularVel = 0
        targetTorque = 36000
    elseif isNeutral then
        currentTargetSpeed = forwardSpeed
        targetAngularVel = 0
        targetTorque = 350
    elseif throttle > 0.05 then
        if forwardSpeed < -2.5 then
            currentTargetSpeed = 0
            targetAngularVel = 0
            targetTorque = 45000
        else
            if currentTargetSpeed < forwardSpeed then
                currentTargetSpeed = forwardSpeed
            end
            currentTargetSpeed = math.min(currentTargetSpeed + ACCEL_RATE * throttle * dt, MAX_FORWARD_SPEED)
            currentTargetSpeed = math.min(currentTargetSpeed, forwardSpeed + 14)
            targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
            targetTorque = 13500 + (speedRatio * 6500)
        end
    elseif throttle < -0.05 then
        if forwardSpeed > 2.5 then
            currentTargetSpeed = forwardSpeed
            targetAngularVel = 0
            targetTorque = 42000 * math.abs(throttle)
        else
            if currentTargetSpeed > forwardSpeed then
                currentTargetSpeed = forwardSpeed
            end
            currentTargetSpeed = math.max(currentTargetSpeed - REVERSE_ACCEL_RATE * math.abs(throttle) * dt, -MAX_REVERSE_SPEED)
            currentTargetSpeed = math.max(currentTargetSpeed, forwardSpeed - 6)
            targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
            targetTorque = 10000
        end
    else
        currentTargetSpeed = forwardSpeed
        targetAngularVel = 0
        targetTorque = 350
    end

    for _, m in ipairs(motors) do
        if m then
            m.MotorMaxTorque = targetTorque
            m.AngularVelocity = targetAngularVel
        end
    end

    -- 3. Instant Client-Side Tire Skid Trails
    local chassis = currentCar:FindFirstChild("Chassis")
    local fp = chassis and chassis:FindFirstChild("FloorPanel")
    if fp then
        local showTrail = (isDrifting and absSpeed > 6) or (isSpaceBraking and absSpeed > 12)
        local tL = fp:FindFirstChild("SkidTrailL")
        local tR = fp:FindFirstChild("SkidTrailR")
        if tL then tL.Enabled = showTrail end
        if tR then tR.Enabled = showTrail end
    end

    -- 4. Subtle Drift Yaw Assist
    if isDrifting and not isHandbrake and not isSpaceBraking and absSpeed > 15 and math.abs(currentSteer) > 0.1 then
        local currentAngVel = currentSeat.AssemblyAngularVelocity
        local desiredYaw = -currentSteer * 1.45 * math.clamp(absSpeed / 45, 0.3, 1.0)
        if forwardSpeed < 0 then desiredYaw = -desiredYaw end
        local blendedYaw = currentAngVel.Y + (desiredYaw - currentAngVel.Y) * math.clamp(dt * 3.5, 0, 1)
        currentSeat.AssemblyAngularVelocity = Vector3.new(currentAngVel.X, blendedYaw, currentAngVel.Z)
    end
end)
