local ok, err = pcall(function()

pcall(function() warn("[Aurora|MM2] script start") end)
pcall(function() if rconsoleprint then rconsoleprint("[Aurora|MM2] script start\n") end end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local hookmetamethod = hookmetamethod
local getrawmetatable = getrawmetatable
local setreadonly = setreadonly
local getnamecallmethod = getnamecallmethod
local gethui = gethui
local Drawing = Drawing

local TITLE = "Project Aurora | MM2"

local AimEnabled, AimSensitivity, AimPart, AimWallCheck, AimConn = false, 0.3, "Head", false, nil
local ShootBtnEnabled, LockShootBtn, WallbangEnabled = false, false, true
local ShootGui, ShootBtn, ShootCross, ShootPing, ShootPingStroke, ShootConn = nil, nil, nil, nil, nil, nil
local ShootHooked, ShootOldNamecall, ShootRemote, CurrentTarget, pingT = false, nil, nil, nil, 0
local KillBtnEnabled, KillAllRunning, KillGui, KillBtn = false, false, nil, nil
local InfJumpEnabled, HideStuffsEnabled, ServerPosEnabled = false, false, false
local infJumpConn, hiddenParts, hideWatchConn = nil, {}, nil
local AntiFlingEnabled, antiFlingLastPos = false, Vector3.zero
local flingDetectConn, flingNeutralConn, detectedFlingers = nil, nil, {}
local RoundTimerEnabled, RT, cachedTimerLabel = false, {}, nil
local CCEnabled, CCColor, CCBright, CCContrast, CCSat = false, Color3.new(1,1,1), 0, 0, 0
local BloomEnabled, BloomInt, BloomSize, BloomThr = false, 1, 24, 1
local SnowEnabled, SnowIntensity = false, 10000
local snowHost, snowNear, snowFar = nil, nil, nil
local AspectEnabled, AspectXScale, AspectYScale = false, 1.0, 0.7
local StatusEnabled, StatusFontName = false, "RobotoMono"
local StatusCol1, StatusCol2 = Color3.fromRGB(255,255,255), Color3.fromRGB(120,200,255)
local StatusFollowTool, StatusPosition = false, "bottom"
local StatusConn, statusGui, linePool = nil, nil, {}
local STATUS_POSITIONS = { ["up"] = 8, ["near middle"] = 35, ["middle"] = 50, ["near bottom"] = 78, ["bottom"] = 92 }
local deathEvents, posHistory, droppedGunHL = {}, {}, {}
local FovShow, FovGradient, FovSpin, FovSpinSpeed, FovFollow, FovSize = false, false, false, 60, "Off", 140
local FovColor = Color3.fromRGB(255,255,255)
local FovPoint1, FovPoint2 = Color3.fromRGB(255,255,255), Color3.fromRGB(80,170,255)
local FovTransparency, FovRotation = 0.5, 45
local FovOutlineOn, FovOutlineColor, FovOutlineThick = true, Color3.fromRGB(255,255,255), 2
local FovGui, FovCircleFrame, FovGradientObj, FovStroke, FovCur = nil, nil, nil, nil, nil
local SP = {}
local ESPEnabled, ESPInnocent, ESPMurder, ESPSheriff = false, true, true, true
local ESPTracers, ESPNames, ESPBoxes, ESPBoxType, ESPNameFont = false, true, true, "Normal", 0
local ESPConn, ESPObjs = nil, {}
local InnocentColor, MurderColor = Color3.fromRGB(0,255,0), Color3.fromRGB(255,0,0)
local SheriffColor, TracerColor = Color3.fromRGB(0,100,255), Color3.fromRGB(255,255,255)

local function worldToScreen(pos)
    local vp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X, vp.Y), (onScreen and vp.Z > 0), vp.Z
end
local function screenCenter() return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end
local function screenBottom() return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y) end

local function getPingSec()
    local ping = 0.1
    pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000 end)
    return math.max(ping, 0.05)
end

local function isVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    if direction.Magnitude < 0.5 then return true end
    local okRay, result = pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local exclude = { Camera }
        if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
        table.insert(exclude, targetPart.Parent)
        params.FilterDescendantsInstances = exclude
        return Workspace:Raycast(origin, direction, params)
    end)
    if not okRay then return true end
    return result == nil
end

local function getRole(plr)
    if plr == LocalPlayer then return "Local" end
    local function checkFor(container, names)
        if not container then return false end
        for _, name in ipairs(names) do
            if container:FindFirstChild(name) or container:FindFirstChild(name, true) then return true end
        end
        return false
    end
    local char, backpack = plr.Character, plr:FindFirstChild("Backpack")
    if checkFor(char, {"Knife","DefaultKnife"}) or checkFor(backpack, {"Knife","DefaultKnife"}) then return "Murder" end
    if checkFor(char, {"Gun"}) or checkFor(backpack, {"Gun"}) then return "Sheriff" end
    return "Innocent"
end

local function roleColor(role)
    if role == "Murder" then return MurderColor end
    if role == "Sheriff" then return SheriffColor end
    return InnocentColor
end
local function roleEnabled(role)
    if role == "Murder" then return ESPMurder end
    if role == "Sheriff" then return ESPSheriff end
    return ESPInnocent
end

local function nearestPlayerToCenter()
    local center = screenCenter()
    local best, bestD = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local sp, on = worldToScreen(root.Position)
                if on then
                    local d = (sp - center).Magnitude
                    if d < bestD then bestD = d; best = plr end
                end
            end
        end
    end
    return best
end

local function getToolPos()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return nil end
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if handle then return handle.Position end
    local okP, piv = pcall(function() return tool:GetPivot().Position end)
    if okP then return piv end
    return nil
end

local function resolveFont(name)
    if name == "Arial" then
        local ok, f = pcall(function() return Enum.Font.Arial end)
        if ok then return f end
        return Enum.Font.Legacy
    elseif name == "RobotoMono" then
        local ok, f = pcall(function() return Enum.Font.RobotoMono end)
        if ok then return f end
        return Enum.Font.Code
    elseif name == "Arcade" then
        local ok, f = pcall(function() return Enum.Font.Arcade end)
        if ok then return f end
        return Enum.Font.Michroma
    elseif name == "FedokaOne" then
        local ok, f = pcall(function() return Enum.Font.FedokaOne end)
        if ok then return f end
        local ok2, f2 = pcall(function() return Enum.Font.FredokaOne end)
        if ok2 then return f2 end
        return Enum.Font.GothamBold
    end
    return Enum.Font.Gotham
end

local function setDrawFont(obj, idx) pcall(function() obj.Font = idx end) end

local function safeParent(gui)
    pcall(function()
        local h = gethui and gethui()
        if h then gui.Parent = h end
    end)
    if gui.Parent then return end
    pcall(function() gui.Parent = CoreGui end)
    if gui.Parent then return end
    pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
end

local function findKnifeTool()
    for _, loc in ipairs({LocalPlayer.Character, LocalPlayer.Backpack}) do
        if loc then
            for _, item in ipairs(loc:GetChildren()) do
                if item:IsA("Tool") and item.Name:lower():find("knife") then return item end
            end
        end
    end
    return nil
end

local function findGunDrop()
    local okF, direct = pcall(function() return Workspace:FindFirstChild("GunDrop", true) end)
    if okF and direct then return direct end
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") and obj.Name:lower():find("gun") then return obj end
    end
    return nil
end

local function hookCharForDeath(char, plr)
    pcall(function()
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                deathEvents[#deathEvents + 1] = { name = plr.DisplayName or plr.Name, untilT = os.clock() + 4 }
            end)
        end
    end)
end

pcall(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then hookCharForDeath(plr.Character, plr) end
        plr.CharacterAdded:Connect(function(c) hookCharForDeath(c, plr) end)
    end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function(c) hookCharForDeath(c, plr) end)
    end)
end)

local function getPlayerData()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remote = extras and extras:FindFirstChild("GetPlayerData")
    if not remote then return nil end
    local okR, data = pcall(function() return remote:InvokeServer() end)
    if not okR or type(data) ~= "table" then return nil end
    return data
end

