-- VELOCITY SPORT CARS | Paste the whole file into Roblox Studio > View > Command Bar.
-- Generates three playable arcade sports cars, indicator controls, headlights and brake lamps.
-- Run in Edit mode (not during Play). Everything is built from native Roblox parts.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local old = Workspace:FindFirstChild("VelocitySportCars")
if old then old:Destroy() end
local oldRemote = ReplicatedStorage:FindFirstChild("VelocityCarRemote")
if oldRemote then oldRemote:Destroy() end
local oldServer = ServerScriptService:FindFirstChild("VelocityCarServer")
if oldServer then oldServer:Destroy() end
local oldClient = StarterPlayer.StarterPlayerScripts:FindFirstChild("VelocityCarControls")
if oldClient then oldClient:Destroy() end

local folder = Instance.new("Folder")
folder.Name = "VelocitySportCars"
folder.Parent = Workspace

local remote = Instance.new("RemoteEvent")
remote.Name = "VelocityCarRemote"
remote.Parent = ReplicatedStorage

local function color(hex)
    return Color3.fromRGB(tonumber(hex:sub(2,3),16), tonumber(hex:sub(4,5),16), tonumber(hex:sub(6,7),16))
end

local BLACK = color("#121820")
local GLASS = color("#15293F")
local SILVER = color("#CED8E1")
local WHITE = color("#E8F5FF")
local RED = color("#FF253B")
local AMBER = color("#FFAA16")

local configs = {
    {name="01 | VORTEX GT", paint="#007DFF", accent="#00E5FF", origin=Vector3.new(-23,0,0), topSpeed=94, acceleration=72, turn=1.70, profile="GT"},
    {name="02 | PHANTOM R", paint="#EE243B", accent="#FFCB4D", origin=Vector3.new(0,0,0), topSpeed=108, acceleration=82, turn=1.92, profile="R"},
    {name="03 | NEON X", paint="#8429ED", accent="#F547E8", origin=Vector3.new(23,0,0), topSpeed=122, acceleration=90, turn=2.00, profile="X"},
}

