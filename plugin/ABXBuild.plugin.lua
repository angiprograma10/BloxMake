-- ABX Build Plugin - acción segura de creación
-- Compatible con el backend actual de ABX Build.
-- Importante: este plugin aplica únicamente acciones JSON permitidas; nunca ejecuta Lua arbitrario.

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local BACKEND_URL = "https://abx-build-backend.onrender.com"
local CONNECTION_CODE = ""
local polling = false
local pendingAction = nil

local toolbar = plugin:CreateToolbar("ABX Build")
local toggleButton = toolbar:CreateButton("ABX Build", "Abrir ABX Build", "rbxassetid://4458901886")
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right, false, false, 360, 420, 300, 320
)
local widget = plugin:CreateDockWidgetPluginGui("ABXBuildSafeActions", widgetInfo)
widget.Title = "ABX Build"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
root.Parent = widget

local function makeLabel(text, y, height)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 12, 0, y)
    label.Size = UDim2.new(1, -24, 0, height)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 240, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.Text = text
    label.Parent = root
    return label
end

local statusLabel = makeLabel("Conectando con ABX Build...", 12, 36)
local codeLabel = makeLabel("Código: generando...", 52, 28)
local actionLabel = makeLabel("No hay acciones pendientes.", 90, 110)
actionLabel.TextYAlignment = Enum.TextYAlignment.Top

local function makeButton(text, y, callback, color)
    local button = Instance.new("TextButton")
    button.Position = UDim2.new(0, 12, 0, y)
    button.Size = UDim2.new(1, -24, 0, 36)
    button.BackgroundColor3 = color or Color3.fromRGB(55, 100, 220)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.Text = text
    button.Parent = root
    button.Activated:Connect(callback)
    return button
end

local function request(method, path, body)
    local options = {
        Url = BACKEND_URL .. path,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
    }
    if body then
        options.Body = HttpService:JSONEncode(body)
    end
    local response = HttpService:RequestAsync(options)
    if not response.Success then
        error("HTTP " .. tostring(response.StatusCode))
    end
    return HttpService:JSONDecode(response.Body)
end

local function generateConnectionCode()
    CONNECTION_CODE = tostring(math.random(10000, 99999))
    local ok, err = pcall(function()
        request("POST", "/register", { code = CONNECTION_CODE })
    end)
    if ok then
        codeLabel.Text = "Código: " .. CONNECTION_CODE .. " (ingrésalo en la web)"
        statusLabel.Text = "Registrado. Abre ABX Build y conecta este código."
    else
        statusLabel.Text = "Error de conexión. Activa HTTP Requests en Studio."
        warn("ABX Build registro:", err)
    end
end