local function getMurder()
    local data = getPlayerData()
    if not data then return nil end
    for i, plrData in pairs(data) do
        if type(plrData) == "table" and plrData.Role == "Murderer" then
            local murd = Players:FindFirstChild(i)
            if murd and murd.Character then
                local hrp = murd.Character:FindFirstChild("HumanoidRootPart")
                if hrp then return hrp end
            end
        end
    end
    return nil
end

local function getShootRemote()
    local backpack, character = LocalPlayer.Backpack, LocalPlayer.Character
    if backpack and backpack:FindFirstChild("Gun") then
        return backpack:FindFirstChild("Gun"):FindFirstChild("Shoot", true)
    elseif character and character:FindFirstChild("Gun") then
        return character:FindFirstChild("Gun"):FindFirstChild("Shoot", true)
    end
    return nil
end

local SilentEnabled, WeaponService, SilentHooked, OrigGetMouseTargetCFrame = false, nil, false, nil

local function hasToolSilent(player, names)
    for _, loc in ipairs({player.Character, player.Backpack}) do
        if loc then
            for _, item in ipairs(loc:GetChildren()) do
                if item:IsA("Tool") then
                    for _, n in ipairs(names) do
                        if item.Name == n then return true end
                    end
                end
            end
        end
    end
    return false
end

local function getLocalTool()
    for _, loc in ipairs({LocalPlayer.Character, LocalPlayer.Backpack}) do
        if loc then
            for _, item in ipairs(loc:GetChildren()) do
                if item:IsA("Tool") then
                    if item.Name == "DefaultKnife" then return "Knife" end
                    if item.Name == "Knife" or item.Name == "Gun" then return item.Name end
                end
            end
        end
    end
    return nil
end

local function isValidTargetSilent(player, localTool)
    if localTool == "Gun" then
        return hasToolSilent(player, {"Knife","DefaultKnife"})
    elseif localTool == "Knife" then
        return hasToolSilent(player, {"Gun"}) or not hasToolSilent(player, {"Knife","DefaultKnife"})
    end
    return false
end

local function getSilentTarget()
    local localTool = getLocalTool()
    if not localTool then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local closest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and isValidTargetSilent(p, localTool) then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local d = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if d < dist then dist = d; closest = hrp end
                end
            end
        end
    end
    return closest
end

local function installSilentHook()
    if SilentHooked then return true end
    local okReq, ws = pcall(function() return require(ReplicatedStorage.ClientServices.WeaponService) end)
    if not okReq or not ws then
        pcall(function() Library:Notify("Silent aim: WeaponService not found", 3) end)
        return false
    end
    WeaponService = ws
    if not WeaponService.GetMouseTargetCFrame then
        pcall(function() Library:Notify("Silent aim: GetMouseTargetCFrame missing", 3) end)
        return false
    end
    OrigGetMouseTargetCFrame = WeaponService.GetMouseTargetCFrame
    WeaponService.GetMouseTargetCFrame = function(self)
        if SilentEnabled then
            local hrp = getSilentTarget()
            if hrp then return CFrame.new(hrp.Position + Vector3.new(0, 0.5, 0)) end
        end
        return OrigGetMouseTargetCFrame(self)
    end
    SilentHooked = true
    pcall(function() Library:Notify("Silent aim hooked", 3) end)
    return true
end

local ShootOffset = 2.8

local function getLocalRole()
    local data = getPlayerData()
    if not data then return "Unknown" end
    local mine = data[LocalPlayer.Name]
    if mine and type(mine) == "table" and mine.Role then return mine.Role end
    return "Unknown"
end

