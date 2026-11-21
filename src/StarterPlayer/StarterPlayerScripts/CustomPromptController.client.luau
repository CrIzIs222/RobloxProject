local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local promptScreenGui = pGui:FindFirstChild("CustomPromptGui")
if not promptScreenGui then
    promptScreenGui = Instance.new("ScreenGui")
    promptScreenGui.Name = "CustomPromptGui"
    promptScreenGui.ResetOnSpawn = false
    promptScreenGui.IgnoreGuiInset = true
    promptScreenGui.Parent = pGui
end

local activePrompts = {}

local function createCustomPromptBillboard(prompt)
    local adornee = prompt.Parent
    if not adornee then return nil end

    local gui = Instance.new("BillboardGui")
    gui.Name = "PromptUI_" .. prompt.Name
    gui.Adornee = adornee
    gui.Size = UDim2.new(0, 150, 0, 48)
    gui.StudsOffset = Vector3.new(0, 1.2, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = prompt.MaxActivationDistance + 2

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundColor3 = Color3.fromRGB(15, 18, 26)
    container.BackgroundTransparency = 0.22
    container.BorderSizePixel = 0
    container.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = container

    local stroke = Instance.new("UIStroke")
    stroke.Name = "BorderGlow"
    stroke.Color = Color3.fromRGB(0, 195, 255)
    stroke.Thickness = 1.6
    stroke.Transparency = 0.35
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = container

    -- Key Badge
    local keyFrame = Instance.new("Frame")
    keyFrame.Name = "KeyBadge"
    keyFrame.Size = UDim2.new(0, 32, 0, 32)
    keyFrame.Position = UDim2.new(0, 8, 0.5, -16)
    keyFrame.BackgroundColor3 = Color3.fromRGB(28, 35, 48)
    keyFrame.BackgroundTransparency = 0.1
    keyFrame.Parent = container

    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyFrame

    local keyStroke = Instance.new("UIStroke")
    keyStroke.Name = "KeyStroke"
    keyStroke.Color = Color3.fromRGB(0, 210, 255)
    keyStroke.Thickness = 1.2
    keyStroke.Transparency = 0.4
    keyStroke.Parent = keyFrame

    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyText"
    keyLabel.Size = UDim2.new(1, 0, 1, 0)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Font = Enum.Font.GothamBold
    local keyString = prompt.KeyboardKeyCode.Name
    keyLabel.Text = keyString
    keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyLabel.TextSize = 16
    keyLabel.Parent = keyFrame

    -- Text Area
    local textContainer = Instance.new("Frame")
    textContainer.Name = "TextContainer"
    textContainer.Size = UDim2.new(1, -52, 1, -8)
    textContainer.Position = UDim2.new(0, 48, 0, 4)
    textContainer.BackgroundTransparency = 1
    textContainer.Parent = container

    local actionLabel = Instance.new("TextLabel")
    actionLabel.Name = "ActionText"
    actionLabel.Size = UDim2.new(1, 0, 0, 20)
    actionLabel.Position = UDim2.new(0, 0, 0, 1)
    actionLabel.BackgroundTransparency = 1
    actionLabel.Font = Enum.Font.GothamBold
    actionLabel.Text = prompt.ActionText
    actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionLabel.TextSize = 14
    actionLabel.TextXAlignment = Enum.TextXAlignment.Left
    actionLabel.Parent = textContainer

    local objectLabel = Instance.new("TextLabel")
    objectLabel.Name = "ObjectText"
    objectLabel.Size = UDim2.new(1, 0, 0, 16)
    objectLabel.Position = UDim2.new(0, 0, 0, 20)
    objectLabel.BackgroundTransparency = 1
    objectLabel.Font = Enum.Font.GothamMedium
    objectLabel.Text = prompt.ObjectText or "Спорткар"
    objectLabel.TextColor3 = Color3.fromRGB(130, 175, 210)
    objectLabel.TextSize = 11
    objectLabel.TextXAlignment = Enum.TextXAlignment.Left
    objectLabel.Parent = textContainer

    -- Smooth entrance animation
    container.Position = UDim2.new(0, 0, 0, 8)
    container.BackgroundTransparency = 1
    stroke.Transparency = 1
    keyFrame.BackgroundTransparency = 1
    keyLabel.TextTransparency = 1
    actionLabel.TextTransparency = 1
    objectLabel.TextTransparency = 1

    TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.22
    }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0.35 }):Play()
    TweenService:Create(keyFrame, TweenInfo.new(0.22), { BackgroundTransparency = 0.1 }):Play()
    TweenService:Create(keyLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
    TweenService:Create(actionLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
    TweenService:Create(objectLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()

    gui.Parent = promptScreenGui
    return gui
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
    if prompt.Style == Enum.ProximityPromptStyle.Custom then
        if activePrompts[prompt] then
            activePrompts[prompt]:Destroy()
            activePrompts[prompt] = nil
        end
        local gui = createCustomPromptBillboard(prompt)
        if gui then
            activePrompts[prompt] = gui
        end
    end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    local gui = activePrompts[prompt]
    if gui then
        activePrompts[prompt] = nil
        local container = gui:FindFirstChild("Container")
        if container then
            TweenService:Create(container, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 0, 6),
                BackgroundTransparency = 1
            }):Play()
            task.delay(0.15, function()
                gui:Destroy()
            end)
        else
            gui:Destroy()
        end
    end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    local gui = activePrompts[prompt]
    if gui then
        local container = gui:FindFirstChild("Container")
        local stroke = container and container:FindFirstChild("BorderGlow")
        if stroke then
            TweenService:Create(stroke, TweenInfo.new(0.1), {
                Color = Color3.fromRGB(0, 255, 170),
                Thickness = 2.4,
                Transparency = 0.1
            }):Play()
        end
    end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
    local gui = activePrompts[prompt]
    if gui then
        local container = gui:FindFirstChild("Container")
        local stroke = container and container:FindFirstChild("BorderGlow")
        if stroke then
            TweenService:Create(stroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(0, 195, 255),
                Thickness = 1.6,
                Transparency = 0.35
            }):Play()
        end
    end
end)
