--========================================================
-- AUTO 1-700 REBIRTH + OBSIDIAN | CLEAN REBUILD v3
-- Rebuilt with:
--  * one-time service/cache setup
--  * unique Obsidian IDs
--  * no unconditional hookmetamethod call
--  * protected remote calls
--  * protected UI notifications
--  * central task/connection cleanup
--  * same main farming logic / place routing
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LP = Players.LocalPlayer
if not LP then return end

--========================================================
-- SAFE HELPERS
--========================================================

local function safeCall(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    return ok, a, b, c
end

local function waitPath(parent, ...)
    local current = parent
    for _, name in ipairs({...}) do
        current = current:WaitForChild(name, 15)
        if not current then
            return nil
        end
    end
    return current
end

local function getCharacter()
    return LP.Character
end

local function getRoot(character)
    character = character or getCharacter()
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
    character = character or getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getWorldMobs()
    return workspace:FindFirstChild("World Mobs")
end

local function getMobRoot(mob)
    if not mob then return nil end
    return mob:FindFirstChild("HumanoidRootPart")
        or mob.PrimaryPart
        or mob:FindFirstChildWhichIsA("BasePart")
end

local function getMobHumanoid(mob)
    return mob and mob:FindFirstChildOfClass("Humanoid")
end

local function aliveMob(mob)
    local hum = getMobHumanoid(mob)
    local root = getMobRoot(mob)
    return mob and root and hum and hum.Health > 0
end

local function notify(title, description)
    if Library and Library.Notify then
        safeCall(function()
            Library:Notify({
                Title = title,
                Description = description,
                Time = 3
            })
        end)
    end
end

--========================================================
-- OBSIDIAN
--========================================================

local Obsidian
do
    local ok, result = safeCall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"
        ))()
    end)

    if not ok or not result then
        warn("[CleanV3] Obsidian failed:", result)
        return
    end

    Obsidian = result
end

local Library = Obsidian

local Window = Library:CreateWindow({
    Title = "Auto 1-700 Rebirth | Clean V3",
    Footer = "Rebuilt",
    Center = true,
    AutoShow = true
})

local TabFarm = Window:AddTab("Farm", "home")
local TabCombat = Window:AddTab("Combat", "swords")
local TabDungeon = Window:AddTab("Dungeon", "skull")
local TabPlayer = Window:AddTab("Player", "user")

local FarmLeft = TabFarm:AddLeftGroupbox("Auto 1-700")
local FarmRight = TabFarm:AddRightGroupbox("Select Farm")
local BasicBox = TabFarm:AddRightGroupbox("Basic Skills")

--========================================================
-- REMOTES
--========================================================

local SkillRemote = waitPath(ReplicatedStorage, "Remotes", "SkillRemote")

local SkillManagerFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "SkillManager", "RE"
)

local LockedOnChanged = SkillManagerFolder
    and SkillManagerFolder:FindFirstChild("LockedOnChanged")

local PlayerLevelFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "PlayerLevelService", "RF"
)

local RequestRebirth = PlayerLevelFolder
    and PlayerLevelFolder:FindFirstChild("RequestRebirth")

local PromptFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "PromptService", "RE"
)

local PromptRemote = PromptFolder and PromptFolder:FindFirstChild("Prompt")

local ToolFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "ToolService", "RE"
)

local ToolbarRemote = ToolFolder
    and ToolFolder:FindFirstChild("UpdatePlayerToolbarSelection")

local DungeonFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "DungeonLobbyService", "RF"
)

local CreateLobby = DungeonFolder and DungeonFolder:FindFirstChild("CreateLobby")
local StartDungeon = DungeonFolder and DungeonFolder:FindFirstChild("StartDungeon")
local ExitLobby = DungeonFolder and DungeonFolder:FindFirstChild("ExitLobby")

local DungeonServiceFolder = waitPath(
    ReplicatedStorage,
    "Packages", "_Index", "sleitnick_knit@1.4.7",
    "knit", "Services", "DungeonService", "RF"
)

local ReturnToWorld = DungeonServiceFolder
    and DungeonServiceFolder:FindFirstChild("ReturnToWorld")

--========================================================
-- THREAD MANAGER
--========================================================

local Threads = {}
local Connections = {}

local function stopThread(name)
    local t = Threads[name]
    if t then
        pcall(task.cancel, t)
        Threads[name] = nil
    end
end

