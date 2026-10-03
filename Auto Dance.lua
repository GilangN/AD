-- [ 0. CLEANUP PREVIOUS INSTANCE & GLOBAL KILLSWITCH ]
if getgenv().AutoLeadCleanup then
    pcall(getgenv().AutoLeadCleanup)
    getgenv().AutoLeadCleanup = nil
end

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

-- [ 1. STORAGE SYSTEM ]
local FILENAME = "AutoLead.json"
local SavedData = {}

local function Load()
    if isfile and isfile(FILENAME) then
        local success, content = pcall(function() return HttpService:JSONDecode(readfile(FILENAME)) end)
        if success and type(content) == "table" then SavedData = content end
    end
end

local function Save()
    local success, err = pcall(function()
        if not writefile then error("Executor tidak mendukung writefile!") end
        local result = HttpService:JSONEncode(SavedData)
        writefile(FILENAME, result)
    end)
    return success, err
end

Load()

-- [ HELPER FORMAT TIME ]
local function FormatTime(seconds)
    local totalSecs = tonumber(seconds) or 0
    local mins = math.floor(totalSecs / 60)
    local secs = math.floor(totalSecs % 60)
    return string.format("%02d:%02d", mins, secs)
end

-- [ 2. UI SETUP ]
local ScreenGui = Instance.new("ScreenGui", (CoreGui or PlayerGui))
ScreenGui.Name = "AutoLeadCustomGui"
_G.AutoLeadGui = ScreenGui

-- Main Window Frame
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.fromOffset(335, 385)
MainFrame.Position = UDim2.new(0.5, -167, 0.5, -192)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BackgroundTransparency = 0.3
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(150, 150, 165)
MainStroke.Transparency = 0.25
MainStroke.Thickness = 1.8

-- Top Bar / Header
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
TopBar.BackgroundTransparency = 0.25
TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel", TopBar)
TitleLabel.Size = UDim2.new(1, -75, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.BorderSizePixel = 0
TitleLabel.Text = "AUTO LEAD <font color='#00ffaa'>✨ Pro v6.2</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
TitleLabel.Font = Enum.Font.FredokaOne
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Forward Declaration
local GlobalStop
local RefreshLists
local RunPlayback
local IsAutoRemotePlayEnabled = false
local RemoteConnection = nil

-- Close Button (×)
local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.BackgroundTransparency = 0.2
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.FredokaOne
CloseBtn.TextSize = 16
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
    if getgenv().AutoLeadCleanup then
        getgenv().AutoLeadCleanup()
    end
end)

-- Hide Button (–) di Samping Close
local HideBtn = Instance.new("TextButton", TopBar)
HideBtn.Size = UDim2.new(0, 26, 0, 26)
HideBtn.Position = UDim2.new(1, -62, 0.5, -13)
HideBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
HideBtn.BackgroundTransparency = 0.2
HideBtn.BorderSizePixel = 0
HideBtn.Text = "–"
HideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HideBtn.Font = Enum.Font.FredokaOne
HideBtn.TextSize = 16
Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0, 6)

HideBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Top Horizontal Tab Bar Container
local TabBar = Instance.new("Frame", MainFrame)
TabBar.Size = UDim2.new(1, -16, 0, 32)
TabBar.Position = UDim2.new(0, 8, 0, 44)
TabBar.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
TabBar.BackgroundTransparency = 0.6
TabBar.BorderSizePixel = 0
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

local TabBarLayout = Instance.new("UIListLayout", TabBar)
TabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
TabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabBarLayout.Padding = UDim.new(0, 4)

-- Content Area Panels
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -16, 1, -86)
ContentArea.Position = UDim2.new(0, 8, 0, 82)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true

local TabsPages = {}
local TabButtons = {}

local function CreateTabPanel(name, index, onSelectedCallback)
    local page = Instance.new("ScrollingFrame", ContentArea)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Visible = (index == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 3
    
    local layout = Instance.new("UIListLayout", page)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    
    local function UpdateCanvas()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
    end
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
    
    local tBtn = Instance.new("TextButton", TabBar)
    tBtn.Size = UDim2.new(0.31, 0, 0.8, 0)
    tBtn.BackgroundColor3 = (index == 1) and Color3.fromRGB(60, 60, 72) or Color3.fromRGB(18, 18, 22)
    tBtn.BackgroundTransparency = (index == 1) and 0.1 or 0.6
    tBtn.BorderSizePixel = 0
    tBtn.Text = name
    tBtn.TextColor3 = (index == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 165)
    tBtn.Font = Enum.Font.GothamBold
    tBtn.TextSize = 10
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)
    
    tBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(TabsPages) do p.Visible = false end
        for _, b in pairs(TabButtons) do 
            b.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
            b.BackgroundTransparency = 0.6
            b.TextColor3 = Color3.fromRGB(150, 150, 165)
        end
        page.Visible = true
        tBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
        tBtn.BackgroundTransparency = 0.1
        tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        UpdateCanvas()
        if onSelectedCallback then onSelectedCallback() end
    end)
    
    table.insert(TabsPages, page)
    table.insert(TabButtons, tBtn)
    return page, UpdateCanvas
end

local Tabs = {
    Main = CreateTabPanel("RECORDER", 1),
    Editor = CreateTabPanel("TIMELINE", 2, function()
        Load()
        if RefreshLists then RefreshLists() end
    end),
    Surgery = CreateTabPanel("PLAYBACK", 3, function()
        Load()
        if RefreshLists then RefreshLists() end
    end)
}

-- Helper Component Generators
local function AddSectionHeader(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Text = "  " .. text
    lbl.TextColor3 = Color3.fromRGB(170, 170, 185)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

local function AddButtonUI(parent, title, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -4, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 0
    btn.Text = title
    btn.TextColor3 = Color3.fromRGB(245, 245, 250)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function AddDualButtonUI(parent, leftTitle, leftColor, leftCallback, rightTitle, rightColor, rightCallback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 36)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    
    local leftBtn = Instance.new("TextButton", container)
    leftBtn.Size = UDim2.new(0.68, -3, 1, 0)
    leftBtn.Position = UDim2.new(0, 0, 0, 0)
    leftBtn.BackgroundColor3 = leftColor or Color3.fromRGB(50, 160, 100)
    leftBtn.BackgroundTransparency = 0.45
    leftBtn.BorderSizePixel = 0
    leftBtn.Text = leftTitle
    leftBtn.TextColor3 = Color3.fromRGB(245, 255, 248)
    leftBtn.Font = Enum.Font.GothamBold
    leftBtn.TextSize = 11
    Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 7)
    leftBtn.MouseButton1Click:Connect(leftCallback)
    
    local rightBtn = Instance.new("TextButton", container)
    rightBtn.Size = UDim2.new(0.32, -3, 1, 0)
    rightBtn.Position = UDim2.new(0.68, 3, 0, 0)
    rightBtn.BackgroundColor3 = rightColor or Color3.fromRGB(180, 70, 70)
    rightBtn.BackgroundTransparency = 0.45
    rightBtn.BorderSizePixel = 0
    rightBtn.Text = rightTitle
    rightBtn.TextColor3 = Color3.fromRGB(255, 245, 245)
    rightBtn.Font = Enum.Font.GothamBold
    rightBtn.TextSize = 11
    Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 7)
    rightBtn.MouseButton1Click:Connect(rightCallback)
    
    return container
