local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local HttpService = game:GetService("HttpService")

-- [ 1. STORAGE SYSTEM ]
local FILENAME = "AutoLead.json"
local SavedData = {}

local function Load()
    if isfile(FILENAME) then
        local success, content = pcall(function() return HttpService:JSONDecode(readfile(FILENAME)) end)
        if success and type(content) == "table" then SavedData = content end
    end
end

local function Save()
    pcall(function() writefile(FILENAME, HttpService:JSONEncode(SavedData)) end)
end

Load()

-- [ 2. UI SETUP ]
local Window = Fluent:CreateWindow({
    Title = "AUTO LEAD RECORDER",
    SubTitle = "VER FINAL HARUSNYA",
    TabWidth = 160,
    Size = UDim2.fromOffset(450, 400), -- Ukuran diperlebar untuk editor
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.End 
})

local MobileGui = Instance.new("ScreenGui", (game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")))
local ToggleButton = Instance.new("TextButton", MobileGui)
ToggleButton.Size = UDim2.new(0, 35, 0, 35)
ToggleButton.Position = UDim2.new(0.05, 0, 0.2, 0)
ToggleButton.Text = "KIW"
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.TextSize = 16
ToggleButton.Draggable = true
Instance.new("UICorner", ToggleButton)
ToggleButton.MouseButton1Click:Connect(function() Window:Minimize() end)


-- [ 3. CORE VARIABLES ]
local IsRecording, IsPlayingPlayback = false, false
local CurrentPlaybackThread = nil
local ActiveTracks = {} 
local TempSession = {}
local StartTime = 0
local player = game.Players.LocalPlayer

-- [ 4. PROTOCOL ENGINE ]
local function FireServerSync(animId, speed)
    local Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if Events then
        local UpdateAnim = Events:FindFirstChild("UpdateAnimation")
        if UpdateAnim and animId then pcall(function() UpdateAnim:FireServer(animId) end) end
        local UpdateSpeed = Events:FindFirstChild("UpdateSpeed")
        if UpdateSpeed then pcall(function() UpdateSpeed:FireServer(speed or 1) end) end
    end
end

local function GlobalStop()
    IsPlayingPlayback = false
    IsRecording = false
    if CurrentPlaybackThread then task.cancel(CurrentPlaybackThread) CurrentPlaybackThread = nil end
    
    local Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if Events then
        local UpdateAnim = Events:FindFirstChild("UpdateAnimation")
        if UpdateAnim then pcall(function() UpdateAnim:FireServer() end) end
        local UpdateSpeed = Events:FindFirstChild("UpdateSpeed")
        if UpdateSpeed then pcall(function() UpdateSpeed:FireServer(1) end) end
    end
    
    local Char = player.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    if Hum then
        for _, track in pairs(Hum:GetPlayingAnimationTracks()) do
            if track.Priority.Value >= Enum.AnimationPriority.Action.Value then track:Stop(0.25) end
        end
        task.delay(0.1, function()
            if Char:FindFirstChild("Animate") then
                Char.Animate.Disabled = true
                task.wait()
                Char.Animate.Disabled = false
            end
        end)
    end
    table.clear(ActiveTracks)
end

-- [ 5. TABS ]
local Tabs = {
    Main = Window:AddTab({ Title = "Recorder", Icon = "record" }),
    Editor = Window:AddTab({ Title = "Timeline Editor", Icon = "edit" }),
    Surgery = Window:AddTab({ Title = "Playback", Icon = "play" })
}

-- [ 6. RECORDER ]
local function SetupRecorder()
    local Char = player.Character or player.CharacterAdded:Wait()
    local Hum = Char:WaitForChild("Humanoid")
    Hum.AnimationPlayed:Connect(function(track)
        if not IsRecording then return end
        if track.Priority == Enum.AnimationPriority.Core then return end
        table.insert(TempSession, {id = track.Animation.AnimationId, time = tick() - StartTime, speed = track.Speed})
        task.spawn(function()
            local lastRecordedSpeed = track.Speed
            while IsRecording and track.IsPlaying do
                if math.abs(track.Speed - lastRecordedSpeed) > 0.01 then
                    lastRecordedSpeed = track.Speed
                    table.insert(TempSession, {id = track.Animation.AnimationId, time = tick() - StartTime, speed = track.Speed, isSpeedUpdateOnly = true})
                end
                task.wait(0.03)
            end
        end)
    end)
end
SetupRecorder()
player.CharacterAdded:Connect(SetupRecorder)

-- [ 7. EDITOR LOGIC ]
local EditorList = {}
local SelectedRecForEdit = ""

local function RefreshEditorUI()
    for _, v in pairs(EditorList) do v:Destroy() end
    table.clear(EditorList)
    
    local data = SavedData[SelectedRecForEdit]
    if not data then return end
    
    for i, entry in ipairs(data) do
        local label = entry.isSpeedUpdateOnly and "⚡ Speed" or "🎬 Anim"
        local section = Tabs.Editor:AddSection(string.format("[%d] %s", i, label))
        table.insert(EditorList, section)
        
        local timeInp = Tabs.Editor:AddInput("Time"..i, {
            Title = "Waktu (detik)",
            Default = tostring(math.floor(entry.time * 1000)/1000),
            Callback = function(v) entry.time = tonumber(v) or entry.time end
        })
        
        local speedInp = Tabs.Editor:AddInput("Speed"..i, {
            Title = "Kecepatan",
            Default = tostring(entry.speed),
            Callback = function(v) entry.speed = tonumber(v) or entry.speed end
        })
        
        local delBtn = Tabs.Editor:AddButton({
            Title = "❌ Hapus Entry ini",
            Callback = function()
                table.remove(data, i)
                Save()
                RefreshEditorUI()
            end
        })
        table.insert(EditorList, timeInp)
        table.insert(EditorList, speedInp)
        table.insert(EditorList, delBtn)
    end
end

-- [ 8. UI ACTIONS ]
local RecToggle = Tabs.Main:AddToggle("RecToggle", {Title = "Mode Rekam", Default = false })
RecToggle:OnChanged(function()
    IsRecording = RecToggle.Value
    if IsRecording then GlobalStop() IsRecording = true TempSession = {} StartTime = tick() end
end)

local RecNameInput = Tabs.Main:AddInput("RecName", { Title = "Nama Dance", Default = "Dance_1" })
Tabs.Main:AddButton({
    Title = "💾 Simpan Hasil Rekaman",
    Callback = function()
        if #TempSession == 0 then return end
        Load()
        SavedData[RecNameInput.Value] = TempSession
        Save()
        RecToggle:SetValue(false)
        Fluent:Notify({Title="Saved", Content="Cek di tab Playback/Editor"})
    end
})

-- EDITOR CONTROLS
local EditSelect = Tabs.Editor:AddDropdown("EditSelect", { Title = "Pilih Rekaman untuk Diedit", Values = {} })
Tabs.Editor:AddButton({
    Title = "🛠️ Buka Timeline",
    Callback = function()
        SelectedRecForEdit = EditSelect.Value
        RefreshEditorUI()
    end
})
Tabs.Editor:AddButton({ Title = "💾 Simpan Perubahan", Callback = Save })

-- -- [ TAB PLAYBACK ]
local PlaybackSection = Tabs.Surgery:AddSection("Playback Settings")

-- 1. DEFINISIKAN DROPDOWN DULU
local RecSelect = Tabs.Surgery:AddDropdown("RecSelect", { 
    Title = "Pilih Rekaman", 
    Values = {}, 
    Multi = false,
    Default = nil,
})

-- 2. DEFINISIKAN INPUT SEARCH (Setelah Dropdown agar bisa panggil 'RecSelect')
local SearchInput = Tabs.Surgery:AddInput("SearchQuery", {
    Title = "Cari & Filter",
    Default = "",
    Placeholder = "Ketik untuk mencari...",
    Callback = function(Value)
        -- Pastikan SavedData tidak nil sebelum looping
        if not SavedData then return end
        
        local query = Value:lower()
        local filtered = {}
        
        for name, _ in pairs(SavedData) do
            if name:lower():find(query) then
                table.insert(filtered, name)
            end
        end
        table.sort(filtered)
        
        -- Update dropdown (pasti aman karena RecSelect sudah dibuat di atas)
        RecSelect:SetValues(filtered)
    end
})

-- 3. PAKSA TAMPILAN 5 BARIS (SCROLLABLE)
task.spawn(function()
    -- Menunggu sebentar agar UI Fluent benar-benar terbentuk di layar
    task.wait(0.5) 
    pcall(function() -- Gunakan pcall agar jika gagal tidak menghentikan seluruh script
        local frame = RecSelect.Frame
        local container = frame and frame:FindFirstChild("Container", true)
        if container and container:IsA("ScrollingFrame") then
            container.Size = UDim2.new(1, 0, 0, 160) -- Tinggi untuk ~5 baris
            container.ScrollBarThickness = 3
        end
    end)
end)

-- 4. NOTIFIKASI 2 DETIK
RecSelect:OnChanged(function(Value)
    if Value and Value ~= "" then
        Fluent:Notify({
            Title = "Selected",
            Content = "Memilih: " .. Value,
            Duration = 2 -- Sesuai permintaan: Hilang dalam 2 detik
        })
    end
end)

-- 4. Fungsi Refresh yang Solid
local function RefreshLists()
    local n = {} 
    if SavedData then
        for k, _ in pairs(SavedData) do table.insert(n, k) end
        table.sort(n) 
        RecSelect:SetValues(n)
        -- Update juga dropdown di tab Editor jika ada
        if EditSelect then EditSelect:SetValues(n) end
    end
end

-- Tombol Refresh manual
Tabs.Surgery:AddButton({
    Title = "🔄 Refresh List",
    Callback = function()
        Load() -- Memuat ulang file JSON
        RefreshLists()
        Fluent:Notify({
            Title = "System",
            Content = "Daftar rekaman telah diperbarui",
            Duration = 2
        })
    end
})

Tabs.Surgery:AddButton({
    Title = "🗑️ HAPUS REKAMAN (PERMANEN)",
    Callback = function()
        if SavedData[RecSelect.Value] then
            SavedData[RecSelect.Value] = nil
            Save()
            Refresh()
            Fluent:Notify({Title="Deleted", Content="Rekaman telah dihapus."})
        end
    end
})

Tabs.Surgery:AddButton({
    Title = "▶️ START PLAYBACK",
    Callback = function()
        local s = RecSelect.Value
        if not s or s == "" then return end
        GlobalStop()
        task.wait(0.1) 
        IsPlayingPlayback = true
        local pStart = tick()
        local Hum = player.Character:FindFirstChildOfClass("Humanoid")
        CurrentPlaybackThread = task.spawn(function()
            local dataList = SavedData[s]
            local currentActiveId = ""
            for _, data in ipairs(dataList) do
                if not IsPlayingPlayback then break end
                while tick() < pStart + data.time do if not IsPlayingPlayback then break end task.wait() end
                if not IsPlayingPlayback then break end
                if data.id ~= currentActiveId and not data.isSpeedUpdateOnly then
                    FireServerSync(data.id, data.speed)
                    local anim = Instance.new("Animation") anim.AnimationId = data.id
                    local newTrack = Hum:LoadAnimation(anim)
                    newTrack.Priority = Enum.AnimationPriority.Action4
                    for i, oldTrack in pairs(ActiveTracks) do oldTrack:Stop(0.3) ActiveTracks[i] = nil end
                    newTrack:Play(0.3)
                    newTrack:AdjustSpeed(data.speed)
                    table.insert(ActiveTracks, newTrack)
                    currentActiveId = data.id
                else
                    FireServerSync(nil, data.speed) 
                    for _, activeTrack in pairs(ActiveTracks) do if activeTrack.IsPlaying then activeTrack:AdjustSpeed(data.speed) end end
                end
            end
            IsPlayingPlayback = false
            GlobalStop()
        end)
    end
})

Tabs.Surgery:AddButton({ Title = "⏹️ STOP ALL", Callback = GlobalStop })

Window:SelectTab(1)