local function isLocalSheriff()
    local role = getLocalRole()
    if role == "Sheriff" or role == "Hero" then return true end
    local char, bp = LocalPlayer.Character, LocalPlayer.Backpack
    if (char and char:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun")) then return true end
    return false
end

local function findMurdererPlayer()
    local data = getPlayerData()
    if data then
        for name, info in pairs(data) do
            if type(info) == "table" and info.Role == "Murderer" then
                local plr = Players:FindFirstChild(name)
                if plr and plr ~= LocalPlayer then return plr end
            end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if plr.Character:FindFirstChild("Knife") or plr.Character:FindFirstChild("DefaultKnife") then return plr end
        end
    end
    return nil
end

local function findSheriffThatsNotMe()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Gun") then return plr end
    end
    return nil
end

local function getPredictedPosition(player, offset)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp.Position + hrp.Velocity * (offset * getPingSec())
end

local function shootMurderer()
    if not isLocalSheriff() then Library:Notify("You're not sheriff/hero.") return end
    local murderer = findMurdererPlayer() or findSheriffThatsNotMe()
    if not murderer then Library:Notify("No murderer (or sheriff) to shoot.") return end
    if not LocalPlayer.Character:FindFirstChild("Gun") then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if LocalPlayer.Backpack:FindFirstChild("Gun") and hum then
            hum:EquipTool(LocalPlayer.Backpack:FindFirstChild("Gun"))
            task.wait(0.15)
        else
            Library:Notify("You don't have the gun..?")
            return
        end
    end
    local murdererHRP = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererHRP then Library:Notify("Could not find the murderer's HumanoidRootPart.") return end
    local predicted = getPredictedPosition(murderer, ShootOffset)
    if not predicted then Library:Notify("Prediction failed.") return end
    local okFire = pcall(function()
        LocalPlayer.Character:WaitForChild("Gun"):WaitForChild("Shoot"):FireServer(
            CFrame.new(LocalPlayer.Character.RightHand.Position),
            CFrame.new(predicted)
        )
    end)
    if not okFire then Library:Notify("Shoot failed.", 3) end
end

local FlingBusy = false
local function flingPlayer(target)
    if FlingBusy then Library:Notify("Fling already running.", 3) return end
    if not target or not target.Character then Library:Notify("Fling: no valid target character.") return end
    local myChar = LocalPlayer.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    local myRoot = myHum and myHum.RootPart
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    local tRoot = tHum and tHum.RootPart
    if not (myHum and myRoot and tRoot) then Library:Notify("Fling: missing parts.") return end
    FlingBusy = true
    Library:Notify("Fling: launching " .. (target.DisplayName or target.Name), 3)
    local oldPos = myRoot.CFrame
    local oldFPDH = Workspace.FallenPartsDestroyHeight
    pcall(function() Workspace.FallenPartsDestroyHeight = 0 / 0 end)
    local bv = Instance.new("BodyVelocity")
    bv.Name = "AuroraFlingVel"
    bv.Velocity = Vector3.new(9e8, 9e8, 9e8)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = myRoot
    pcall(function() myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end)
    local deadline, spin, launched = tick() + 2, 0, false
    pcall(function()
        while tick() < deadline do
            if not (myRoot and myRoot.Parent and tRoot and tRoot.Parent) then break end
            spin = spin + 100
            local offset = CFrame.new(math.random(-2, 2), 1.5, math.random(-2, 2))
            myRoot.CFrame = CFrame.new(tRoot.Position) * offset * CFrame.Angles(math.rad(spin), 0, 0)
            myRoot.Velocity = Vector3.new(9e7, 9e8, 9e7)
            myRoot.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            task.wait()
            if tRoot.Velocity.Magnitude > 500 then launched = true break end
        end
    end)
    pcall(function() bv:Destroy() end)
    pcall(function() myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
    pcall(function() Camera.CameraSubject = myHum end)
    pcall(function()
        for _ = 1, 50 do
            myRoot.CFrame = oldPos * CFrame.new(0, 0.5, 0)
            myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
            for _, part in ipairs(myChar:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            if (myRoot.Position - oldPos.Position).Magnitude < 25 then break end
            task.wait()
        end
    end)
    pcall(function() Workspace.FallenPartsDestroyHeight = oldFPDH end)
    Library:Notify(launched and "Fling: launched!" or "Fling: finished.", 3)
    FlingBusy = false
end

local function startAntiFling()
    if flingDetectConn then return end
    flingDetectConn = RunService.Heartbeat:Connect(function()
        for _, pl in ipairs(Players:GetPlayers()) do
            local char = pl.Character
            local root = char and char.PrimaryPart
            if char and root then
                pcall(function()
                    if root.AssemblyAngularVelocity.Magnitude > 50 or root.AssemblyLinearVelocity.Magnitude > 100 then
                        if not detectedFlingers[pl.Name] then
                            detectedFlingers[pl.Name] = true
                            Library:Notify("Flinger detected: " .. pl.Name, 3)
                        end
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.CanCollide = false
                                p.AssemblyAngularVelocity = Vector3.zero
                                p.AssemblyLinearVelocity = Vector3.zero
                                p.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0, 0, 0)
                            end
                        end
                    end
                end)
            end
        end
    end)
    flingNeutralConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local root = char and char.PrimaryPart
        if root then
            pcall(function()
                if root.AssemblyLinearVelocity.Magnitude > 250 or root.AssemblyAngularVelocity.Magnitude > 250 then
                    Library:Notify("You were flung. Neutralizing!", 3)
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    if antiFlingLastPos ~= Vector3.zero then root.CFrame = CFrame.new(antiFlingLastPos) end
                else
                    antiFlingLastPos = root.Position
                end
            end)
        end
    end)
end

local function stopAntiFling()
    if flingDetectConn then flingDetectConn:Disconnect() flingDetectConn = nil end
    if flingNeutralConn then flingNeutralConn:Disconnect() flingNeutralConn = nil end
    detectedFlingers = {}
end

RT.Label = Drawing.new("Text")
RT.Label.Size = 20
RT.Label.Center = true
RT.Label.Outline = true
RT.Label.Color = Color3.fromRGB(255, 255, 255)
RT.Label.Visible = false

local function findTimerLabel()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local best = nil
    pcall(function()
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = d.Text or ""
                if t:find("%d+:%d%d") then best = d break end
            end
        end
    end)
    return best
end

RunService.RenderStepped:Connect(function()
    if not RoundTimerEnabled then RT.Label.Visible = false return end
    if not cachedTimerLabel or not cachedTimerLabel.Parent then cachedTimerLabel = findTimerLabel() end
    if cachedTimerLabel then
        local vp = Camera.ViewportSize
        RT.Label.Text = "[ " .. cachedTimerLabel.Text .. " ]"
        RT.Label.Position = Vector2.new(vp.X / 2, 30)
        RT.Label.Visible = true
    else
        RT.Label.Visible = false
    end
end)

pcall(function()
    for _, e in ipairs(Lighting:GetChildren()) do
        if e.Name == "AURORA_CC" or e.Name == "AURORA_BLOOM" then e:Destroy() end
    end
end)

local ccWorld = Instance.new("ColorCorrectionEffect")
ccWorld.Name = "AURORA_CC"
ccWorld.Enabled = false
ccWorld.TintColor = Color3.new(1, 1, 1)
ccWorld.Brightness = 0
ccWorld.Contrast = 0
ccWorld.Saturation = 0
ccWorld.Parent = Lighting

local bloomFx = Instance.new("BloomEffect")
bloomFx.Name = "AURORA_BLOOM"
bloomFx.Enabled = false
bloomFx.Intensity = 1
bloomFx.Size = 24
bloomFx.Threshold = 1
bloomFx.Parent = Lighting

local function applyCC()
    ccWorld.Enabled = CCEnabled
    ccWorld.TintColor = CCColor
    ccWorld.Brightness = CCBright
    ccWorld.Contrast = CCContrast
    ccWorld.Saturation = CCSat
end

local function applyBloom()
    bloomFx.Enabled = BloomEnabled
    bloomFx.Intensity = BloomInt
    bloomFx.Size = BloomSize
    bloomFx.Threshold = BloomThr
end

local function toggleSnow(enable)
    if not enable then
        if snowHost then snowHost:Destroy() snowHost = nil end
        snowNear, snowFar = nil, nil
        return
    end
    if snowHost then snowHost:Destroy() end
    snowHost = Instance.new("Part")
    snowHost.Name = "AuroraSnowHost"
    snowHost.Anchored = true
    snowHost.CanCollide = false
    snowHost.Transparency = 1
    snowHost.Size = Vector3.new(250, 1, 250)
    snowHost.Parent = Workspace
    local function createEmitter(name, size, rate)
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = name
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        emitter.Size = NumberSequence.new(size)
        emitter.Rate = rate
        emitter.Lifetime = NumberRange.new(3, 6)
        emitter.Speed = NumberRange.new(100, 140)
        emitter.VelocityInheritance = 0
        emitter.EmissionDirection = Enum.NormalId.Bottom
        emitter.Shape = Enum.ParticleEmitterShape.Box
        emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        emitter.ShapePartial = Vector3.new(1, 0, 1)
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.05, 0),
            NumberSequenceKeypoint.new(0.95, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        emitter.Parent = snowHost
        return emitter
    end
    snowNear = createEmitter("NearSnow", 3, SnowIntensity * 0.3)
    snowNear.ZOffset = 2
    snowFar = createEmitter("FarSnow", 1.5, SnowIntensity * 0.7)
    snowFar.ZOffset = -2
end

local function updateSnowRate()
    if snowNear then snowNear.Rate = SnowIntensity * 0.3 end
    if snowFar then snowFar.Rate = SnowIntensity * 0.7 end
end

RunService.Heartbeat:Connect(function()
    if SnowEnabled and snowHost and snowHost.Parent then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then snowHost.CFrame = hrp.CFrame * CFrame.new(0, 100, 0) end
    end
end)

local function killAllSequence()
    if KillAllRunning then Library:Notify("Kill All already running.", 3) return end
    KillAllRunning = true
    Library:Notify("Kill All: waiting for knife...", 3)
    local knife, waited = nil, 0
    while not knife and waited < 60 and KillAllRunning do
        knife = findKnifeTool()
        if not knife then task.wait(0.2) waited = waited + 0.2 end
    end
    if not knife then Library:Notify("Kill All: no knife found.", 3) KillAllRunning = false return end
    if knife.Parent == LocalPlayer.Backpack then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(knife) end) task.wait(0.15) end
    end
    Library:Notify("Kill All: ACTIVE (3s)", 3)
    local startT = os.clock()
    while os.clock() - startT < 3 and KillAllRunning do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        pcall(function()
                            tRoot.CFrame = hrp.CFrame * CFrame.new(math.random(-2, 2), 0, math.random(-2, 2))
                        end)
                    end
                end
            end
            pcall(function() knife:Activate() end)
            pcall(function()
                for _, obj in ipairs(knife:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        pcall(function() obj:FireServer() end)
                        pcall(function() obj:FireServer(hrp.Position) end)
                    end
                end
            end)
        end
        task.wait(0.05)
    end
    Library:Notify("Kill All: done.", 3)
    KillAllRunning = false
end

local function makeDraggable(btn)
    local dragging, dragStart, startPos = false, Vector2.zero, UDim2.new(0, 0, 0, 0)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function createKillGui()
    if KillGui then KillGui:Destroy() end
    KillGui = Instance.new("ScreenGui")
    KillGui.Name = "MM2_KillAllBtn"
    KillGui.ResetOnSpawn = false
    KillGui.DisplayOrder = 994
    KillGui.IgnoreGuiInset = true
    safeParent(KillGui)
    KillBtn = Instance.new("TextButton")
    KillBtn.Text = "KILL ALL"
    KillBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    KillBtn.Size = UDim2.new(0, 100, 0, 100)
    KillBtn.Position = UDim2.new(0.5, 0, 0.52, 0)
    KillBtn.BackgroundColor3 = Color3.fromRGB(30, 12, 28)
    KillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    KillBtn.Font = Enum.Font.RobotoMono
    KillBtn.TextSize = 14
    KillBtn.BorderSizePixel = 0
    KillBtn.AutoButtonColor = false
    KillBtn.Parent = KillGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = KillBtn
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 40, 120)
    stroke.Thickness = 2
    stroke.Parent = KillBtn
    makeDraggable(KillBtn)
    KillBtn.MouseButton1Click:Connect(function() task.spawn(killAllSequence) end)
    KillBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then task.spawn(killAllSequence) end
    end)
end