local function startThread(name, fn)
    stopThread(name)
    Threads[name] = task.spawn(function()
        local ok, err = pcall(fn)
        if not ok then
            warn("[CleanV3][" .. name .. "]", err)
        end
        Threads[name] = nil
    end)
end

local function disconnect(name)
    local c = Connections[name]
    if c then
        pcall(function() c:Disconnect() end)
        Connections[name] = nil
    end
end

local function connect(name, signal, fn)
    disconnect(name)
    Connections[name] = signal:Connect(function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            warn("[CleanV3][" .. name .. "]", err)
        end
    end)
end

--========================================================
-- COMMON MOVEMENT
--========================================================

local function tweenToCFrame(cf, speed)
    local root = getRoot()
    if not root or not cf then return false end

    speed = speed or 180

    local distance = (root.Position - cf.Position).Magnitude
    local duration = math.max(distance / speed, 0.05)

    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = cf}
    )

    tween:Play()

    while tween.PlaybackState == Enum.PlaybackState.Playing do
        task.wait()
    end

    return true
end

local function stopVelocity()
    local root = getRoot()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function findMobByName(name, folders)
    for _, folder in ipairs(folders) do
        if folder then
            for _, object in ipairs(folder:GetDescendants()) do
                if object:IsA("Model")
                    and object.Name == name
                    and aliveMob(object) then
                    return object
                end
            end
        end
    end
    return nil
end

--========================================================
-- AUTO 1-700
--========================================================

local Auto1700 = false
local SafeCFrame = nil
local Reset20Enabled = false

local function saveSafeCFrame()
    local root = getRoot()
    if not root then return end

    local y = root.Position.Y
    if y > -100 and y < 100000 then
        SafeCFrame = root.CFrame
    end
end

local function startAntiVoid()
    startThread("AntiVoid", function()
        while Auto1700 do
            local root = getRoot()

            if root then
                saveSafeCFrame()

                if root.Position.Y <= -100 then
                    local recovery = SafeCFrame

                    if not recovery then
                        if game.PlaceId == 7040546583 then
                            recovery = CFrame.new(
                                -1028.61804, 66.1857834, -1514.43213
                            )
                        else
                            recovery = CFrame.new(
                                2034.02405, 1154.9751, -122.715225
                            )
                        end
                    end

                    stopVelocity()
                    root.CFrame = recovery + Vector3.new(0, 4, 0)
                end
            end

            task.wait(0.05)
        end
    end)
end

local function startReset20()
    startThread("Reset20", function()
        while Reset20Enabled do
            for _ = 1, 1200 do
                if not Reset20Enabled then return end
                task.wait(1)
            end

            if Reset20Enabled then
                local hum = getHumanoid()
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
                task.wait(3)
            end
        end
    end)
end

local function attackSkill1(mob)
    if not SkillRemote or not aliveMob(mob) then return end

    local root = getRoot()
    local mobRoot = getMobRoot(mob)
    if not root or not mobRoot then return end

    local target = mobRoot.Position
    local cf = CFrame.lookAt(
        target + Vector3.new(0, 8, 0),
        target
    )

    root.CFrame = cf

    safeCall(function()
        SkillRemote:FireServer({
            Camera = cf,
            SkillId = "1",
            Began = true,
            CFrame = cf,
            ["Typ\208\181"] = 1,
            Aim = target
        })
    end)
end

local function rebirth()
    if RequestRebirth then
        safeCall(function()
            RequestRebirth:InvokeServer(true)
        end)
    end
end

local function upgrade(path)
    if not PromptRemote then return end

    safeCall(function()
        PromptRemote:FireServer({
            Timer = 15,
            Description = "Upgrade Energy Blast>" .. path .. " for 1 Skill Points?",
            LeftButton = "Upgrade",
            PathName = path,
            Prompt = "UpgradeSkill",
            RightButton = "Return",
            SkillId = "101"
        }, "Upgrade")
    end)
end

local function joinCrimson()
    if not PromptRemote then return end

    safeCall(function()
        PromptRemote:FireServer({
            UniqueTag = "TeleporterGui",
            Description = "Join World [Crimson Planet]?",
            LeftButton = "Join",
            Timer = 30,
            Prompt = "TeleportDirect",
            RightButton = "Cancel",
            PlaceDataId = 2
        }, "Join")
    end)
end

