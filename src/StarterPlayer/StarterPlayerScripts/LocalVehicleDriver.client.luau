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
local COAST_DECEL_RATE = 4.2 -- studs/s^2 (gentle natural coasting ~6.7 km/h per sec)
local BASE_SPRING_LEN = 2.45

local currentSeat = nil
local currentCar = nil
local currentHumanoid = nil
local motorFL, motorFR, motorRL, motorRR = nil, nil, nil, nil
local motors = {}
local springFL, springFR, springRL, springRR = nil, nil, nil, nil
local steerPrismatic = nil

local currentSteer = 0
local currentTargetSpeed = 0
local prevForwardSpeed = 0
local currentPitch = 0
local currentRoll = 0
local wasSpaceBraking = false

local function resetSprings()
    if springFL then springFL.FreeLength = BASE_SPRING_LEN end
    if springFR then springFR.FreeLength = BASE_SPRING_LEN end
    if springRL then springRL.FreeLength = BASE_SPRING_LEN end
    if springRR then springRR.FreeLength = BASE_SPRING_LEN end
end

local function clearVehicle()
    if currentHumanoid then
        currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
    resetSprings()
    currentSeat = nil
    currentCar = nil
    motorFL, motorFR, motorRL, motorRR = nil, nil, nil, nil
    motors = {}
    springFL, springFR, springRL, springRR = nil, nil, nil, nil
    steerPrismatic = nil
    currentSteer = 0
    currentTargetSpeed = 0
    prevForwardSpeed = 0
    currentPitch = 0
    currentRoll = 0
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

    motorFL = constraints:FindFirstChild("MotorFL")
    motorFR = constraints:FindFirstChild("MotorFR")
    motorRL = constraints:FindFirstChild("MotorRL")
    motorRR = constraints:FindFirstChild("MotorRR")
    motors = {motorFL, motorFR, motorRL, motorRR}

    springFL = constraints:FindFirstChild("StrutSpringFL")
    springFR = constraints:FindFirstChild("StrutSpringFR")
    springRL = constraints:FindFirstChild("StrutSpringRL")
    springRR = constraints:FindFirstChild("StrutSpringRR")

    for _, m in ipairs(motors) do
        if m then
            m.MotorMaxAngularAcceleration = 38
        end
    end
    if steerPrismatic then
        steerPrismatic.Speed = 14
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

    -- 1. Alive, Speed-Sensitive Steering with Fast Counter-Steer Response
    local rawSteer = currentSeat.SteerFloat
    local isCounterSteering = (rawSteer * currentSteer) < -0.02
    local steerRate = isCounterSteering and 14.5 or ((math.abs(rawSteer) > 0.05) and 8.5 or 11.5)
    currentSteer = currentSteer + (rawSteer - currentSteer) * math.clamp(dt * steerRate, 0, 1)

    local maxSteerAngle = isDrifting and 0.55 or (0.55 - speedRatio * 0.25)
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
        currentTargetSpeed = forwardSpeed
        targetAngularVel = 0
        targetTorque = 36000
    elseif isNeutral then
        if currentTargetSpeed > 0 then
            currentTargetSpeed = math.min(currentTargetSpeed, math.max(0, forwardSpeed + 1.5))
            currentTargetSpeed = math.max(0, currentTargetSpeed - (COAST_DECEL_RATE * 0.75) * dt)
        elseif currentTargetSpeed < 0 then
            currentTargetSpeed = math.max(currentTargetSpeed, math.min(0, forwardSpeed - 1.5))
            currentTargetSpeed = math.min(0, currentTargetSpeed + (COAST_DECEL_RATE * 0.75) * dt)
        end
        targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
        targetTorque = (math.abs(currentTargetSpeed) > 0.5) and 3800 or 200
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
        -- Smooth natural coasting when releasing W / S
        if currentTargetSpeed > 0 then
            currentTargetSpeed = math.min(currentTargetSpeed, math.max(0, forwardSpeed + 1.5))
            currentTargetSpeed = math.max(0, currentTargetSpeed - COAST_DECEL_RATE * dt)
        elseif currentTargetSpeed < 0 then
            currentTargetSpeed = math.max(currentTargetSpeed, math.min(0, forwardSpeed - 1.5))
            currentTargetSpeed = math.min(0, currentTargetSpeed + COAST_DECEL_RATE * dt)
        end
        targetAngularVel = currentTargetSpeed / WHEEL_RADIUS
        targetTorque = (math.abs(currentTargetSpeed) > 0.5) and 4200 or 250
    end

    -- 3. Active Torque Vectoring Differential & RWD-Biased Sports AWD Split
    local diffRatio = currentSteer * 0.18 * math.clamp(speedRatio * 1.5, 0.2, 1.0)
    local leftSpeedMult = 1 + diffRatio
    local rightSpeedMult = 1 - diffRatio

    if motorFL then
        motorFL.MotorMaxTorque = targetTorque * 0.85
        motorFL.AngularVelocity = targetAngularVel * leftSpeedMult
    end
    if motorFR then
        motorFR.MotorMaxTorque = targetTorque * 0.85
        motorFR.AngularVelocity = targetAngularVel * rightSpeedMult
    end
    if motorRL then
        motorRL.MotorMaxTorque = targetTorque * 1.15
        motorRL.AngularVelocity = targetAngularVel * leftSpeedMult
    end
    if motorRR then
        motorRR.MotorMaxTorque = targetTorque * 1.15
        motorRR.AngularVelocity = targetAngularVel * rightSpeedMult
    end

    -- 4. Realistic Active Suspension Weight Transfer (Pitch Squat/Dive & Cornering Body Roll)
    local lonAccel = (forwardSpeed - prevForwardSpeed) / math.max(dt, 0.008)
    prevForwardSpeed = forwardSpeed

    local targetPitch = 0
    if not isHandbrake and not isBroken and not isNeutral then
        if isSpaceBraking and forwardSpeed > 3 then
            targetPitch = -0.22 * math.clamp(absSpeed / 35, 0.3, 1.0)
        elseif throttle > 0.05 and forwardSpeed >= -1 then
            targetPitch = 0.16 * throttle * (1 - speedRatio * 0.45)
        elseif throttle < -0.05 and forwardSpeed > 3 then
            targetPitch = -0.24 * math.abs(throttle) * math.clamp(absSpeed / 35, 0.3, 1.0)
        elseif throttle < -0.05 and forwardSpeed <= 1 then
            targetPitch = -0.10 * math.abs(throttle)
        else
            targetPitch = math.clamp(lonAccel * 0.004, -0.12, 0.12)
        end
    end

    local latFactor = math.clamp(absSpeed / 32, 0, 1.15)
    if forwardSpeed < -1 then latFactor = -latFactor end
    local targetRoll = currentSteer * 0.22 * latFactor

    currentPitch = currentPitch + (targetPitch - currentPitch) * math.clamp(dt * 8.0, 0, 1)
    currentRoll = currentRoll + (targetRoll - currentRoll) * math.clamp(dt * 9.0, 0, 1)

    if springFL then springFL.FreeLength = BASE_SPRING_LEN + currentPitch - currentRoll end
    if springFR then springFR.FreeLength = BASE_SPRING_LEN + currentPitch + currentRoll end
    if springRL then springRL.FreeLength = BASE_SPRING_LEN - (currentPitch * 0.85) - currentRoll end
    if springRR then springRR.FreeLength = BASE_SPRING_LEN - (currentPitch * 0.85) + currentRoll end

    -- 5. Instant Client-Side Tire Skid Trails
    local chassis = currentCar:FindFirstChild("Chassis")
    local fp = chassis and chassis:FindFirstChild("FloorPanel")
    if fp then
        local showTrail = (isDrifting and absSpeed > 6) or (isSpaceBraking and absSpeed > 12)
        local tL = fp:FindFirstChild("SkidTrailL")
        local tR = fp:FindFirstChild("SkidTrailR")
        if tL then tL.Enabled = showTrail end
        if tR then tR.Enabled = showTrail end
    end

    -- 6. Lively Turn-In & Drift Yaw Dynamics
    if not isHandbrake and not isSpaceBraking and absSpeed > 12 and math.abs(currentSteer) > 0.08 then
        local currentAngVel = currentSeat.AssemblyAngularVelocity
        if isDrifting then
            local desiredYaw = -currentSteer * 1.55 * math.clamp(absSpeed / 42, 0.35, 1.05)
            if forwardSpeed < 0 then desiredYaw = -desiredYaw end
            local blendedYaw = currentAngVel.Y + (desiredYaw - currentAngVel.Y) * math.clamp(dt * 4.0, 0, 1)
            currentSeat.AssemblyAngularVelocity = Vector3.new(currentAngVel.X, blendedYaw, currentAngVel.Z)
        end
    end
end)