end

local function AddToggleUI(parent, title, defaultState, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 38)
    container.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 7)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(245, 245, 250)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggled = defaultState
    local switch = Instance.new("TextButton", container)
    switch.Size = UDim2.new(0, 48, 0, 22)
    switch.Position = UDim2.new(1, -52, 0.5, -11)
    switch.BackgroundColor3 = toggled and Color3.fromRGB(50, 160, 100) or Color3.fromRGB(60, 60, 70)
    switch.BackgroundTransparency = toggled and 0.3 or 0.4
    switch.BorderSizePixel = 0
    switch.Text = toggled and "ON" or "OFF"
    switch.TextColor3 = Color3.fromRGB(255, 255, 255)
    switch.Font = Enum.Font.GothamBold
    switch.TextSize = 10
    Instance.new("UICorner", switch).CornerRadius = UDim.new(0, 5)
    
    switch.MouseButton1Click:Connect(function()
        toggled = not toggled
        switch.BackgroundColor3 = toggled and Color3.fromRGB(50, 160, 100) or Color3.fromRGB(60, 60, 70)
        switch.BackgroundTransparency = toggled and 0.3 or 0.4
        switch.Text = toggled and "ON" or "OFF"
        if callback then callback(toggled) end
    end)
    
    return { Value = toggled }
end