local function runOldWorld()
    while Auto1700 and game.PlaceId == 3177438863 do
        local stats = LP:FindFirstChild("Stats")
        local strength = stats and stats:FindFirstChild("Strength")
        local rebirthValue = stats and stats:FindFirstChild("Rebirth")

        local str = strength and tonumber(strength.Value) or 0
        local reb = rebirthValue and tonumber(rebirthValue.Value) or 0

        if reb > 50 or str >= 60000000 then
            for _ = 1, 50 do
                if not Auto1700 then return end
                rebirth()
                task.wait(0.2)
            end

            if rebirthValue and tonumber(rebirthValue.Value) >= 50 then
                joinCrimson()
                task.wait(1)
                return
            end

        elseif str >= 200000 and reb >= 2 then
            local mob = findMobByName("Brawly Minion", {
                workspace:FindFirstChild("World Mobs")
            })

            if mob then
                local root = getRoot()
                local mobRoot = getMobRoot(mob)

                if root and mobRoot then
                    tweenToCFrame(
                        CFrame.lookAt(
                            mobRoot.Position + Vector3.new(0, 8, 0),
                            mobRoot.Position
                        ),
                        180
                    )
                end

                while Auto1700
                    and game.PlaceId == 3177438863
                    and aliveMob(mob) do

                    attackSkill1(mob)
                    task.wait(0.25)
                end
            else
                tweenToCFrame(
                    CFrame.new(2034.02405, 1149.9751, -122.715225),
                    180
                )
                task.wait(0.5)
            end

        elseif str >= 200000 then
            for _ = 1, 10 do
                if not Auto1700 then return end
                rebirth()
                task.wait(0.2)
            end

            upgrade("Path1")
            task.wait(0.5)
            upgrade("Path2")

        else
            local mob = findMobByName("Bandit", {
                workspace:FindFirstChild("World Mobs")
            })

            if mob then
                local mobRoot = getMobRoot(mob)
                if mobRoot then
                    tweenToCFrame(
                        CFrame.lookAt(
                            mobRoot.Position + Vector3.new(0, 8, 0),
                            mobRoot.Position
                        ),
                        180
                    )
                end

                while Auto1700
                    and game.PlaceId == 3177438863
                    and aliveMob(mob) do

                    attackSkill1(mob)
                    task.wait(0.25)
                end
            else
                task.wait(0.25)
            end
        end

        task.wait(0.05)
    end
end