local function destroyKillGui()
    if KillGui then KillGui:Destroy() KillGui = nil KillBtn = nil end
end

local function installShootHook()
    if ShootHooked then return true end
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    ShootOldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if ShootRemote and self == ShootRemote and method == "FireServer" then
            if not CurrentTarget or not CurrentTarget.Parent then
                return ShootOldNamecall(self, ...)
            end
            if not WallbangEnabled and not isVisible(CurrentTarget) then
                return ShootOldNamecall(self, ...)
            end
            args[1] = CurrentTarget.CFrame + Vector3.new(0, 3, 0)
            args[2] = CurrentTarget.CFrame
            return ShootOldNamecall(self, unpack(args))
        end
        return ShootOldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    ShootHooked = true
    return true
end

local function removeShootHook()
    if not ShootHooked then return end
    ShootRemote = nil
    CurrentTarget = nil
    ShootHooked = false
end

local function createShootGui()
    if ShootGui then ShootGui:Destroy() end
    ShootGui = Instance.new("ScreenGui")
    ShootGui.Name = "MM2_ShootBtn"
    ShootGui.ResetOnSpawn = false
    ShootGui.DisplayOrder = 995
    ShootGui.IgnoreGuiInset = true
    safeParent(ShootGui)
    ShootBtn = Instance.new("TextButton")
    ShootBtn.Text = ""
    ShootBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    ShootBtn.Size = UDim2.new(0, 112, 0, 112)
    ShootBtn.Position = UDim2.new(0.5, 0, 0.70, 0)
    ShootBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    ShootBtn.BorderSizePixel = 0
    ShootBtn.AutoButtonColor = false
    ShootBtn.Parent = ShootGui
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 16, 22)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(24, 16, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 16))
    })
    bgGrad.Rotation = 90
    bgGrad.Parent = ShootBtn
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = ShootBtn
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 60, 70)
    stroke.Thickness = 2
    stroke.Parent = ShootBtn
    ShootPing = Instance.new("Frame")
    ShootPing.AnchorPoint = Vector2.new(0.5, 0.5)
    ShootPing.Position = UDim2.new(0.5, 0, 0.5, 0)
    ShootPing.Size = UDim2.new(0, 112, 0, 112)
    ShootPing.BackgroundTransparency = 1
    ShootPing.ZIndex = 0
    ShootPing.Parent = ShootBtn
    local pingCorner = Instance.new("UICorner")
    pingCorner.CornerRadius = UDim.new(0, 18)
    pingCorner.Parent = ShootPing
    ShootPingStroke = Instance.new("UIStroke")
    ShootPingStroke.Color = Color3.fromRGB(255, 70, 80)
    ShootPingStroke.Thickness = 1.5
    ShootPingStroke.Parent = ShootPing
    ShootCross = Instance.new("Frame")
    ShootCross.AnchorPoint = Vector2.new(0.5, 0.5)
    ShootCross.Position = UDim2.new(0.5, 0, 0.42, 0)
    ShootCross.Size = UDim2.new(0, 44, 0, 44)
    ShootCross.BackgroundTransparency = 1
    ShootCross.Parent = ShootBtn
    local function mkTick(name, size, pos, color)
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = size
        f.Position = pos
        f.BackgroundColor3 = color or Color3.fromRGB(255, 80, 90)
        f.BorderSizePixel = 0
        f.Parent = ShootCross
        return f
    end
    mkTick("Top", UDim2.new(0, 2.5, 0, 12), UDim2.new(0.5, -1, 0, 0))
    mkTick("Bottom", UDim2.new(0, 2.5, 0, 12), UDim2.new(0.5, -1, 1, -12))
    mkTick("Left", UDim2.new(0, 12, 0, 2.5), UDim2.new(0, 0, 0.5, -1))
    mkTick("Right", UDim2.new(0, 12, 0, 2.5), UDim2.new(1, -12, 0.5, -1))
    local dot = mkTick("Dot", UDim2.new(0, 4, 0, 4), UDim2.new(0.5, -2, 0.5, -2), Color3.fromRGB(255, 255, 255))
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot
    local label = Instance.new("TextLabel")
    label.Text = "SHOOT MURD"
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.new(0, 0, 1, -24)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 13
    label.Parent = ShootBtn
    makeDraggable(ShootBtn)
    ShootBtn.MouseButton1Click:Connect(function() shootMurderer() end)
    ShootBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then shootMurderer() end
    end)
end

local function destroyShootGui()
    if ShootGui then
        ShootGui:Destroy()
        ShootGui = nil
        ShootBtn = nil
        ShootCross = nil
        ShootPing = nil
        ShootPingStroke = nil
    end
end

local function startShootFeature()
    ShootBtnEnabled = true
    pingT = 0
    createShootGui()
    installShootHook()
    if ShootConn then ShootConn:Disconnect() end
    ShootConn = RunService.RenderStepped:Connect(function(dt)
        if not ShootBtnEnabled then return end
        dt = dt or 0.016
        if ShootCross then ShootCross.Rotation = (ShootCross.Rotation + 200 * dt) % 360 end
        if ShootPing and ShootPingStroke then
            pingT = pingT + dt
            local p = (pingT % 1.4) / 1.4
            local s = 112 + p * 54
            ShootPing.Size = UDim2.new(0, s, 0, s)
            ShootPingStroke.Transparency = 0.15 + p * 0.85
        end
        pcall(function()
            ShootRemote = getShootRemote()
            CurrentTarget = getMurder()
        end)
    end)
end

local function stopShootFeature()
    ShootBtnEnabled = false
    destroyShootGui()
    removeShootHook()
    if ShootConn then ShootConn:Disconnect() ShootConn = nil end
end

local function startInfJump()
    if infJumpConn then return end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        if not InfJumpEnabled then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            pcall(function() hum.Jump = true end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        end
    end)
end

local function stopInfJump()
    if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
end

local function isInsideCharacter(part)
    local cur = part
    for _ = 1, 8 do
        cur = cur.Parent
        if not cur then return false end
        if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then return true end
    end
    return false
end

local function hideOnePart(part)
    if not part:IsA("BasePart") then return end
    if isInsideCharacter(part) then return end
    if hiddenParts[part] == nil then
        pcall(function()
            hiddenParts[part] = part.Transparency
            part.Transparency = 0.65
        end)
    end
end

local function startHideStuffs()
    for _, obj in ipairs(Workspace:GetDescendants()) do hideOnePart(obj) end
    if hideWatchConn then hideWatchConn:Disconnect() end
    hideWatchConn = Workspace.DescendantAdded:Connect(function(obj)
        if not HideStuffsEnabled then return end
        hideOnePart(obj)
    end)
end

local function stopHideStuffs()
    for part, orig in pairs(hiddenParts) do pcall(function() part.Transparency = orig end) end
    hiddenParts = {}
    if hideWatchConn then hideWatchConn:Disconnect() hideWatchConn = nil end
end

RunService.RenderStepped:Connect(function()
    if not AspectEnabled then return end
    Camera = Workspace.CurrentCamera
    pcall(function()
        Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, AspectXScale, 0, 0, 0, AspectYScale, 0, 0, 0, 1)
    end)
end)

SP.Box = Drawing.new("Square")
SP.Box.Filled = false
SP.Box.Thickness = 1.5
SP.Box.Color = Color3.fromRGB(0, 255, 255)
SP.Box.Visible = false
SP.Trace = Drawing.new("Line")
SP.Trace.Thickness = 1.5
SP.Trace.Color = Color3.fromRGB(0, 255, 255)
SP.Trace.Visible = false
SP.Label = Drawing.new("Text")
SP.Label.Text = "SERVER"
SP.Label.Size = 12
SP.Label.Center = true
SP.Label.Outline = true
SP.Label.Color = Color3.fromRGB(0, 255, 255)
SP.Label.Visible = false

local function recordPosHistory()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    table.insert(posHistory, { t = os.clock(), p = hrp.Position })
    while #posHistory > 0 and os.clock() - posHistory[1].t > 2 do
        table.remove(posHistory, 1)
    end
end