local function AddBigRecordToggle(parent, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 54)
    container.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
    
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1, -8, 1, -8)
    btn.Position = UDim2.new(0, 4, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
    btn.BackgroundTransparency = 0.4
    btn.BorderSizePixel = 0
    btn.Text = "●  RECORD"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.FredokaOne
    btn.TextSize = 13
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local toggled = false
    local animThread = nil
    local toggleObj = { Value = toggled }
    
    local function UpdateState(val)
        toggled = val
        toggleObj.Value = val
        if animThread then task.cancel(animThread) animThread = nil end
        
        if toggled then
            btn.BackgroundColor3 = Color3.fromRGB(50, 160, 100)
            btn.BackgroundTransparency = 0.3
            animThread = task.spawn(function()
                local dots = {"", ".", "..", "..."}
                local i = 1
                while toggled do
                    btn.Text = "●  RECORDING" .. dots[i]
                    i = (i % #dots) + 1
                    task.wait(0.4)
                end
            end)
        else
            btn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
            btn.BackgroundTransparency = 0.4
            btn.Text = "●  RECORD"
        end
        if callback then callback(toggled) end
    end
    
    btn.MouseButton1Click:Connect(function() UpdateState(not toggled) end)
    function toggleObj:SetValue(val) UpdateState(val) end
    return toggleObj
end

local function AddInputUI(parent, title, defaultText, placeholder, callback)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 52)
    container.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 7)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -12, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(170, 170, 185)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local box = Instance.new("TextBox", container)
    box.Size = UDim2.new(1, -16, 0, 24)
    box.Position = UDim2.new(0, 8, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    box.BackgroundTransparency = 0.2
    box.BorderSizePixel = 0
    box.Text = defaultText or ""
    box.PlaceholderText = placeholder or ""
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    
    local inputObj = { Value = defaultText or "", Box = box }
    box:GetPropertyChangedSignal("Text"):Connect(function()
        inputObj.Value = box.Text
        if callback then callback(box.Text) end
    end)
    
    return inputObj
end

local function AddSearchableDropdown(parent, title, items)
    local container = Instance.new("Frame", parent)
    container.Size = UDim2.new(1, -4, 0, 52)
    container.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    container.BackgroundTransparency = 0.4
    container.BorderSizePixel = 0
    container.ClipsDescendants = true
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 7)
    
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, -12, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel = 0
    lbl.Text = title
    lbl.TextColor3 = Color3.fromRGB(170, 170, 185)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local searchBox = Instance.new("TextBox", container)
    searchBox.Size = UDim2.new(1, -42, 0, 24)
    searchBox.Position = UDim2.new(0, 8, 0, 24)
    searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    searchBox.BackgroundTransparency = 0.2
    searchBox.BorderSizePixel = 0
    searchBox.Text = ""
    searchBox.PlaceholderText = "Cari atau pilih..."
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 11
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)

    local refreshBtn = Instance.new("TextButton", container)
    refreshBtn.Size = UDim2.new(0, 24, 0, 24)
    refreshBtn.Position = UDim2.new(1, -30, 0, 24)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    refreshBtn.BackgroundTransparency = 0.3
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄"
    refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 11
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 5)
    
    local listFrame = Instance.new("ScrollingFrame", container)
    listFrame.Size = UDim2.new(1, -16, 0, 0)
    listFrame.Position = UDim2.new(0, 8, 0, 52)
    listFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    listFrame.BackgroundTransparency = 0.4
    listFrame.Visible = false
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.ScrollBarThickness = 3
    listFrame.BorderSizePixel = 0
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 5)
    
    local dropLayout = Instance.new("UIListLayout", listFrame)
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local dropObj = { Value = "", Values = items or {} }
    local currentFilteredValues = {}
    
    local function RefreshValues(filterText)
        filterText = filterText or ""
        for _, c in pairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local query = filterText:lower()
        currentFilteredValues = {}
        
        local sortedValues = {}
        for _, val in ipairs(dropObj.Values) do
            if query == "" or val:lower():find(query) then
                table.insert(sortedValues, val)
            end
        end
        table.sort(sortedValues)
        
        local count = 0
        for _, val in ipairs(sortedValues) do
            count = count + 1
            table.insert(currentFilteredValues, val)
            
            local durationStr = "00:00"
            local recData = SavedData[val]
            if recData and type(recData) == "table" and #recData > 0 then
                local lastEntry = recData[#recData]
                if lastEntry and lastEntry.time then
                    durationStr = FormatTime(lastEntry.time)
                end
            end
            
            local itemBtn = Instance.new("TextButton", listFrame)
            itemBtn.Size = UDim2.new(1, 0, 0, 26)
            itemBtn.BackgroundColor3 = (dropObj.Value == val) and Color3.fromRGB(50, 160, 100) or Color3.fromRGB(26, 26, 32)
            itemBtn.BackgroundTransparency = (dropObj.Value == val) and 0.3 or 0.4
            itemBtn.BorderSizePixel = 0
            itemBtn.Text = ""
            itemBtn.Font = Enum.Font.GothamMedium
            itemBtn.TextSize = 11
            
            local nameLbl = Instance.new("TextLabel", itemBtn)
            nameLbl.Size = UDim2.new(1, -55, 1, 0)
            nameLbl.Position = UDim2.new(0, 8, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = val
            nameLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
            nameLbl.Font = Enum.Font.GothamMedium
            nameLbl.TextSize = 11
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            
            local timeLbl = Instance.new("TextLabel", itemBtn)
            timeLbl.Size = UDim2.new(0, 50, 1, 0)
            timeLbl.Position = UDim2.new(1, -55, 0, 0)
            timeLbl.BackgroundTransparency = 1
            timeLbl.Text = durationStr
            timeLbl.TextColor3 = Color3.fromRGB(0, 255, 170)
            timeLbl.Font = Enum.Font.GothamBold
            timeLbl.TextSize = 10
            timeLbl.TextXAlignment = Enum.TextXAlignment.Right
            
            itemBtn.MouseButton1Click:Connect(function()
                dropObj.Value = val
                searchBox.Text = val
                listFrame.Visible = false
                container.Size = UDim2.new(1, -4, 0, 52)
            end)
        end
        
        if #currentFilteredValues > 0 and query ~= "" then
            dropObj.Value = currentFilteredValues[1]
        end
        
        local displayCount = math.min(count, 4)
        local targetHeight = displayCount * 26
        
        if count > 0 then
            listFrame.Visible = true
            listFrame.Size = UDim2.new(1, -16, 0, targetHeight)
            container.Size = UDim2.new(1, -4, 0, 58 + targetHeight)
        else
            listFrame.Visible = false
            listFrame.Size = UDim2.new(1, -16, 0, 0)
            container.Size = UDim2.new(1, -4, 0, 52)
        end
        listFrame.CanvasSize = UDim2.new(0, 0, 0, count * 26)
    end
    
    searchBox.Focused:Connect(function()
        RefreshValues(searchBox.Text)
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        RefreshValues(searchBox.Text)
    end)
    
    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and #currentFilteredValues > 0 then
            local topMatch = currentFilteredValues[1]
            dropObj.Value = topMatch
            searchBox.Text = topMatch
            listFrame.Visible = false
            container.Size = UDim2.new(1, -4, 0, 52)
            
            task.spawn(function()
                searchBox.BackgroundColor3 = Color3.fromRGB(50, 160, 100)
                task.wait(0.3)
                searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            end)
        end
    end)
    
    refreshBtn.MouseButton1Click:Connect(function()
        Load()
        if RefreshLists then RefreshLists() end
        dropObj.Value = ""
        searchBox.Text = ""
        listFrame.Visible = false
        container.Size = UDim2.new(1, -4, 0, 52)
    end)
    
    function dropObj:SetValues(newVals)
        dropObj.Values = newVals or {}
        RefreshValues(searchBox.Text)
    end
    
    RefreshValues()
    return dropObj
end

-- [ STACKING NOTIFICATION SYSTEM ]
local activeNotifications = {}

local function Notify(data)
    table.insert(activeNotifications, 1, nil)
    
    local notif = Instance.new("Frame", ScreenGui)
    notif.Size = UDim2.new(0, 215, 0, 44)
    notif.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    notif.BackgroundTransparency = 0.2
    notif.BorderSizePixel = 0
    notif.ZIndex = 100
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", notif)
    stroke.Color = data.Color or Color3.fromRGB(50, 160, 100)
    stroke.Transparency = 0.4
    
    local tLbl = Instance.new("TextLabel", notif)
    tLbl.Size = UDim2.new(1, -12, 0, 16)
    tLbl.Position = UDim2.new(0, 10, 0, 4)
    tLbl.BackgroundTransparency = 1
    tLbl.BorderSizePixel = 0
    tLbl.Text = data.Title or "System"
    tLbl.TextColor3 = data.Color or Color3.fromRGB(50, 160, 100)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 11
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.ZIndex = 101
    
    local cLbl = Instance.new("TextLabel", notif)
    cLbl.Size = UDim2.new(1, -12, 0, 18)
    cLbl.Position = UDim2.new(0, 10, 0, 20)
    cLbl.BackgroundTransparency = 1
    cLbl.BorderSizePixel = 0
    cLbl.Text = data.Content or ""
    cLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
    cLbl.Font = Enum.Font.GothamMedium
    cLbl.TextSize = 10
    cLbl.TextXAlignment = Enum.TextXAlignment.Left
    cLbl.ZIndex = 101
    
    table.remove(activeNotifications, 1)
    table.insert(activeNotifications, notif)
    
    local function UpdateNotificationPositions()
        for i, gui in ipairs(activeNotifications) do
            if gui and gui.Parent then
                local targetY = 20 + ((#activeNotifications - i) * 50)
                gui.Position = UDim2.new(1, -230, 0, targetY)
            end
        end
    end
    
    UpdateNotificationPositions()
    
    task.delay(2.5, function()
        pcall(function()
            local index = table.find(activeNotifications, notif)
            if index then
                table.remove(activeNotifications, index)
            end
            notif:Destroy()
            UpdateNotificationPositions()
        end)
    end)
end

-- Floating Toggle Button (KIW)
local ToggleButton = Instance.new("TextButton", ScreenGui)
ToggleButton.Size = UDim2.new(0, 44, 0, 44)
ToggleButton.Position = UDim2.new(0.18, 0, 0.08, 0)
ToggleButton.Text = "KIW"
ToggleButton.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ToggleButton.BackgroundTransparency = 0.3
ToggleButton.BorderSizePixel = 0
ToggleButton.TextColor3 = Color3.fromRGB(245, 245, 250)
ToggleButton.Font = Enum.Font.FredokaOne
ToggleButton.TextSize = 12
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 10)

local ToggleStroke = Instance.new("UIStroke", ToggleButton)
ToggleStroke.Color = Color3.fromRGB(150, 150, 165)
ToggleStroke.Transparency = 0.3
ToggleStroke.Thickness = 1.5

ToggleButton.MouseButton1Click:Connect(function() 
    MainFrame.Visible = not MainFrame.Visible 
end)

-- Quick Playback Panel
local QuickFrame = Instance.new("Frame", ScreenGui)
QuickFrame.Size = UDim2.fromOffset(190, 105)
QuickFrame.Position = UDim2.new(0.23, 0, 0.15, 0)
QuickFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
QuickFrame.BackgroundTransparency = 0.3
QuickFrame.BorderSizePixel = 0
QuickFrame.ClipsDescendants = false
QuickFrame.Visible = false
Instance.new("UICorner", QuickFrame).CornerRadius = UDim.new(0, 10)

local QuickStroke = Instance.new("UIStroke", QuickFrame)
QuickStroke.Color = Color3.fromRGB(150, 150, 165)
QuickStroke.Transparency = 0.3
QuickStroke.Thickness = 1.5

local QuickTitle = Instance.new("TextLabel", QuickFrame)
QuickTitle.Size = UDim2.new(1, 0, 0, 22)
QuickTitle.Position = UDim2.new(0, 0, 0, 3)
QuickTitle.BackgroundTransparency = 1
QuickTitle.BorderSizePixel = 0
QuickTitle.Text = "⚡ QUICK PLAY"
QuickTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
QuickTitle.Font = Enum.Font.FredokaOne
QuickTitle.TextSize = 10

local QuickSearchBox = Instance.new("TextBox", QuickFrame)
QuickSearchBox.Size = UDim2.new(1, -50, 0, 24)
QuickSearchBox.Position = UDim2.new(0, 8, 0, 26)
QuickSearchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
QuickSearchBox.BackgroundTransparency = 0.2
QuickSearchBox.BorderSizePixel = 0
QuickSearchBox.Text = ""
QuickSearchBox.PlaceholderText = "Cari..."
QuickSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickSearchBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 155)
QuickSearchBox.Font = Enum.Font.Gotham
QuickSearchBox.TextSize = 10
Instance.new("UICorner", QuickSearchBox).CornerRadius = UDim.new(0, 5)

local QuickRefreshBtn = Instance.new("TextButton", QuickFrame)
QuickRefreshBtn.Size = UDim2.new(0, 24, 0, 24)
QuickRefreshBtn.Position = UDim2.new(1, -32, 0, 26)
QuickRefreshBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
QuickRefreshBtn.BackgroundTransparency = 0.3
QuickRefreshBtn.BorderSizePixel = 0
QuickRefreshBtn.Text = "🔄"
QuickRefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickRefreshBtn.Font = Enum.Font.GothamBold
QuickRefreshBtn.TextSize = 10
Instance.new("UICorner", QuickRefreshBtn).CornerRadius = UDim.new(0, 5)

local QuickListFrame = Instance.new("ScrollingFrame", QuickFrame)
QuickListFrame.Size = UDim2.new(1, -16, 0, 0)
QuickListFrame.Position = UDim2.new(0, 8, 0, 54)
QuickListFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
QuickListFrame.BackgroundTransparency = 0.4
QuickListFrame.Visible = false
QuickListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
QuickListFrame.ScrollBarThickness = 3
QuickListFrame.BorderSizePixel = 0
Instance.new("UICorner", QuickListFrame).CornerRadius = UDim.new(0, 5)

local QuickListLayout = Instance.new("UIListLayout", QuickListFrame)
QuickListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local QuickPlayBtn = Instance.new("TextButton", QuickFrame)
QuickPlayBtn.Size = UDim2.new(0.55, -4, 0, 26)
QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68)
QuickPlayBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 100)
QuickPlayBtn.BackgroundTransparency = 0.4
QuickPlayBtn.BorderSizePixel = 0
QuickPlayBtn.Text = "▶ PLAY"
QuickPlayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickPlayBtn.Font = Enum.Font.GothamBold
QuickPlayBtn.TextSize = 10
Instance.new("UICorner", QuickPlayBtn).CornerRadius = UDim.new(0, 6)

