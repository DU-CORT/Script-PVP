-- [[ SCRIPT DE COMBAT DEBUG & TESTING - AIMBOT COM CLICK DIREITO/ESQUERDO ]]

local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Erro ao carregar a biblioteca Fluent! Verifique se seu executor suporta game:HttpGet.")
    return
end

local Window = Fluent:CreateWindow({
    Title = "Combat Debug & Testing Suite",
    SubTitle = "Painel Oficial de Combate",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Criando as abas
local Tabs = {
    Aiming = Window:AddTab({ Title = "Aim & Lock", Icon = "target" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "move" }),
    Visuals = Window:AddTab({ Title = "ESP & Settings", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Serviços do Jogo
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--------------------------------------------------------------------------------
-- 1. AIM ASSIST, SILENT AIM & TARGET LOCK (CORRIGIDO PARA O BOTÃO ESQUERDO)
--------------------------------------------------------------------------------
local AimSettings = {
    Enabled = false,
    SilentAim = false,
    FOVRainbow = false,
    FOV = 120,
    MaxDist = 500,
    Smoothness = 3,
    TargetPart = "HumanoidRootPart",
    TeamCheck = true,
    VisibleCheck = false,
    TriggerBot = false,
    Prediction = false,
    PredictionFactor = 0.133,
    HitboxExpander = false,
    HitboxSize = 3
}

-- Variável para rastrear se o botão esquerdo do mouse está pressionado
local IsMouseDown = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsMouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        IsMouseDown = false
    end
end)

local AimToggle = Tabs.Aiming:AddToggle("AimAssistToggle", { Title = "Ativar Aim Assist / Lock", Default = false })
AimToggle:OnChanged(function(v) AimSettings.Enabled = v end)

local SilentAim_Toggle = Tabs.Aiming:AddToggle("SilentAimToggle", { Title = "Ativar Silent Aim", Default = false })
SilentAim_Toggle:OnChanged(function(v) AimSettings.SilentAim = v end)

local FOVRainbow_Toggle = Tabs.Aiming:AddToggle("FOVRainbowToggle", { Title = "FOV Rainbow (Cores Dinâmicas)", Default = false })
FOVRainbow_Toggle:OnChanged(function(v) AimSettings.FOVRainbow = v end)

local AimFOV_Slider = Tabs.Aiming:AddSlider("AimFOV", { Title = "FOV do Aim Assist", Default = 120, Min = 10, Max = 400, Rounding = 0 })
AimFOV_Slider:OnChanged(function(v) AimSettings.FOV = v end)

local AimSmooth_Slider = Tabs.Aiming:AddSlider("AimSmooth", { Title = "Smoothness (Suavização)", Default = 3, Min = 1, Max = 20, Rounding = 1 })
AimSmooth_Slider:OnChanged(function(v) AimSettings.Smoothness = v end)

local TargetPart_Drop = Tabs.Aiming:AddDropdown("TargetPartDrop", { Title = "Parte do Alvo", Values = {"Head", "UpperTorso", "HumanoidRootPart"}, Default = 3 })
TargetPart_Drop:OnChanged(function(v) AimSettings.TargetPart = v end)

local TeamCheck_Toggle = Tabs.Aiming:AddToggle("TeamCheckToggle", { Title = "Team Check (Apenas Inimigos)", Default = true })
TeamCheck_Toggle:OnChanged(function(v) AimSettings.TeamCheck = v end)

local VisibleCheck_Toggle = Tabs.Aiming:AddToggle("VisibleCheckToggle", { Title = "Visible Check (WallCheck)", Default = false })
VisibleCheck_Toggle:OnChanged(function(v) AimSettings.VisibleCheck = v end)

local Prediction_Toggle = Tabs.Aiming:AddToggle("PredictionToggle", { Title = "Predição de Movimento", Default = false })
Prediction_Toggle:OnChanged(function(v) AimSettings.Prediction = v end)

local TriggerBot_Toggle = Tabs.Aiming:AddToggle("TriggerBotToggle", { Title = "TriggerBot Automático", Default = false })
TriggerBot_Toggle:OnChanged(function(v) AimSettings.TriggerBot = v end)

local Hitbox_Toggle = Tabs.Aiming:AddToggle("HitboxToggle", { Title = "Expandir Hitbox (Hitbox Expander)", Default = false })
Hitbox_Toggle:OnChanged(function(v) AimSettings.HitboxExpander = v end)

-- Desenho do círculo de FOV na tela
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

-- Função auxiliar para validar se o jogador é inimigo considerando o TeamCheck
local function IsValidTarget(p)
    if p == LocalPlayer or not p.Character then return false end
    local hum = p.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    if AimSettings.TeamCheck then
        if p.Team == LocalPlayer.Team and p.Team ~= nil then
            return false
        end
    end
    return true
end

-- Função para encontrar o melhor alvo dentro do FOV
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closestTarget = nil
    local shortestDist = AimSettings.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if IsValidTarget(p) then
            local part = p.Character:FindFirstChild(AimSettings.TargetPart) or p.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local isVisible = true
                if AimSettings.VisibleCheck then
                    local origin = Camera.CFrame.Position
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, p.Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                    local result = Workspace:Raycast(origin, part.Position - origin, raycastParams)
                    if result then isVisible = false end
                end

                if isVisible then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closestTarget = part
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

-- Hook de Silent Aim
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if AimSettings.SilentAim and IsMouseDown and (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay" or method == "Raycast") then
        local targetPart = GetClosestTarget()
        if targetPart then
            local origin = args[1]
            if typeof(origin) == "Ray" then
                args[1] = Ray.new(origin.Origin, (targetPart.Position - origin.Origin).Unit * origin.Direction.Magnitude)
            elseif method == "Raycast" and typeof(args[2]) == "Vector3" then
                args[2] = (targetPart.Position - args[1]).Unit * args[2].Magnitude
            end
            return oldNamecall(self, unpack(args))
        end
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    
    -- Atualiza FOV Circle
    if AimSettings.Enabled or AimSettings.SilentAim then
        FOVCircle.Visible = true
        FOVCircle.Radius = AimSettings.FOV
        FOVCircle.Position = mousePos
        if AimSettings.FOVRainbow then
            FOVCircle.Color = Color3.fromHSV(tick() % 5 / 5, 1, 1)
        else
            FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        end
    else
        FOVCircle.Visible = false
    end

    -- Hitbox Expander Loop
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local part = p.Character:FindFirstChild(AimSettings.TargetPart)
            if part then
                local isEnemy = not AimSettings.TeamCheck or (p.Team ~= LocalPlayer.Team)
                if isEnemy and AimSettings.HitboxExpander then
                    part.Size = Vector3.new(AimSettings.HitboxSize * 2, AimSettings.HitboxSize * 2, AimSettings.HitboxSize * 2)
                    part.Transparency = 0.7
                    part.CanCollide = false
                else
                    part.Size = Vector3.new(2, 1, 1)
                    part.Transparency = 0
                end
            end
        end
    end

    -- Aim Assist & Target Lock Core (Funciona apenas se ativado E o botão esquerdo estiver pressionado)
    if AimSettings.Enabled and IsMouseDown then
        local closestPart = GetClosestTarget()
        
        if closestPart then
            local targetPos = closestPart.Position
            if AimSettings.Prediction and closestPart.Parent and closestPart.Parent:FindFirstChild("HumanoidRootPart") then
                local rootPart = closestPart.Parent.HumanoidRootPart
                targetPos = targetPos + (rootPart.AssemblyLinearVelocity * AimSettings.PredictionFactor)
            end

            local targetScreen = Camera:WorldToViewportPoint(targetPos)
            local moveX = (targetScreen.X - mousePos.X) / math.max(AimSettings.Smoothness, 1)
            local moveY = (targetScreen.Y - mousePos.Y) / math.max(AimSettings.Smoothness, 1)
            
            pcall(function()
                if mousemoverel then
                    mousemoverel(moveX, moveY)
                end
            end)

            -- TriggerBot Logic
            local distToMouse = (Vector2.new(targetScreen.X, targetScreen.Y) - mousePos).Magnitude
            if AimSettings.TriggerBot and distToMouse < 25 then
                pcall(function()
                    mouse1press()
                    task.wait(0.05)
                    mouse1release()
                end)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 2. MOVEMENT
--------------------------------------------------------------------------------
local MovementPara = Tabs.Movement:AddParagraph({ Title = "Controles de Movimento Avançados", Content = "Gerencie velocidade, pulo, voo e colisão." })

local MoveConfig = {
    JumpBooster = false,
    JumpInf = false,
    SpeedBooster = false,
    WalkSpeedVal = 16,
    Fly = false,
    FlySpeedVal = 50,
    NoClip = false,
    NoClipSpeedVal = 50
}

local JumpBoost_Toggle = Tabs.Movement:AddToggle("JumpBoostToggle", { Title = "Jump Booster", Default = false })
JumpBoost_Toggle:OnChanged(function(v)
    MoveConfig.JumpBooster = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = 50 end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if MoveConfig.JumpBooster and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.JumpPower = 100
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

local JumpInf_Toggle = Tabs.Movement:AddToggle("JumpInfToggle", { Title = "Jump Inf", Default = false })
JumpInf_Toggle:OnChanged(function(v) MoveConfig.JumpInf = v end)

UserInputService.JumpRequest:Connect(function()
    if MoveConfig.JumpInf and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

local SpeedBoost_Toggle = Tabs.Movement:AddToggle("SpeedBoostToggle", { Title = "Speed Booster", Default = false })
SpeedBoost_Toggle:OnChanged(function(v)
    MoveConfig.SpeedBooster = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
    end
end)

local Speed_Slider = Tabs.Movement:AddSlider("SpeedSlider", { Title = "Speed (Caminhada)", Default = 16, Min = 16, Max = 150, Rounding = 0 })
Speed_Slider:OnChanged(function(v) MoveConfig.WalkSpeedVal = v end)

RunService.RenderStepped:Connect(function()
    if MoveConfig.SpeedBooster and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = MoveConfig.WalkSpeedVal
        end
    end
end)

local Fly_Toggle = Tabs.Movement:AddToggle("FlyToggle", { Title = "Fly (Voo)", Default = false })
Fly_Toggle:OnChanged(function(v)
    MoveConfig.Fly = v
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local bg = char.HumanoidRootPart:FindFirstChild("FlyBodyGyro")
        local bv = char.HumanoidRootPart:FindFirstChild("FlyBodyVelocity")
        if v then
            if not bg then
                bg = Instance.new("BodyGyro")
                bg.Name = "FlyBodyGyro"
                bg.P = 9e4
                bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bg.CFrame = char.HumanoidRootPart.CFrame
                bg.Parent = char.HumanoidRootPart
            end
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "FlyBodyVelocity"
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bv.Parent = char.HumanoidRootPart
            end
        else
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
        end
    end
end)

local FlySpeed_Slider = Tabs.Movement:AddSlider("FlySpeedSlider", { Title = "Speed Fly", Default = 50, Min = 10, Max = 200, Rounding = 0 })
FlySpeed_Slider:OnChanged(function(v) MoveConfig.FlySpeedVal = v end)

RunService.RenderStepped:Connect(function()
    if MoveConfig.Fly and LocalPlayer.Character then
        local char = LocalPlayer.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local bg = root:FindFirstChild("FlyBodyGyro")
            local bv = root:FindFirstChild("FlyBodyVelocity")
            if bg and bv then
                bg.CFrame = Camera.CFrame
                local moveDir = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
                bv.Velocity = moveDir * MoveConfig.FlySpeedVal
            end
        end
    end
end)

local NoClip_Toggle = Tabs.Movement:AddToggle("NoClipToggle", { Title = "No Clip", Default = false })
NoClip_Toggle:OnChanged(function(v)
    MoveConfig.NoClip = v
    if not v and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end)

local NoClipSpeed_Slider = Tabs.Movement:AddSlider("NoClipSpeedSlider", { Title = "Speed (No Clip)", Default = 50, Min = 16, Max = 150, Rounding = 0 })
NoClipSpeed_Slider:OnChanged(function(v) MoveConfig.NoClipSpeedVal = v end)

RunService.Stepped:Connect(function()
    if MoveConfig.NoClip and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = MoveConfig.NoClipSpeedVal
        end
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 3. ESP DE COMBATE
--------------------------------------------------------------------------------
local VisualsPara = Tabs.Visuals:AddParagraph({ Title = "Configurações de ESP Individual", Content = "Ative cada elemento visual separadamente." })

local ESP_States = {
    Line = false,
    Box = false,
    Health = false,
    Distance = false,
    Name = false,
    ShowVisuals = true
}

local ESPLine_Toggle = Tabs.Visuals:AddToggle("ESPLineToggle", { Title = "ESP Line (Vindo de Cima)", Default = false })
ESPLine_Toggle:OnChanged(function(v) ESP_States.Line = v end)

local ESPBox_Toggle = Tabs.Visuals:AddToggle("ESPBoxToggle", { Title = "ESP Box", Default = false })
ESPBox_Toggle:OnChanged(function(v) ESP_States.Box = v end)

local ESPHealth_Toggle = Tabs.Visuals:AddToggle("ESPHealthToggle", { Title = "ESP Vida", Default = false })
ESPHealth_Toggle:OnChanged(function(v) ESP_States.Health = v end)

local ESPDistance_Toggle = Tabs.Visuals:AddToggle("ESPDistanceToggle", { Title = "ESP Distância", Default = false })
ESPDistance_Toggle:OnChanged(function(v) ESP_States.Distance = v end)

local ESPName_Toggle = Tabs.Visuals:AddToggle("ESPNameToggle", { Title = "ESP Nome", Default = false })
ESPName_Toggle:OnChanged(function(v) ESP_States.Name = v end)

local ESP_Cache = {}

local function RemoveESP(p)
    if ESP_Cache[p] then
        for _, obj in pairs(ESP_Cache[p]) do
            pcall(function() obj:Remove() end)
        end
        ESP_Cache[p] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if not ESP_States.ShowVisuals then
        for p, _ in pairs(ESP_Cache) do RemoveESP(p) end
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local isEnemy = not AimSettings.TeamCheck or (p.Team ~= LocalPlayer.Team)
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            
            if isEnemy and char and root and humanoid and humanoid.Health > 0 then
                if not ESP_Cache[p] then
                    ESP_Cache[p] = {
                        Line = Drawing.new("Line"),
                        Box = Drawing.new("Square"),
                        HealthBar = Drawing.new("Line"),
                        HealthBarBg = Drawing.new("Line"),
                        Text = Drawing.new("Text")
                    }
                    ESP_Cache[p].Line.Thickness = 1
                    ESP_Cache[p].Line.Color = Color3.fromRGB(255, 255, 255)
                    
                    ESP_Cache[p].Box.Thickness = 1
                    ESP_Cache[p].Box.Color = Color3.fromRGB(255, 255, 255)
                    ESP_Cache[p].Box.Filled = false
                    
                    ESP_Cache[p].HealthBarBg.Thickness = 3
                    ESP_Cache[p].HealthBarBg.Color = Color3.fromRGB(0, 0, 0)
                    
                    ESP_Cache[p].HealthBar.Thickness = 1
                    ESP_Cache[p].HealthBar.Color = Color3.fromRGB(0, 255, 0)
                    
                    ESP_Cache[p].Text.Size = 13
                    ESP_Cache[p].Text.Center = true
                    ESP_Cache[p].Text.Outline = true
                    ESP_Cache[p].Text.Color = Color3.fromRGB(255, 255, 255)
                end
                
                local cache = ESP_Cache[p]
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    local size = Vector2.new(2000 / pos.Z, 3000 / pos.Z)
                    local topLeft = Vector2.new(pos.X - size.X / 2, pos.Y - size.Y / 2)
                    
                    if ESP_States.Line then
                        cache.Line.Visible = true
                        cache.Line.From = Vector2.new(Camera.ViewportSize.X / 2, 0)
                        cache.Line.To = Vector2.new(pos.X, pos.Y - size.Y / 2)
                    else
                        cache.Line.Visible = false
                    end
                    
                    if ESP_States.Box then
                        cache.Box.Visible = true
                        cache.Box.Size = size
                        cache.Box.Position = topLeft
                    else
                        cache.Box.Visible = false
                    end
                    
                    if ESP_States.Health then
                        local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        local barHeight = size.Y * healthPercent
                        
                        cache.HealthBarBg.Visible = true
                        cache.HealthBarBg.From = Vector2.new(topLeft.X - 6, topLeft.Y + size.Y)
                        cache.HealthBarBg.To = Vector2.new(topLeft.X - 6, topLeft.Y)
                        
                        cache.HealthBar.Visible = true
                        cache.HealthBar.From = Vector2.new(topLeft.X - 6, topLeft.Y + size.Y)
                        cache.HealthBar.To = Vector2.new(topLeft.X - 6, (topLeft.Y + size.Y) - barHeight)
                    else
                        cache.HealthBar.Visible = false
                        cache.HealthBarBg.Visible = false
                    end
                    
                    local infoString = ""
                    if ESP_States.Name then
                        infoString = p.Name
                    end
                    if ESP_States.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = math.floor((root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude)
                        infoString = infoString ~= "" and (infoString .. " [" .. dist .."m]") or ("[" .. dist .. "m]")
                    end
                    
                    if infoString ~= "" then
                        cache.Text.Visible = true
                        cache.Text.Text = infoString
                        cache.Text.Position = Vector2.new(pos.X, topLeft.Y - 18)
                    else
                        cache.Text.Visible = false
                    end
                else
                    cache.Line.Visible = false
                    cache.Box.Visible = false
                    cache.HealthBar.Visible = false
                    cache.HealthBarBg.Visible = false
                    cache.Text.Visible = false
                end
            else
                RemoveESP(p)
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    RemoveESP(p)
end)

--------------------------------------------------------------------------------
-- 4. SETTINGS
--------------------------------------------------------------------------------
local Translations = {
    ["Português"] = {
        MoveTitle = "Controles de Movimento Avançados", MoveDesc = "Gerencie velocidade, pulo, voo e colisão.",
        ESPTitle = "Configurações de ESP Individual", ESPDesc = "Ative cada elemento visual separadamente.",
        LangNotif = "Idioma alterado para: Português (Brasil)",
        
        AimToggle = "Ativar Aim Assist / Lock", AimFOV = "FOV do Aim Assist", AimSmooth = "Smoothness (Suavização)", TargetPart = "Parte do Alvo", TeamCheck = "Team Check (Apenas Inimigos)",
        JumpBoost = "Jump Booster", JumpInf = "Jump Inf", SpeedBoost = "Speed Booster", SpeedWalk = "Speed (Caminhada)", Fly = "Fly (Voo)", FlySpeed = "Speed Fly", NoClip = "No Clip", NoClipSpeed = "Speed (No Clip)",
        ESPLine = "ESP Line (Vindo de Cima)", ESPBox = "ESP Box", ESPHealth = "ESP Vida", ESPDist = "ESP Distância", ESPName = "ESP Nome",
        
        SecTrans = "🌐 Tradução de IA (Idioma)", SecTransDesc = "Altere o idioma do painel em tempo real.",
        SecInterface = "Interface & Visualização", SecInterfaceDesc = "Configurações gerais do painel.",
        InterfaceToggle = "Habilitar Interface", NotifToggle = "Mostrar Notificações", ResetBtn = "Restaurar Configurações",
        SecPerf = "Performance & Otimização", SecPerfDesc = "Ajustes de desempenho do cliente e monitores.",
        PerfMode = "Modo Performance", ReduceFX = "Reduzir Efeitos Visuais", FPSDisp = "Display de FPS", PingDisp = "Display de Ping",
        SecKeys = "Atalhos (Keybinds)", SecKeysDesc = "Defina as teclas de acesso rápido.",
        KeybindTitle = "Tecla de Menu (Abrir/Fechar)",
        SecTheme = "Temas & Cores", SecThemeDesc = "Personalize o visual e a paleta de cores.",
        ThemeTitle = "Tema Base"
    },
    ["Português (Portugal)"] = {
        MoveTitle = "Controlos de Movimento Avançados", MoveDesc = "Gerencie velocidade, salto, voo e colisão.",
        ESPTitle = "Configurações de ESP Individual", ESPDesc = "Ative cada elemento visual em separado.",
        LangNotif = "Idioma alterado para: Português (Portugal)",
        
        AimToggle = "Ativar Aim Assist / Lock", AimFOV = "FOV do Aim Assist", AimSmooth = "Suavidade", TargetPart = "Parte do Alvo", TeamCheck = "Verificação de Equipa",
        JumpBoost = "Impulsionador de Salto", JumpInf = "Salto Infinito", SpeedBoost = "Impulsionador de Velocidade", SpeedWalk = "Velocidade (Caminhada)", Fly = "Voo (Fly)", FlySpeed = "Velocidade de Voo", NoClip = "No Clip", NoClipSpeed = "Velocidade (No Clip)",
        ESPLine = "Linha ESP (Do Topo)", ESPBox = "Caixa ESP", ESPHealth = "Vida ESP", ESPDist = "Distância ESP", ESPName = "Nome ESP",
        
        SecTrans = "🌐 Tradução de IA (Idioma)", SecTransDesc = "Altere o idioma do painel em tempo real.",
        SecInterface = "Interface & Visualização", SecInterfaceDesc = "Configurações gerais do painel.",
        InterfaceToggle = "Ativar Interface", NotifToggle = "Mostrar Notificações", ResetBtn = "Repor Configurações",
        SecPerf = "Performance & Desempenho", SecPerfDesc = "Ajustes de desempenho do cliente e monitores.",
        PerfMode = "Modo Desempenho", ReduceFX = "Reduzir Efeitos Visuais", FPSDisp = "Mostrar FPS", PingDisp = "Mostrar Ping",
        SecKeys = "Atalhos (Keybinds)", SecKeysDesc = "Defina as teclas de acesso rápido.",
        KeybindTitle = "Tecla do Menu (Abrir/Fechar)",
        SecTheme = "Temas & Cores", SecThemeDesc = "Personalize o visual e a paleta de cores.",
        ThemeTitle = "Tema Base"
    },
    ["English"] = {
        MoveTitle = "Advanced Movement Controls", MoveDesc = "Manage speed, jump, flight and collision.",
        ESPTitle = "Individual ESP Settings", ESPDesc = "Toggle each visual element separately.",
        LangNotif = "Language changed to: English",
        
        AimToggle = "Enable Aim Assist / Lock", AimFOV = "Aim Assist FOV", AimSmooth = "Smoothness", TargetPart = "Target Part", TeamCheck = "Team Check",
        JumpBoost = "Jump Booster", JumpInf = "Infinite Jump", SpeedBoost = "Speed Booster", SpeedWalk = "Walk Speed", Fly = "Fly", FlySpeed = "Fly Speed", NoClip = "No Clip", NoClipSpeed = "No Clip Speed",
        ESPLine = "ESP Line (Top)", ESPBox = "ESP Box", ESPHealth = "ESP Health", ESPDist = "ESP Distance", ESPName = "ESP Name",
        
        SecTrans = "🌐 AI Translation (Language)", SecTransDesc = "Change panel language in real time.",
        SecInterface = "Interface & Display", SecInterfaceDesc = "General panel settings.",
        InterfaceToggle = "Enable Interface", NotifToggle = "Show Notifications", ResetBtn = "Reset Settings",
        SecPerf = "Performance & Optimization", SecPerfDesc = "Client performance adjustments and monitors.",
        PerfMode = "Performance Mode", ReduceFX = "Reduce Visual Effects", FPSDisp = "FPS Display", PingDisp = "Ping Display",
        SecKeys = "Keybinds", SecKeysDesc = "Set quick access keys.",
        KeybindTitle = "Menu Open/Close Key",
        SecTheme = "Themes & Colors", SecThemeDesc = "Customize the visual and color palette.",
        ThemeTitle = "Base Theme"
    },
    ["Español"] = {
        MoveTitle = "Controles de Movimiento Avançados", MoveDesc = "Administre velocidad, salto, vuelo y colisión.",
        ESPTitle = "Configuración de ESP Individual", ESPDesc = "Active cada elemento visual por separado.",
        LangNotif = "Idioma cambiado a: Español",
        
        AimToggle = "Activar Aim Assist / Lock", AimFOV = "FOV de Aim Assist", AimSmooth = "Suavidad", TargetPart = "Parte Objetivo", TeamCheck = "Verificación de Equipo",
        JumpBoost = "Booster de Salto", JumpInf = "Salto Infinito", SpeedBoost = "Booster de Velocidad", SpeedWalk = "Velocidad (Caminata)", Fly = "Vuelo (Fly)", FlySpeed = "Velocidad de Vuelo", NoClip = "No Clip", NoClipSpeed = "Velocidad (No Clip)",
        ESPLine = "Línea ESP (Desde Arriba)", ESPBox = "Caja ESP", ESPHealth = "ESP Salud", ESPDist = "ESP Distancia", ESPName = "ESP Nombre",
        
        SecTrans = "🌐 Traducción de IA (Idioma)", SecTransDesc = "Cambie el idioma del panel en tiempo real.",
        SecInterface = "Interfaz y Visualización", SecInterfaceDesc = "Configuraciones generales del panel.",
        InterfaceToggle = "Habilitar Interfaz", NotifToggle = "Mostrar Notificaciones", ResetBtn = "Restablecer Ajustes",
        SecPerf = "Rendimiento y Optimización", SecPerfDesc = "Ajustes de rendimiento del cliente y monitores.",
        PerfMode = "Modo Rendimiento", ReduceFX = "Reduzir Efeitos Visuais", FPSDisp = "Mostrar FPS", PingDisp = "Mostrar Ping",
        SecKeys = "Atajos (Keybinds)", SecKeysDesc = "Defina las teclas de acesso rápido.",
        KeybindTitle = "Tecla de Menú (Abrir/Cerrar)",
        SecTheme = "Temas y Colores", SecThemeDesc = "Personalice el aspecto y la paleta de cores.",
        ThemeTitle = "Tema Base"
    }
}

local ShowNotifs = true
local CurrentLanguage = "Português"

local function ApplyTranslation(langName)
    CurrentLanguage = langName
    local t = Translations[langName] or Translations["Português"]
    
    MovementPara:SetTitle(t.MoveTitle)
    MovementPara:SetDesc(t.MoveDesc)
    JumpBoost_Toggle:SetTitle(t.JumpBoost)
    JumpInf_Toggle:SetTitle(t.JumpInf)
    SpeedBoost_Toggle:SetTitle(t.SpeedBoost)
    Speed_Slider:SetTitle(t.SpeedWalk)
    Fly_Toggle:SetTitle(t.Fly)
    FlySpeed_Slider:SetTitle(t.FlySpeed)
    NoClip_Toggle:SetTitle(t.NoClip)
    NoClipSpeed_Slider:SetTitle(t.NoClipSpeed)
    
    VisualsPara:SetTitle(t.ESPTitle)
    VisualsPara:SetDesc(t.ESPDesc)
    ESPLine_Toggle:SetTitle(t.ESPLine)
    ESPBox_Toggle:SetTitle(t.ESPBox)
    ESPHealth_Toggle:SetTitle(t.ESPHealth)
    ESPDistance_Toggle:SetTitle(t.ESPDist)
    ESPName_Toggle:SetTitle(t.ESPName)
    
    AimToggle:SetTitle(t.AimToggle)
    AimFOV_Slider:SetTitle(t.AimFOV)
    AimSmooth_Slider:SetTitle(t.AimSmooth)
    TargetPart_Drop:SetTitle(t.TargetPart)
    TeamCheck_Toggle:SetTitle(t.TeamCheck)
    
    pcall(function()
        SecTransPara:SetTitle(t.SecTrans)
        SecTransPara:SetDesc(t.SecTransDesc)
        Translate_Drop:SetTitle(t.SecTrans)
        
        SecInterfacePara:SetTitle(t.SecInterface)
        SecInterfacePara:SetDesc(t.SecInterfaceDesc)
        Interface_Toggle:SetTitle(t.InterfaceToggle)
        Notif_Toggle:SetTitle(t.NotifToggle)
        Reset_Btn:SetTitle(t.ResetBtn)
        
        SecPerfPara:SetTitle(t.SecPerf)
        SecPerfPara:SetDesc(t.SecPerfDesc)
        PerfMode_Toggle:SetTitle(t.PerfMode)
        ReduceFX_Toggle:SetTitle(t.ReduceFX)
        FPSDisp_Toggle:SetTitle(t.FPSDisp)
        PingDisp_Toggle:SetTitle(t.PingDisp)
        
        SecKeysPara:SetTitle(t.SecKeys)
        SecKeysPara:SetDesc(t.SecKeysDesc)
        MenuKeybind:SetTitle(t.KeybindTitle)
        
        SecThemePara:SetTitle(t.SecTheme)
        SecThemePara:SetDesc(t.SecThemeDesc)
        Theme_Drop:SetTitle(t.ThemeTitle)
    end)
end

SecTransPara = Tabs.Settings:AddParagraph({ Title = "🌐 Tradução de IA (Idioma)", Content = "Altere o idioma do painel em tempo real." })
Translate_Drop = Tabs.Settings:AddDropdown("AITranslateDropdown", {
    Title = "🌐 Tradução de IA (Idioma)",
    Values = {"Português", "Português (Portugal)", "English", "Español"},
    Default = 1
})
Translate_Drop:OnChanged(function(v)
    ApplyTranslation(v)
    local t = Translations[v] or Translations["Português"]
    if ShowNotifs then
        Fluent:Notify({ Title = "Tradução IA", Content = t.LangNotif, Duration = 3 })
    end
end)

SecInterfacePara = Tabs.Settings:AddParagraph({ Title = "Interface & Visualização", Content = "Configurações gerais do painel." })
Interface_Toggle = Tabs.Settings:AddToggle("EnableInterface", { Title = "Habilitar Interface", Default = true })
Interface_Toggle:OnChanged(function(v) Window.Enabled = v end)

Notif_Toggle = Tabs.Settings:AddToggle("ShowNotifications", { Title = "Mostrar Notificações", Default = true })
Notif_Toggle:OnChanged(function(v) ShowNotifs = v end)

Reset_Btn = Tabs.Settings:AddButton({ Title = "Restaurar Configurações", Callback = function()
    if ShowNotifs then Fluent:Notify({ Title = "Settings", Content = (CurrentLanguage == "English" and "Settings reset!" or "Configurações restauradas!"), Duration = 2 }) end
end })

SecPerfPara = Tabs.Settings:AddParagraph({ Title = "Performance & Otimização", Content = "Ajustes de desempenho do cliente e monitores." })

PerfMode_Toggle = Tabs.Settings:AddToggle("PerformanceMode", { Title = "Modo Performance", Default = false })
PerfMode_Toggle:OnChanged(function(v)
    if v then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            end
        end
    else
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        Lighting.GlobalShadows = true
    end
    if ShowNotifs then
        Fluent:Notify({ Title = "Performance", Content = v and "Modo Performance ativado (Gráficos otimizados)." or "Modo Performance desativado.", Duration = 3 })
    end
end)

ReduceFX_Toggle = Tabs.Settings:AddToggle("ReduceVisualEffects", { Title = "Reduzir Efeitos Visuais", Default = false })
ReduceFX_Toggle:OnChanged(function(v)
    ESP_States.ShowVisuals = not v
    if ShowNotifs then
        Fluent:Notify({ Title = "Performance", Content = v and "Efeitos visuais reduzidos." or "Efeitos reativados.", Duration = 2 })
    end
end)

local FpsDisplayActive = false
local PingDisplayActive = false

local OverlayText = Drawing.new("Text")
OverlayText.Size = 16
OverlayText.Position = Vector2.new(25, 20)
OverlayText.Color = Color3.fromRGB(0, 255, 100)
OverlayText.Outline = true
OverlayText.Visible = false

FPSDisp_Toggle = Tabs.Settings:AddToggle("FPSDisplay", { Title = "Display de FPS", Default = false })
FPSDisp_Toggle:OnChanged(function(v) FpsDisplayActive = v end)

PingDisp_Toggle = Tabs.Settings:AddToggle("PingDisplay", { Title = "Display de Ping", Default = false })
PingDisp_Toggle:OnChanged(function(v) PingDisplayActive = v end)

RunService.RenderStepped:Connect(function()
    if FpsDisplayActive or PingDisplayActive then
        OverlayText.Visible = true
        local fps = math.floor(1 / RunService.RenderStepped:Wait())
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        
        local textOut = ""
        if FpsDisplayActive then textOut = textOut .. "FPS: " .. fps end
        if PingDisplayActive then 
            if textOut ~= "" then textOut = textOut .. " | " end
            textOut = textOut .. "Ping: " .. ping .. "ms"
        end
        OverlayText.Text = textOut
    else
        OverlayText.Visible = false
    end
end)

SecKeysPara = Tabs.Settings:AddParagraph({ Title = "Atalhos (Keybinds)", Content = "Defina as teclas de acesso rápido." })

MenuKeybind = Tabs.Settings:AddKeybind("MenuKey", {
    Title = "Tecla de Menu (Abrir/Fechar)",
    Mode = "Toggle",
    Default = Enum.KeyCode.LeftControl,
    Callback = function()
        Window:Toggle()
    end
})

SecThemePara = Tabs.Settings:AddParagraph({ Title = "Temas & Cores", Content = "Personalize o visual e a paleta de cores." })
Theme_Drop = Tabs.Settings:AddDropdown("ThemeSelect", { Title = "Tema Base", Values = {"Dark", "Light", "Darker"}, Default = 1 })
Theme_Drop:OnChanged(function(v)
    pcall(function() Fluent:SetTheme(v) end)
end)

-- Inicializa na primeira aba
Window:SelectTab(1)
Fluent:Notify({
    Title = "Atualizado com Sucesso!",
    Content = "O aimbot agora só funciona quando você segura o botão esquerdo do mouse.",
    Duration = 5
})