local function boundedNumber(value, fallback, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number then
        return fallback
    end
    return math.clamp(number, minimum, maximum)
end

local allowedColors = {
    red = Color3.fromRGB(255, 75, 75),
    blue = Color3.fromRGB(65, 135, 255),
    green = Color3.fromRGB(65, 200, 120),
    yellow = Color3.fromRGB(255, 220, 65),
    black = Color3.fromRGB(35, 35, 40),
    white = Color3.fromRGB(240, 240, 240),
    purple = Color3.fromRGB(165, 90, 230),
    orange = Color3.fromRGB(255, 145, 45),
}

local function applyAction(action)
    assert(type(action) == "table", "La acción no es un objeto JSON válido.")
    assert(type(action.type) == "string", "Falta el tipo de acción.")

    if action.type == "CREATE_PART" then
        local size = action.size
        assert(type(size) == "table" and #size == 3, "El tamaño debe tener tres números.")
        local part = Instance.new("Part")
        part.Name = "ABX_Part"
        part.Size = Vector3.new(
            boundedNumber(size[1], 10, 0.2, 512),
            boundedNumber(size[2], 1, 0.2, 512),
            boundedNumber(size[3], 10, 0.2, 512)
        )
        local position = action.position
        if type(position) == "table" and #position == 3 then
            part.Position = Vector3.new(
                boundedNumber(position[1], 0, -10000, 10000),
                boundedNumber(position[2], 5, -10000, 10000),
                boundedNumber(position[3], 0, -10000, 10000)
            )
        else
            part.Position = Vector3.new(0, 5, 0)
        end
        part.Anchored = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = allowedColors[action.color] or allowedColors.blue
        part.Parent = Workspace
        return "Pieza creada en Workspace."
    elseif action.type == "CREATE_GUI" then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ABXGeneratedUI"
        screenGui.ResetOnSpawn = false

        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.Size = UDim2.fromOffset(320, 160)
        panel.Position = UDim2.new(0.5, -160, 0.5, -80)
        panel.BackgroundColor3 = Color3.fromRGB(28, 35, 52)
        panel.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = panel

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.Size = UDim2.new(1, -20, 0, 52)
        title.Position = UDim2.fromOffset(10, 10)
        title.BackgroundTransparency = 1
        title.Text = string.sub(tostring(action.title or "Mi interfaz"), 1, 48)
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Font = Enum.Font.GothamBold
        title.TextScaled = true
        title.Parent = panel

        local button = Instance.new("TextButton")
        button.Name = "TestButton"
        button.Size = UDim2.new(1, -32, 0, 44)
        button.Position = UDim2.fromOffset(16, 94)
        button.BackgroundColor3 = Color3.fromRGB(65, 120, 245)
        button.Text = "¡Funciona!"
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = Enum.Font.GothamBold
        button.TextSize = 16
        button.Parent = panel
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button

        local oldGui = StarterGui:FindFirstChild("ABXGeneratedUI")
        if oldGui then oldGui:Destroy() end
        screenGui.Parent = StarterGui
        return "Interfaz creada en StarterGui. Inicia Play para verla."
    else
        error("Tipo de acción no permitido: " .. action.type)
    end
end

makeButton("APLICAR ACCIÓN", 214, function()
    if not pendingAction then
        statusLabel.Text = "No hay una acción para aplicar."
        return
    end

    local recording
    pcall(function()
        recording = ChangeHistoryService:TryBeginRecording("ABX Build")
    end)

    local ok, result = pcall(applyAction, pendingAction)
    if recording then
        pcall(function()
            ChangeHistoryService:FinishRecording(recording, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
        end)
    end

    if ok then
        statusLabel.Text = result
        pendingAction = nil
        actionLabel.Text = "No hay acciones pendientes."
    else
        statusLabel.Text = "No se pudo aplicar: " .. tostring(result)
        warn("ABX Build acción:", result)
    end
end, Color3.fromRGB(35, 150, 100))

makeButton("COMPROBAR CONEXIÓN", 258, function()
    local ok, result = pcall(function()
        return request("GET", "/poll/" .. CONNECTION_CODE)
    end)
    statusLabel.Text = ok and "Conexión con backend activa." or ("Error HTTP: " .. tostring(result))
end, Color3.fromRGB(65, 100, 180))

makeButton("GENERAR CÓDIGO NUEVO", 302, function()
    generateConnectionCode()
end, Color3.fromRGB(80, 80, 100))

local function pollOnce()
    if CONNECTION_CODE == "" then return end
    local ok, data = pcall(function()
        return request("GET", "/poll/" .. CONNECTION_CODE)
    end)
    if not ok then
        statusLabel.Text = "No se pudo consultar el backend. Revisa HTTP Requests."
        return
    end
    if type(data.script) ~= "string" or data.script == "" then return end

    local decodedOk, action = pcall(function()
        return HttpService:JSONDecode(data.script)
    end)
    if not decodedOk or type(action) ~= "table" then
        statusLabel.Text = "Recibí datos no válidos; no se ejecutó ningún código."
        warn("ABX Build rechazó una carga que no era JSON.")
        return
    end
    if action.type ~= "CREATE_PART" and action.type ~= "CREATE_GUI" then
        statusLabel.Text = "Acción no permitida; se ignoró."
        return
    end
    pendingAction = action
    actionLabel.Text = "Acción pendiente: " .. action.type .. "\nPulsa APLICAR ACCIÓN para modificar el proyecto."
    statusLabel.Text = "Acción recibida y lista para revisar."
end

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

if not polling then
    polling = true
    task.spawn(function()
        while polling do
            pollOnce()
            task.wait(4)
        end
    end)
end

generateConnectionCode()