local QuickStopBtn = Instance.new("TextButton", QuickFrame)
QuickStopBtn.Size = UDim2.new(0.35, -4, 0, 26)
QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68)
QuickStopBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
QuickStopBtn.BackgroundTransparency = 0.4
QuickStopBtn.BorderSizePixel = 0
QuickStopBtn.Text = "⏹ STOP"
QuickStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickStopBtn.Font = Enum.Font.GothamBold
QuickStopBtn.TextSize = 10
Instance.new("UICorner", QuickStopBtn).CornerRadius = UDim.new(0, 6)

local QuickSelectedValue = ""
local QuickFilteredValues = {}

local function UpdateQuickDropdownList(filterText)
    filterText = filterText or ""
    for _, c in pairs(QuickListFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    local query = filterText:lower()
    QuickFilteredValues = {}
    
    local matchedNames = {}
    for name, _ in pairs(SavedData) do
        if query == "" or name:lower():find(query) then
            table.insert(matchedNames, name)
        end
    end
    table.sort(matchedNames)
    
    local count = 0
    for _, name in ipairs(matchedNames) do
        count = count + 1
        table.insert(QuickFilteredValues, name)
        
        local itemBtn = Instance.new("TextButton", QuickListFrame)
        itemBtn.Size = UDim2.new(1, 0, 0, 26)
        itemBtn.BackgroundColor3 = (QuickSelectedValue == name) and Color3.fromRGB(50, 160, 100) or Color3.fromRGB(26, 26, 32)
        itemBtn.BackgroundTransparency = (QuickSelectedValue == name) and 0.3 or 0.4
        itemBtn.BorderSizePixel = 0
        itemBtn.Text = "  " .. name
        itemBtn.TextColor3 = Color3.fromRGB(245, 245, 250)
        itemBtn.Font = Enum.Font.GothamMedium
        itemBtn.TextSize = 10
        itemBtn.TextXAlignment = Enum.TextXAlignment.Left
        
        itemBtn.MouseButton1Click:Connect(function()
            QuickSelectedValue = name
            QuickSearchBox.Text = name
            QuickListFrame.Visible = false
            QuickFrame.Size = UDim2.fromOffset(190, 105)
            QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68)
            QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68)
        end)
    end
    
    if #QuickFilteredValues > 0 and query ~= "" then
        QuickSelectedValue = QuickFilteredValues[1]
    end
    
    local displayCount = math.min(count, 3)
    local targetHeight = displayCount * 26
    
    if count > 0 then
        QuickListFrame.Visible = true
        QuickListFrame.Size = UDim2.new(1, -16, 0, targetHeight)
        local totalDynamicHeight = 105 + targetHeight
        QuickFrame.Size = UDim2.fromOffset(190, totalDynamicHeight)
        QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68 + targetHeight)
        QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68 + targetHeight)
    else
        QuickListFrame.Visible = false
        QuickListFrame.Size = UDim2.new(1, -16, 0, 0)
        QuickFrame.Size = UDim2.fromOffset(190, 105)
        QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68)
        QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68)
    end
    QuickListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 26)