local function makePart(parent, name, size, relativeCFrame, partColor, material, transparency, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = relativeCFrame
    p.Color = partColor
    p.Material = material or Enum.Material.SmoothPlastic
    p.Transparency = transparency or 0
    p.Shape = shape or Enum.PartType.Block
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CastShadow = transparency ~= 1
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function weld(root, item)
    local joint = Instance.new("WeldConstraint")
    joint.Part0 = root
    joint.Part1 = item
    joint.Parent = root
end

local function setLight(part, lightKind, tint, brightness, range)
    local light = Instance.new(lightKind)
    light.Name = "Lamp"
    light.Color = tint
    light.Brightness = brightness
    if light:IsA("PointLight") then
        light.Range = range
    else
        light.Range = range
        light.Angle = 65
        light.Face = Enum.NormalId.Front
    end
    light.Parent = part
    return light
end

local function buildCar(info)
    local model = Instance.new("Model")
    model.Name = info.name
    model.Parent = folder
    model:SetAttribute("VelocityCar", true)
    model:SetAttribute("MaxSpeed", info.topSpeed)
    model:SetAttribute("Acceleration", info.acceleration)
    model:SetAttribute("TurnRate", info.turn)
    model:SetAttribute("Headlights", false)
    model:SetAttribute("LeftIndicator", false)
    model:SetAttribute("RightIndicator", false)
    model:SetAttribute("Hazards", false)

    local paint = color(info.paint)
    local accent = color(info.accent)
    local pieces = {}
    local function add(name,size,x,y,z,c,mat,trans,shape,ax,ay,az)
        local cf = CFrame.new(x,y,z) * CFrame.Angles(math.rad(ax or 0), math.rad(ay or 0), math.rad(az or 0))
        local p = makePart(model,name,size,cf,c,mat,trans,shape)
        table.insert(pieces,p)
        return p
    end

    -- Only the invisible chassis collides; all body detail is welded to it.
    local chassis = add("PhysicsHull",Vector3.new(6.5,1.9,12.9),0,1.20,0,BLACK,Enum.Material.Plastic,1)
    chassis.CanCollide = true
    chassis.CanTouch = true
    chassis.Massless = false
    chassis.CustomPhysicalProperties = PhysicalProperties.new(2.0,0.75,0.1,100,100)
    model.PrimaryPart = chassis

    add("LowerBody",Vector3.new(7.4,0.74,13.1),0,1.75,0,paint)
    add("UpperBelt",Vector3.new(7.25,0.50,11.6),0,2.27,0,paint)
    add("FrontNose",Vector3.new(7.15,0.35,2.9),0,2.13,-5.70,paint)
    add("NoseSplitter",Vector3.new(7.75,0.15,1.05),0,1.38,-6.65,BLACK,Enum.Material.Metal)
    add("FrontGrille",Vector3.new(4.55,0.41,0.11),0,1.90,-6.73,BLACK,Enum.Material.Metal)
    add("RearDiffuser",Vector3.new(7.45,0.21,0.88),0,1.42,6.42,BLACK,Enum.Material.Metal)
    add("HoodCenter",Vector3.new(6.45,0.14,4.1),0,2.57,-3.73,paint)
    add("RearDeck",Vector3.new(6.25,0.20,2.55),0,2.62,4.47,paint)
    add("CarbonFrontHoodStrip",Vector3.new(1.45,0.025,2.9),0,2.65,-3.4,BLACK,Enum.Material.Metal)
    add("LeftSideSkirt",Vector3.new(0.38,0.30,8.5),-3.74,1.48,0,BLACK,Enum.Material.Metal)
    add("RightSideSkirt",Vector3.new(0.38,0.30,8.5),3.74,1.48,0,BLACK,Enum.Material.Metal)

    -- Cockpit, greenhouse and roof. Front of the car is negative Z.
    add("Windshield",Vector3.new(6.15,1.70,0.16),0,3.50,-1.60,GLASS,Enum.Material.Glass,0.26,nil,-32)
    add("RearGlass",Vector3.new(6.0,1.4,0.14),0,3.53,2.56,GLASS,Enum.Material.Glass,0.27,nil,32)
    add("Roof",Vector3.new(5.65,0.20,2.85),0,4.23,0.55,paint)
    add("LeftWindow",Vector3.new(0.14,1.30,3.72),-3.13,3.38,0.45,GLASS,Enum.Material.Glass,0.28)
    add("RightWindow",Vector3.new(0.14,1.30,3.72),3.13,3.38,0.45,GLASS,Enum.Material.Glass,0.28)
    for _, side in ipairs({-1,1}) do
        local label = side == -1 and "L" or "R"
        add(label.."DoorPanel",Vector3.new(0.12,0.56,3.1),side*3.69,2.39,0.0,paint)
        add(label.."DoorHandle",Vector3.new(0.15,0.10,0.55),side*3.78,2.62,0.42,BLACK,Enum.Material.Metal)
        add(label.."MirrorStalk",Vector3.new(0.46,0.10,0.12),side*3.33,3.12,-1.47,BLACK)
        add(label.."Mirror",Vector3.new(0.63,0.28,0.48),side*3.67,3.21,-1.47,BLACK,Enum.Material.Metal)
        add(label.."SideIntake",Vector3.new(0.10,0.50,1.42),side*3.76,2.12,3.1,BLACK,Enum.Material.Metal)
        add(label.."AccentStrip",Vector3.new(0.09,0.085,4.0),side*3.80,1.86,-0.2,accent,Enum.Material.Neon)
    end

    -- Four tires, metallic rims, hubs and visible brake calipers.
    for _, x in ipairs({-3.56,3.56}) do
        for _, z in ipairs({-4.35,4.45}) do
            local side = x<0 and "L" or "R"
            local axle = z<0 and "Front" or "Rear"
            add(side..axle.."Tire",Vector3.new(2.70,1.08,2.70),x,1.43,z,BLACK,Enum.Material.Rubber,0,Enum.PartType.Cylinder,0,0,90)
            add(side..axle.."Alloy",Vector3.new(1.78,1.11,1.78),x+(x<0 and -0.04 or 0.04),1.43,z,SILVER,Enum.Material.Metal,0,Enum.PartType.Cylinder,0,0,90)
            add(side..axle.."Hub",Vector3.new(0.49,1.14,0.49),x+(x<0 and -0.06 or 0.06),1.43,z,BLACK,Enum.Material.Metal,0,Enum.PartType.Cylinder,0,0,90)
        end
    end

    -- Headlight optics, DRLs, tail lamps and independent orange turn indicators.
    for _, x in ipairs({-2.70,2.70}) do
        local side = x<0 and "Left" or "Right"
        local head = add(side.."Headlight",Vector3.new(1.25,0.29,0.12),x,2.44,-6.63,WHITE,Enum.Material.Glass)
        setLight(head,"SpotLight",WHITE,3.6,46).Enabled=false
        add(side.."DRL",Vector3.new(1.45,0.07,0.13),x,2.25,-6.69,accent,Enum.Material.Neon)
        local frontTurn = add(side.."TurnFront",Vector3.new(0.46,0.19,0.15),x*1.23,2.31,-6.64,BLACK,Enum.Material.SmoothPlastic)
        setLight(frontTurn,"PointLight",AMBER,1.8,12).Enabled=false
        local rearLamp = add(side.."TailLamp",Vector3.new(1.36,0.23,0.12),x,2.33,6.63,RED,Enum.Material.Neon)
        setLight(rearLamp,"PointLight",RED,0.6,10)
        local rearTurn = add(side.."TurnRear",Vector3.new(0.45,0.16,0.13),x*1.24,2.33,6.64,BLACK,Enum.Material.SmoothPlastic)
        setLight(rearTurn,"PointLight",AMBER,1.6,10).Enabled=false
    end
    add("RearLightBar",Vector3.new(3.4,0.065,0.14),0,2.26,6.64,RED,Enum.Material.Neon)
    for _, x in ipairs({-2.30,2.30}) do
        add("Exhaust",Vector3.new(0.58,0.30,0.35),x,1.51,6.83,SILVER,Enum.Material.Metal,0,Enum.PartType.Cylinder,90)
    end

    -- A few unique details on each of the three car silhouettes.
    if info.profile == "GT" then
        add("GrandTouringWing",Vector3.new(6.25,0.20,0.83),0,3.22,5.93,BLACK,Enum.Material.Metal)
        for _,x in ipairs({-2.35,2.35}) do add("WingMount",Vector3.new(0.16,0.68,0.17),x,2.89,5.73,BLACK) end
        for _,x in ipairs({-1.9,1.9}) do add("HoodVent",Vector3.new(1.03,0.03,1.32),x,2.67,-3.5,BLACK,Enum.Material.Metal) end
    elseif info.profile == "R" then
        add("TrackWing",Vector3.new(7.55,0.22,1.10),0,3.55,5.79,BLACK,Enum.Material.Metal)
        for _,x in ipairs({-2.60,2.60}) do add("WingMount",Vector3.new(0.15,0.94,0.19),x,3.02,5.64,BLACK) end
        add("RoofScoop",Vector3.new(1.30,0.24,1.50),0,4.42,0.40,BLACK,Enum.Material.Metal)
        for _,x in ipairs({-2.1,2.1}) do add("AeroFin",Vector3.new(0.09,0.24,1.5),x,2.78,4.61,BLACK,Enum.Material.Metal) end
    else
        add("HyperRearWing",Vector3.new(7.65,0.17,0.92),0,3.45,5.78,accent,Enum.Material.Neon)
        for _,x in ipairs({-2.65,2.65}) do add("WingPylon",Vector3.new(0.13,0.85,0.18),x,3.00,5.57,BLACK) end
        add("CenterSpine",Vector3.new(0.22,0.045,2.1),0,4.36,0.48,accent,Enum.Material.Neon)
        add("NeonDiffuser",Vector3.new(5.6,0.075,0.13),0,1.47,6.77,accent,Enum.Material.Neon)
    end

    local seat = Instance.new("VehicleSeat")
    seat.Name = "DriverSeat"
    seat.Size = Vector3.new(2.1,0.55,2.2)
    seat.CFrame = CFrame.new(-1.05,2.82,0.42)
    seat.Color = BLACK
    seat.Material = Enum.Material.Fabric
    seat.Anchored = true
    seat.CanCollide = false
    seat.HeadsUpDisplay = false
    seat.MaxSpeed = info.topSpeed
    seat.Torque = 0
    seat.TurnSpeed = 0
    seat.Parent = model
    table.insert(pieces,seat)
    add("PassengerSeatLook",Vector3.new(1.85,0.33,1.95),1.16,2.79,0.42,BLACK,Enum.Material.Fabric)
    add("Dashboard",Vector3.new(5.60,0.35,0.71),0,3.04,-1.46,BLACK)
    add("SteeringWheel",Vector3.new(0.22,0.82,0.82),-1.08,3.25,-1.12,BLACK,Enum.Material.Metal,0,Enum.PartType.Cylinder,0,0,90)

    local enterAnchor = add("EnterPoint",Vector3.new(0.25,0.25,0.25),-3.80,2.70,0.05,accent,Enum.Material.Neon,1)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "EnterCar"
    prompt.ActionText = "Сесть за руль"
    prompt.ObjectText = info.name
    prompt.KeyboardKeyCode = Enum.KeyCode.F
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = enterAnchor
    prompt.Triggered:Connect(function(player)
        if seat.Occupant then return end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            seat:Sit(humanoid)
        end
    end)

    -- Weld before moving the model; then all components are unanchored as one assembly.
    for _,piece in ipairs(pieces) do
        if piece ~= chassis then
            piece.Massless = true
            weld(chassis,piece)
        end
    end
    model:PivotTo(CFrame.new(info.origin + Vector3.new(0,1.2,0)))
    for _,piece in ipairs(pieces) do piece.Anchored = false end
    return model
end

for _,config in ipairs(configs) do buildCar(config) end

-- Server authority: validate who is seated; handle keyboard signals and lamp blinking.
local server = Instance.new("Script")
server.Name = "VelocityCarServer"
server.Source = [==[
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local folder = workspace:WaitForChild("VelocitySportCars")
local remote = ReplicatedStorage:WaitForChild("VelocityCarRemote")
local WHITE = Color3.fromRGB(232,245,255)
local RED = Color3.fromRGB(255,37,59)
local AMBER = Color3.fromRGB(255,170,22)
local OFF = Color3.fromRGB(20,24,29)

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
end

remote.OnServerEvent:Connect(function(player,action)
    if typeof(action) ~= "string" then return end
    local car = getCarForPlayer(player)
    if not car then return end
    if action == "Left" then
        local on = not car:GetAttribute("LeftIndicator")
        car:SetAttribute("LeftIndicator",on)
        car:SetAttribute("RightIndicator",false)
        car:SetAttribute("Hazards",false)
    elseif action == "Right" then
        local on = not car:GetAttribute("RightIndicator")
        car:SetAttribute("RightIndicator",on)
        car:SetAttribute("LeftIndicator",false)
        car:SetAttribute("Hazards",false)
    elseif action == "Hazard" then
        local on = not car:GetAttribute("Hazards")
        car:SetAttribute("Hazards",on)
        car:SetAttribute("LeftIndicator",false)
        car:SetAttribute("RightIndicator",false)
    elseif action == "Headlights" then
        car:SetAttribute("Headlights",not car:GetAttribute("Headlights"))
    end
end)

local function illuminate(p,on,brightColor,offColor)
    if not p then return end
    p.Color = on and brightColor or offColor
    p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
    local lamp = p:FindFirstChild("Lamp")
    if lamp then lamp.Enabled = on end
end

local carState = {}
for _,car in ipairs(folder:GetChildren()) do
    local chassis = car:WaitForChild("PhysicsHull")
    local seat = car:WaitForChild("DriverSeat")
    carState[car] = {speed=0}
    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        if not seat.Occupant then
            car:SetAttribute("LeftIndicator",false)
            car:SetAttribute("RightIndicator",false)
            car:SetAttribute("Hazards",false)
        end
        pcall(function() chassis:SetNetworkOwner(nil) end)
    end)
    pcall(function() chassis:SetNetworkOwner(nil) end)
end

local tickAccum=0
RunService.Heartbeat:Connect(function(dt)
    dt = math.min(dt,0.08)
    tickAccum += dt
    local flash = (math.floor(os.clock()*2.4)%2 == 0)
    for car,state in pairs(carState) do
        if not car.Parent then continue end
        local chassis = car.PrimaryPart
        local seat = car:FindFirstChild("DriverSeat")
        if not chassis or not seat then continue end
        local driver = seat.Occupant
        local targetSpeed = driver and seat.ThrottleFloat * car:GetAttribute("MaxSpeed") or 0
        local speed = state.speed
        local accel = car:GetAttribute("Acceleration") or 70
        local step = accel * dt * (driver and 1 or 1.35)
        if speed < targetSpeed then speed = math.min(targetSpeed,speed+step)
        else speed = math.max(targetSpeed,speed-step) end
        state.speed = speed
        local look = chassis.CFrame.LookVector
        local vertical = chassis.AssemblyLinearVelocity.Y
        if driver or math.abs(speed) > 0.25 then
            chassis.AssemblyLinearVelocity = Vector3.new(look.X*speed,vertical,look.Z*speed)
            local steer = driver and seat.SteerFloat or 0
            local steerFactor = math.clamp(math.abs(speed)/38,0,1)
            chassis.AssemblyAngularVelocity = Vector3.new(0,-steer*(car:GetAttribute("TurnRate") or 1.7)*steerFactor*(speed>=0 and 1 or -1),0)
        else
            chassis.AssemblyAngularVelocity = Vector3.zero
        end
        if tickAccum < 0.07 then continue end
        local hazard = car:GetAttribute("Hazards")
        local left = (hazard or car:GetAttribute("LeftIndicator")) and flash
        local right = (hazard or car:GetAttribute("RightIndicator")) and flash
        illuminate(car:FindFirstChild("LeftTurnFront"),left,AMBER,OFF)
        illuminate(car:FindFirstChild("LeftTurnRear"),left,AMBER,OFF)
        illuminate(car:FindFirstChild("RightTurnFront"),right,AMBER,OFF)
        illuminate(car:FindFirstChild("RightTurnRear"),right,AMBER,OFF)
        local lights = car:GetAttribute("Headlights")
        illuminate(car:FindFirstChild("LeftHeadlight"),lights,WHITE,Color3.fromRGB(77,91,102))
        illuminate(car:FindFirstChild("RightHeadlight"),lights,WHITE,Color3.fromRGB(77,91,102))
        local braking = driver and seat.ThrottleFloat < -0.1 and speed > 2
        for _,side in ipairs({"Left","Right"}) do
            local tail=car:FindFirstChild(side.."TailLamp")
            if tail then
                local lamp = tail:FindFirstChild("Lamp")
                if lamp then lamp.Brightness = braking and 3.5 or 0.55 end
                tail.Color = braking and Color3.fromRGB(255,110,116) or RED
            end
        end
    end
    if tickAccum >= 0.07 then tickAccum=0 end
end)
]==]
server.Parent = ServerScriptService

-- Client key input only. Movement itself is read from Roblox VehicleSeat by the server.
local client = Instance.new("LocalScript")
client.Name = "VelocityCarControls"
client.Source = [==[
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local remote = ReplicatedStorage:WaitForChild("VelocityCarRemote")
local player = Players.LocalPlayer

UIS.InputBegan:Connect(function(input,processed)
    if processed then return end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") then return end
    local car = seat.Parent
    if not (car and car:GetAttribute("VelocityCar")) then return end
    if input.KeyCode == Enum.KeyCode.Q then
        remote:FireServer("Left")
    elseif input.KeyCode == Enum.KeyCode.E then
        remote:FireServer("Right")
    elseif input.KeyCode == Enum.KeyCode.Z then
        remote:FireServer("Hazard")
    elseif input.KeyCode == Enum.KeyCode.H then
        remote:FireServer("Headlights")
    end
end)
]==]
client.Parent = StarterPlayer.StarterPlayerScripts

print("SUCCESS: three Velocity Sport Cars created. Press Play, F to enter; W/S drive, A/D steer, Q/E signals, Z hazards, H headlights.")