local function getServerPos()
    local targetT = os.clock() - getPingSec()
    local best = nil
    for _, e in ipairs(posHistory) do
        if e.t <= targetT then best = e else break end
    end
    return best and best.p or nil
end

RunService.RenderStepped:Connect(function()
    recordPosHistory()
    if not ServerPosEnabled then
        SP.Box.Visible = false
        SP.Trace.Visible = false
        SP.Label.Visible = false
        return
    end
    Camera = Workspace.CurrentCamera
    local serverPos = getServerPos()
    if not serverPos then
        SP.Box.Visible = false
        SP.Trace.Visible = false
        SP.Label.Visible = false
        return
    end
    local sp, on = worldToScreen(serverPos)
    if on then
        local size = 60
        SP.Box.Size = Vector2.new(size, size * 1.4)
        SP.Box.Position = Vector2.new(sp.X - size / 2, sp.Y - size * 0.7)
        SP.Box.Visible = true
        SP.Label.Position = Vector2.new(sp.X, sp.Y - size * 0.7 - 16)
        SP.Label.Visible = true
        SP.Trace.From = screenBottom()
        SP.Trace.To = sp
        SP.Trace.Visible = true
    else
        SP.Box.Visible = false
        SP.Trace.Visible = false
        SP.Label.Visible = false
    end
end)

RunService.RenderStepped:Connect(function()
    local gun = findGunDrop()
    local hue = (os.clock() * 0.4) % 1
    local rainbow = Color3.fromHSV(hue, 1, 1)
    if gun and not droppedGunHL[gun] then
        pcall(function()
            local hl = Instance.new("Highlight")
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0
            hl.Parent = gun
            droppedGunHL[gun] = hl
        end)
    end
    for tool, hl in pairs(droppedGunHL) do
        if not tool.Parent then
            pcall(function() hl:Destroy() end)
            droppedGunHL[tool] = nil
        else
            pcall(function()
                hl.FillColor = rainbow
                hl.OutlineColor = rainbow
            end)
        end
    end
end)

local function applyFovGradient()
    if not FovGradientObj then return end
    pcall(function()
        FovGradientObj.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, FovPoint1),
            ColorSequenceKeypoint.new(0.5, FovPoint2),
            ColorSequenceKeypoint.new(1, FovPoint1)
        })
    end)
end

local function applyFovMode()
    if not FovCircleFrame or not FovGradientObj then return end
    FovGradientObj.Enabled = FovGradient
    if FovGradient then
        FovCircleFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    else
        FovCircleFrame.BackgroundColor3 = FovColor
    end
end

local function applyFovOutline()
    if not FovStroke then return end
    FovStroke.Enabled = FovOutlineOn
    FovStroke.Color = FovOutlineColor
    FovStroke.Thickness = FovOutlineThick
end

local function buildFovGui()
    if FovGui then FovGui:Destroy() end
    FovGui = Instance.new("ScreenGui")
    FovGui.Name = "MM2_FOV"
    FovGui.IgnoreGuiInset = true
    FovGui.ResetOnSpawn = false
    FovGui.DisplayOrder = 890
    safeParent(FovGui)
    FovCircleFrame = Instance.new("Frame")
    FovCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    FovCircleFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    FovCircleFrame.Size = UDim2.new(0, FovSize * 2, 0, FovSize * 2)
    FovCircleFrame.BackgroundTransparency = FovTransparency
    FovCircleFrame.BorderSizePixel = 0
    FovCircleFrame.Visible = FovShow
    FovCircleFrame.Parent = FovGui
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = FovCircleFrame
    FovStroke = Instance.new("UIStroke")
    FovStroke.Parent = FovCircleFrame
    FovGradientObj = Instance.new("UIGradient")
    FovGradientObj.Rotation = FovRotation
    FovGradientObj.Parent = FovCircleFrame
    applyFovGradient()
    applyFovMode()
    applyFovOutline()
end

local function destroyFovGui()
    if FovGui then
        FovGui:Destroy()
        FovGui = nil
        FovCircleFrame = nil
        FovGradientObj = nil
        FovStroke = nil
    end
end

buildFovGui()

RunService.RenderStepped:Connect(function(dt)
    Camera = Workspace.CurrentCamera
    if not FovCircleFrame then return end
    if not FovShow then return end
    if FovSpin and FovGradientObj then
        FovRotation = (FovRotation + FovSpinSpeed * (dt or 0.016)) % 360
        FovGradientObj.Rotation = FovRotation
    end
    local goal = screenCenter()
    if FovFollow == "Follow Player" then
        local plr = nearestPlayerToCenter()
        if plr and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local sp, on = worldToScreen(root.Position)
                if on then goal = sp end
            end
        end
    elseif FovFollow == "Follow Tool" then
        local tp = getToolPos()
        if tp then
            local sp, on = worldToScreen(tp)
            if on then goal = sp end
        end
    end
    if not FovCur then FovCur = goal end
    FovCur = FovCur:Lerp(goal, 0.18)
    FovCircleFrame.Position = UDim2.new(0, FovCur.X, 0, FovCur.Y)
    FovCircleFrame.Size = UDim2.new(0, FovSize * 2, 0, FovSize * 2)
end)

local SKY_THRESHOLD = 60

local function ensureStatusGui()
    if statusGui and statusGui.Parent then return statusGui end
    statusGui = Instance.new("ScreenGui")
    statusGui.Name = "MM2_StatusText"
    statusGui.IgnoreGuiInset = true
    statusGui.ResetOnSpawn = false
    statusGui.DisplayOrder = 999
    safeParent(statusGui)
    linePool = {}
    return statusGui
end

local function getLine(i)
    local e = linePool[i]
    if not e then
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Text = ""
        lbl.Font = Enum.Font.RobotoMono
        lbl.TextSize = 18
        lbl.TextTransparency = 0
        lbl.TextStrokeTransparency = 0.2
        lbl.Size = UDim2.new(0, 800, 0, 26)
        lbl.ZIndex = 10
        local grad = Instance.new("UIGradient")
        grad.Parent = lbl
        lbl.Parent = ensureStatusGui()
        e = { lbl = lbl, grad = grad }
        linePool[i] = e
    end
    return e
end

local function hideLines(from)
    for i = from, #linePool do
        linePool[i].lbl.Visible = false
    end
end

local function typeOn(opts, key)
    if not opts then return false end
    if opts[key] == true then return true end
    for _, v in pairs(opts) do
        if v == key then return true end
    end
    return false
end