end

QuickSearchBox.Focused:Connect(function()
    UpdateQuickDropdownList(QuickSearchBox.Text)
end)

QuickSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    UpdateQuickDropdownList(QuickSearchBox.Text)
end)

QuickSearchBox.FocusLost:Connect(function(enterPressed)
    if enterPressed and #QuickFilteredValues > 0 then
        local topMatch = QuickFilteredValues[1]
        QuickSelectedValue = topMatch
        QuickSearchBox.Text = topMatch
        QuickListFrame.Visible = false
        QuickFrame.Size = UDim2.fromOffset(190, 105)
        QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68)
        QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68)
        
        task.spawn(function()
            QuickSearchBox.BackgroundColor3 = Color3.fromRGB(50, 160, 100)
            task.wait(0.3)
            QuickSearchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        end)
    end
end)

QuickRefreshBtn.MouseButton1Click:Connect(function()
    Load()
    if RefreshLists then RefreshLists() end
    QuickSelectedValue = ""
    QuickSearchBox.Text = ""
    QuickListFrame.Visible = false
    QuickFrame.Size = UDim2.fromOffset(190, 105)
    QuickPlayBtn.Position = UDim2.new(0.05, 0, 0, 68)
    QuickStopBtn.Position = UDim2.new(0.62, 0, 0, 68)
    UpdateQuickDropdownList("")
end)

local function MakeDraggable(obj, handle)
    handle = handle or obj
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = obj.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local ResizeHandle = Instance.new("Frame", MainFrame)
ResizeHandle.Size = UDim2.fromOffset(18, 18)
ResizeHandle.Position = UDim2.new(1, -18, 1, -18)
ResizeHandle.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
ResizeHandle.BackgroundTransparency = 0.5
ResizeHandle.BorderSizePixel = 0

local CornerFix = Instance.new("UICorner", ResizeHandle)
CornerFix.CornerRadius = UDim.new(0, 12)

local ResizeIcon = Instance.new("TextButton", ResizeHandle)
ResizeIcon.Size = UDim2.fromScale(1, 1)
ResizeIcon.BackgroundTransparency = 1
ResizeIcon.BorderSizePixel = 0
ResizeIcon.Text = "◢"
ResizeIcon.TextColor3 = Color3.fromRGB(180, 180, 195)
ResizeIcon.TextTransparency = 0.3
ResizeIcon.Font = Enum.Font.GothamBold
ResizeIcon.TextSize = 11

local resizing = false
local resizeStart, startSize
ResizeIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = input.Position
        startSize = MainFrame.AbsoluteSize
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then resizing = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - resizeStart
        local newWidth = math.clamp(startSize.X + delta.X, 300, 600)
        local newHeight = math.clamp(startSize.Y + delta.Y, 300, 550)
        MainFrame.Size = UDim2.fromOffset(newWidth, newHeight)
    end
end)

MakeDraggable(MainFrame, TopBar)
MakeDraggable(ToggleButton)
MakeDraggable(QuickFrame)

-- [ 3. CORE VARIABLES ]
local IsRecording, IsPlayingPlayback = false, false
local CurrentPlaybackThread = nil
local TempSession = {}
local StartTime = 0
local CharacterConnection = nil
local IsFromRandomLoop = false

-- [ NOW PLAYING UI COMPONENTS ]
local NowPlayingContainer = Instance.new("Frame", Tabs.Surgery)
NowPlayingContainer.Size = UDim2.new(1, -4, 0, 52)
NowPlayingContainer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
NowPlayingContainer.BackgroundTransparency = 0.3
NowPlayingContainer.BorderSizePixel = 0
NowPlayingContainer.Visible = false
Instance.new("UICorner", NowPlayingContainer).CornerRadius = UDim.new(0, 8)

local NowPlayingTitle = Instance.new("TextLabel", NowPlayingContainer)
NowPlayingTitle.Size = UDim2.new(1, -12, 0, 16)
NowPlayingTitle.Position = UDim2.new(0, 8, 0, 6)
NowPlayingTitle.BackgroundTransparency = 1
NowPlayingTitle.BorderSizePixel = 0
NowPlayingTitle.Text = "NOW PLAYING"
NowPlayingTitle.TextColor3 = Color3.fromRGB(170, 170, 185)
NowPlayingTitle.Font = Enum.Font.GothamBold
NowPlayingTitle.TextSize = 9
NowPlayingTitle.TextXAlignment = Enum.TextXAlignment.Left

local NowPlayingSongLabel = Instance.new("TextLabel", NowPlayingContainer)
NowPlayingSongLabel.Size = UDim2.new(0.65, 0, 0, 24)
NowPlayingSongLabel.Position = UDim2.new(0, 8, 0, 22)
NowPlayingSongLabel.BackgroundTransparency = 1
NowPlayingSongLabel.BorderSizePixel = 0
NowPlayingSongLabel.Text = ""
NowPlayingSongLabel.TextColor3 = Color3.fromRGB(0, 255, 170)
NowPlayingSongLabel.Font = Enum.Font.FredokaOne
NowPlayingSongLabel.TextSize = 11
NowPlayingSongLabel.TextXAlignment = Enum.TextXAlignment.Left

local NowPlayingTimeLabel = Instance.new("TextLabel", NowPlayingContainer)
NowPlayingTimeLabel.Size = UDim2.new(0.33, 0, 0, 24)
NowPlayingTimeLabel.Position = UDim2.new(0.67, -8, 0, 22)
NowPlayingTimeLabel.BackgroundTransparency = 1
NowPlayingTimeLabel.BorderSizePixel = 0
NowPlayingTimeLabel.Text = ""
NowPlayingTimeLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
NowPlayingTimeLabel.Font = Enum.Font.GothamBold
NowPlayingTimeLabel.TextSize = 10
NowPlayingTimeLabel.TextXAlignment = Enum.TextXAlignment.Right

