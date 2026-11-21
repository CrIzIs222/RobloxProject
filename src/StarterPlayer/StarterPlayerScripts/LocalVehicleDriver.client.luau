local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local WHEEL_RADIUS = 1.5
local MAX_FORWARD_SPEED = 82 -- studs/s (~131 km/h)
local MAX_REVERSE_SPEED = 26 -- studs/s (~42 km/h)
local ACCEL_RATE = 23.0 -- studs/s^2 (~2.7 sec 0-100 km/h)
local REVERSE_ACCEL_RATE = 13.0

local currentSeat = nil
local currentCar = nil
local motors = {}
local steerPrismatic = nil
local currentSteer = 0
local currentTargetSpeed = 0

local function clearVehicle()
    currentSeat = nil
    currentCar = nil
    motors = {}
    steerPrismatic = nil
    currentSteer = 0
    currentTargetSpeed = 0
end

local function bindVehicle(seat)
    clearVehicle()
    if not seat or not seat:IsA("VehicleSeat") then return end

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

    humanoid.Seated:Connect(function(active, seat)
        if active and seat and seat:IsA("VehicleSeat") then
            bindVehicle(seat)
        else
            clearVehicle()
        end
    end)

    if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
        bindVehicle(humanoid.SeatPart)
    end
end

if player.Character then
    hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

RunService.RenderStepped:Connect(function(dt)
    if not currentSeat or not currentSeat.Parent or not currentCar then return end
    dt = math.min(dt, 0.05)

    local velocity = currentSeat.AssemblyLinearVelocity
    local look = currentSeat.CFrame.LookVector
    local forwardSpeed = look:Dot(velocity)
    local absSpeed = math.abs(forwardSpeed)
    local speedRatio = math.clamp(absSpeed / MAX_FORWARD_SPEED, 0, 1)

    local isHandbrake = currentCar:GetAttribute("Handbrake") == true
    local isDrifting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

    -- 1. Smooth Speed-Sensitive Steering
    local rawSteer = currentSeat.SteerFloat
    local steerRate = (math.abs(rawSteer) > 0.05) and 7.5 or 11.0
    currentSteer = currentSteer + (rawSteer - currentSteer) * math.clamp(dt * steerRate, 0, 1)

    local maxSteerAngle = isDrifting and 0.55 or (0.55 - speedRatio * 0.27)
    if steerPrismatic then
        steerPrismatic.TargetPosition = -currentSteer * maxSteerAngle
    end

    -- 2. Realistic Progressive Acceleration, Braking, Reverse & Natural Coasting
    local throttle = currentSeat.ThrottleFloat
    local targetAngularVel = 0
    local targetTorque = 350

    if isHandbrake then
        currentTargetSpeed = 0
        targetAngularVel = 0
        targetTorque = 120000
    elseif throttle > 0.05 then
        if forwardSpeed < -2.5 then
            -- Braking from reverse
            currentTargetSpeed = 0
            targetAngularVel = 0
            targetTorque = 45000
        else
            -- Smooth progressive acceleration (syncs to actual speed + gradual ramp)
            if currentTargetSpeed < forwardSpeed then
                currentTargetSpeed = forwardSpeed
            end
            currentTargetSpeed = math.min(currentTargetSpeed + ACCEL_RATE * throttle * dt, MAX_FORWARD_SPEED)
            currentTargetSpeed = math.min(currentTargetSpeed, forwardSpeed + 14)
            targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
            -- Sporty responsive launch torque
            targetTorque = 13500 + (speedRatio * 6500)
        end
    elseif throttle < -0.05 then
        if forwardSpeed > 2.5 then
            -- Progressive braking
            currentTargetSpeed = forwardSpeed
            targetAngularVel = 0
            targetTorque = 42000 * math.abs(throttle)
        else
            -- Smooth reversing
            if currentTargetSpeed > forwardSpeed then
                currentTargetSpeed = forwardSpeed
            end
            currentTargetSpeed = math.max(currentTargetSpeed - REVERSE_ACCEL_RATE * math.abs(throttle) * dt, -MAX_REVERSE_SPEED)
            currentTargetSpeed = math.max(currentTargetSpeed, forwardSpeed - 6)
            targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
            targetTorque = 10000
        end
    else
        -- Free-rolling coasting
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

    -- 3. Subtle Drift Yaw Assist for smooth, controllable slides
    if isDrifting and not isHandbrake and absSpeed > 15 and math.abs(currentSteer) > 0.1 then
        local currentAngVel = currentSeat.AssemblyAngularVelocity
        local desiredYaw = -currentSteer * 1.45 * math.clamp(absSpeed / 45, 0.3, 1.0)
        if forwardSpeed < 0 then desiredYaw = -desiredYaw end
        local blendedYaw = currentAngVel.Y + (desiredYaw - currentAngVel.Y) * math.clamp(dt * 3.5, 0, 1)
        currentSeat.AssemblyAngularVelocity = Vector3.new(currentAngVel.X, blendedYaw, currentAngVel.Z)
    end
end)