local function buildStatusLines()
    local lines = {}
    local now = os.clock()
    local sel = Options and Options.StatusTypes and Options.StatusTypes.Value or nil
    if not sel then return lines end
    if typeOn(sel, "idle") then
        lines[#lines + 1] = "projaurora : idle"
    end
    if typeOn(sel, "is in void") then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y > SKY_THRESHOLD then
            lines[#lines + 1] = "(voided)"
        else
            lines[#lines + 1] = "(no voiding)"
        end
    end
    if typeOn(sel, "dead") then
        for i = #deathEvents, 1, -1 do
            local ev = deathEvents[i]
            if ev.untilT > now then
                lines[#lines + 1] = ev.name .. " dead"
            else
                table.remove(deathEvents, i)
            end
        end
    end
    if typeOn(sel, "gun dropped") then
        if findGunDrop() then
            lines[#lines + 1] = "Gun dropped, follow the rainbow highlight"
        end
    end
    return lines
end

local function renderStatus()
    ensureStatusGui()
    local lines = buildStatusLines()
    if #lines == 0 then
        hideLines(1)
        return
    end
    local vp = Camera.ViewportSize
    local font = resolveFont(StatusFontName)
    local lineHeight = 26
    local yPos = STATUS_POSITIONS[StatusPosition] or 92
    local anchor = Vector2.new(vp.X * 0.5, vp.Y * yPos / 100)
    if StatusFollowTool then
        local tp = getToolPos()
        if tp then
            local sp, on = worldToScreen(tp)
            if on then anchor = Vector2.new(sp.X, sp.Y - 26) end
        end
    end
    for li, line in ipairs(lines) do
        local e = getLine(li)
        e.lbl.Text = line
        e.lbl.Font = font
        e.lbl.TextSize = 18
        pcall(function()
            e.grad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, StatusCol1),
                ColorSequenceKeypoint.new(1, StatusCol2)
            })
        end)
        local w = e.lbl.TextBounds.X
        if not w or w <= 0 then w = #line * 11 end
        e.lbl.Position = UDim2.fromOffset(anchor.X - w / 2, anchor.Y - (li - 1) * lineHeight)
        e.lbl.Visible = true
    end
    hideLines(#lines + 1)
end

local function startStatus()
    StatusEnabled = true
    ensureStatusGui()
    if StatusConn then StatusConn:Disconnect() end
    StatusConn = RunService.RenderStepped:Connect(function()
        Camera = Workspace.CurrentCamera
        if not StatusEnabled then
            hideLines(1)
            return
        end
        renderStatus()
    end)
end

local function stopStatus()
    StatusEnabled = false
    if StatusConn then StatusConn:Disconnect() StatusConn = nil end
    hideLines(1)
end

local function closestAimTarget()
    local center = screenCenter()
    local best, bestD = nil, 999999
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not plr.Character then continue end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local partName = AimPart == "Torso" and "HumanoidRootPart" or "Head"
        local part = plr.Character:FindFirstChild(partName, true)
        if not part or not part:IsA("BasePart") then continue end
        if AimWallCheck and not isVisible(part) then continue end
        local sp, on = worldToScreen(part.Position)
        if not on then continue end
        local d = (sp - center).Magnitude
        if d < bestD then bestD = d; best = plr end
    end
    return best
end

local function startAim()
    if AimConn then AimConn:Disconnect() end
    AimConn = RunService.RenderStepped:Connect(function()
        Camera = Workspace.CurrentCamera
        if not AimEnabled then return end
        local target = closestAimTarget()
        if not target or not target.Character then return end
        local partName = AimPart == "Torso" and "HumanoidRootPart" or "Head"
        local part = target.Character:FindFirstChild(partName, true)
        if not part then return end
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, part.Position), AimSensitivity)
    end)
end

local function stopAim()
    if AimConn then AimConn:Disconnect() AimConn = nil end
end

local function makeESP(plr)
    if plr == LocalPlayer or ESPObjs[plr] then return end
    local e = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Trace = Drawing.new("Line"),
        Corners = {}
    }
    e.Box.Filled = false
    e.Box.Thickness = 1
    e.Name.Center = true
    e.Name.Outline = true
    e.Name.Size = 13
    e.Trace.Thickness = 1
    for i = 1, 8 do
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Visible = false
        e.Corners[i] = l
    end
    ESPObjs[plr] = e
end

local function killESP(plr)
    local e = ESPObjs[plr]
    if not e then return end
    e.Box:Remove()
    e.Name:Remove()
    e.Trace:Remove()
    for _, l in ipairs(e.Corners) do l:Remove() end
    ESPObjs[plr] = nil
end

local function hideESP(e)
    e.Box.Visible = false
    e.Name.Visible = false
    e.Trace.Visible = false
    for _, l in ipairs(e.Corners) do l.Visible = false end
end

local function drawCorners(e, x, y, w, h, color)
    local cl = math.min(w, h) * 0.25
    if cl < 4 then cl = 4 end
    e.Corners[1].From = Vector2.new(x, y); e.Corners[1].To = Vector2.new(x + cl, y)
    e.Corners[2].From = Vector2.new(x, y); e.Corners[2].To = Vector2.new(x, y + cl)
    e.Corners[3].From = Vector2.new(x + w, y); e.Corners[3].To = Vector2.new(x + w - cl, y)
    e.Corners[4].From = Vector2.new(x + w, y); e.Corners[4].To = Vector2.new(x + w, y + cl)
    e.Corners[5].From = Vector2.new(x, y + h); e.Corners[5].To = Vector2.new(x + cl, y + h)
    e.Corners[6].From = Vector2.new(x, y + h); e.Corners[6].To = Vector2.new(x, y + h - cl)
    e.Corners[7].From = Vector2.new(x + w, y + h); e.Corners[7].To = Vector2.new(x + w - cl, y + h)
    e.Corners[8].From = Vector2.new(x + w, y + h); e.Corners[8].To = Vector2.new(x + w, y + h - cl)
    for _, l in ipairs(e.Corners) do
        l.Color = color
        l.Visible = true
    end
    e.Box.Visible = false
end

local function startESP()
    if ESPConn then ESPConn:Disconnect() end
    for _, p in ipairs(Players:GetPlayers()) do makeESP(p) end
    ESPConn = RunService.RenderStepped:Connect(function()
        Camera = Workspace.CurrentCamera
        local bottom = screenBottom()
        for plr, e in pairs(ESPObjs) do
            local show = false
            if ESPEnabled and plr ~= LocalPlayer and plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                local head = plr.Character:FindFirstChild("Head")
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if root and head and hum and hum.Health > 0 then
                    local role = getRole(plr)
                    if roleEnabled(role) then
                        local hs, hon = worldToScreen(head.Position + Vector3.new(0, 0.5, 0))
                        local rs, ron = worldToScreen(root.Position - Vector3.new(0, 3, 0))
                        if hon and ron then
                            show = true
                            local bh = math.abs(hs.Y - rs.Y)
                            local bw = bh * 0.6
                            local bx = hs.X - bw / 2
                            local by = hs.Y
                            local col = roleColor(role)
                            if ESPNames then
                                local roleName = ""
                                if role == "Murder" then roleName = " [M]"
                                elseif role == "Sheriff" then roleName = " [S]" end
                                e.Name.Text = (plr.DisplayName or plr.Name) .. roleName
                                e.Name.Position = Vector2.new(hs.X, by - 16)
                                e.Name.Color = col
                                setDrawFont(e.Name, ESPNameFont)
                                e.Name.Visible = true
                            else
                                e.Name.Visible = false
                            end
                            if ESPBoxes then
                                if ESPBoxType == "Corners" then
                                    drawCorners(e, bx, by, bw, bh, col)
                                else
                                    e.Box.Size = Vector2.new(bw, bh)
                                    e.Box.Position = Vector2.new(bx, by)
                                    e.Box.Color = col
                                    e.Box.Visible = true
                                    for _, l in ipairs(e.Corners) do l.Visible = false end
                                end
                            else
                                e.Box.Visible = false
                                for _, l in ipairs(e.Corners) do l.Visible = false end
                            end
                            if ESPTracers then
                                e.Trace.From = bottom
                                e.Trace.To = Vector2.new(hs.X, by + bh)
                                e.Trace.Color = col
                                e.Trace.Visible = true
                            else
                                e.Trace.Visible = false
                            end
                        end
                    end
                end
            end
            if not show then hideESP(e) end
        end
    end)
end

local function stopESP()
    if ESPConn then ESPConn:Disconnect() ESPConn = nil end
    for p in pairs(ESPObjs) do killESP(p) end
end

Players.PlayerAdded:Connect(function(p)
    if ESPEnabled then makeESP(p) end
end)
Players.PlayerRemoving:Connect(killESP)

local repo = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

pcall(function() Library.Font = Enum.Font.RobotoMono end)
pcall(function() Library:SetFont(Enum.Font.RobotoMono) end)

local Options = Library.Options
local Toggles = Library.Toggles

Library:SetWatermarkVisibility(true)
Library:SetWatermark(TITLE .. " | 60 fps")

local FrameTimer, FrameCounter, FPS = tick(), 0, 60
RunService.RenderStepped:Connect(function()
    FrameCounter = FrameCounter + 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter
        FrameTimer = tick()
        FrameCounter = 0
        pcall(function() Library:SetWatermark(("%s | %d fps"):format(TITLE, FPS)) end)
    end
end)