-- [ 4. PROTOCOL ENGINE & GLOBAL CLEANUP ]
GlobalStop = function()
    IsPlayingPlayback = false
    IsRecording = false
    IsFromRandomLoop = false
    
    if CurrentPlaybackThread then 
        pcall(function() task.cancel(CurrentPlaybackThread) end)
        CurrentPlaybackThread = nil 
    end
    
    NowPlayingSongLabel.Text = ""
    NowPlayingTimeLabel.Text = ""
    NowPlayingContainer.Visible = false
    
    pcall(function()
        local Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        if Events then
            local UpdateAnim = Events:FindFirstChild("UpdateAnimation")
            local UpdateSpeed = Events:FindFirstChild("UpdateSpeed")
            
            if UpdateAnim then
                UpdateAnim:FireServer(nil)
                task.wait(0.05)
                UpdateAnim:FireServer(nil)
            end
            if UpdateSpeed then UpdateSpeed:FireServer(1) end
        end
    end)
end

getgenv().AutoLeadCleanup = function()
    GlobalStop()
    if CharacterConnection then pcall(function() CharacterConnection:Disconnect() end) end
    if RemoteConnection then pcall(function() RemoteConnection:Disconnect() end) end
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
    getgenv().AutoLeadCleanup = nil
end

-- [ 6. RECORDER ]
local function SetupRecorder()
    local Char = player.Character or player.CharacterAdded:Wait()
    local Hum = Char:WaitForChild("Humanoid")
    
    Hum.AnimationPlayed:Connect(function(track)
        if not IsRecording then return end
        if track.Priority == Enum.AnimationPriority.Core then return end
        
        table.insert(TempSession, {
            id = track.Animation.AnimationId, 
            time = tick() - StartTime, 
            speed = track.Speed,
            isNewAnim = true 
        })

        task.spawn(function()
            local lastRecordedSpeed = track.Speed
            while IsRecording and track.IsPlaying do
                if math.abs(track.Speed - lastRecordedSpeed) > 0.01 then
                    lastRecordedSpeed = track.Speed
                    table.insert(TempSession, {
                        id = track.Animation.AnimationId, 
                        time = tick() - StartTime, 
                        speed = track.Speed, 
                        isSpeedUpdateOnly = true 
                    })
                end
                task.wait(0.03)
            end
        end)
    end)
end
SetupRecorder()
CharacterConnection = player.CharacterAdded:Connect(SetupRecorder)

-- [ 7. EDITOR LOGIC & UI ACTIONS ]
local EditorList = {}
local SelectedRecForEdit = ""
local RefreshEditorUI

RefreshEditorUI = function()
    for _, v in pairs(EditorList) do if v and v.Destroy then v:Destroy() end end
    table.clear(EditorList)
    
    local data = SavedData[SelectedRecForEdit]
    if not data then return end
    
    for i, entry in ipairs(data) do
        local label = entry.isSpeedUpdateOnly and "⚡ SPEED" or "🎬 ANIM"
        local section = AddSectionHeader(Tabs.Editor, string.format("[%d] %s", i, label))
        table.insert(EditorList, section)
        
        local timeInp = AddInputUI(Tabs.Editor, "WAKTU (DETIK)", tostring(math.floor(entry.time * 1000)/1000), "", function(v)
            entry.time = tonumber(v) or entry.time
        end)
        
        local speedInp = AddInputUI(Tabs.Editor, "KECEPATAN", tostring(entry.speed), "", function(v)
            entry.speed = tonumber(v) or entry.speed
        end)
        
        local delBtn = AddButtonUI(Tabs.Editor, "❌ HAPUS ENTRY INI", function()
            table.remove(data, i)
            Save()
            RefreshEditorUI()
        end)
        
        table.insert(EditorList, timeInp.Box.Parent)
        table.insert(EditorList, speedInp.Box.Parent)
        table.insert(EditorList, delBtn)
    end
end

local RecToggle = AddBigRecordToggle(Tabs.Main, function(value)
    IsRecording = value
    if IsRecording then GlobalStop() IsRecording = true TempSession = {} StartTime = tick() end
end)

local RecNameInput = AddInputUI(Tabs.Main, "NAMA DANCE", "Dance_1", "Masukkan nama dance...")
AddButtonUI(Tabs.Main, "💾 SIMPAN HASIL REKAMAN", function()
    if #TempSession == 0 then
        Notify({Title="ERROR", Content="Belum ada animasi yang terekam!", Duration=2.0})
        return
    end
    if not RecNameInput.Value or RecNameInput.Value == "" then
        Notify({Title="ERROR", Content="Nama dance tidak boleh kosong!", Duration=2.0})
        return
    end
    
    Load()
    SavedData[RecNameInput.Value] = TempSession
    local success, err = Save()
    
    if success then
        RecToggle:SetValue(false)
        RefreshLists()
        Notify({Title="SAVED", Content="Rekaman berhasil disimpan!", Duration = 2.0})
    else
        Notify({Title="SAVE FAILED", Content=tostring(err or "Executor block writefile"), Duration = 2.0})
    end
end)

AddSectionHeader(Tabs.Editor, "PILIH & EDIT")
local EditSelect = AddSearchableDropdown(Tabs.Editor, "PILIH REKAMAN UNTUK DIEDIT", {})

AddSectionHeader(Tabs.Editor, "GANTI NAMA REKAMAN")
local NewNameInputObj = AddInputUI(Tabs.Editor, "NAMA BARU", "", "Masukkan nama baru...")

AddButtonUI(Tabs.Editor, "📝 GANTI NAMA (RENAME)", function()
    local oldName = EditSelect.Value
    local newName = NewNameInputObj.Value
    if not oldName or oldName == "" or not newName or newName == "" or newName == oldName then return end
    if SavedData[newName] then return end

    SavedData[newName] = SavedData[oldName]
    SavedData[oldName] = nil
    Save()
    if RefreshLists then RefreshLists() end
    Notify({Title = "SUCCESS", Content = string.format("Rekaman '%s' diganti menjadi '%s'", oldName, newName), Duration = 2.0})
end)

AddSectionHeader(Tabs.Editor, "EDITOR")
AddButtonUI(Tabs.Editor, "🛠 BUKA TIMELINE", function()
    SelectedRecForEdit = EditSelect.Value
    RefreshEditorUI()
end)
AddButtonUI(Tabs.Editor, "💾 SIMPAN PERUBAHAN", Save)

-- [ TAB PLAYBACK ]
local RecSelect = AddSearchableDropdown(Tabs.Surgery, "REKAMAN", {})

RefreshLists = function()
    local n = {} 
    if SavedData then
        for k, _ in pairs(SavedData) do table.insert(n, k) end
        table.sort(n) 
        RecSelect:SetValues(n)
        if EditSelect then EditSelect:SetValues(n) end
    end
    UpdateQuickDropdownList(QuickSearchBox.Text)
end