local function runCalciWorld()
    while Auto1700 and game.PlaceId == 7040546583 do
        local world = workspace:FindFirstChild("World Mobs")
        local mobs = world and world:FindFirstChild("Mobs")

        local list = {}
        if mobs then
            for _, mob in ipairs(mobs:GetChildren()) do
                if mob.Name == "Calci Army" and aliveMob(mob) then
                    table.insert(list, mob)
                end
            end
        end

        if #list == 0 then
            tweenToCFrame(
                CFrame.new(-1028.61804, 61.1857834, -1514.43213),
                180
            )
            task.wait(0.15)
        else
            local target = list[math.random(1, #list)]
            local mobRoot = getMobRoot(target)

            if mobRoot then
                tweenToCFrame(
                    CFrame.lookAt(
                        mobRoot.Position + Vector3.new(0, 8, 0),
                        mobRoot.Position
                    ),
                    180
                )

                while Auto1700
                    and game.PlaceId == 7040546583
                    and aliveMob(target) do

                    attackSkill1(target)

                    if LockedOnChanged then
                        safeCall(function()
                            LockedOnChanged:FireServer(target)
                        end)
                    end

                    rebirth()
                    task.wait(0.25)
                end
            end
        end
    end
end

local function startAuto1700()
    if Auto1700 then return end

    Auto1700 = true
    startAntiVoid()
    startReset20()

    startThread("Auto1700", function()
        while Auto1700 do
            if game.PlaceId == 3177438863 then
                runOldWorld()
            elseif game.PlaceId == 7040546583 then
                runCalciWorld()
            else
                task.wait(1)
            end
            task.wait(0.1)
        end
    end)

    notify("Auto 1-700", "ON")
end

local function stopAuto1700()
    Auto1700 = false
    Reset20Enabled = false
    stopThread("Auto1700")
    stopThread("AntiVoid")
    stopThread("Reset20")
    notify("Auto 1-700", "OFF")
end

FarmLeft:AddToggle("Clean_Auto1700", {
    Text = "Auto 1-700 Rebirth",
    Default = false,
    Callback = function(value)
        if value then
            startAuto1700()
        else
            stopAuto1700()
        end
    end
})

FarmLeft:AddToggle("Clean_Reset20", {
    Text = "Reset every 20 minutes",
    Default = false,
    Callback = function(value)
        Reset20Enabled = value
        if value then
            startReset20()
        else
            stopThread("Reset20")
        end
    end
})

--========================================================
-- ANTI FALL
--========================================================

local AntiFall = true

connect("AntiFall", RunService.Heartbeat, function()
    if not AntiFall then return end

    local root = getRoot()
    if not root then return end

    local velocity = root.AssemblyLinearVelocity
    if velocity.Y < 0 then
        root.AssemblyLinearVelocity = Vector3.new(
            velocity.X, 0, velocity.Z
        )
    end
end)

FarmLeft:AddToggle("Clean_AntiFall", {
    Text = "Anti Fall",
    Default = false,
    Callback = function(value)
        AntiFall = value
    end
})

--========================================================
-- TOOLBAR
--========================================================

local ToolbarNumber = 1
local ToolbarEnabled = false

FarmLeft:AddDropdown("Clean_Toolbar", {
    Values = {"1","2","3","4","5","6"},
    Default = "1",
    Multi = false,
    Text = "Select equip",
    Callback = function(value)
        ToolbarNumber = tonumber(value) or 1
        ToolbarEnabled = true
    end
})

startThread("Toolbar", function()
    while true do
        if ToolbarEnabled and ToolbarRemote then
            safeCall(function()
                ToolbarRemote:FireServer(ToolbarNumber)
            end)
        end
        task.wait(0.15)
    end
end)

--========================================================
-- BASIC SKILLS
--========================================================

local BasicTransform = false
local AutoFusion = false
local AutoBeast = false

local function getStatusCharacter()
    local chars = workspace:FindFirstChild("Characters")
    return chars and chars:FindFirstChild(LP.Name)
end

local function hasMode()
    local c = getStatusCharacter()
    return c and c:FindFirstChild("Mode") ~= nil
end

local function fireStaticSkill(skillId)
    if not SkillRemote then return end

    local root = getRoot()
    if not root then return end

    local cf = root.CFrame

    safeCall(function()
        SkillRemote:FireServer({
            Camera = cf,
            SkillId = tostring(skillId),
            Began = true,
            CFrame = cf,
            ["Typ\208\181"] = 1,
            Aim = root.Position
        })
    end)
end

BasicBox:AddToggle("Clean_Transform", {
    Text = "auto transform",
    Default = false,
    Callback = function(value)
        BasicTransform = value
    end
})

BasicBox:AddToggle("Clean_Fusion", {
    Text = "Auto fusion",
    Default = false,
    Callback = function(value)
        AutoFusion = value
    end
})

BasicBox:AddToggle("Clean_Beast", {
    Text = "Auto beast [work all kaioken]",
    Default = false,
    Callback = function(value)
        AutoBeast = value
    end
})

startThread("BasicSkills", function()
    local fusionClock = 0

    while true do
        if BasicTransform and not hasMode() then
            fireStaticSkill(10)
        end

        if AutoBeast then
            fireStaticSkill(8)
        end

        fusionClock += 0.1
        if AutoFusion and fusionClock >= 9 then
            fireStaticSkill(9)
            fusionClock = 0
        end

        task.wait(0.1)
    end
end)

--========================================================
-- SELECT FARM
--========================================================

local SelectedMob = nil
local SelectFarmEnabled = false
local SelectSpeed = 200

local function getMobNames()
    local result = {}
    local seen = {}
    local world = getWorldMobs()

    if not world then return result end

    for _, obj in ipairs(world:GetDescendants()) do
        if obj:IsA("Model") and not seen[obj.Name] then
            if aliveMob(obj) then
                seen[obj.Name] = true
                table.insert(result, obj.Name)
            end
        end
    end

    table.sort(result)
    return result
end

local SelectDropdown = FarmRight:AddDropdown("Clean_SelectMob", {
    Values = getMobNames(),
    Default = nil,
    Multi = false,
    Text = "Select Farm",
    Callback = function(value)
        SelectedMob = value
    end
})

FarmRight:AddSlider("Clean_SelectSpeed", {
    Text = "Tween Speed",
    Default = 200,
    Min = 20,
    Max = 500,
    Rounding = 0,
    Callback = function(value)
        SelectSpeed = value
    end
})

FarmRight:AddToggle("Clean_SelectFarm", {
    Text = "Auto Farm Select",
    Default = false,
    Callback = function(value)
        SelectFarmEnabled = value
        if value then
            startThread("SelectFarm", function()
                while SelectFarmEnabled do
                    if SelectedMob then
                        local mob = findMobByName(SelectedMob, {getWorldMobs()})

                        if mob then
                            local root = getMobRoot(mob)
                            if root then
                                tweenToCFrame(
                                    CFrame.lookAt(
                                        root.Position + Vector3.new(0, 8, 0),
                                        root.Position
                                    ),
                                    SelectSpeed
                                )

                                while SelectFarmEnabled and aliveMob(mob) do
                                    attackSkill1(mob)
                                    task.wait(0.25)
                                end
                            end
                        else
                            task.wait(0.2)
                        end
                    else
                        task.wait(0.2)
                    end
                end
            end)
        else
            stopThread("SelectFarm")
        end
    end
})

startThread("MobRefresh", function()
    while true do
        local names = getMobNames()
        safeCall(function()
            SelectDropdown:SetValues(names)
        end)
        task.wait(2)
    end
end)

--========================================================
-- DUNGEON AUTO JOIN
--========================================================

local SelectedDungeon = "Mecha"
local SelectedDifficulty = "Easy"
local AutoJoin = false

local DungeonIds = {
    Mecha = 1,
    Atom = 2,
    Droid = 3,
    Hideout = 4
}

local DifficultyIds = {
    Easy = 1,
    Normal = 2,
    Hard = 3,
    Hell = 4
}

local DungeonBox = TabDungeon:AddLeftGroupbox("Dungeon Auto Join")

DungeonBox:AddDropdown("Clean_DungeonMode", {
    Values = {"Mecha","Atom","Droid","Hideout"},
    Default = "Mecha",
    Multi = false,
    Text = "Choose Mode",
    Callback = function(value)
        SelectedDungeon = value
    end
})

DungeonBox:AddDropdown("Clean_Difficulty", {
    Values = {"Easy","Normal","Hard","Hell"},
    Default = "Easy",
    Multi = false,
    Text = "Choose Difficulty",
    Callback = function(value)
        SelectedDifficulty = value
    end
})

DungeonBox:AddToggle("Clean_AutoJoin", {
    Text = "Auto Join",
    Default = false,
    Callback = function(value)
        AutoJoin = value

        if value then
            startThread("AutoJoin", function()
                while AutoJoin do
                    local args = {
                        DungeonIdSelected = DungeonIds[SelectedDungeon] or 1,
                        DungeonStats = {
                            Difficulty = DifficultyIds[SelectedDifficulty] or 1
                        }
                    }

                    if CreateLobby then
                        safeCall(function()
                            CreateLobby:InvokeServer(args)
                        end)
                    end

                    for _ = 10, 1, -1 do
                        if not AutoJoin then return end
                        task.wait(1)
                    end

                    if StartDungeon then
                        safeCall(function()
                            StartDungeon:InvokeServer(args)
                        end)
                    end

                    task.wait(1)
                end
            end)
        else
            stopThread("AutoJoin")
        end
    end
})

--========================================================
-- AUTO SKILL
--========================================================

local SkillNames = {
    ["Orange supernova"] = "113",
    ["Enenry boom"] = "104",
    ["Tri beam"] = "117",
    ["Stardust breaker"] = "116",
    ["Final enenry wave"] = "111",
    ["Blast first"] = "107",
    ["Enenry blast"] = "101",
    ["Death beam"] = "106",
    ["Death cannon"] = "105",
    ["Hellzone ge"] = "103",
    ["Shock wave blast"] = "102",
    ["Destructo disc"] = "108"
}

local SelectedSkills = {
    ["Orange supernova"] = true
}

local AutoSkill = false

local SkillBox = TabCombat:AddLeftGroupbox("Auto Skill")

SkillBox:AddDropdown("Clean_AutoSkillList", {
    Values = {
        "Orange supernova",
        "Enenry boom",
        "Tri beam",
        "Stardust breaker",
        "Final enenry wave",
        "Blast first",
        "Enenry blast",
        "Death beam",
        "Death cannon",
        "Hellzone ge",
        "Shock wave blast",
        "Destructo disc"
    },
    Default = {"Orange supernova"},
    Multi = true,
    Text = "Choose skills",
    Callback = function(value)
        SelectedSkills = {}
        for name, enabled in pairs(value) do
            if enabled then
                SelectedSkills[name] = true
            end
        end
    end
})

SkillBox:AddToggle("Clean_AutoSkill", {
    Text = "Auto skill",
    Default = false,
    Callback = function(value)
        AutoSkill = value
        if value then
            startThread("AutoSkill", function()
                while AutoSkill do
                    for name, enabled in pairs(SelectedSkills) do
                        if enabled then
                            fireStaticSkill(SkillNames[name])
                            task.wait(0.25)
                        end
                    end
                    task.wait(0.25)
                end
            end)
        else
            stopThread("AutoSkill")
        end
    end
})

--========================================================
-- DUNGEON KILL / NEXT AREA
--========================================================

local DungeonKill = false
local NextArea = false

local DungeonCombatBox = TabDungeon:AddRightGroupbox("Dungeon Combat")

DungeonCombatBox:AddToggle("Clean_DungeonKill", {
    Text = "auto kill Dungeon",
    Default = false,
    Callback = function(value)
        DungeonKill = value

        if value then
            startThread("DungeonKill", function()
                while DungeonKill do
                    local world = getWorldMobs()
                    local mobs = world and world:FindFirstChild("Mobs")

                    if mobs then
                        for _, mob in ipairs(mobs:GetChildren()) do
                            if not DungeonKill then return end
                            if aliveMob(mob) then
                                local root = getMobRoot(mob)
                                if root then
                                    tweenToCFrame(
                                        CFrame.lookAt(
                                            root.Position + Vector3.new(0, 8, 0),
                                            root.Position
                                        ),
                                        180
                                    )

                                    while DungeonKill and aliveMob(mob) do
                                        attackSkill1(mob)
                                        task.wait(0.25)
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                end
            end)
        else
            stopThread("DungeonKill")
        end
    end
})

DungeonCombatBox:AddToggle("Clean_NextArea", {
    Text = "Auto nextarea",
    Default = false,
    Callback = function(value)
        NextArea = value

        if value then
            startThread("NextArea", function()
                while NextArea do
                    local dungeon = workspace:FindFirstChild("Dungeon")
                    local stages = dungeon and dungeon:FindFirstChild("Stages")
                    local stage0 = stages and stages:FindFirstChild("0")
                    local nextArea = stage0 and stage0:FindFirstChild("NextArea")
                    local container = nextArea and nextArea:FindFirstChild("Container")
                    local visual = container and container:FindFirstChild("Visual")

                    local atomMax = findMobByName("Atom Max", {
                        workspace:FindFirstChild("World Mobs")
                    })

                    if visual and visual:IsA("BasePart") and not atomMax then
                        local root = getRoot()
                        if root then
                            local distance = (root.Position - visual.Position).Magnitude
                            if distance > 5 then
                                tweenToCFrame(
                                    CFrame.lookAt(
                                        visual.Position,
                                        visual.Position + visual.CFrame.LookVector
                                    ),
                                    80
                                )
                            end
                        end
                    end

                    task.wait(0.15)
                end
            end)
        else
            stopThread("NextArea")
        end
    end
})

--========================================================
-- ANTI FALL SUPPORT
--========================================================

local FloatSupport = false

DungeonCombatBox:AddToggle("Clean_FloatSupport", {
    Text = "anti fall support tween",
    Default = false,
    Callback = function(value)
        FloatSupport = value
    end
})

connect("FloatSupport", RunService.Heartbeat, function()
    if not FloatSupport then return end

    local root = getRoot()
    if not root then return end

    if root.Position.Y < -50 then
        local recovery = SafeCFrame
        if recovery then
            root.CFrame = recovery + Vector3.new(0, 8, 0)
            stopVelocity()
        end
    end
end)

--========================================================
-- DUNGEON AUTO START / REPLAY
--========================================================

local AutoStart = false
local AutoReplay = false

local DungeonAutoBox = TabDungeon:AddLeftGroupbox("Auto Start / Replay")

DungeonAutoBox:AddToggle("Clean_DungeonAutoStart", {
    Text = "Auto Start",
    Default = false,
    Callback = function(value)
        AutoStart = value

        if value then
            startThread("DungeonAutoStart", function()
                while AutoStart do
                    if StartDungeon then
                        safeCall(function()
                            StartDungeon:InvokeServer()
                        end)
                    end
                    task.wait(2)
                end
            end)
        else
            stopThread("DungeonAutoStart")
        end
    end
})

DungeonAutoBox:AddToggle("Clean_DungeonAutoReplay", {
    Text = "Auto Replay",
    Default = false,
    Callback = function(value)
        AutoReplay = value

        if value then
            startThread("DungeonAutoReplay", function()
                while AutoReplay do
                    local hum = getHumanoid()

                    if hum and hum.Health <= 0 then
                        task.wait(13)

                        if not AutoReplay then
                            return
                        end

                        if ReturnToWorld then
                            safeCall(function()
                                ReturnToWorld:InvokeServer()
                            end)
                        end

                        task.wait(2)

                        if AutoStart and StartDungeon then
                            safeCall(function()
                                StartDungeon:InvokeServer()
                            end)
                        end
                    end

                    task.wait(0.1)
                end
            end)
        else
            stopThread("DungeonAutoReplay")
        end
    end
})

--========================================================
-- LOCK CHOOSE
--========================================================

local LockEnabled = false
local LockTargetType = "Mobs"
local LockMode = "Near"
local LockRange = 100

local LockBox = TabCombat:AddRightGroupbox("Lock Choose")

LockBox:AddDropdown("Clean_LockType", {
    Values = {"Mobs","Player"},
    Default = "Mobs",
    Multi = false,
    Text = "Choose Target",
    Callback = function(value)
        LockTargetType = value
    end
})

LockBox:AddDropdown("Clean_LockMode", {
    Values = {"Near","Distant","Random"},
    Default = "Near",
    Multi = false,
    Text = "Lock Mode",
    Callback = function(value)
        LockMode = value
    end
})

LockBox:AddSlider("Clean_LockRange", {
    Text = "Lockon Range",
    Default = 100,
    Min = 1,
    Max = 1000,
    Rounding = 0,
    Callback = function(value)
        LockRange = value
    end
})

local function getLockTargets()
    local result = {}

    if LockTargetType == "Player" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP and player.Character and getRoot(player.Character) then
                table.insert(result, player.Character)
            end
        end
    else
        local world = getWorldMobs()
        if world then
            for _, obj in ipairs(world:GetDescendants()) do
                if obj:IsA("Model") and aliveMob(obj) then
                    table.insert(result, obj)
                end
            end
        end
    end

    return result
end

local function chooseLockTarget()
    local myRoot = getRoot()
    if not myRoot then return nil end

    local valid = {}

    for _, target in ipairs(getLockTargets()) do
        local root = getRoot(target)
        if root then
            local distance = (root.Position - myRoot.Position).Magnitude
            if distance <= LockRange then
                table.insert(valid, {
                    Object = target,
                    Distance = distance
                })
            end
        end
    end

    if #valid == 0 then return nil end

    if LockMode == "Random" then
        return valid[math.random(1, #valid)].Object
    end

    table.sort(valid, function(a, b)
        if LockMode == "Distant" then
            return a.Distance > b.Distance
        end
        return a.Distance < b.Distance
    end)

    return valid[1].Object
end

LockBox:AddToggle("Clean_LockOn", {
    Text = "Lockon",
    Default = false,
    Callback = function(value)
        LockEnabled = value

        if value then
            startThread("LockOn", function()
                while LockEnabled do
                    local target = chooseLockTarget()

                    if target and LockedOnChanged then
                        safeCall(function()
                            LockedOnChanged:FireServer(target)
                        end)
                    end

                    task.wait(0.15)
                end
            end)
        else
            stopThread("LockOn")
        end
    end
})

--========================================================
-- COOLDOWN
--========================================================

local CooldownBox = TabCombat:AddLeftGroupbox("Cooldown")
local NoCooldownDash = false

CooldownBox:AddToggle("Clean_NoCooldownDash", {
    Text = "No cooldown dash",
    Default = false,
    Callback = function(value)
        NoCooldownDash = value
    end
})

CooldownBox:AddButton({
    Text = "Delete animation beast",
    Func = function()
        local clientSource = ReplicatedStorage:FindFirstChild("ClientSource")
        local modules = clientSource and clientSource:FindFirstChild("Modules")
        local systems = modules and modules:FindFirstChild("SkillSystems")

        if systems then
            safeCall(function()
                systems:Destroy()
            end)
            notify("SkillSystems", "Deleted")
        else
            notify("SkillSystems", "Not found")
        end
    end
})

-- Optional hook: never call nil unconditionally.
-- If the executor does not expose hookmetamethod, the toggle remains
-- harmless instead of crashing the whole script.
local hookmetamethodFn = rawget(getgenv and getgenv() or _G, "hookmetamethod")
local getnamecallmethodFn = rawget(getgenv and getgenv() or _G, "getnamecallmethod")
local newcclosureFn = rawget(getgenv and getgenv() or _G, "newcclosure")

if hookmetamethodFn and getnamecallmethodFn and newcclosureFn and SkillRemote then
    local oldNamecall

    safeCall(function()
        oldNamecall = hookmetamethodFn(game, "__namecall", newcclosureFn(function(self, ...)
            local method = getnamecallmethodFn()
            local args = {...}

            if NoCooldownDash
                and self == SkillRemote
                and method == "FireServer" then

                local data = args[1]

                if type(data) == "table"
                    and tostring(data.SkillId) == "7" then
                    return nil
                end
            end

            return oldNamecall(self, ...)
        end))
    end)
end

--========================================================
-- GAMEPASS / PLAYER STATS
--========================================================

local GamepassBox = TabPlayer:AddRightGroupbox("Gamepass")
local SelectedPlayer = nil

local function playerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(names, player.Name)
    end
    table.sort(names)
    return names
end

local PlayerDropdown = GamepassBox:AddDropdown("Clean_SelectPlayer", {
    Text = "Select Player",
    Values = playerNames(),
    Default = nil,
    Callback = function(value)
        SelectedPlayer = value
    end
})

local function copyValues(source, target)
    if not source or not target then return end

    for _, valueObject in ipairs(source:GetDescendants()) do
        if valueObject:IsA("ValueBase") then
            local targetValue = target:FindFirstChild(valueObject.Name, true)
            if targetValue and targetValue:IsA("ValueBase") then
                safeCall(function()
                    targetValue.Value = valueObject.Value
                end)
            end
        end
    end
end

GamepassBox:AddButton({
    Text = "Check stats select",
    Func = function()
        if not SelectedPlayer then return end

        local targetPlayer = Players:FindFirstChild(SelectedPlayer)
        if not targetPlayer or targetPlayer == LP then return end

        copyValues(
            targetPlayer:FindFirstChild("Stats"),
            LP:FindFirstChild("Stats")
        )

        local chars = workspace:FindFirstChild("Characters")
        if chars then
            copyValues(
                chars:FindFirstChild(targetPlayer.Name)
                    and chars[targetPlayer.Name]:FindFirstChild("Status"),
                chars:FindFirstChild(LP.Name)
                    and chars[LP.Name]:FindFirstChild("Status")
            )
        end
    end
})

GamepassBox:AddButton({
    Text = "Reset",
    Func = function()
        local hum = getHumanoid()
        if hum then
            hum.Health = 0
        end
    end
})

GamepassBox:AddToggle("Clean_AutoRebirth", {
    Text = "auto rebirth",
    Default = false,
    Callback = function(value)
        if value then
            startThread("StandaloneRebirth", function()
                while true do
                    rebirth()
                    task.wait(0.25)
                end
            end)
        else
            stopThread("StandaloneRebirth")
        end
    end
})

startThread("PlayerRefresh", function()
    while true do
        safeCall(function()
            PlayerDropdown:SetValues(playerNames())
        end)
        task.wait(2)
    end
end)

--========================================================
-- PSI SPECIAL SKILLS
--========================================================

local PsiEnabled = false
local PsiSkills = {}

GamepassBox:AddDropdown("Clean_PsiSkills", {
    Values = {
        "Orange supernova",
        "Enenry boom",
        "Tri beam",
        "Stardust breaker",
        "Final enenry wave",
        "Blast first",
        "Enenry blast",
        "Death beam",
        "Death cannon",
        "Hellzone ge",
        "Shock wave blast",
        "Destructo disc"
    },
    Default = {},
    Multi = true,
    Text = "Psi skills",
    Callback = function(value)
        PsiSkills = {}
        for name, enabled in pairs(value) do
            if enabled and SkillNames[name] then
                table.insert(PsiSkills, SkillNames[name])
            end
        end
    end
})

GamepassBox:AddToggle("Clean_AutoSkillPsi", {
    Text = "Auto skill Psi",
    Default = false,
    Callback = function(value)
        PsiEnabled = value

        if value then
            startThread("Psi", function()
                while PsiEnabled do
                    for _, id in ipairs(PsiSkills) do
                        if not PsiEnabled then return end
                        fireStaticSkill(id)
                        task.wait(0.25)
                    end
                    task.wait(0.25)
                end
            end)
        else
            stopThread("Psi")
        end
    end
})

--========================================================
-- CLEANUP
--========================================================

connect("CharacterAdded", LP.CharacterAdded, function()
    SafeCFrame = nil
    task.wait(1)

    if Auto1700 then
        startAntiVoid()
    end
end)

notify("Clean V3", "Script loaded successfully")
print("[CleanV3] Loaded | unique IDs | protected calls | no unconditional nil hook")