local Window = Library:CreateWindow({
    Title = TITLE,
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
    UnlockMouseWhileOpen = true,
    NotifySide = "Left",
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab("Main"),
    Visual = Window:AddTab("Visual"),
    World = Window:AddTab("World"),
    ESP = Window:AddTab("ESP"),
    Settings = Window:AddTab("Settings")
}

local function tab(name, f)
    local o2, e2 = pcall(f)
    if not o2 then
        warn("[Aurora|MM2] " .. name .. " build failed: " .. tostring(e2))
        pcall(function() Library:Notify("[Aurora|MM2] " .. name .. " error", 6) end)
    end
end

tab("Main", function()
    local MainLeft = Tabs.Main:AddLeftGroupbox("Aimbot")
    local Main2 = Tabs.Main:AddRightGroupbox("Main2")
    local MiscBox = Tabs.Main:AddLeftGroupbox("Misc")

    MainLeft:AddToggle("AimToggle", { Text = "Aimbot", Default = false, Callback = function(v)
        AimEnabled = v
        if v then startAim() else stopAim() end
    end })
    MainLeft:AddSlider("AimSens", { Text = "Aim Sensitivity", Default = 30, Min = 1, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v)
        AimSensitivity = v / 100
    end })
    MainLeft:AddDropdown("AimPart", { Text = "Aim Part", Default = "Head", Values = {"Head", "Torso"}, Multi = false, Callback = function(v)
        AimPart = v
    end })
    MainLeft:AddToggle("AimWallCheckToggle", { Text = "Wall Check", Default = false, Callback = function(v)
        AimWallCheck = v
    end })
    MainLeft:AddToggle("SilentAimToggle", { Text = "Silent Aim", Default = false, Callback = function(v)
        SilentEnabled = v
        if v then installSilentHook() end
    end })

    Main2:AddToggle("ShootBtnToggle", { Text = "Show shoot murder button outside linoria ui", Default = false, Callback = function(v)
        ShootBtnEnabled = v
        if v then startShootFeature() else stopShootFeature() end
    end })
    Main2:AddToggle("LockShootBtnToggle", { Text = "Lock shoot button", Default = false, Callback = function(v)
        LockShootBtn = v
    end })
    Main2:AddToggle("KillBtnToggle", { Text = "Show kill all button outside linoria ui", Default = false, Callback = function(v)
        KillBtnEnabled = v
        if v then createKillGui() else destroyKillGui() end
    end })
    Main2:AddToggle("WallbangToggle", { Text = "Wallbang", Default = true, Callback = function(v)
        WallbangEnabled = v
    end })

    MiscBox:AddToggle("AntiFlingToggle", { Text = "Anti Fling", Default = false, Callback = function(v)
        AntiFlingEnabled = v
        if v then startAntiFling() else stopAntiFling() end
    end })
    MiscBox:AddToggle("RoundTimerToggle", { Text = "Round Timer", Default = false, Callback = function(v)
        RoundTimerEnabled = v
    end })
    MiscBox:AddButton({ Text = "Fling Murderer", Func = function()
        task.spawn(function()
            local murd = findMurdererPlayer()
            if not murd then Library:Notify("No murderer to fling.", 3) return end
            flingPlayer(murd)
        end)
    end })
    MiscBox:AddButton({ Text = "Fling Sheriff", Func = function()
        task.spawn(function()
            local sheriff = findSheriffThatsNotMe()
            if not sheriff then Library:Notify("No sheriff to fling.", 3) return end
            flingPlayer(sheriff)
        end)
    end })
    MiscBox:AddToggle("InfJumpToggle", { Text = "Infinite Jump", Default = false, Callback = function(v)
        InfJumpEnabled = v
        if v then startInfJump() else stopInfJump() end
    end })
    MiscBox:AddToggle("HideStuffsToggle", { Text = "Hide Stuffs", Default = false, Callback = function(v)
        HideStuffsEnabled = v
        if v then startHideStuffs() else stopHideStuffs() end
    end })
    MiscBox:AddToggle("ServerPosToggle", { Text = "Show Server Position", Default = false, Callback = function(v)
        ServerPosEnabled = v
    end })
    MiscBox:AddButton({ Text = "Show Jump Boost Menu", Func = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/pope12042/ProjectArouraHub/refs/heads/main/woohooboost"))()
        end)
    end })
    MiscBox:AddButton({ Text = "AEFM Max Emote", Func = function()
        pcall(function()
            loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-AFEM-Max-Open-Alpha-50210"))()
        end)
    end })
end)

tab("Visual", function()
    local VisLeft = Tabs.Visual:AddLeftGroupbox("Status Text")
    local VisRight = Tabs.Visual:AddRightGroupbox("FOV Circle")

    VisLeft:AddToggle("StatusToggle", { Text = "Status Text", Default = false, Callback = function(v)
        if v then startStatus() else stopStatus() end
    end })
    VisLeft:AddDropdown("StatusTypes", { Text = "Text Type", Values = {"idle", "is in void", "dead", "gun dropped"}, Default = {"idle"}, Multi = true })
    pcall(function() Options.StatusTypes:SetValue({ ["idle"] = true }) end)
    VisLeft:AddDropdown("StatusPosDropdown", { Text = "Text Position", Default = "bottom", Values = {"up", "near middle", "middle", "near bottom", "bottom"}, Multi = false, Callback = function(v)
        StatusPosition = v
    end })
    VisLeft:AddDropdown("StatusFont", { Text = "Text Font", Default = "RobotoMono", Values = {"Arial", "RobotoMono", "Arcade", "FedokaOne"}, Multi = false, Callback = function(v)
        StatusFontName = v
    end })
    VisLeft:AddLabel("Text Colors")
        :AddColorPicker("StatusCol1Pick", { Title = "Color Point 1", Default = StatusCol1, Callback = function(v) StatusCol1 = v end })
        :AddColorPicker("StatusCol2Pick", { Title = "Color Point 2", Default = StatusCol2, Callback = function(v) StatusCol2 = v end })
    VisLeft:AddToggle("StatusFollowToolToggle", { Text = "Follow Tool", Default = false, Callback = function(v)
        StatusFollowTool = v
    end })

    VisRight:AddToggle("FovShowToggle", { Text = "FOV Circle", Default = false, Callback = function(v)
        FovShow = v
        if v and not FovGui then buildFovGui() end
        if FovCircleFrame then FovCircleFrame.Visible = v end
    end })
    VisRight:AddToggle("FovGradientToggle", { Text = "Gradient Mode", Default = false, Callback = function(v)
        FovGradient = v
        applyFovMode()
    end })
    VisRight:AddToggle("FovSpinToggle", { Text = "Spin", Default = false, Callback = function(v)
        FovSpin = v
    end })
    VisRight:AddSlider("FovSpinSpeed", { Text = "Spin Speed", Default = 60, Min = 1, Max = 360, Rounding = 0, Suffix = " deg/s", Callback = function(v)
        FovSpinSpeed = v
    end })
    VisRight:AddDropdown("FovFollow", { Text = "FOV Follow", Default = "Off", Values = {"Off", "Follow Player", "Follow Tool"}, Multi = false, Callback = function(v)
        FovFollow = v
    end })
    VisRight:AddSlider("FovSize", { Text = "FOV Size", Default = 140, Min = 20, Max = 500, Rounding = 0, Suffix = "px", Callback = function(v)
        FovSize = v
    end })
    VisRight:AddLabel("FOV Color"):AddColorPicker("FovColorPick", { Title = "FOV Color", Default = FovColor, Callback = function(v)
        FovColor = v
        applyFovMode()
    end })
    VisRight:AddLabel("Color Point 1"):AddColorPicker("FovPoint1Pick", { Title = "Color Point 1", Default = FovPoint1, Callback = function(v)
        FovPoint1 = v
        applyFovGradient()
    end })
    VisRight:AddLabel("Color Point 2"):AddColorPicker("FovPoint2Pick", { Title = "Color Point 2", Default = FovPoint2, Callback = function(v)
        FovPoint2 = v
        applyFovGradient()
    end })
    VisRight:AddToggle("FovOutlineToggle", { Text = "FOV Outline", Default = true, Callback = function(v)
        FovOutlineOn = v
        applyFovOutline()
    end })
    VisRight:AddLabel("Outline Color"):AddColorPicker("FovOutlineColorPick", { Title = "Outline Color", Default = FovOutlineColor, Callback = function(v)
        FovOutlineColor = v
        applyFovOutline()
    end })
    VisRight:AddSlider("FovOutlineThick", { Text = "Outline Thickness", Default = 2, Min = 1, Max = 6, Rounding = 0, Suffix = "px", Callback = function(v)
        FovOutlineThick = v
        applyFovOutline()
    end })
end)