RunPlayback = function(targetName, isRandomLoop)
    if not targetName or not SavedData[targetName] then 
        local keys = {}
        for k, _ in pairs(SavedData) do table.insert(keys, k) end
        if #keys > 0 then
            math.randomseed(tick())
            targetName = keys[math.random(1, #keys)]
        else
            return 
        end
    end
    
    IsPlayingPlayback = false
    if CurrentPlaybackThread then 
        pcall(function() task.cancel(CurrentPlaybackThread) end)
        CurrentPlaybackThread = nil 
    end
    task.wait(0.05) 
    
    IsPlayingPlayback = true
    IsFromRandomLoop = isRandomLoop or false
    local pStart = tick()
    
    CurrentPlaybackThread = task.spawn(function()
        local rawDataList = SavedData[targetName] 
        if not rawDataList or type(rawDataList) ~= "table" or #rawDataList == 0 then 
            IsPlayingPlayback = false 
            NowPlayingContainer.Visible = false
            return 
        end
        
        local processedData = {}         
        local lastId = ""

        for _, entry in ipairs(rawDataList) do
            if entry and type(entry) == "table" and entry.id then
                local newEntry = { 
                    id = entry.id, 
                    time = tonumber(entry.time) or 0, 
                    speed = tonumber(entry.speed) or 1 
                }
                
                if entry.isNewAnim ~= nil or entry.isSpeedUpdateOnly ~= nil then
                    newEntry.isNewAnim = entry.isNewAnim
                    newEntry.isSpeedUpdateOnly = entry.isSpeedUpdateOnly
                else
                    if entry.id == lastId and lastId ~= "" then
                        newEntry.isNewAnim = false
                        newEntry.isSpeedUpdateOnly = true
                    else
                        newEntry.isNewAnim = true
                        newEntry.isSpeedUpdateOnly = false
                    end
                end
                lastId = newEntry.id
                table.insert(processedData, newEntry)
            end
        end

        if #processedData == 0 then
            IsPlayingPlayback = false
            NowPlayingContainer.Visible = false
            return
        end

        local totalDuration = processedData[#processedData].time or 0
        NowPlayingSongLabel.Text = string.upper(targetName)
        NowPlayingContainer.Visible = true

        local Events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        local UpdateAnimationEvent = Events and Events:FindFirstChild("UpdateAnimation")
        local UpdateSpeedEvent = Events and Events:FindFirstChild("UpdateSpeed")

        local firstData = processedData[1]
        if firstData and UpdateAnimationEvent then
            pcall(function() UpdateAnimationEvent:FireServer(firstData.id) end)
            if UpdateSpeedEvent then
                pcall(function() UpdateSpeedEvent:FireServer(firstData.speed or 1) end)
            end
        end

        for i = 2, #processedData do
            if not IsPlayingPlayback then break end
            local data = processedData[i]
            
            local targetTime = pStart + data.time
            while IsPlayingPlayback and tick() < targetTime do 
                local elapsed = tick() - pStart
                NowPlayingTimeLabel.Text = string.format("%s / %s", FormatTime(elapsed), FormatTime(totalDuration))
                task.wait() 
            end
            
            if not IsPlayingPlayback then break end
            
            if data.isNewAnim then
                if UpdateAnimationEvent then 
                    pcall(function() UpdateAnimationEvent:FireServer(data.id) end) 
                end
                if UpdateSpeedEvent then 
                    pcall(function() UpdateSpeedEvent:FireServer(data.speed or 1) end) 
                end
            elseif data.isSpeedUpdateOnly then
                if UpdateSpeedEvent then 
                    pcall(function() UpdateSpeedEvent:FireServer(data.speed or 1) end) 
                end
            end
        end
        
        NowPlayingTimeLabel.Text = string.format("%s / %s", FormatTime(totalDuration), FormatTime(totalDuration))
        IsPlayingPlayback = false
        
        task.wait(0.5)
        NowPlayingContainer.Visible = false
        NowPlayingSongLabel.Text = ""
        NowPlayingTimeLabel.Text = ""
        
        if IsAutoRemotePlayEnabled and not IsPlayingPlayback and not IsRecording then
            local keys = {}
            for k, _ in pairs(SavedData) do table.insert(keys, k) end
            if #keys > 0 then
                math.randomseed(tick())
                local randomKey = keys[math.random(1, #keys)]
                Notify({Title="AUTO PLAY", Content="Lanjut Random: " .. randomKey, Color=Color3.fromRGB(255, 140, 0)})
                RunPlayback(randomKey, true)
            end
        end
    end)
end

AddDualButtonUI(Tabs.Surgery, "▶ START PLAYBACK", Color3.fromRGB(50, 160, 100), function()
    RunPlayback(RecSelect.Value, false)
end, "⏹ STOP", Color3.fromRGB(180, 70, 70), function()
    GlobalStop()
    Notify({Title="SYSTEM", Content="Playback dihentikan", Duration = 2.0})
end)

-- Tombol Toggle Auto Play via Remote (Random Choice + Dual Notification)
AddToggleUI(Tabs.Surgery, "AUTO PLAY VIA REMOTE", false, function(Value)
    IsAutoRemotePlayEnabled = Value
    
    if RemoteConnection then
        pcall(function() RemoteConnection:Disconnect() end)
        RemoteConnection = nil
    end
    
    if Value then
        task.spawn(function()
            local djFolder = game:GetService("ReplicatedStorage"):WaitForChild("DJRemotes", 5)
            local djEvent = djFolder and djFolder:WaitForChild("UpdateNowPlaying", 5)
            
            if djEvent and djEvent:IsA("RemoteEvent") then
                local function HandleRemoteData(...)
                    if not IsAutoRemotePlayEnabled or IsRecording then return end
                    
                    local args = {...}
                    local rawName = ""
                    
                    for _, arg in ipairs(args) do
                        if type(arg) == "string" and arg ~= "" then
                            rawName = arg
                            break
                        elseif type(arg) == "table" then
                            rawName = tostring(arg.Name or arg.Title or arg.Song or arg.SongName or arg[1] or "")
                            if rawName ~= "" then break end
                        end
                    end
                    
                    if rawName == "" and #args > 0 then
                        rawName = tostring(args[1])
                    end
                    
                    if rawName == "" or rawName == "nil" then return end
                    
                    local remoteName = string.lower(string.gsub(rawName, "^%s*(.-)%s*$", "%1"))
                    
                    -- NOTIFIKASI 1: Lagu terdeteksi dari remote
                    Notify({
                        Title = "DETEKSI REMOTE", 
                        Content = "Lagu terdeteksi: " .. rawName, 
                        Color = Color3.fromRGB(0, 170, 255)
                    })
                    
                    local matchedKeys = {}
                    
                    for k, _ in pairs(SavedData) do
                        local savedKeyLower = string.lower(string.gsub(k, "^%s*(.-)%s*$", "%1"))
                        if savedKeyLower == remoteName or remoteName:find(savedKeyLower, 1, true) or savedKeyLower:find(remoteName, 1, true) then
                            table.insert(matchedKeys, k)
                        end
                    end
                    
                    if #matchedKeys > 0 then
                        math.randomseed(tick())
                        local chosenKey = matchedKeys[math.random(1, #matchedKeys)]
                        
                        local notifText = (#matchedKeys > 1) and string.format("Acak (%d opsi) & Memutar: %s", #matchedKeys, chosenKey) or ("Cocok & Memutar: " .. chosenKey)
                        
                        -- NOTIFIKASI 2: Lagu cocok & mulai diputar
                        Notify({
                            Title = "AUTO PLAY", 
                            Content = notifText, 
                            Color = Color3.fromRGB(50, 160, 100)
                        })
                        RunPlayback(chosenKey, false)
                    else
                        Notify({
                            Title = "AUTO PLAY", 
                            Content = "Tidak ada di list rekaman: " .. rawName, 
                            Color = Color3.fromRGB(200, 50, 50)
                        })
                    end
                end
                
                RemoteConnection = djEvent.OnClientEvent:Connect(HandleRemoteData)
                Notify({Title="AUTO REMOTE", Content="Berhasil mendengarkan DJRemotes", Color=Color3.fromRGB(50, 160, 100)})
            else
                Notify({Title="WARNING", Content="Event DJRemotes tidak ditemukan!", Color=Color3.fromRGB(200, 50, 50)})
            end
        end)
    end
end)

AddToggleUI(Tabs.Surgery, "MUNCULKAN FLOATING PLAYBACK UI", false, function(Value)
    QuickFrame.Visible = Value
end)

QuickPlayBtn.MouseButton1Click:Connect(function()
    if QuickSelectedValue ~= "" and SavedData[QuickSelectedValue] then
        RunPlayback(QuickSelectedValue, false)
        Notify({Title="QUICK PLAY", Content="Memutar: " .. QuickSelectedValue, Color=Color3.fromRGB(50, 160, 100)})
    else
        Notify({Title="ERROR", Content="Pilih rekaman di list pop-up dulu!", Color=Color3.fromRGB(200, 50, 50)})
    end
end)

QuickStopBtn.MouseButton1Click:Connect(function()
    GlobalStop()
    Notify({Title="QUICK STOP", Content="Playback dihentikan", Color=Color3.fromRGB(200, 50, 50)})
end)

RefreshLists()

local function ShowConfirmDialog(recordName, onConfirm)
    local dialogBg = Instance.new("Frame", ScreenGui)
    dialogBg.Size = UDim2.fromScale(1, 1)
    dialogBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dialogBg.BackgroundTransparency = 0.6
    dialogBg.BorderSizePixel = 0
    dialogBg.ZIndex = 150
    
    local dialogBox = Instance.new("Frame", dialogBg)
    dialogBox.Size = UDim2.fromOffset(275, 135)
    dialogBox.Position = UDim2.new(0.5, -137, 0.5, -67)
    dialogBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    dialogBox.BackgroundTransparency = 0.2
    dialogBox.BorderSizePixel = 0
    dialogBox.ZIndex = 151
    Instance.new("UICorner", dialogBox).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", dialogBox)
    stroke.Color = Color3.fromRGB(180, 70, 70)
    stroke.Transparency = 0.4
    stroke.Thickness = 1.5
    
    local title = Instance.new("TextLabel", dialogBox)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.BorderSizePixel = 0
    title.Text = "⚠ KONFIRMASI HAPUS"
    title.TextColor3 = Color3.fromRGB(255, 100, 100)
    title.Font = Enum.Font.FredokaOne
    title.TextSize = 13
    title.ZIndex = 152
    
    local msg = Instance.new("TextLabel", dialogBox)
    msg.Size = UDim2.new(1, -20, 0, 35)
    msg.Position = UDim2.new(0, 10, 0, 42)
    msg.BackgroundTransparency = 1
    msg.BorderSizePixel = 0
    msg.Text = "Hapus rekaman '" .. recordName .. "' secara permanen?"
    msg.TextColor3 = Color3.fromRGB(230, 230, 240)
    msg.Font = Enum.Font.GothamMedium
    msg.TextSize = 11
    msg.TextWrapped = true
    msg.ZIndex = 152
    
    local yesBtn = Instance.new("TextButton", dialogBox)
    yesBtn.Size = UDim2.new(0.45, 0, 0, 28)
    yesBtn.Position = UDim2.new(0.05, 0, 1, -38)
    yesBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
    yesBtn.BackgroundTransparency = 0.3
    yesBtn.BorderSizePixel = 0
    yesBtn.Text = "YA, HAPUS"
    yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    yesBtn.Font = Enum.Font.GothamBold
    yesBtn.TextSize = 11
    yesBtn.ZIndex = 152
    Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 6)
    
    local noBtn = Instance.new("TextButton", dialogBox)
    noBtn.Size = UDim2.new(0.45, 0, 0, 28)
    noBtn.Position = UDim2.new(0.5, 0, 1, -38)
    noBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    noBtn.BackgroundTransparency = 0.3
    noBtn.BorderSizePixel = 0
    noBtn.Text = "BATAL"
    noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    noBtn.Font = Enum.Font.GothamBold
    noBtn.TextSize = 11
    noBtn.ZIndex = 152
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 6)
    
    yesBtn.MouseButton1Click:Connect(function()
        pcall(function() dialogBg:Destroy() end)
        if onConfirm then onConfirm() end
    end)
    
    noBtn.MouseButton1Click:Connect(function()
        pcall(function() dialogBg:Destroy() end)
    end)
end

AddButtonUI(Tabs.Surgery, "🗑️ HAPUS REKAMAN (PERMANEN)", function()
    local selectedName = RecSelect.Value
    if not selectedName or selectedName == "" or not SavedData[selectedName] then
        Notify({Title="ERROR", Content="Tidak ada rekaman yang dipilih.", Color=Color3.fromRGB(200, 50, 50)})
        return
    end
    
    ShowConfirmDialog(selectedName, function()
        SavedData[selectedName] = nil
        Save()
        RefreshLists()
        Notify({Title="DELETED", Content="Rekaman telah dihapus.", Color=Color3.fromRGB(200, 50, 50)})
    end)
end)
