local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("VelocityCarRemote")
local player = Players.LocalPlayer

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if UserInputService:GetFocusedTextBox() then return end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local seat = hum and hum.SeatPart
    if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") then return end
    local car = seat.Parent
    if not (car and car:GetAttribute("VelocityCar")) then return end

    if input.KeyCode == Enum.KeyCode.Q then
        remote:FireServer("Left")
    elseif input.KeyCode == Enum.KeyCode.E then
        remote:FireServer("Right")
    elseif input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Z then
        remote:FireServer("Hazard")
    elseif input.KeyCode == Enum.KeyCode.L or input.KeyCode == Enum.KeyCode.H then
        remote:FireServer("Headlights")
    end
end)