tab("World", function()
    local WorldLeft = Tabs.World:AddLeftGroupbox("Color Correction")
    local WorldRight = Tabs.World:AddRightGroupbox("Bloom")
    local SnowBox = Tabs.World:AddLeftGroupbox("Snow")
    local AspectBox = Tabs.World:AddRightGroupbox("Aspect Ratio")

    WorldLeft:AddToggle("CCToggle", { Text = "Enable Color Correction", Default = false, Callback = function(v)
        CCEnabled = v
        applyCC()
    end })
    WorldLeft:AddLabel("World Color"):AddColorPicker("CCColorPick", { Title = "World Color", Default = CCColor, Callback = function(v)
        CCColor = v
        applyCC()
    end })
    WorldLeft:AddSlider("CCBrightSlider", { Text = "Brightness", Default = 0, Min = -100, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v)
        CCBright = v / 100
        applyCC()
    end })
    WorldLeft:AddSlider("CCContrastSlider", { Text = "Contrast", Default = 0, Min = -100, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v)
        CCContrast = v / 100
        applyCC()
    end })
    WorldLeft:AddSlider("CCSatSlider", { Text = "Saturation", Default = 0, Min = -100, Max = 100, Rounding = 0, Suffix = "%", Callback = function(v)
        CCSat = v / 100
        applyCC()
    end })

    WorldRight:AddToggle("BloomToggle", { Text = "Enable Bloom", Default = false, Callback = function(v)
        BloomEnabled = v
        applyBloom()
    end })
    WorldRight:AddSlider("BloomIntSlider", { Text = "Intensity", Default = 10, Min = 0, Max = 40, Rounding = 0, Callback = function(v)
        BloomInt = v / 10
        applyBloom()
    end })
    WorldRight:AddSlider("BloomSizeSlider", { Text = "Size", Default = 24, Min = 0, Max = 100, Rounding = 0, Callback = function(v)
        BloomSize = v
        applyBloom()
    end })
    WorldRight:AddSlider("BloomThrSlider", { Text = "Threshold", Default = 10, Min = 0, Max = 40, Rounding = 0, Callback = function(v)
        BloomThr = v / 10
        applyBloom()
    end })

    SnowBox:AddToggle("SnowToggle", { Text = "Snow Blizzard", Default = false, Callback = function(v)
        SnowEnabled = v
        toggleSnow(v)
    end })
    SnowBox:AddSlider("SnowIntensitySlider", { Text = "Snow Intensity", Default = 10000, Min = 500, Max = 30000, Rounding = 0, Callback = function(v)
        SnowIntensity = v
        updateSnowRate()
    end })

    AspectBox:AddToggle("AspectToggle", { Text = "Aspect Ratio", Default = false, Callback = function(v)
        AspectEnabled = v
    end })
    AspectBox:AddSlider("AspectXSlider", { Text = "Ratio X", Default = 100, Min = 10, Max = 200, Rounding = 0, Suffix = "%", Callback = function(v)
        AspectXScale = v / 100
    end })
    AspectBox:AddSlider("AspectYSlider", { Text = "Ratio Y", Default = 70, Min = 10, Max = 200, Rounding = 0, Suffix = "%", Callback = function(v)
        AspectYScale = v / 100
    end })
end)

tab("ESP", function()
    local ESPLeft = Tabs.ESP:AddLeftGroupbox("ESP")
    local ESPRight = Tabs.ESP:AddRightGroupbox("Colors & Style")
    local ESPFont = Tabs.ESP:AddRightGroupbox("Fonts")

    ESPLeft:AddToggle("ESPToggle", { Text = "Enable ESP", Default = false, Callback = function(v)
        ESPEnabled = v
        if v then startESP() else stopESP() end
    end })
    ESPLeft:AddToggle("ESPInnocentToggle", { Text = "ESP Innocent", Default = true, Callback = function(v) ESPInnocent = v end })
    ESPLeft:AddToggle("ESPMurderToggle", { Text = "ESP Murder", Default = true, Callback = function(v) ESPMurder = v end })
    ESPLeft:AddToggle("ESPSheriffToggle", { Text = "ESP Sheriff", Default = true, Callback = function(v) ESPSheriff = v end })
    ESPLeft:AddToggle("ESPTracerToggle", { Text = "Tracers", Default = false, Callback = function(v) ESPTracers = v end })
    ESPLeft:AddToggle("ESPNameToggle", { Text = "Name ESP", Default = true, Callback = function(v) ESPNames = v end })
    ESPLeft:AddToggle("ESPBoxToggle", { Text = "Box ESP", Default = true, Callback = function(v) ESPBoxes = v end })
    ESPLeft:AddDropdown("ESPBoxType", { Text = "Box Type", Default = "Normal", Values = {"Normal", "Corners"}, Multi = false, Callback = function(v)
        ESPBoxType = v
    end })

    ESPRight:AddLabel("Innocent Color"):AddColorPicker("InnocentCol", { Title = "Innocent Color", Default = InnocentColor, Callback = function(v) InnocentColor = v end })
    ESPRight:AddLabel("Murder Color"):AddColorPicker("MurderCol", { Title = "Murder Color", Default = MurderColor, Callback = function(v) MurderColor = v end })
    ESPRight:AddLabel("Sheriff Color"):AddColorPicker("SheriffCol", { Title = "Sheriff Color", Default = SheriffColor, Callback = function(v) SheriffColor = v end })
    ESPRight:AddLabel("Tracer Color"):AddColorPicker("TracerCol", { Title = "Tracer Color", Default = TracerColor, Callback = function(v) TracerColor = v end })

    ESPFont:AddDropdown("ESPNameFontDrop", { Text = "Name Font", Default = "UI", Values = {"UI", "System", "Plex", "Mono", "Ubuntu"}, Multi = false, Callback = function(v)
        local map = { UI = 0, System = 1, Plex = 2, Mono = 3, Ubuntu = 4 }
        ESPNameFont = map[v] or 0
    end })
end)

tab("Settings", function()
    pcall(function() ThemeManager:SetLibrary(Library) end)
    pcall(function() SaveManager:SetLibrary(Library) end)
    pcall(function() SaveManager:IgnoreThemeSettings() end)
    pcall(function() SaveManager:SetIgnoreIndexes({"MenuKeybind"}) end)
    pcall(function() ThemeManager:SetFolder("Aurora_MM2_UI") end)
    pcall(function() SaveManager:SetFolder("Aurora_MM2_UI") end)
    pcall(function() SaveManager:BuildConfigSection(Tabs.Settings) end)
    pcall(function() ThemeManager:ApplyToTab(Tabs.Settings) end)

    local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")
    MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", Mode = "Toggle", Text = "Menu keybind", NoUI = false })
    pcall(function() Library.ToggleKeybind = Options.MenuKeybind end)
    MenuBox:AddButton({ Text = "Unload", Func = function()
        stopAim()
        stopShootFeature()
        destroyKillGui()
        stopESP()
        stopStatus()
        stopInfJump()
        stopHideStuffs()
        stopAntiFling()
        toggleSnow(false)
        ccWorld.Enabled = false
        bloomFx.Enabled = false
        destroyFovGui()
        for tool, hl in pairs(droppedGunHL) do pcall(function() hl:Destroy() end) end
        droppedGunHL = {}
        pcall(function() SP.Box:Remove() SP.Trace:Remove() SP.Label:Remove() end)
        pcall(function() RT.Label:Remove() end)
        Library:Unload()
    end })
    pcall(function() SaveManager:LoadAutoloadConfig() end)
end)

pcall(function() warn("[Aurora|MM2] script built ok") end)
Library:Notify("Project Aurora | MM2 loaded", 4)

end)

if not ok then
    local msg = "[Aurora|MM2 FATAL] " .. tostring(err)
    warn(msg)
    pcall(function() if rconsoleprint then rconsoleprint(msg .. "\n") end end)
end
