--[[
    MEGA PLUGIN v10.3.1 - EXTENDED STUDIO TOOLKIT
    Creador: Angiblox
    Backend: https://abx-build-backend.onrender.com

    V10.3.1:
    - Las funciones grandes viven en una tabla para no pasar el límite de 200 locales de Luau.

    V10.3:
    - Capa ampliada de 121 acciones extendidas con ejecución real y contratos.
    - Herramientas de construcción, selección, geometría, UI, VFX, audio y física.
    - Configuraciones de gameplay: economía, rondas, progresión, misiones y checkpoints.
    - Catálogo de contratos para MEGA DIRECTOR y especialistas.
    - Playbooks por especialidad y recetas de planificación CREATE/EDIT/REPAIR.
    - Matriz ampliada de escenarios y autopruebas ejecutables dentro de Studio.
    - Prevalidación de campos, límites de payload y reportes estructurales.

    V10.2:
    - Reporte al backend del resultado real: aplicado, fallido o rechazado.
    - Prevalidación de lotes contra el catálogo completo de acciones.
    - Bloqueo de propiedades de scripts y jerarquía en cambios genéricos.
    - Creación de árboles con limpieza completa al fallar un descendiente.
    - Auditoría sin doble conteo de servicios anidados y métricas útiles del proyecto.
    - Herramientas locales de selección: alinear, apoyar, física y agrupar.
    - Selección por descendientes, distribución y renombrado por patrón para IA.
    - Polling con backoff limitado y rechazo de payloads excesivos.
    FUNCIONES: revisión/confirmación de acciones.
    - Creación de piezas, estructuras, carpetas, valores y remotos.
    - Creación de árboles de instancias y GUIs.
    - Creación de scripts con comprobaciones de seguridad básicas.
    - Inspección de selección, rutas y proyecto.
    - Búsqueda, edición de propiedades, atributos y nombres.
    - Duplicación, movimiento y eliminación de instancias.
    - Herramientas locales para inspeccionar y editar objetos.
    - Registro de acciones y puntos de deshacer de Studio.
    V9.0:
    - Kit de herramientas para Terrain, iluminación, efectos, constraints y sonido.
    - Creación de modelos, checkpoints, equipos, Tools, attachments y prompts.
    - Etiquetas, atributos en lote, análisis estático de scripts y auditoría de proyecto.
    - Catálogo de acciones y prevalidación de lotes con control de operaciones destructivas.
V8.0:
    - Constructor UI declarativo avanzado con validación, estilos y rollback.
    - BATCH_ACTIONS con límite, validación y registro de undo.
    - Informe estructural de GUIs.
    - Movimiento físico opcional independiente del cambio de padre.
    - Correcciones de inspección y conversión de colores.
    NOTA: el backend debe generar uiTree y BATCH_ACTIONS para aprovechar
    las funciones nuevas; el plugin por sí solo no actualiza el backend web.

    IMPORTANTE:
    Activa las solicitudes HTTP en la configuración de Studio
    si el entorno lo requiere. Revisa siempre los scripts generados.
    Los modelos importados desde Toolbox/Marketplace deben inspeccionarse antes de publicarse.
]]

--==============================================================
-- 1. SERVICIOS Y CONFIGURACIÓN
--==============================================================

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")
local InsertService = game:GetService("InsertService")
local CollectionService = game:GetService("CollectionService")

local BACKEND = "https://abx-build-backend.onrender.com"
local VERSION = "10.3.1"

local COLORS = {
	Background = Color3.fromRGB(13, 18, 32),
	Panel = Color3.fromRGB(23, 31, 51),
	PanelLight = Color3.fromRGB(32, 43, 67),
	Blue = Color3.fromRGB(55, 130, 255),
	Orange = Color3.fromRGB(255, 155, 65),
	White = Color3.fromRGB(240, 245, 255),
	Muted = Color3.fromRGB(155, 170, 195),
	Green = Color3.fromRGB(75, 210, 140),
	Red = Color3.fromRGB(255, 95, 105),
	Border = Color3.fromRGB(52, 66, 94),
	Dark = Color3.fromRGB(9, 13, 24),
}

local sessionCode = nil
local pendingAction = nil
local polling = false
local pollDelay = 3
local pollFailures = 0
local lastLog = "MEGA v" .. VERSION .. " listo."

--==============================================================
-- 2. INTERFAZ DEL PLUGIN
--==============================================================

local toolbar = plugin:CreateToolbar("MEGA")

local openButton = toolbar:CreateButton(
	"MEGAPluginV103",
	"Abrir MEGA v" .. VERSION,
	"rbxassetid://4458901886"
)

openButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true,
	false,
	440,
	740,
	350,
	480
)

local widget = plugin:CreateDockWidgetPluginGui(
	"MEGAPluginWidgetV103",
	widgetInfo
)

widget.Title = "MEGA v" .. VERSION

local root = Instance.new("ScrollingFrame")
root.Name = "MainScroll"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = COLORS.Background
root.BorderSizePixel = 0
root.ScrollBarThickness = 6
root.CanvasSize = UDim2.new(0, 0, 0, 1000)
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.ScrollingDirection = Enum.ScrollingDirection.Y
root.Parent = widget

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 12)
rootPadding.PaddingBottom = UDim.new(0, 16)
rootPadding.PaddingLeft = UDim.new(0, 12)
rootPadding.PaddingRight = UDim.new(0, 12)
rootPadding.Parent = root

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 10)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = root

local layoutOrder = 0

local F = {}
function F.registerOrder(obj)
	layoutOrder += 1
	obj.LayoutOrder = layoutOrder
	return obj
end

function F.addCorner(obj, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = obj
	return corner
end

function F.addStroke(obj, color, thickness)
	local outline = Instance.new("UIStroke")
	outline.Color = color or COLORS.Border
	outline.Thickness = thickness or 1
	outline.Transparency = 0.15
	outline.Parent = obj
	return outline
end

function F.makeLabel(parent, text, size, position, textSize, color, font)
	local obj = Instance.new("TextLabel")
	obj.BackgroundTransparency = 1
	obj.Size = size
	obj.Position = position
	obj.Text = text
	obj.TextColor3 = color or COLORS.White
	obj.TextSize = textSize or 13
	obj.Font = font or Enum.Font.Gotham
	obj.TextXAlignment = Enum.TextXAlignment.Left
	obj.TextYAlignment = Enum.TextYAlignment.Center
	obj.TextWrapped = true
	obj.Parent = parent
	return obj
end

function F.makeButton(parent, text, size, position, color)
	local obj = Instance.new("TextButton")
	obj.Size = size
	obj.Position = position
	obj.BackgroundColor3 = color or COLORS.Blue
	obj.BorderSizePixel = 0
	obj.Text = text
	obj.TextColor3 = COLORS.White
	obj.TextSize = 12
	obj.Font = Enum.Font.GothamBold
	obj.AutoButtonColor = true
	obj.Parent = parent

	F.addCorner(obj, 8)
	return obj
end

function F.makeTextBox(parent, placeholder, size, position, multiline)
	local obj = Instance.new("TextBox")
	obj.Size = size
	obj.Position = position
	obj.BackgroundColor3 = COLORS.Dark
	obj.BorderSizePixel = 0
	obj.TextColor3 = COLORS.White
	obj.PlaceholderColor3 = COLORS.Muted
	obj.PlaceholderText = placeholder
	obj.Text = ""
	obj.TextSize = 12
	obj.Font = Enum.Font.Code
	obj.TextXAlignment = Enum.TextXAlignment.Left
	obj.TextYAlignment = Enum.TextYAlignment.Top
	obj.TextWrapped = false
	obj.ClearTextOnFocus = false
	obj.MultiLine = multiline == true
	obj.Parent = parent

	F.addCorner(obj, 8)
	F.addStroke(obj)
	return obj
end

function F.makeCard(title, height)
	local frame = Instance.new("Frame")
	frame.Name = title:gsub("%W", "") .. "Card"
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BorderSizePixel = 0
	frame.Parent = root

	F.registerOrder(frame)
	F.addCorner(frame, 12)
	F.addStroke(frame)

	F.makeLabel(
		frame,
		title,
		UDim2.new(1, -24, 0, 24),
		UDim2.fromOffset(12, 5),
		11,
		COLORS.Muted,
		Enum.Font.GothamBold
	)

	return frame
end

-- Header
local header = F.makeCard("MEGA STUDIO AI", 66)

F.makeLabel(
	header,
	"Asistente profesional de construcción para Roblox Studio",
	UDim2.new(1, -100, 0, 24),
	UDim2.fromOffset(12, 29),
	11,
	COLORS.White
)

local versionLabel = F.makeLabel(
	header,
	"V" .. VERSION,
	UDim2.fromOffset(58, 27),
	UDim2.new(1, -70, 0, 20),
	12,
	COLORS.Orange,
	Enum.Font.GothamBold
)

versionLabel.TextXAlignment = Enum.TextXAlignment.Center
versionLabel.BackgroundTransparency = 0
versionLabel.BackgroundColor3 = Color3.fromRGB(65, 44, 31)
F.addCorner(versionLabel, 8)

-- Connection card
local connectionCard = F.makeCard("CONEXIÓN CON MEGA WEB", 132)

local connectionDot = Instance.new("Frame")
connectionDot.Size = UDim2.fromOffset(10, 10)
connectionDot.Position = UDim2.fromOffset(13, 36)
connectionDot.BackgroundColor3 = COLORS.Orange
connectionDot.BorderSizePixel = 0
connectionDot.Parent = connectionCard
F.addCorner(connectionDot, 10)

local connectionStatus = F.makeLabel(
	connectionCard,
	"Estado: desconectado",
	UDim2.new(1, -40, 0, 22),
	UDim2.fromOffset(30, 30),
	12,
	COLORS.White,
	Enum.Font.GothamBold
)

local codeLabel = F.makeLabel(
	connectionCard,
	"Código: —",
	UDim2.new(1, -24, 0, 22),
	UDim2.fromOffset(12, 53),
	13,
	COLORS.Orange,
	Enum.Font.GothamBold
)

local generateButton = F.makeButton(
	connectionCard,
	"Generar código",
	UDim2.fromOffset(140, 30),
	UDim2.fromOffset(12, 88),
	COLORS.Blue
)

local checkButton = F.makeButton(
	connectionCard,
	"Comprobar",
	UDim2.fromOffset(112, 30),
	UDim2.fromOffset(160, 88),
	COLORS.PanelLight
)
F.addStroke(checkButton)

-- Preview card
local previewCard = F.makeCard("VISTA PREVIA DE LA ACCIÓN", 218)

F.makeLabel(
	previewCard,
	"Revisa la acción antes de modificar tu proyecto",
	UDim2.new(1, -24, 0, 22),
	UDim2.fromOffset(12, 27),
	11,
	COLORS.White
)

local previewBox = F.makeTextBox(
	previewCard,
	"Esperando una acción...",
	UDim2.new(1, -24, 1, -99),
	UDim2.fromOffset(12, 51),
	true
)

local confirmButton = F.makeButton(
	previewCard,
	"✓  Confirmar y aplicar",
	UDim2.new(0.58, -8, 0, 32),
	UDim2.new(0, 12, 1, -39),
	COLORS.Orange
)
confirmButton.TextColor3 = Color3.fromRGB(35, 27, 19)
confirmButton.Visible = false

local rejectButton = F.makeButton(
	previewCard,
	"Rechazar",
	UDim2.new(0.42, -8, 0, 32),
	UDim2.new(0.58, 4, 1, -39),
	COLORS.Red
)
rejectButton.Visible = false

-- Local Explorer card
local explorerCard = F.makeCard("EXPLORADOR Y HERRAMIENTAS LOCALES", 222)

local searchBox = F.makeTextBox(
	explorerCard,
	"Buscar por nombre...",
	UDim2.new(1, -124, 0, 31),
	UDim2.fromOffset(12, 31),
	false
)
searchBox.TextYAlignment = Enum.TextYAlignment.Center

local refreshButton = F.makeButton(
	explorerCard,
	"Buscar",
	UDim2.fromOffset(100, 31),
	UDim2.new(1, -112, 0, 31),
	COLORS.Blue
)

local explorerOutput = F.makeTextBox(
	explorerCard,
	"Los resultados aparecerán aquí.",
	UDim2.new(1, -24, 0, 68),
	UDim2.fromOffset(12, 68),
	true
)
explorerOutput.TextEditable = false

local renameBox = F.makeTextBox(
	explorerCard,
	"Nuevo nombre",
	UDim2.new(1, -24, 0, 28),
	UDim2.fromOffset(12, 143),
	false
)
renameBox.TextYAlignment = Enum.TextYAlignment.Center

local renameButton = F.makeButton(
	explorerCard,
	"Renombrar selección",
	UDim2.new(0.5, -17, 0, 30),
	UDim2.fromOffset(12, 181),
	COLORS.Blue
)

local duplicateButton = F.makeButton(
	explorerCard,
	"Duplicar selección",
	UDim2.new(0.5, -17, 0, 30),
	UDim2.new(0.5, 5, 0, 181),
	COLORS.PanelLight
)
F.addStroke(duplicateButton)

-- MEGA asset and catalog tools
local assetCard = F.makeCard("TOOLBOX / ASSET IMPORTER", 142)
F.makeLabel(assetCard, "Importa un modelo mediante su ID público de Roblox. Los scripts importados quedan deshabilitados para revisión.", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 27), 10, COLORS.Muted)
local assetIdBox = F.makeTextBox(assetCard, "ID numérico del modelo", UDim2.new(0.48, -16, 0, 30), UDim2.fromOffset(12, 66), false)
assetIdBox.TextYAlignment = Enum.TextYAlignment.Center
local assetParentBox = F.makeTextBox(assetCard, "Workspace (ruta destino)", UDim2.new(0.52, -16, 0, 30), UDim2.new(0.48, 4, 0, 66), false)
assetParentBox.Text = "Workspace"
assetParentBox.TextYAlignment = Enum.TextYAlignment.Center
local importAssetButton = F.makeButton(assetCard, "Importar modelo", UDim2.new(0.5, -18, 0, 30), UDim2.fromOffset(12, 104), COLORS.Orange)
importAssetButton.TextColor3 = Color3.fromRGB(35, 27, 19)
local materialsButton = F.makeButton(assetCard, "Ver materiales", UDim2.new(0.5, -18, 0, 30), UDim2.new(0.5, 6, 0, 104), COLORS.Blue)

-- Selection workflow: non-destructive tools for fast, consistent Studio editing.
local selectionCard = F.makeCard("HERRAMIENTAS DE SELECCIÓN", 150)
F.makeLabel(selectionCard, "Alinea, apoya, agrupa y ajusta la física de objetos seleccionados.", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 27), 10, COLORS.Muted)
local gridSizeBox = F.makeTextBox(selectionCard, "Tamaño de rejilla", UDim2.new(0.31, -14, 0, 29), UDim2.fromOffset(12, 57), false)
gridSizeBox.Text = "1"
gridSizeBox.TextYAlignment = Enum.TextYAlignment.Center
local alignSelectionButton = F.makeButton(selectionCard, "Alinear", UDim2.new(0.32, -12, 0, 29), UDim2.new(0.34, 0, 0, 57), COLORS.Blue)
local groundSelectionButton = F.makeButton(selectionCard, "Apoyar en suelo", UDim2.new(0.34, -12, 0, 29), UDim2.new(0.66, 0, 0, 57), COLORS.PanelLight)
F.addStroke(groundSelectionButton)
local anchorSelectionButton = F.makeButton(selectionCard, "Anclar / desanclar", UDim2.new(0.5, -18, 0, 29), UDim2.fromOffset(12, 96), COLORS.PanelLight)
F.addStroke(anchorSelectionButton)
local groupSelectionButton = F.makeButton(selectionCard, "Agrupar en Model", UDim2.new(0.5, -18, 0, 29), UDim2.new(0.5, 6, 0, 96), COLORS.Orange)
groupSelectionButton.TextColor3 = Color3.fromRGB(35, 27, 19)

-- Project diagnostics shortcuts.
local diagnosticsCard = F.makeCard("DIAGNÓSTICO DEL PROYECTO", 126)
F.makeLabel(diagnosticsCard, "Inspecciones locales; no ejecutan código ni modifican el proyecto.", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 27), 10, COLORS.Muted)
local auditProjectButton = F.makeButton(diagnosticsCard, "Auditar proyecto", UDim2.new(0.33, -12, 0, 29), UDim2.fromOffset(12, 55), COLORS.Blue)
local inspectSelectionButton = F.makeButton(diagnosticsCard, "Inspeccionar selección", UDim2.new(0.34, -12, 0, 29), UDim2.new(0.33, 0, 0, 55), COLORS.PanelLight)
F.addStroke(inspectSelectionButton)
local inspectProjectButton = F.makeButton(diagnosticsCard, "Resumen del juego", UDim2.new(0.33, -12, 0, 29), UDim2.new(0.67, 0, 0, 55), COLORS.PanelLight)
F.addStroke(inspectProjectButton)
local selfTestButton = F.makeButton(diagnosticsCard, "Ejecutar autopruebas MEGA", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 91), COLORS.Orange)
selfTestButton.TextColor3 = Color3.fromRGB(35, 27, 19)

-- Log card
local logCard = F.makeCard("REGISTRO Y ESTADO", 80)

local logLabel = F.makeLabel(
	logCard,
	lastLog,
	UDim2.new(1, -24, 1, -32),
	UDim2.fromOffset(12, 27),
	12,
	COLORS.Green
)
logLabel.TextYAlignment = Enum.TextYAlignment.Top

local footer = F.makeLabel(
	root,
	"Las modificaciones se aplican a tu proyecto de Studio. Guarda una copia de seguridad.",
	UDim2.new(1, -8, 0, 38),
	UDim2.new(),
	10,
	COLORS.Muted
)
F.registerOrder(footer)

--==============================================================
-- 3. REGISTRO, ESTADO Y SOLICITUDES HTTP
--==============================================================

function F.setLog(message, color)
	lastLog = tostring(message)
	logLabel.Text = lastLog
	logLabel.TextColor3 = color or COLORS.White
end

function F.setStatus(connected, message)
	connectionDot.BackgroundColor3 =
		connected and COLORS.Green or COLORS.Orange

	connectionStatus.Text =
		connected and "Estado: conectado" or "Estado: desconectado"

	connectionStatus.TextColor3 =
		connected and COLORS.Green or COLORS.White

	if message then
		F.setLog(
			message,
			connected and COLORS.Green or COLORS.Orange
		)
	end
end

function F.request(method, path, body)
	local options = {
		Url = BACKEND .. path,
		Method = method,
		Headers = {
			["Content-Type"] = "application/json",
		},
	}

	if body ~= nil then
		options.Body = HttpService:JSONEncode(body)
	end

	local response = HttpService:RequestAsync(options)

	if not response.Success then
		error(
			"HTTP " .. tostring(response.StatusCode)
				.. ": " .. tostring(response.StatusMessage)
		)
	end

	if response.Body == "" then
		return {}
	end

	return HttpService:JSONDecode(response.Body)
end

-- Send only the result and a compact, non-sensitive summary to the backend.
-- The plugin never transmits script source or the full action payload here.
function F.reportActionResult(status, action, message)
	local reportCode = sessionCode
	if not reportCode or not action or type(action.type) ~= "string" then return end
	local targetPath = tostring(action.target or action.path or action.parent or action.location or ""):sub(1, 180)
	local studioVersion = "unknown"
	pcall(function() studioVersion = version() end)
	local body = {
		code = reportCode,
		status = status,
		action = action.type,
		message = tostring(message or ""):sub(1, 600),
		data = {
			pluginVersion = VERSION,
			studioVersion = tostring(studioVersion):sub(1, 80),
			target = targetPath,
		},
	}

	task.spawn(function()
		local ok, err = pcall(function()
			F.request("POST", "/report", body)
		end)
		if not ok then
			warn("[MEGA] No se pudo sincronizar el reporte de acción: " .. tostring(err))
		end
	end)
end

--==============================================================
-- 4. CONTENEDORES Y RUTAS
--==============================================================

function F.getContainers()
	return {
		Workspace = workspace,
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		ServerStorage = game:GetService("ServerStorage"),
		ServerScriptService = game:GetService("ServerScriptService"),
		StarterGui = game:GetService("StarterGui"),
		StarterPack = game:GetService("StarterPack"),
		StarterPlayer = StarterPlayer,
		StarterPlayerScripts =
			StarterPlayer:WaitForChild("StarterPlayerScripts"),
		StarterCharacterScripts =
			StarterPlayer:WaitForChild("StarterCharacterScripts"),
		Lighting = game:GetService("Lighting"),
		SoundService = game:GetService("SoundService"),
		Teams = game:GetService("Teams"),
		ReplicatedFirst = game:GetService("ReplicatedFirst"),
	}
end

function F.safeName(name, fallback)
	if type(name) ~= "string" or name:gsub("%s", "") == "" then
		return fallback
	end

	return name:sub(1, 80)
end

function F.resolvePath(path, defaultRoot)
	if type(path) ~= "string" or path == "" then
		local roots = F.getContainers()
		return roots[defaultRoot or "Workspace"]
	end

	path = path:gsub("^game%.", "")
	path = path:gsub("^DataModel%.", "")

	local pieces = string.split(path, ".")
	local roots = F.getContainers()
	local current = roots[pieces[1]]

	if not current then
		error("Contenedor raíz no permitido: " .. pieces[1])
	end

	for i = 2, #pieces do
		current = current:FindFirstChild(pieces[i])

		if not current then
			error("No se encontró la ruta: " .. path)
		end
	end

	return current
end

function F.findTarget(path)
	if type(path) ~= "string" or path == "" then
		error("La acción necesita una ruta de destino.")
	end

	return F.resolvePath(path, "Workspace")
end

--==============================================================
-- 5. CONVERSIÓN DE PROPIEDADES
--==============================================================

function F.convertValue(value, kind)
	if not kind or kind == "raw" then
		return value
	end

	if kind == "UDim2" then
		return UDim2.new(
			value[1] or 0,
			value[2] or 0,
			value[3] or 0,
			value[4] or 0
		)
	end

	if kind == "UDim" then
		return UDim.new(value[1] or 0, value[2] or 0)
	end

	if kind == "Vector2" then
		return Vector2.new(value[1] or 0, value[2] or 0)
	end

	if kind == "Vector3" then
		return Vector3.new(
			value[1] or 0,
			value[2] or 0,
			value[3] or 0
		)
	end

	if kind == "Color3" then
		if type(value) == "table" and value.r then
			local r, g, b = tonumber(value.r) or 1, tonumber(value.g) or 1, tonumber(value.b) or 1
			if r > 1 or g > 1 or b > 1 then
				return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
			end
			return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
		end

		return Color3.fromRGB(
			math.clamp(tonumber(value[1]) or 255, 0, 255),
			math.clamp(tonumber(value[2]) or 255, 0, 255),
			math.clamp(tonumber(value[3]) or 255, 0, 255)
		)
	end

	if kind == "BrickColor" then
		return BrickColor.new(tostring(value))
	end

	if kind == "Enum" then
		if type(value) ~= "table"
			or type(value.enum) ~= "string"
			or type(value.name) ~= "string" then
			error("Enum requiere enum y name.")
		end

		local enumType = Enum[value.enum]

		if not enumType then
			error("Tipo Enum desconocido: " .. value.enum)
		end

		local enumItem = enumType[value.name]

		if not enumItem then
			error("Valor Enum desconocido: " .. value.name)
		end

		return enumItem
	end

	if kind == "CFrame" then
		if #value == 3 then
			return CFrame.new(value[1], value[2], value[3])
		elseif #value == 12 then
			return CFrame.new(table.unpack(value))
		end
	end

	error("Tipo de conversión no compatible: " .. tostring(kind))
end

function F.inferKind(object, property, value)
	if type(value) == "table" and type(value.enum) == "string" and type(value.name) == "string" then
		return "Enum", value
	end

	if type(value) ~= "table" then
		if property == "Material" and type(value) == "string" then
			return "Enum", { enum = "Material", name = value }
		end

		if property == "Font" and type(value) == "string" then
			return "Enum", { enum = "Font", name = value }
		end

		if property == "Shape" and type(value) == "string" then
			return "Enum", { enum = "PartType", name = value }
		end

		if property == "Color" or property == "TextColor3"
			or property == "BackgroundColor3"
			or property == "ImageColor3" then

			if type(value) == "string" then
				return "BrickColor", value
			end
		end

		return "raw", value
	end

	if property == "Color" or property == "TextColor3"
		or property == "BackgroundColor3"
		or property == "ImageColor3" then
		return "Color3", value
	end

	if property == "Size" or property == "Position" then
		if object:IsA("GuiObject") then
			if #value == 4 then
				return "UDim2", value
			end

			if #value == 2 then
				return "UDim2", {
					0, value[1] or 0,
					0, value[2] or 0,
				}
			end
		end

		if #value == 3 then
			return "Vector3", value
		end
	end

	if property == "Orientation" and #value == 3 then
		return "Vector3", value
	end

	if property == "AnchorPoint" and #value == 2 then
		return "Vector2", value
	end

	if property == "CanvasSize" and #value == 4 then
		return "UDim2", value
	end

	return "raw", value
end

local PROPERTY_ALIASES = {
	size = "Size",
	position = "Position",
	rotation = "Orientation",
	color = "Color",
	material = "Material",
	anchored = "Anchored",
	canCollide = "CanCollide",
	transparency = "Transparency",
	reflectance = "Reflectance",
	shape = "Shape",
}

local PROTECTED_PROPERTY_NAMES = {
	Parent = true,
	Source = true,
	LinkedSource = true,
	Disabled = true,
	RunContext = true,
	ScriptGuid = true,
	Capabilities = true,
}

function F.assertWritableProperty(propertyName)
	if type(propertyName) ~= "string" or propertyName == "" then
		error("Nombre de propiedad inválido.")
	end
	if PROTECTED_PROPERTY_NAMES[propertyName] then
		error("La propiedad " .. propertyName .. " está protegida. Usa una acción específica y explícita para modificarla.")
	end
end

function F.setProperties(object, properties)
	if type(properties) ~= "table" then
		return
	end

	-- Formato normalizado del backend: lista de {name, value, kind}.
	if #properties > 0 then
		for _, entry in ipairs(properties) do
			if type(entry) ~= "table" or type(entry.name) ~= "string" then
				error("Entrada de propiedad mal formada.")
			end
			F.assertWritableProperty(entry.name)

			local value = F.convertValue(entry.value, entry.kind)

			local ok, err = pcall(function()
				object[entry.name] = value
			end)

			if not ok then
				error(
					"No se pudo establecer "
						.. entry.name .. ": " .. tostring(err)
				)
			end
		end

		return
	end

	-- Formato de árbol: tabla de propiedades.
	for rawName, rawValue in pairs(properties) do
		local property = PROPERTY_ALIASES[rawName] or rawName
		F.assertWritableProperty(property)
		local kind, value = F.inferKind(object, property, rawValue)

		-- No se intenta asignar la forma Wedge a Part.Shape:
		-- las cuñas deben crearse como WedgePart.
		if property == "Shape" and object:IsA("BasePart") then
			if rawValue == "Wedge" or rawValue == "CornerWedge" then
				continue
			end
		end

		local ok, converted = pcall(F.convertValue, value, kind)

		if ok then
			local assigned, err = pcall(function()
				object[property] = converted
			end)

			if not assigned then
				warn(
					"[MEGA] Propiedad omitida: "
						.. property .. " (" .. tostring(err) .. ")"
				)
			end
		else
			warn("[MEGA] Conversión omitida: " .. property)
		end
	end
end

--==============================================================
-- 6. CREACIÓN DE PIEZAS Y ÁRBOLES
--==============================================================

local ALLOWED_TREE_CLASSES = {
	Folder = true,
	Model = true,
	Part = true,
	WedgePart = true,
	CornerWedgePart = true,
	TrussPart = true,
	SpawnLocation = true,
	Seat = true,
	VehicleSeat = true,
	Attachment = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Highlight = true,
	ProximityPrompt = true,
	ClickDetector = true,
	Sound = true,
	ParticleEmitter = true,
	Beam = true,
	Trail = true,
	StringValue = true,
	BoolValue = true,
	IntValue = true,
	NumberValue = true,
	ScreenGui = true,
	BillboardGui = true,
	SurfaceGui = true,
	Frame = true,
	ScrollingFrame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ViewportFrame = true,
	UICorner = true,
	UIStroke = true,
	UIPadding = true,
	UIListLayout = true,
	UIGridLayout = true,
	UIScale = true,
	UIAspectRatioConstraint = true,
	UIGradient = true,
	CanvasGroup = true,
	UIFlexItem = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
	UIPageLayout = true,
	UITableLayout = true,
	UIStroke = true,
	UIGradient = true,
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	Configuration = true,
	Team = true,
	Atmosphere = true,
	Sky = true,
	BloomEffect = true,
	BlurEffect = true,
	ColorCorrectionEffect = true,
	DepthOfFieldEffect = true,
	SunRaysEffect = true,
}

local MEGA_COLOR_PALETTE = {
	megablue = {55, 130, 255}, megaorange = {255, 155, 65},
	white = {245, 247, 255}, black = {15, 18, 26},
	red = {235, 75, 85}, green = {65, 195, 125},
	yellow = {255, 205, 65}, purple = {145, 95, 230},
	cyan = {55, 195, 220}, pink = {240, 110, 175},
	gray = {125, 135, 150}, darkgray = {45, 52, 65},
	brown = {125, 82, 52}, grass = {80, 145, 75},
	sky = {105, 185, 245}, gold = {230, 175, 55},
}

function F.createPart(data, parent)
	local shape = tostring(data.shape or "Block")

	local className = ({
		Block = "Part",
		Ball = "Part",
		Cylinder = "Part",
		Wedge = "WedgePart",
		CornerWedge = "CornerWedgePart",
		Truss = "TrussPart",
	})[shape]

	if not className then
		error("Forma no admitida: " .. shape)
	end

	local part = Instance.new(className)
	part.Name = F.safeName(data.name, "ABX_Part")

	if part:IsA("Part") then
		if shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
	end

	local size = data.size or { 4, 1, 4 }
	local position = data.position or { 0, 5, 0 }
	local rotation = data.rotation or { 0, 0, 0 }

	part.Size = Vector3.new(
		math.clamp(tonumber(size[1]) or 4, 0.5, 512),
		math.clamp(tonumber(size[2]) or 1, 0.5, 512),
		math.clamp(tonumber(size[3]) or 4, 0.5, 512)
	)

	part.CFrame =
		CFrame.new(
			math.clamp(tonumber(position[1]) or 0, -10000, 10000),
			math.clamp(tonumber(position[2]) or 5, -10000, 10000),
			math.clamp(tonumber(position[3]) or 0, -10000, 10000)
		)
		* CFrame.Angles(
			math.rad(tonumber(rotation[1]) or 0),
			math.rad(tonumber(rotation[2]) or 0),
			math.rad(tonumber(rotation[3]) or 0)
		)

	if data.color then
		if type(data.color) == "table" then
			part.Color = F.convertValue(data.color, "Color3")
		else
			local paletteKey = string.lower(tostring(data.color)):gsub("%s+", "")
			local rgb = MEGA_COLOR_PALETTE[paletteKey]
			if rgb then
				part.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
			else
				local ok, brick = pcall(BrickColor.new, data.color)
				if ok then part.BrickColor = brick end
			end
		end
	end

	if data.material then
		local material = Enum.Material[tostring(data.material)]

		if material then
			part.Material = material
		end
	end

	part.Transparency = math.clamp(
		tonumber(data.transparency) or 0, 0, 1
	)

	part.Reflectance = math.clamp(
		tonumber(data.reflectance) or 0, 0, 1
	)

	part.Anchored = data.anchored ~= false
	part.CanCollide = data.canCollide ~= false
	part.Parent = parent

	return part
end

function F.createTree(node, parent, counter, depth)
	counter = counter or { count = 0 }
	depth = depth or 0

	if type(node) ~= "table" then
		error("Nodo de árbol inválido.")
	end

	if depth > 15 then
		error("La jerarquía supera el límite de profundidad.")
	end

	counter.count += 1
	if counter.count > 500 then
		error("Se superó el límite de 500 instancias.")
	end

	local className = node.className or node.class
	if type(className) ~= "string" or not ALLOWED_TREE_CLASSES[className] then
		error("Clase no permitida: " .. tostring(className))
	end

	local object = Instance.new(className)
	local ok, result = pcall(function()
		object.Name = F.safeName(node.name, "MEGA_" .. className)
		if object:IsA("BasePart") then
			object.Anchored = true
		end
		if node.properties then
			F.setProperties(object, node.properties)
		end
		object.Parent = parent

		local children = node.children or {}
		if type(children) ~= "table" then
			error("La lista children no es válida.")
		end
		for _, child in ipairs(children) do
			F.createTree(child, object, counter, depth + 1)
		end
		return object
	end)

	if not ok then
		pcall(function() object:Destroy() end)
		error("Árbol revertido en " .. tostring(className) .. ": " .. tostring(result))
	end
	return result
end

--==============================================================
-- 7. INSPECCIÓN Y BÚSQUEDA
--==============================================================

function F.inspectInstance(object, depth, maxDepth)
	depth = depth or 0
	maxDepth = maxDepth or 3

	local result = {
		name = object.Name,
		className = object.ClassName,
		path = object:GetFullName(),
		childCount = #object:GetChildren(),
	}

	if object:IsA("BasePart") then
		result.position = {
			object.Position.X,
			object.Position.Y,
			object.Position.Z,
		}

		result.size = {
			object.Size.X,
			object.Size.Y,
			object.Size.Z,
		}

		result.anchored = object.Anchored
		result.canCollide = object.CanCollide
		result.transparency = object.Transparency
		result.material = object.Material.Name
	end

	if object:IsA("GuiObject") then
		result.visible = object.Visible
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			result.text = object.Text
		end
		result.position = { object.Position.X.Scale, object.Position.X.Offset, object.Position.Y.Scale, object.Position.Y.Offset }
		result.size = { object.Size.X.Scale, object.Size.X.Offset, object.Size.Y.Scale, object.Size.Y.Offset }
		result.anchorPoint = { object.AnchorPoint.X, object.AnchorPoint.Y }
		result.zIndex = object.ZIndex
	end

	local children = {}

	if depth < maxDepth then
		for _, child in ipairs(object:GetChildren()) do
			if #children >= 80 then
				break
			end

			table.insert(
				children,
				F.inspectInstance(child, depth + 1, maxDepth)
			)
		end
	end

	result.children = children
	return result
end

function F.inspectSelection()
	local result = {}

	for _, object in ipairs(Selection:Get()) do
		table.insert(result, F.inspectInstance(object, 0, 3))
	end

	return result
end

function F.inspectProject()
	local roots = F.getContainers()
	local rootNames = {
		"Workspace", "ReplicatedStorage", "ServerStorage", "ServerScriptService",
		"StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService",
		"Teams", "ReplicatedFirst",
	}
	local report = {
		pluginVersion = VERSION,
		services = {},
		counts = {instances = 0, parts = 0, models = 0, scripts = 0, enabledScripts = 0,
			localScripts = 0, moduleScripts = 0, guiObjects = 0, remotes = 0, sounds = 0,
			unanchoredParts = 0},
	}
	local seen = {}
	local maxObjects = 40000

	for _, serviceName in ipairs(rootNames) do
		local service = roots[serviceName]
		if service then
			local serviceCount = 0
			for _, object in ipairs(service:GetDescendants()) do
				if not seen[object] then
					seen[object] = true
					serviceCount += 1
					report.counts.instances += 1
					if object:IsA("BasePart") then
						report.counts.parts += 1
						if not object.Anchored then report.counts.unanchoredParts += 1 end
					elseif object:IsA("Model") then
						report.counts.models += 1
					elseif object:IsA("Script") then
						report.counts.scripts += 1
						if not object.Disabled then report.counts.enabledScripts += 1 end
					elseif object:IsA("LocalScript") then
						report.counts.scripts += 1
						report.counts.localScripts += 1
						if not object.Disabled then report.counts.enabledScripts += 1 end
					elseif object:IsA("ModuleScript") then
						report.counts.scripts += 1
						report.counts.moduleScripts += 1
					elseif object:IsA("GuiObject") then
						report.counts.guiObjects += 1
					elseif object:IsA("RemoteEvent") or object:IsA("RemoteFunction") then
						report.counts.remotes += 1
					elseif object:IsA("Sound") then
						report.counts.sounds += 1
					end
					if report.counts.instances >= maxObjects then break end
				end
			end
			table.insert(report.services, {
				service = serviceName,
				children = #service:GetChildren(),
				uniqueDescendants = serviceCount,
			})
		end
		if report.counts.instances >= maxObjects then
			report.truncated = true
			break
		end
	end

	report.scanLimit = maxObjects
	return report
end

function F.findInstances(query, className)
	query = string.lower(tostring(query or ""))
	className = tostring(className or "")

	local results = {}

	for _, object in ipairs(game:GetDescendants()) do
		local matchesName =
			query == ""
			or string.find(string.lower(object.Name), query, 1, true)

		local matchesClass =
			className == ""
			or object.ClassName == className

		if matchesName and matchesClass then
			table.insert(results, {
				name = object.Name,
				className = object.ClassName,
				path = object:GetFullName(),
			})

			if #results >= 100 then
				break
			end
		end
	end

	return results
end

function F.showJSON(value)
	previewBox.Text = HttpService:JSONEncode(value)
end

--==============================================================
-- 8. CREACIÓN DE INTERFACES
--==============================================================

--==============================================================
-- 8A. SISTEMA DE DISEÑO DE INTERFACES V8
--==============================================================
-- CREATE_GUI acepta ahora action.uiTree/action.root con nodos declarativos.
-- Cada nodo puede incluir className, name, properties, children y layout.
-- El árbol se valida antes de crear objetos y se revierte si algo falla.

local GUI_ALLOWED_CLASSES = {
	ScreenGui=true, Frame=true, ScrollingFrame=true, TextLabel=true,
	TextButton=true, TextBox=true, ImageLabel=true, ImageButton=true,
	ViewportFrame=true, CanvasGroup=true, UICorner=true, UIStroke=true,
	UIPadding=true, UIListLayout=true, UIGridLayout=true, UIScale=true,
	UIAspectRatioConstraint=true, UISizeConstraint=true,
	UITextSizeConstraint=true, UIGradient=true, UIPageLayout=true,
	UITableLayout=true, UIFlexItem=true,
}

local GUI_DEFAULTS = {
	Frame = {BackgroundColor3={24,31,49}, BorderSizePixel=0},
	ScrollingFrame = {BackgroundColor3={24,31,49}, BorderSizePixel=0, ScrollBarThickness=6, AutomaticCanvasSize={enum="AutomaticSize",name="Y"}},
	TextLabel = {BackgroundTransparency=1, TextColor3={245,247,255}, Font={enum="Font",name="Gotham"}, TextSize=14, TextWrapped=true},
	TextButton = {BackgroundColor3={55,130,255}, BorderSizePixel=0, TextColor3={255,255,255}, Font={enum="Font",name="GothamBold"}, TextSize=14, AutoButtonColor=true},
	TextBox = {BackgroundColor3={12,17,29}, BorderSizePixel=0, TextColor3={245,247,255}, PlaceholderColor3={155,170,195}, Font={enum="Font",name="Gotham"}, TextSize=14, ClearTextOnFocus=false},
	ImageLabel = {BackgroundTransparency=1, ScaleType={enum="ScaleType",name="Fit"}},
	ImageButton = {BackgroundTransparency=1, AutoButtonColor=true, ScaleType={enum="ScaleType",name="Fit"}},
}

local GUI_PROPERTY_ALLOWLIST = {
	Name=true, Visible=true, Active=true, AnchorPoint=true, Position=true, Size=true,
	Rotation=true, ZIndex=true, LayoutOrder=true, BackgroundColor3=true,
	BackgroundTransparency=true, BorderSizePixel=true, ClipsDescendants=true,
	AutomaticSize=true, SizeConstraint=true, LayoutDirection=true,
	HorizontalAlignment=true, VerticalAlignment=true, SortOrder=true,
	Padding=true, PaddingTop=true, PaddingBottom=true, PaddingLeft=true,
	PaddingRight=true, CellPadding=true, CellSize=true, FillDirection=true,
	FillDirectionMaxCells=true, StartCorner=true, HorizontalFlex=true,
	VerticalFlex=true, ItemLineAlignment=true, Wraps=true,
	Text=true, TextColor3=true, TextTransparency=true, TextSize=true,
	TextScaled=true, TextWrapped=true, TextXAlignment=true, TextYAlignment=true,
	Font=true, RichText=true, LineHeight=true, TextTruncate=true,
	PlaceholderText=true, PlaceholderColor3=true, ClearTextOnFocus=true,
	MultiLine=true, TextEditable=true, MaxVisibleGraphemes=true,
	Image=true, ImageColor3=true, ImageTransparency=true, ScaleType=true,
	SliceCenter=true, SliceScale=true, TileSize=true, ResampleMode=true,
	AspectRatio=true, DominantAxis=true, MinSize=true, MaxSize=true,
	MinTextSize=true, MaxTextSize=true, Thickness=true, Transparency=true,
	Color=true, Offset=true, Rotation=true, Enabled=true, ResetOnSpawn=true,
	IgnoreGuiInset=true, DisplayOrder=true, ZIndexBehavior=true,
	ScrollBarThickness=true, ScrollBarImageColor3=true,
	CanvasSize=true, CanvasPosition=true, AutomaticCanvasSize=true,
	ElasticBehavior=true, ScrollingDirection=true, VerticalScrollBarInset=true,
	HorizontalScrollBarInset=true, CornerRadius=true, ApplyStrokeMode=true,
	StrokeSizingMode=true, PaddingMode=true, Scale=true, MinScale=true,
	MaxScale=true, AspectType=true, DominantAxis=true,
	AbsoluteWindowSize=true, BackgroundColor=true,
}

function F.guiPathName(node, fallback)
	if type(node) ~= "table" then return fallback end
	return F.safeName(node.name or node.Name, fallback)
end

function F.guiNodeClass(node)
	if type(node) ~= "table" then error("Nodo UI inválido: se esperaba una tabla.") end
	local className = node.className or node.class or node.ClassName
	if type(className) ~= "string" or not GUI_ALLOWED_CLASSES[className] then
		error("Clase UI no permitida: " .. tostring(className))
	end
	return className
end

function F.validateGuiTree(node, state, depth)
	state = state or { count=0, names={} }
	depth = depth or 0
	if depth > 18 then error("La interfaz supera la profundidad máxima de 18 niveles.") end
	state.count += 1
	if state.count > 450 then error("La interfaz supera el límite de 450 objetos.") end
	local className = F.guiNodeClass(node)
	local props = node.properties or node.props or {}
	if type(props) ~= "table" then error("properties debe ser una tabla en " .. tostring(node.name)) end
	for key, value in pairs(props) do
		if type(key) ~= "string" or not GUI_PROPERTY_ALLOWLIST[key] then
			error("Propiedad UI no permitida: " .. tostring(key))
		end
		if type(value) == "string" and #value > 20000 then error("Texto/valor demasiado grande en " .. key) end
	end
	local children = node.children or {}
	if type(children) ~= "table" then error("children debe ser una lista") end
	for _, child in ipairs(children) do F.validateGuiTree(child, state, depth + 1) end
	return state
end

function F.applyGuiDefaults(object, className)
	local defaults = GUI_DEFAULTS[className]
	if not defaults then return end
	for property, value in pairs(defaults) do
		local kind, normalized = F.inferKind(object, property, value)
		local ok, converted = pcall(F.convertValue, normalized, kind)
		if ok then pcall(function() object[property] = converted end) end
	end
end

function F.applyGuiProperties(object, properties)
	if type(properties) ~= "table" then return end
	for property, value in pairs(properties) do
		if not GUI_PROPERTY_ALLOWLIST[property] then
			error("Propiedad no permitida en UI: " .. tostring(property))
		end
		local kind, normalized = F.inferKind(object, property, value)
		if property == "CornerRadius" and object:IsA("UICorner") then kind, normalized = "UDim", value end
		if property == "Padding" and (object:IsA("UIPadding") or object:IsA("UIListLayout") or object:IsA("UIGridLayout")) then
			if type(value) == "table" and value[1] and value[2] then kind, normalized = "UDim", value end
		end
		local convertedOk, converted = pcall(F.convertValue, normalized, kind)
		if not convertedOk then error("No se pudo convertir " .. property .. ": " .. tostring(converted)) end
		local assigned, err = pcall(function() object[property] = converted end)
		if not assigned then error("No se pudo aplicar " .. property .. " en " .. object.ClassName .. ": " .. tostring(err)) end
	end
end

function F.createGuiNode(node, parent, counter, depth)
	counter = counter or {count=0}
	depth = depth or 0
	if depth > 18 then error("Profundidad UI excedida") end
	counter.count += 1
	if counter.count > 450 then error("Demasiados objetos UI") end
	local className = F.guiNodeClass(node)
	local object = Instance.new(className)
	object.Name = F.guiPathName(node, "ABX_" .. className)
	F.applyGuiDefaults(object, className)
	local properties = node.properties or node.props or {}
	F.applyGuiProperties(object, properties)
	if object:IsA("GuiObject") then
		if properties.ZIndex == nil then object.ZIndex = math.max(1, depth + 1) end
		if properties.Visible == nil then object.Visible = true end
	end
	object.Parent = parent
	for _, child in ipairs(node.children or {}) do F.createGuiNode(child, object, counter, depth + 1) end
	-- Apply requested convenience styles after children have been built.
	local style = node.style
	if type(style) == "table" and object:IsA("GuiObject") then
		if style.cornerRadius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, math.clamp(tonumber(style.cornerRadius) or 10, 0, 80))
			corner.Parent = object
		end
		if style.stroke then
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = math.clamp(tonumber(style.strokeThickness) or 1, 0.5, 8)
			stroke.Color = F.convertValue(style.stroke, "Color3")
			stroke.Transparency = math.clamp(tonumber(style.strokeTransparency) or 0, 0, 1)
			stroke.Parent = object
		end
		if style.padding then
			local padding = Instance.new("UIPadding")
			local amount = math.clamp(tonumber(style.padding) or 8, 0, 100)
			padding.PaddingTop = UDim.new(0, amount)
			padding.PaddingBottom = UDim.new(0, amount)
			padding.PaddingLeft = UDim.new(0, amount)
			padding.PaddingRight = UDim.new(0, amount)
			padding.Parent = object
		end
	end
	return object
end

function F.createProfessionalGui(action)
	local parent = F.resolvePath(action.parent, "StarterGui")
	if not parent:IsA("StarterGui") and not parent:IsA("PlayerGui") then
		error("La raíz de una interfaz debe estar en StarterGui o PlayerGui.")
	end
	local tree = action.uiTree or action.root or action.tree
	if type(tree) ~= "table" then error("CREATE_GUI avanzado requiere uiTree/root/tree") end
	F.validateGuiTree(tree)
	local screen = Instance.new("ScreenGui")
	screen.Name = F.safeName(action.name, "ABX_Interface")
	screen.ResetOnSpawn = action.resetOnSpawn == true
	screen.IgnoreGuiInset = action.ignoreGuiInset == true
	screen.DisplayOrder = math.clamp(tonumber(action.displayOrder) or 10, 0, 1000)
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local createdRoot
	local ok, err = pcall(function()
		screen.Parent = parent
		createdRoot = F.createGuiNode(tree, screen, {count=0}, 0)
		if action.scale ~= nil then
			local scaler = Instance.new("UIScale")
			scaler.Scale = math.clamp(tonumber(action.scale) or 1, 0.5, 1.5)
			scaler.Parent = screen
		end
	end)
	if not ok then screen:Destroy(); error("Construcción UI cancelada y revertida: " .. tostring(err)) end
	Selection:Set({screen})
	return "Interfaz avanzada creada: " .. screen:GetFullName() .. " (" .. tostring(#screen:GetDescendants()) .. " descendientes). Revisa visualmente en Play/Test."
end

function F.validateGuiInstance(screen)
	local issues = {}
	if not screen:IsA("ScreenGui") then table.insert(issues, "La raíz no es ScreenGui") end
	local count = 0
	for _, object in ipairs(screen:GetDescendants()) do
		count += 1
		if object:IsA("GuiObject") then
			if object.Size.X.Scale == 0 and object.Size.X.Offset <= 0 then
				table.insert(issues, object:GetFullName() .. ": ancho no positivo")
			end
			if object.Size.Y.Scale == 0 and object.Size.Y.Offset <= 0 then
				table.insert(issues, object:GetFullName() .. ": alto no positivo")
			end
			if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
				if object.TextSize < 8 then table.insert(issues, object:GetFullName() .. ": texto demasiado pequeño") end
				if object.Text == "" and object:IsA("TextButton") then table.insert(issues, object:GetFullName() .. ": botón sin texto (puede ser intencional si usa icono)") end
			end
		end
	end
	return {path=screen:GetFullName(), descendants=count, issues=issues, ok=#issues==0}
end

function F.getGuiQualityReport()
	local report = {}
	local starterGui = game:GetService("StarterGui")
	for _, child in ipairs(starterGui:GetChildren()) do
		if child:IsA("ScreenGui") then table.insert(report, F.validateGuiInstance(child)) end
	end
	return report
end

function F.createGui(action)
	if action.uiTree or action.root or action.tree then
		return F.createProfessionalGui(action)
	end
	local parent = F.resolvePath(action.parent, "StarterGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = F.safeName(action.name, "ABX_Interface")
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10

	local panel = Instance.new("Frame")
	panel.Name = "MainPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 250)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Parent = screen

	F.addCorner(panel, 14)
	F.addStroke(panel, COLORS.Blue, 1.5)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -36, 0, 38)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = COLORS.White
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = F.safeName(action.title, "Mi interfaz")
	title.Parent = panel

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(18, 58)
	description.Size = UDim2.new(1, -36, 0, 70)
	description.Font = Enum.Font.Gotham
	description.TextSize = 14
	description.TextColor3 = COLORS.Muted
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Text = "Interfaz creada por MEGA."
	description.Parent = panel

	panel.Parent = screen
	screen.Parent = parent

	Selection:Set({ screen })

	return "Interfaz base creada. Aún necesita lógica para sus botones."
end

--==============================================================
-- 8B. HERRAMIENTAS AVANZADAS DE CONSTRUCCIÓN Y DIAGNÓSTICO
--==============================================================
-- Estas funciones usan APIs disponibles en el entorno de plugins de Studio.
-- No sustituyen servicios que Roblox no expone al plugin ni ejecutan Play Test.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

function F.requireTable(value, label)
	if type(value) ~= "table" then
		error((label or "El dato") .. " debe ser una tabla.")
	end
	return value
end

function F.numeric(value, fallback, minimum, maximum, label)
	local number = tonumber(value)
	if not number or number ~= number or number == math.huge or number == -math.huge then
		number = fallback
	end
	if minimum then number = math.max(minimum, number) end
	if maximum then number = math.min(maximum, number) end
	return number
end

function F.vector3From(value, fallback)
	if typeof(value) == "Vector3" then return value end
	if type(value) ~= "table" then return fallback or Vector3.zero end
	return Vector3.new(
		F.numeric(value[1] or value.x, fallback and fallback.X or 0, -100000, 100000),
		F.numeric(value[2] or value.y, fallback and fallback.Y or 0, -100000, 100000),
		F.numeric(value[3] or value.z, fallback and fallback.Z or 0, -100000, 100000)
	)
end

function F.colorFrom(value, fallback)
	if typeof(value) == "Color3" then return value end
	if type(value) == "string" then
		local ok, brick = pcall(BrickColor.new, value)
		if ok then return brick.Color end
		return fallback or Color3.new(1, 1, 1)
	end
	if type(value) ~= "table" then return fallback or Color3.new(1, 1, 1) end
	local r = tonumber(value.r or value[1])
	local g = tonumber(value.g or value[2])
	local b = tonumber(value.b or value[3])
	if not r or not g or not b then return fallback or Color3.new(1, 1, 1) end
	if r > 1 or g > 1 or b > 1 then
		return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
	end
	return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

function F.ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("Folder") then return existing end
		error("Ya existe " .. existing:GetFullName() .. " y no es Folder.")
	end
	local folder = Instance.new("Folder")
	folder.Name = F.safeName(name, "ABX_Folder")
	folder.Parent = parent
	return folder
end

function F.findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName == className then return existing end
		error("Conflicto de clase para " .. existing:GetFullName())
	end
	local object = Instance.new(className)
	object.Name = F.safeName(name, "ABX_" .. className)
	object.Parent = parent
	return object
end

function F.validateParenting(target, parent)
	if not target or not parent then error("Falta la instancia o el padre.") end
	if target == game or target == workspace then error("La raíz protegida no se puede modificar así.") end
	if parent == target or parent:IsDescendantOf(target) then
		error("La operación produciría un ciclo en la jerarquía.")
	end
end

function F.createModelBlueprint(action)
	local entries = F.requireTable(action.objects or action.parts, "objects/parts")
	if #entries < 1 or #entries > 250 then
		error("CREATE_MODEL_BLUEPRINT admite entre 1 y 250 objetos.")
	end
	local parent = F.resolvePath(action.parent, "Workspace")
	local model = Instance.new("Model")
	model.Name = F.safeName(action.name, "ABX_Model")
	local ok, err = pcall(function()
		for index, data in ipairs(entries) do
			if type(data) ~= "table" then error("Objeto inválido en índice " .. index) end
			local part = F.createPart(data, model)
			if data.attributes then
				for key, value in pairs(data.attributes) do
					if type(key) == "string" and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then
						part:SetAttribute(key, value)
					end
				end
			end
		end
		model.Parent = parent
		if action.primaryPart then
			local candidate = model:FindFirstChild(tostring(action.primaryPart), true)
			if candidate and candidate:IsA("BasePart") then model.PrimaryPart = candidate end
		end
		if action.pivot then model:PivotTo(CFrame.new(F.vector3From(action.pivot))) end
	end)
	if not ok then model:Destroy(); error("Modelo cancelado y limpiado: " .. tostring(err)) end
	Selection:Set({model})
	return "Modelo " .. model:GetFullName() .. " creado con " .. #entries .. " piezas."
end

function F.createConstraint(action)
	local allowed = {
		WeldConstraint=true, Weld=true, Motor6D=true,
		HingeConstraint=true, BallSocketConstraint=true, RopeConstraint=true,
		SpringConstraint=true, RodConstraint=true, CylindricalConstraint=true,
		PrismaticConstraint=true, AlignPosition=true, AlignOrientation=true,
		NoCollisionConstraint=true, VectorForce=true, LinearVelocity=true,
		AngularVelocity=true, Torque=true, LineForce=true,
	}
	local className = tostring(action.className or action.constraintType or "WeldConstraint")
	if not allowed[className] then error("Tipo de constraint no permitido: " .. className) end
	local parent = F.resolvePath(action.parent, "Workspace")
	local object = Instance.new(className)
	object.Name = F.safeName(action.name, "ABX_" .. className)
	local ok, err = pcall(function()
		if action.attachment0 then
			local target = F.findTarget(action.attachment0)
			if not target:IsA("Attachment") then error("attachment0 debe apuntar a Attachment") end
			object.Attachment0 = target
		end
		if action.attachment1 then
			local target = F.findTarget(action.attachment1)
			if not target:IsA("Attachment") then error("attachment1 debe apuntar a Attachment") end
			object.Attachment1 = target
		end
		if action.part0 then
			local target = F.findTarget(action.part0)
			if not target:IsA("BasePart") then error("part0 debe ser BasePart") end
			object.Part0 = target
		end
		if action.part1 then
			local target = F.findTarget(action.part1)
			if not target:IsA("BasePart") then error("part1 debe ser BasePart") end
			object.Part1 = target
		end
		if action.properties then F.setProperties(object, action.properties) end
		object.Parent = parent
	end)
	if not ok then object:Destroy(); error("No se pudo crear constraint: " .. tostring(err)) end
	Selection:Set({object})
	return className .. " creado: " .. object:GetFullName()
end

local LIGHTING_PRESETS = {
	BrightDay = {ClockTime=14, Brightness=2, ExposureCompensation=0, Ambient={135,135,145}, OutdoorAmbient={150,150,160}, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=1},
	Sunset = {ClockTime=17.7, Brightness=2, ExposureCompensation=0.1, Ambient={120,78,72}, OutdoorAmbient={160,105,80}, EnvironmentDiffuseScale=0.8, EnvironmentSpecularScale=0.7},
	Night = {ClockTime=0.5, Brightness=1, ExposureCompensation=-0.25, Ambient={35,43,75}, OutdoorAmbient={45,50,85}, EnvironmentDiffuseScale=0.35, EnvironmentSpecularScale=0.4},
	Horror = {ClockTime=1, Brightness=0.65, ExposureCompensation=-0.6, Ambient={30,20,35}, OutdoorAmbient={35,25,40}, EnvironmentDiffuseScale=0.2, EnvironmentSpecularScale=0.25},
	Cartoon = {ClockTime=13, Brightness=3, ExposureCompensation=0.2, Ambient={180,190,205}, OutdoorAmbient={195,205,220}, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=0.5},
	StudioNeutral = {ClockTime=14, Brightness=2, ExposureCompensation=0, Ambient={127,127,127}, OutdoorAmbient={127,127,127}, EnvironmentDiffuseScale=1, EnvironmentSpecularScale=1},
}

function F.applyLightingPreset(action)
	local presetName = tostring(action.preset or "BrightDay")
	local preset = LIGHTING_PRESETS[presetName]
	if not preset then error("Preset desconocido. Opciones: BrightDay, Sunset, Night, Horror, Cartoon, StudioNeutral.") end
	ChangeHistoryService:SetWaypoint("Antes de preset de iluminación")
	for property, value in pairs(preset) do
		local ok, converted = pcall(function()
			if property == "Ambient" or property == "OutdoorAmbient" then return F.colorFrom(value) end
			return value
		end)
		if ok then pcall(function() Lighting[property] = converted end) end
	end
	if action.atmosphere ~= false then
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atmosphere.Name = "ABX_Atmosphere"
		atmosphere.Density = F.numeric(action.density, presetName == "Horror" and 0.38 or 0.25, 0, 1)
		atmosphere.Offset = F.numeric(action.offset, 0, -1, 1)
		atmosphere.Color = F.colorFrom(action.atmosphereColor, Color3.fromRGB(199, 215, 255))
		atmosphere.Decay = F.colorFrom(action.decayColor, Color3.fromRGB(106, 112, 125))
		atmosphere.Glare = F.numeric(action.glare, 0, 0, 10)
		atmosphere.Haze = F.numeric(action.haze, presetName == "Horror" and 2 or 0.5, 0, 10)
		atmosphere.Parent = Lighting
	end
	if action.colorCorrection == true then
		local effect = Lighting:FindFirstChild("ABX_ColorCorrection") or Instance.new("ColorCorrectionEffect")
		effect.Name = "ABX_ColorCorrection"
		effect.Brightness = F.numeric(action.ccBrightness, 0, -1, 1)
		effect.Contrast = F.numeric(action.contrast, 0.05, -1, 1)
		effect.Saturation = F.numeric(action.saturation, 0.05, -1, 1)
		effect.TintColor = F.colorFrom(action.tint, Color3.new(1,1,1))
		effect.Parent = Lighting
	end
	ChangeHistoryService:SetWaypoint("Después de preset de iluminación")
	return "Preset de iluminación aplicado: " .. presetName .. ". Revisa el resultado en distintas zonas del mapa."
end

function F.createTerrainPrimitive(action)
	local operation = tostring(action.operation or "FillBlock")
	local materialName = tostring(action.material or "Grass")
	local material = Enum.Material[materialName]
	if not material then error("Material de terreno desconocido: " .. materialName) end
	local center = F.vector3From(action.position, Vector3.new(0, 0, 0))
	local size = F.vector3From(action.size, Vector3.new(32, 8, 32))
	size = Vector3.new(math.clamp(size.X, 4, 512), math.clamp(size.Y, 4, 512), math.clamp(size.Z, 4, 512))
	ChangeHistoryService:SetWaypoint("Antes de editar Terrain")
	if operation == "FillBlock" then
		Terrain:FillBlock(CFrame.new(center), size, material)
	elseif operation == "FillBall" then
		Terrain:FillBall(center, math.clamp(F.numeric(action.radius, 16, 2, 256), 2, 256), material)
	elseif operation == "FillCylinder" then
		Terrain:FillCylinder(CFrame.new(center), math.clamp(F.numeric(action.height, 32, 4, 512), 4, 512), math.clamp(F.numeric(action.radius, 16, 2, 256), 2, 256), material)
	elseif operation == "ReplaceMaterial" then
		local source = Enum.Material[tostring(action.sourceMaterial or "Grass")]
		if not source then error("sourceMaterial no válido") end
		Terrain:ReplaceMaterial(Region3.new(center - size/2, center + size/2), 4, source, material)
	elseif operation == "Clear" then
		if action.confirmClear ~= true then error("Para borrar terreno se requiere confirmClear=true explícito.") end
		Terrain:FillBlock(CFrame.new(center), size, Enum.Material.Air)
	else
		error("Operación Terrain no admitida: " .. operation)
	end
	ChangeHistoryService:SetWaypoint("Después de editar Terrain")
	return "Terrain actualizado: " .. operation .. " / " .. materialName
end

function F.createSoundObject(action)
	local parent = F.resolvePath(action.parent, "Workspace")
	local sound = Instance.new("Sound")
	sound.Name = F.safeName(action.name, "ABX_Sound")
	sound.SoundId = tostring(action.soundId or "")
	sound.Volume = F.numeric(action.volume, 0.5, 0, 10)
	sound.PlaybackSpeed = F.numeric(action.playbackSpeed, 1, 0.1, 3)
	sound.Looped = action.looped == true
	sound.RollOffMaxDistance = F.numeric(action.rollOffMaxDistance, 100, 1, 10000)
	sound.RollOffMinDistance = F.numeric(action.rollOffMinDistance, 10, 0, 10000)
	sound.Parent = parent
	if action.play == true then
		local ok, err = pcall(function() sound:Play() end)
		if not ok then sound:Destroy(); error("No se pudo reproducir el sonido: " .. tostring(err)) end
	end
	Selection:Set({sound})
	return "Sound creado: " .. sound:GetFullName() .. ". Comprueba permisos y disponibilidad del asset de audio."
end

function F.createEffect(action)
	local allowed = {
		ParticleEmitter=true, Trail=true, Beam=true, Smoke=true, Fire=true, Sparkles=true,
		PointLight=true, SpotLight=true, SurfaceLight=true, Highlight=true,
		BloomEffect=true, BlurEffect=true, ColorCorrectionEffect=true,
		DepthOfFieldEffect=true, SunRaysEffect=true, Atmosphere=true,
	}
	local className = tostring(action.className or action.effectType or "ParticleEmitter")
	if not allowed[className] then error("Efecto no admitido: " .. className) end
	local defaultParent = (className == "Atmosphere" or className:match("Effect$")) and "Lighting" or "Workspace"
	local parent = F.resolvePath(action.parent, defaultParent)
	local object = Instance.new(className)
	object.Name = F.safeName(action.name, "ABX_" .. className)
	local ok, err = pcall(function()
		if action.properties then F.setProperties(object, action.properties) end
		if object:IsA("ParticleEmitter") then
			object.Rate = F.numeric(action.rate, 10, 0, 10000)
			object.Lifetime = NumberRange.new(F.numeric(action.lifetimeMin, 1, 0, 100), F.numeric(action.lifetimeMax, 2, 0, 100))
			object.Speed = NumberRange.new(F.numeric(action.speedMin, 2, 0, 1000), F.numeric(action.speedMax, 5, 0, 1000))
			object.Enabled = action.enabled ~= false
		elseif object:IsA("Light") then
			object.Brightness = F.numeric(action.brightness, 1, 0, 100)
			object.Range = F.numeric(action.range, 16, 0, 100000)
			object.Color = F.colorFrom(action.color, Color3.new(1,1,1))
			object.Enabled = action.enabled ~= false
		elseif object:IsA("Highlight") then
			object.FillColor = F.colorFrom(action.fillColor, Color3.fromRGB(55,130,255))
			object.OutlineColor = F.colorFrom(action.outlineColor, Color3.new(1,1,1))
		end
		object.Parent = parent
	end)
	if not ok then object:Destroy(); error("No se pudo crear efecto: " .. tostring(err)) end
	Selection:Set({object})
	return className .. " creado: " .. object:GetFullName()
end

function F.setAttributesBulk(action)
	local target = F.findTarget(action.target or action.path)
	local attributes = F.requireTable(action.attributes, "attributes")
	local count = 0
	for name, value in pairs(attributes) do
		if type(name) ~= "string" or name == "" or #name > 100 then error("Nombre de atributo inválido") end
		if type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then
			error("Atributo " .. name .. " debe ser string, number o boolean")
		end
		if type(value) == "string" and #value > 2000 then error("Valor demasiado largo para " .. name) end
		target:SetAttribute(name, value)
		count += 1
	end
	Selection:Set({target})
	return tostring(count) .. " atributo(s) establecidos en " .. target:GetFullName()
end

function F.manageTags(action)
	local target = F.findTarget(action.target or action.path)
	local tag = tostring(action.tag or "")
	if tag == "" or #tag > 100 then error("Tag vacío o demasiado largo") end
	local operation = tostring(action.operation or "Add")
	if operation == "Add" then
		CollectionService:AddTag(target, tag)
	elseif operation == "Remove" then
		CollectionService:RemoveTag(target, tag)
	elseif operation == "List" then
		F.showJSON(CollectionService:GetTags(target))
		return "Tags consultados para " .. target:GetFullName()
	else
		error("Operación de tags debe ser Add, Remove o List")
	end
	return "Tag " .. operation .. ": " .. tag .. " en " .. target:GetFullName()
end

function F.createTeam(action)
	local teams = game:GetService("Teams")
	local team = Instance.new("Team")
	team.Name = F.safeName(action.name, "ABX_Team")
	team.TeamColor = BrickColor.new(tostring(action.teamColor or "Bright blue"))
	team.AutoAssignable = action.autoAssignable == true
	team.Parent = teams
	Selection:Set({team})
	return "Equipo creado: " .. team.Name
end

function F.createTool(action)
	local tool = Instance.new("Tool")
	tool.Name = F.safeName(action.name, "ABX_Tool")
	tool.RequiresHandle = action.requiresHandle ~= false
	tool.CanBeDropped = action.canBeDropped ~= false
	tool.ToolTip = tostring(action.tooltip or "")
	local parent = F.resolvePath(action.parent, "StarterPack")
	if tool.RequiresHandle and not action.createHandle then
		tool:Destroy()
		error("Tool requiere Handle; usa createHandle=true o requiresHandle=false")
	end
	if action.createHandle then
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = F.vector3From(action.handleSize, Vector3.new(1,1,2))
		handle.Color = F.colorFrom(action.handleColor, Color3.fromRGB(55,130,255))
		handle.Material = Enum.Material[tostring(action.handleMaterial or "Metal")] or Enum.Material.Metal
		handle.CanCollide = false
		handle.Parent = tool
	end
	tool.Parent = parent
	Selection:Set({tool})
	return "Tool creado: " .. tool:GetFullName() .. ". La lógica de activación requiere un Script/LocalScript aparte."
end

function F.createCheckpointSet(action)
	local count = math.floor(F.numeric(action.count, 5, 1, 100))
	local start = F.vector3From(action.startPosition, Vector3.new(0, 5, 0))
	local spacing = F.vector3From(action.spacing, Vector3.new(0, 0, 40))
	local parent = F.resolvePath(action.parent, "Workspace")
	local model = Instance.new("Model")
	model.Name = F.safeName(action.name, "ABX_Checkpoints")
	local ok, err = pcall(function()
		for index = 1, count do
			local checkpoint = Instance.new("SpawnLocation")
			checkpoint.Name = string.format("Checkpoint_%02d", index)
			checkpoint.Size = F.vector3From(action.size, Vector3.new(8, 1, 8))
			checkpoint.Position = start + spacing * (index - 1)
			checkpoint.Anchored = true
			checkpoint.Neutral = action.neutral ~= false
			checkpoint.AllowTeamChangeOnTouch = false
			checkpoint.Color = F.colorFrom(action.color, Color3.fromRGB(55,130,255))
			checkpoint.Material = Enum.Material.Neon
			checkpoint:SetAttribute("CheckpointIndex", index)
			checkpoint.Parent = model
		end
		model.Parent = parent
	end)
	if not ok then model:Destroy(); error("Creación de checkpoints revertida: " .. tostring(err)) end
	Selection:Set({model})
	return tostring(count) .. " checkpoints creados. El sistema de progreso/respawn debe programarse por separado."
end

function F.inspectScript(action)
	local target = F.findTarget(action.target or action.path)
	if not target:IsA("LuaSourceContainer") then error("El destino no contiene código Luau") end
	local ok, source = pcall(function() return target.Source end)
	if not ok then error("Studio no permitió leer Source: " .. tostring(source)) end
	local lines, functions, events, remotes, TODOs = 0, 0, 0, 0, 0
	for line in (source .. "\n"):gmatch("(.-)\n") do
		lines += 1
		if line:match("^%s*function%s") or line:match("^%s*local%s+function%s") then functions += 1 end
		if line:find(":Connect%s*%(") then events += 1 end
		if line:find("RemoteEvent") or line:find("RemoteFunction") then remotes += 1 end
		if line:find("TODO", 1, true) or line:find("FIXME", 1, true) then TODOs += 1 end
	end
	F.showJSON({path=target:GetFullName(), className=target.ClassName, lineCount=lines, functionCount=functions, connectionCount=events, remoteMentions=remotes, todoMentions=TODOs, source=action.includeSource == true and source or nil})
	return "Análisis estático del script listo. No ejecuta ni demuestra que el código funcione."
end

function F.validateProjectDeep(action)
	local roots = F.getContainers()
	local report = {
		issues = {},
		counts = {instances = 0, parts = 0, scripts = 0, enabledScripts = 0, unanchoredParts = 0, guiObjects = 0},
		checkedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		pluginVersion = VERSION,
	}
	local maxObjects = math.floor(F.numeric(action.maxObjects, 30000, 100, 100000))
	local rootNames = {
		"Workspace", "ReplicatedStorage", "ServerStorage", "ServerScriptService",
		"StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService",
		"Teams", "ReplicatedFirst",
	}
	local seen = {}
	local truncated = false

	for _, serviceName in ipairs(rootNames) do
		local service = roots[serviceName]
		if service then
			for _, object in ipairs(service:GetDescendants()) do
				if not seen[object] then
					seen[object] = true
					if report.counts.instances >= maxObjects then
						truncated = true
						break
					end
					report.counts.instances += 1

					if object:IsA("BasePart") then
						report.counts.parts += 1
						if not object.Anchored then report.counts.unanchoredParts += 1 end
						if object.Size.X <= 0 or object.Size.Y <= 0 or object.Size.Z <= 0 then
							table.insert(report.issues, {severity="error", path=object:GetFullName(), message="Pieza con tamaño no positivo."})
						end
						if object.Anchored == false and object.AssemblyLinearVelocity.Magnitude > 500 then
							table.insert(report.issues, {severity="warning", path=object:GetFullName(), message="Pieza sin anclar con velocidad elevada durante inspección."})
						end
					elseif object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") then
						report.counts.scripts += 1
						if not object:IsA("ModuleScript") and not object.Disabled then report.counts.enabledScripts += 1 end
						local ok, source = pcall(function() return object.Source end)
						if ok and source == "" then
							table.insert(report.issues, {severity="warning", path=object:GetFullName(), message="Script vacío."})
						end
					elseif object:IsA("GuiObject") then
						report.counts.guiObjects += 1
						if object:IsA("TextButton") and object.Text == "" and object.Image == "" then
							table.insert(report.issues, {severity="info", path=object:GetFullName(), message="Botón sin texto ni imagen aparente."})
						end
					end
				end
			end
		end
		if truncated then break end
	end

	report.truncated = truncated
	report.scanLimit = maxObjects
	report.issueCount = #report.issues
	F.showJSON(report)
	return "Auditoría estática completada: " .. #report.issues .. " observaciones y " .. report.counts.instances .. " instancias revisadas. No equivale a Play Test ni a una inspección visual."
end

function F.setTerrainWater(action)
	local center = F.vector3From(action.position, Vector3.zero)
	local size = F.vector3From(action.size, Vector3.new(32, 8, 32))
	size = Vector3.new(math.clamp(size.X, 4, 512), math.clamp(size.Y, 4, 512), math.clamp(size.Z, 4, 512))
	local material = action.water == false and Enum.Material.Air or Enum.Material.Water
	ChangeHistoryService:SetWaypoint("Antes de cambiar agua Terrain")
	Terrain:FillBlock(CFrame.new(center), size, material)
	ChangeHistoryService:SetWaypoint("Después de cambiar agua Terrain")
	return (action.water == false and "Agua eliminada de la región" or "Volumen de agua creado") .. "."
end

function F.createAttachment(action)
	local parent = F.resolvePath(action.parent, "Workspace")
	if not parent:IsA("BasePart") and not parent:IsA("Bone") then error("Attachment requiere BasePart o Bone como padre") end
	local attachment = Instance.new("Attachment")
	attachment.Name = F.safeName(action.name, "ABX_Attachment")
	attachment.Position = F.vector3From(action.position, Vector3.zero)
	attachment.Orientation = F.vector3From(action.orientation, Vector3.zero)
	attachment.Parent = parent
	Selection:Set({attachment})
	return "Attachment creado: " .. attachment:GetFullName()
end

function F.createProximityPrompt(action)
	local parent = F.resolvePath(action.parent, "Workspace")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = F.safeName(action.name, "ABX_Prompt")
	prompt.ActionText = tostring(action.actionText or "Interactuar"):sub(1, 100)
	prompt.ObjectText = tostring(action.objectText or "Objeto"):sub(1, 100)
	prompt.KeyboardKeyCode = Enum.KeyCode[tostring(action.keyCode or "E")] or Enum.KeyCode.E
	prompt.HoldDuration = F.numeric(action.holdDuration, 0, 0, 10)
	prompt.MaxActivationDistance = F.numeric(action.maxDistance, 10, 0, 100)
	prompt.RequiresLineOfSight = action.requiresLineOfSight ~= false
	prompt.Enabled = action.enabled ~= false
	prompt.Parent = parent
	Selection:Set({prompt})
	return "ProximityPrompt creado. Conecta su evento Triggered a lógica validada en servidor."
end

function F.setTerrainDecoration(action)
	local parent = F.resolvePath(action.parent, "Workspace")
	local count = math.floor(F.numeric(action.count, 10, 1, 200))
	local center = F.vector3From(action.center, Vector3.new(0, 0, 0))
	local radius = F.numeric(action.radius, 50, 1, 1000)
	local height = F.numeric(action.height, 8, 1, 100)
	local model = Instance.new("Model")
	model.Name = F.safeName(action.name, "ABX_DecorationSet")
	local color = F.colorFrom(action.color, Color3.fromRGB(55, 145, 75))
	local material = Enum.Material[tostring(action.material or "Grass")] or Enum.Material.Grass
	local ok, err = pcall(function()
		for i = 1, count do
			local angle = (i - 1) / count * math.pi * 2
			local distance = radius * (0.65 + ((i * 37) % 35) / 100)
			local x = center.X + math.cos(angle) * distance
			local z = center.Z + math.sin(angle) * distance
			local part = Instance.new("Part")
			part.Name = string.format("Decoration_%03d", i)
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(height, F.numeric(action.width, 1, 0.2, 10), F.numeric(action.width, 1, 0.2, 10))
			part.CFrame = CFrame.new(x, center.Y + height/2, z) * CFrame.Angles(0, 0, math.rad(90))
			part.Anchored = true
			part.CanCollide = action.canCollide == true
			part.Color = color
			part.Material = material
			part.Parent = model
		end
		model.Parent = parent
	end)
	if not ok then model:Destroy(); error("Decoración revertida: " .. tostring(err)) end
	Selection:Set({model})
	return "Conjunto decorativo creado con " .. count .. " elementos. Ajusta su forma al estilo del mapa."
end

--==============================================================
-- MEGA V10.2: ASSET IMPORT, MATERIALS, COLOR PALETTE AND UI HELPERS
--==============================================================

function F.listMaterials()
	local names = {}
	for _, item in ipairs(Enum.Material:GetEnumItems()) do
		table.insert(names, item.Name)
	end
	table.sort(names)
	F.showJSON({kind="MATERIAL_CATALOG", count=#names, materials=names,
		guidance="Usa el nombre exacto de Enum.Material. El material debe ser compatible con la clase de instancia."})
	return "Catálogo de materiales listo: " .. tostring(#names) .. " materiales."
end

function F.listColorPalette()
	F.showJSON({kind="MEGA_COLOR_PALETTE", colors=MEGA_COLOR_PALETTE,
		format="RGB 0-255", note="Puedes enviar una tabla {r,g,b} o uno de estos nombres como colorName."})
	return "Paleta de colores MEGA mostrada."
end

function F.resolveMegaColor(value, fallback)
	if type(value) == "string" then
		local key = string.lower(value):gsub("%s+", "")
		local rgb = MEGA_COLOR_PALETTE[key]
		if rgb then return Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
		local ok, brick = pcall(BrickColor.new, value)
		if ok then return brick.Color end
		return fallback or Color3.new(1, 1, 1)
	end
	if type(value) == "table" then
		return F.colorFrom(value, fallback)
	end
	return fallback or Color3.new(1, 1, 1)
end

function F.sanitizeImportedAsset(root, maxInstances)
	maxInstances = math.clamp(tonumber(maxInstances) or 500, 1, 1500)
	local descendants = root:GetDescendants()
	if #descendants > maxInstances then
		root:Destroy()
		error("El asset supera el límite de " .. tostring(maxInstances) .. " descendientes.")
	end
	local disabledScripts = 0
	for _, item in ipairs(descendants) do
		if item:IsA("Script") or item:IsA("LocalScript") then
			pcall(function() item.Disabled = true end)
			disabledScripts += 1
		elseif item:IsA("ModuleScript") then
			-- ModuleScripts no se ejecutan solos, pero se reportan para revisión.
			disabledScripts += 1
		end
	end
	return #descendants, disabledScripts
end

function F.importToolboxAsset(action)
	local rawId = tostring(action.assetId or action.assetID or "")
	if not rawId:match("^%d+$") then
		error("assetId debe ser un ID numérico de Roblox, no una URL ni un nombre.")
	end
	if #rawId > 20 then error("ID de asset demasiado largo.") end
	local assetId = tonumber(rawId)
	if not assetId or assetId <= 0 then error("ID de asset inválido.") end
	local parent = F.resolvePath(action.parent or "Workspace", "Workspace")
	if parent == game then error("No se puede insertar directamente en game.") end

	local ok, loadedOrError = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not loadedOrError then
		error("Roblox no permitió cargar el asset " .. rawId .. ". Comprueba que sea un modelo accesible, que el ID sea correcto y que Studio permita cargarlo. Detalle: " .. tostring(loadedOrError))
	end

	local container = loadedOrError
	local count, scripts = F.sanitizeImportedAsset(container, action.maxInstances)
	container.Name = F.safeName(action.name, "MEGA_Asset_" .. rawId)
	container.Parent = parent
	Selection:Set({container})
	return "Asset importado: " .. container:GetFullName() .. " | " .. tostring(count) .. " descendientes | " .. tostring(scripts) .. " scripts deshabilitados y módulos reportados para revisión. Inspecciona el modelo antes de usarlo."
end

function F.createColorSwatchSet(action)
	local parent = F.resolvePath(action.parent or "Workspace", "Workspace")
	local folder = Instance.new("Folder")
	folder.Name = F.safeName(action.name, "MEGA_ColorSwatches")
	local entries = action.colors or MEGA_COLOR_PALETTE
	local made = 0
	for name, value in pairs(entries) do
		if made >= 64 then break end
		local part = Instance.new("Part")
		part.Name = F.safeName(tostring(name), "Color_" .. tostring(made + 1))
		part.Size = Vector3.new(3, 1, 3)
		part.Anchored = true
		part.Color = F.resolveMegaColor(value)
		part.Material = Enum.Material.SmoothPlastic
		part.Position = Vector3.new((made % 8) * 4, 3, math.floor(made / 8) * 4)
		part.Parent = folder
		made += 1
	end
	if made == 0 then folder:Destroy(); error("No se recibieron colores válidos.") end
	folder.Parent = parent
	Selection:Set({folder})
	return "Muestrario creado con " .. tostring(made) .. " colores."
end

function F.createUiPreset(action)
	local parent = F.resolvePath(action.parent or "StarterGui", "StarterGui")
	if not parent:IsA("PlayerGui") and not parent:IsA("StarterGui") and not parent:IsA("Folder") then
		error("El preset UI debe insertarse en StarterGui, PlayerGui o una carpeta.")
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = F.safeName(action.name, "MEGA_Interface")
	screen.ResetOnSpawn = action.resetOnSpawn ~= false
	screen.IgnoreGuiInset = action.ignoreGuiInset == true
	screen.DisplayOrder = math.clamp(math.floor(tonumber(action.displayOrder) or 5), 0, 100)
	local panel = Instance.new("Frame")
	panel.Name = "MainPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(math.clamp(tonumber(action.width) or 560, 280, 1200), math.clamp(tonumber(action.height) or 360, 180, 900))
	panel.BackgroundColor3 = F.resolveMegaColor(action.backgroundColor or "darkGray")
	panel.BorderSizePixel = 0
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.clamp(tonumber(action.cornerRadius) or 14, 0, 40))
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = F.resolveMegaColor(action.accentColor or "megaBlue")
	stroke.Thickness = 1.5
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 38)
	title.Font = Enum.Font.GothamBold
	title.Text = tostring(action.title or "MEGA Interface")
	title.TextSize = 22
	title.TextColor3 = F.resolveMegaColor(action.titleColor or "white")
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local body = Instance.new("TextLabel")
	body.Name = "Description"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 64)
	body.Font = Enum.Font.Gotham
	body.Text = tostring(action.description or "Interfaz creada por MEGA. Personaliza sus componentes desde el árbol UI.")
	body.TextWrapped = true
	body.TextSize = 14
	body.TextColor3 = F.resolveMegaColor("gray")
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.Parent = panel
	screen.Parent = parent
	Selection:Set({screen})
	return "Preset UI profesional creado. Añade funcionalidad mediante LocalScripts y validación del servidor."
end

--==============================================================
-- MEGA V10.2: SELECTION WORKFLOW AND SCENE EDITING
--==============================================================

function F.getTopLevelSelection()
	local raw = Selection:Get()
	if #raw == 0 then error("Selecciona al menos un objeto en Explorer o en el viewport.") end
	if #raw > 100 then error("La selección supera el límite de 100 elementos raíz.") end

	local selectedSet = {}
	for _, object in ipairs(raw) do selectedSet[object] = true end
	local result = {}
	for _, object in ipairs(raw) do
		local hasSelectedAncestor = false
		local ancestor = object.Parent
		while ancestor and ancestor ~= game do
			if selectedSet[ancestor] then
				hasSelectedAncestor = true
				break
			end
			ancestor = ancestor.Parent
		end
		if not hasSelectedAncestor then table.insert(result, object) end
	end
	if #result == 0 then error("La selección no contiene objetos raíz editables.") end
	return result
end

function F.getMovablePivot(object)
	if object:IsA("BasePart") then return object.CFrame end
	if object:IsA("Model") then return object:GetPivot() end
	error("Solo se pueden mover BaseParts y Models: " .. object:GetFullName())
end

function F.setMovablePivot(object, pivot)
	if object:IsA("BasePart") then
		object.CFrame = pivot
	elseif object:IsA("Model") then
		object:PivotTo(pivot)
	else
		error("Solo se pueden mover BaseParts y Models: " .. object:GetFullName())
	end
end

function F.getSelectedBaseParts(maxParts)
	local targets = F.getTopLevelSelection()
	local result, seen = {}, {}
	maxParts = maxParts or 2000
	for _, target in ipairs(targets) do
		if target:IsA("BasePart") and not seen[target] then
			seen[target] = true
			table.insert(result, target)
		end
		for _, descendant in ipairs(target:GetDescendants()) do
			if descendant:IsA("BasePart") and not seen[descendant] then
				seen[descendant] = true
				table.insert(result, descendant)
				if #result > maxParts then error("La selección supera el límite de " .. tostring(maxParts) .. " piezas físicas.") end
			end
		end
	end
	if #result == 0 then error("La selección no contiene piezas físicas.") end
	return result
end

function F.alignSelectionToGrid(action)
	local targets = F.getTopLevelSelection()
	local grid = F.numeric(action.gridSize, 1, 0.125, 512)
	local axes = type(action.axes) == "table" and action.axes or {x=true, y=true, z=true}
	local moved = 0
	for _, object in ipairs(targets) do
		local pivot = F.getMovablePivot(object)
		local position = pivot.Position
		local function snap(value)
			return math.floor(value / grid + 0.5) * grid
		end
		local nextPosition = Vector3.new(
			axes.x == false and position.X or snap(position.X),
			axes.y == false and position.Y or snap(position.Y),
			axes.z == false and position.Z or snap(position.Z)
		)
		F.setMovablePivot(object, CFrame.new(nextPosition) * (pivot - pivot.Position))
		moved += 1
	end
	return "Alineados " .. moved .. " objeto(s) a una rejilla de " .. tostring(grid) .. " studs."
end

function F.groundSelection(action)
	local targets = F.getTopLevelSelection()
	local filter = RaycastParams.new()
	filter.FilterType = Enum.RaycastFilterType.Exclude
	filter.FilterDescendantsInstances = targets
	filter.IgnoreWater = action.ignoreWater ~= false
	local clearance = F.numeric(action.clearance, 0.05, 0, 20)
	local rayHeight = F.numeric(action.rayHeight, 2048, 32, 10000)
	local rayDepth = F.numeric(action.rayDepth, 4096, 64, 20000)
	local moved, missed = 0, 0

	for _, object in ipairs(targets) do
		local pivot = F.getMovablePivot(object)
		local boundsSize
		if object:IsA("BasePart") then
			boundsSize = object.Size
		else
			local _, size = object:GetBoundingBox()
			boundsSize = size
		end
		local origin = Vector3.new(pivot.Position.X, pivot.Position.Y + rayHeight, pivot.Position.Z)
		local hit = workspace:Raycast(origin, Vector3.new(0, -rayDepth, 0), filter)
		if hit then
			local targetPosition = Vector3.new(pivot.Position.X, hit.Position.Y + boundsSize.Y / 2 + clearance, pivot.Position.Z)
			F.setMovablePivot(object, CFrame.new(targetPosition) * (pivot - pivot.Position))
			moved += 1
		else
			missed += 1
		end
	end
	return "Apoyados en suelo: " .. moved .. "; sin superficie detectada: " .. missed .. "."
end

function F.setSelectionPhysics(action)
	local parts = F.getSelectedBaseParts(2000)
	local changed = 0
	local hasOption = action.anchored ~= nil or action.canCollide ~= nil or action.canTouch ~= nil or action.canQuery ~= nil or action.massless ~= nil
	if not hasOption then error("Indica al menos una propiedad física que quieras cambiar.") end
	for _, part in ipairs(parts) do
		if action.anchored ~= nil then part.Anchored = action.anchored == true end
		if action.canCollide ~= nil then part.CanCollide = action.canCollide == true end
		if action.canTouch ~= nil then part.CanTouch = action.canTouch == true end
		if action.canQuery ~= nil then part.CanQuery = action.canQuery == true end
		if action.massless ~= nil then part.Massless = action.massless == true end
		changed += 1
	end
	return "Propiedades físicas actualizadas en " .. changed .. " pieza(s)."
end

function F.styleSelection(action)
	local parts = F.getSelectedBaseParts(2000)
	local colorValue = action.color or action.colorName
	local materialName = action.material
	local material = materialName and Enum.Material[tostring(materialName)] or nil
	if materialName and not material then error("Material desconocido: " .. tostring(materialName)) end
	local transparency = action.transparency ~= nil and F.numeric(action.transparency, 0, 0, 1) or nil
	local reflectance = action.reflectance ~= nil and F.numeric(action.reflectance, 0, 0, 1) or nil
	if colorValue == nil and material == nil and transparency == nil and reflectance == nil then
		error("Indica color, material, transparencia o reflectancia.")
	end
	local color = colorValue ~= nil and F.resolveMegaColor(colorValue) or nil
	for _, part in ipairs(parts) do
		if color then part.Color = color end
		if material then part.Material = material end
		if transparency ~= nil then part.Transparency = transparency end
		if reflectance ~= nil then part.Reflectance = reflectance end
	end
	return "Estilo aplicado a " .. #parts .. " pieza(s)."
end

function F.groupSelection(action)
	local targets = F.getTopLevelSelection()
	if #targets < 2 then error("Selecciona al menos dos objetos para agrupar.") end
	local parent = targets[1].Parent
	if not parent or parent == game then error("No se pueden agrupar servicios raíz ni objetos sin contenedor.") end
	for _, object in ipairs(targets) do
		if object == game or object == workspace or object.Parent ~= parent then error("Para agrupar, selecciona objetos del mismo contenedor; no se admiten servicios raíz.") end
		if object == parent then error("No puedes agrupar un objeto dentro de sí mismo.") end
	end

	local model = Instance.new("Model")
	model.Name = F.safeName(action.name, "MEGA_Group")
	local moved = {}
	local ok, err = pcall(function()
		model.Parent = parent
		for _, object in ipairs(targets) do
			object.Parent = model
			table.insert(moved, object)
		end
		local primary = model:FindFirstChildWhichIsA("BasePart", true)
		if primary then model.PrimaryPart = primary end
	end)
	if not ok then
		for _, object in ipairs(moved) do pcall(function() object.Parent = parent end) end
		model:Destroy()
		error("Agrupación revertida: " .. tostring(err))
	end
	Selection:Set({model})
	return "Grupo creado: " .. model:GetFullName() .. " (" .. #targets .. " objetos)."
end

function F.distributeSelection(action)
	local targets = F.getTopLevelSelection()
	if #targets < 3 then error("Distribuir requiere al menos tres objetos raíz.") end
	local axis = string.upper(tostring(action.axis or "X"))
	if axis ~= "X" and axis ~= "Y" and axis ~= "Z" then error("El eje debe ser X, Y o Z.") end
	local spacing = F.numeric(action.spacing, 8, 0.5, 10000)
	local entries = {}
	local sum = 0
	for index, object in ipairs(targets) do
		local pivot = F.getMovablePivot(object)
		local coordinate = axis == "X" and pivot.Position.X or (axis == "Y" and pivot.Position.Y or pivot.Position.Z)
		table.insert(entries, {object=object, pivot=pivot, coordinate=coordinate, originalIndex=index})
		sum += coordinate
	end
	table.sort(entries, function(a, b)
		if a.coordinate == b.coordinate then return a.originalIndex < b.originalIndex end
		return a.coordinate < b.coordinate
	end)
	local center = sum / #entries
	for index, entry in ipairs(entries) do
		local coordinate = center + (index - (#entries + 1) / 2) * spacing
		local p = entry.pivot.Position
		local nextPosition = axis == "X" and Vector3.new(coordinate, p.Y, p.Z)
			or (axis == "Y" and Vector3.new(p.X, coordinate, p.Z) or Vector3.new(p.X, p.Y, coordinate))
		F.setMovablePivot(entry.object, CFrame.new(nextPosition) * (entry.pivot - entry.pivot.Position))
	end
	return "Distribuidos " .. #entries .. " objetos sobre el eje " .. axis .. " con separación " .. spacing .. "."
end

function F.renameSelectionPattern(action)
	local targets = F.getTopLevelSelection()
	local template = tostring(action.template or "{name}_{index}"):sub(1, 100)
	if template:gsub("%s", "") == "" then error("La plantilla de nombres está vacía.") end
	local selectedSet, reserved = {}, {}
	for _, object in ipairs(targets) do selectedSet[object] = true end
	local renamed = 0
	for index, object in ipairs(targets) do
		if object == game or object == workspace or not object.Parent or object.Parent == game then
			error("No se permite renombrar servicios raíz ni objetos sin contenedor.")
		end
		local desired = template:gsub("{name}", function() return object.Name end)
		desired = desired:gsub("{index}", function() return tostring(index) end)
		desired = F.safeName(desired, "MEGA_Object_" .. index)
		local base, candidate, suffix = desired, desired, 2
		local parent = object.Parent
		reserved[parent] = reserved[parent] or {}
		while reserved[parent][candidate] or (parent:FindFirstChild(candidate) and not selectedSet[parent:FindFirstChild(candidate)]) do
			candidate = base .. "_" .. tostring(suffix)
			suffix += 1
		end
		reserved[parent][candidate] = true
		object.Name = candidate
		renamed += 1
	end
	return "Renombrados " .. renamed .. " objetos. Usa {name} y {index} en la plantilla."
end

function F.selectDescendants(action)
	local target = F.findTarget(action.target or action.path)
	local descendants = target:GetDescendants()
	local limit = math.floor(F.numeric(action.limit, 200, 1, 500))
	local result = {}
	if action.includeRoot == true then table.insert(result, target) end
	for _, object in ipairs(descendants) do
		if #result >= limit then break end
		table.insert(result, object)
	end
	if #result == 0 then error("No se encontraron descendientes para seleccionar.") end
	Selection:Set(result)
	return "Seleccionados " .. #result .. " objetos descendientes de " .. target:GetFullName() .. "."
end

-- MEGA v10.3: extended action layer for Roblox Studio.
-- All runtime-sensitive systems remain explicit scaffolds unless a handler is supplied.
local MEGA_EXT_LIMITS = {selection=2000, targets=500, nodes=200, children=500, text=20000, effects=100, assets=500}
local MEGA_EXT_CLASSES = {Folder=true,Model=true,Part=true,WedgePart=true,CornerWedgePart=true,TrussPart=true,SpawnLocation=true,Attachment=true,WeldConstraint=true,Motor6D=true,RopeConstraint=true,RodConstraint=true,SpringConstraint=true,HingeConstraint=true,BallSocketConstraint=true,AlignPosition=true,AlignOrientation=true,VectorForce=true,LinearVelocity=true,AngularVelocity=true,ParticleEmitter=true,Beam=true,Trail=true,Highlight=true,BillboardGui=true,SurfaceGui=true,Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,UIListLayout=true,UIGridLayout=true,UICorner=true,UIStroke=true,UIGradient=true,UIPadding=true,UIScale=true,UISizeConstraint=true,UIAspectRatioConstraint=true,Sound=true,SoundGroup=true,ClickDetector=true,ProximityPrompt=true,ObjectValue=true,StringValue=true,BoolValue=true,IntValue=true,NumberValue=true,RemoteEvent=true,RemoteFunction=true,BindableEvent=true,BindableFunction=true,Animation=true,Configuration=true,Tool=true,Team=true,Camera=true,WorldModel=true,Atmosphere=true,BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,DepthOfFieldEffect=true,SunRaysEffect=true,Sky=true,Clouds=true}

function F.exNumber(value, default, min, max, label)
	if value == nil then value = default end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then error((label or "number") .. " must be finite") end
	if min and value < min or max and value > max then error((label or "number") .. " out of range") end
	return value
end
function F.exText(value, default, limit, label)
	if value == nil then value = default end
	if type(value) ~= "string" or value == "" then error((label or "text") .. " must be a non-empty string") end
	if #value > (limit or 20000) then error((label or "text") .. " exceeds limit") end
	return value
end
function F.exVec(value, default, label)
	if typeof(value) == "Vector3" then return value end
	if type(value) ~= "table" then if default then return default end; error((label or "vector") .. " must be Vector3/table") end
	local x = F.exNumber(tonumber(value.x or value[1]), nil, nil, nil, "x")
	local y = F.exNumber(tonumber(value.y or value[2]), nil, nil, nil, "y")
	local z = F.exNumber(tonumber(value.z or value[3]), nil, nil, nil, "z")
	return Vector3.new(x,y,z)
end
function F.exColor(value, default)
	if typeof(value) == "Color3" then return value end
	if type(value) ~= "table" then return default or COLORS.Blue end
	return Color3.fromRGB(math.floor(F.exNumber(tonumber(value.r or value[1]),55,0,255,"red")),math.floor(F.exNumber(tonumber(value.g or value[2]),130,0,255,"green")),math.floor(F.exNumber(tonumber(value.b or value[3]),255,0,255,"blue")))
end
function F.exParent(path, fallback)
	if (path == nil or path == "") and typeof(fallback) == "Instance" then return fallback end
	local parent = F.resolvePath(path, fallback or "Workspace")
	if not parent then error("Parent path could not be resolved: " .. tostring(path)) end
	return parent
end
function F.exTarget(path, className)
	local target = F.findTarget(path)
	if not target then error("Target not found: " .. tostring(path)) end
	if className and not target:IsA(className) then error("Target must be " .. className) end
	return target
end
function F.exFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = F.safeName(name,"MEGA_Folder")
	folder.Parent = parent
	return folder
end
function F.exPart(parent, spec, fallbackName)
	local part = Instance.new(spec.className or "Part")
	part.Name = F.safeName(spec.name,fallbackName or "MEGA_Part")
	part.Size = F.exVec(spec.size,Vector3.new(4,1,4),"size")
	if part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then error("Part size must be positive") end
	part.CFrame = CFrame.new(F.exVec(spec.position,Vector3.new(0,5,0),"position"))
	part.Color = F.exColor(spec.color,COLORS.Blue)
	part.Material = Enum.Material[tostring(spec.material or "SmoothPlastic")] or Enum.Material.SmoothPlastic
	part.Anchored = spec.anchored ~= false
	part.CanCollide = spec.canCollide ~= false
	part.CanTouch = spec.canTouch ~= false
	part.CanQuery = spec.canQuery ~= false
	part.Transparency = F.exNumber(spec.transparency,0,0,1,"transparency")
	part.Parent = parent
	return part
end
function F.exAssetId(value, label)
	local id = tostring(value or "")
	if id ~= "" and not id:match("^rbxassetid://%d+$") then error((label or "asset") .. " must be rbxassetid://<verified-id>") end
	return id
end
function F.exRollback(container, ok, err, label)
	if not ok then if container and container.Parent then container:Destroy() end; error((label or "MEGA operation failed") .. ": " .. tostring(err)) end
end

function F.exCreateSpawnSet(a)
	if type(a.points)~="table" or #a.points<1 or #a.points>100 then error("points must contain 1..100 spawns") end
	local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_Spawns")
	local ok,err=pcall(function()
		for i,p in ipairs(a.points) do
			local s=Instance.new("SpawnLocation"); s.Name=F.safeName(p.name,"Spawn_"..i); s.Size=F.exVec(p.size,Vector3.new(8,1,8)); s.Position=F.exVec(p.position,Vector3.new(0,4,i*12)); s.Anchored=true; s.Neutral=p.neutral~=false; s.Enabled=p.enabled~=false; s.Duration=F.exNumber(p.duration,0,0,30,"duration"); if p.color then s.Color=F.exColor(p.color) end; s.Parent=root
			if p.teamColor then s.TeamColor=BrickColor.new(F.exColor(p.teamColor)) end
		end
	end)
	F.exRollback(root,ok,err,"CREATE_SPAWN_SET")
	Selection:Set({root}); return "Spawn set created: "..#a.points
end
function F.exCreateHighlight(a)
	local target=F.exTarget(a.target); local h=Instance.new("Highlight"); h.Name=F.safeName(a.name,"MEGA_Highlight"); h.Adornee=target; h.FillColor=F.exColor(a.fillColor,COLORS.Blue); h.OutlineColor=F.exColor(a.outlineColor,COLORS.Orange); h.FillTransparency=F.exNumber(a.fillTransparency,0.65,0,1); h.OutlineTransparency=F.exNumber(a.outlineTransparency,0,0,1); h.DepthMode=a.depthMode=="Occluded" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop; h.Parent=F.exParent(a.parent,target); return "Highlight created for "..target:GetFullName()
end
function F.exCreateClickDetector(a)
	local part=F.exTarget(a.target,"BasePart"); local d=Instance.new("ClickDetector"); d.Name=F.safeName(a.name,"MEGA_ClickDetector"); d.MaxActivationDistance=F.exNumber(a.maxDistance,24,0,1000); d.CursorIcon=tostring(a.cursorIcon or ""); d.Parent=part; return "ClickDetector added. Server Script must connect MouseClick."
end
function F.exCreateBillboard(a)
	local target=F.exTarget(a.target); if not (target:IsA("BasePart") or target:IsA("Model") or target:IsA("Attachment")) then error("Billboard target must be BasePart, Model or Attachment") end
	local adornee=target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart",true)) or target; if not adornee then error("Model has no BasePart") end
	local gui=Instance.new("BillboardGui"); gui.Name=F.safeName(a.name,"MEGA_Billboard"); gui.Adornee=adornee; gui.Size=UDim2.fromOffset(F.exNumber(a.width,220,20,1200),F.exNumber(a.height,70,20,1200)); gui.StudsOffset=F.exVec(a.offset,Vector3.new(0,3,0)); gui.AlwaysOnTop=a.alwaysOnTop~=false; gui.MaxDistance=F.exNumber(a.maxDistance,150,0,10000)
	local label=Instance.new("TextLabel"); label.Name="Text"; label.Size=UDim2.fromScale(1,1); label.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); label.BackgroundTransparency=F.exNumber(a.backgroundTransparency,0.2,0,1); label.Text=F.exText(a.text,"MEGA",500); label.TextColor3=F.exColor(a.textColor,COLORS.White); label.TextScaled=true; label.TextWrapped=true; label.Font=Enum.Font.GothamBold; label.Parent=gui; local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=label; gui.Parent=F.exParent(a.parent,target); return "BillboardGui created"
end
function F.exCreateSurfaceGui(a)
	local target=F.exTarget(a.target,"BasePart"); local face=Enum.NormalId[tostring(a.face or "Front")]; if not face then error("Invalid SurfaceGui face") end
	local gui=Instance.new("SurfaceGui"); gui.Name=F.safeName(a.name,"MEGA_SurfaceGui"); gui.Face=face; gui.PixelsPerStud=F.exNumber(a.pixelsPerStud,50,1,500); gui.AlwaysOnTop=a.alwaysOnTop==true; gui.Parent=target
	local frame=Instance.new("Frame"); frame.Name="Content"; frame.Size=UDim2.fromScale(1,1); frame.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); frame.Parent=gui
	local text=Instance.new("TextLabel"); text.Name="Title"; text.Size=UDim2.fromScale(1,1); text.BackgroundTransparency=1; text.Text=F.exText(a.text,"MEGA",500); text.TextColor3=F.exColor(a.textColor,COLORS.White); text.TextScaled=true; text.Font=Enum.Font.GothamBold; text.Parent=frame; return "SurfaceGui created"
end
function F.exCreateWeld(a)
	local p0=F.exTarget(a.part0,"BasePart"); local p1=F.exTarget(a.part1,"BasePart"); if p0==p1 then error("Weld requires two distinct parts") end
	local weld=Instance.new("WeldConstraint"); weld.Name=F.safeName(a.name,"MEGA_Weld"); weld.Part0=p0; weld.Part1=p1; weld.Parent=F.exParent(a.parent,p0); return "WeldConstraint connected"
end
function F.exCreateBeam(a,isTrail)
	local p0=F.exTarget(a.part0 or a.target,"BasePart"); local p1=isTrail and p0 or F.exTarget(a.part1,"BasePart")
	local function attachment(part,name,offset) local found=part:FindFirstChild(name); if found and found:IsA("Attachment") then return found end; local at=Instance.new("Attachment"); at.Name=name; at.Position=F.exVec(offset,Vector3.zero); at.Parent=part; return at end
	local at0=attachment(p0,F.safeName(a.attachment0,"MEGA_Attachment0"),a.offset0); local at1=attachment(p1,F.safeName(a.attachment1,"MEGA_Attachment1"),a.offset1)
	local effect=Instance.new(isTrail and "Trail" or "Beam"); effect.Name=F.safeName(a.name,isTrail and "MEGA_Trail" or "MEGA_Beam"); effect.Attachment0=at0; effect.Attachment1=at1; effect.Color=ColorSequence.new(F.exColor(a.color0,COLORS.Blue),F.exColor(a.color1,COLORS.Orange)); effect.Transparency=NumberSequence.new(F.exNumber(a.transparency,0.1,0,1)); effect.Enabled=a.enabled~=false
	if isTrail then effect.Lifetime=F.exNumber(a.lifetime,0.5,0.05,10); effect.MinLength=F.exNumber(a.minLength,0.1,0,100) else effect.Width0=F.exNumber(a.width0,0.2,0,20); effect.Width1=F.exNumber(a.width1,0.2,0,20); effect.LightEmission=F.exNumber(a.lightEmission,0,0,1) end
	effect.Parent=F.exParent(a.parent,p0); return (isTrail and "Trail" or "Beam").." created"
end
function F.exCreateParticles(a)
	local target=F.exTarget(a.target); if not (target:IsA("BasePart") or target:IsA("Attachment")) then error("ParticleEmitter target must be BasePart/Attachment") end
	local e=Instance.new("ParticleEmitter"); e.Name=F.safeName(a.name,"MEGA_Particles"); e.Rate=F.exNumber(a.rate,10,0,500); e.Lifetime=NumberRange.new(F.exNumber(a.lifeMin,1,0.1,30),F.exNumber(a.lifeMax,2,0.1,30)); if e.Lifetime.Min>e.Lifetime.Max then error("lifeMin > lifeMax") end; e.Speed=NumberRange.new(F.exNumber(a.speedMin,1,0,500),F.exNumber(a.speedMax,3,0,500)); e.Color=ColorSequence.new(F.exColor(a.color0,COLORS.Blue),F.exColor(a.color1,COLORS.Orange)); e.Size=NumberSequence.new(F.exNumber(a.size,1,0,100)); e.LightEmission=F.exNumber(a.lightEmission,0,0,1); e.Enabled=a.enabled~=false; e.Parent=target; return "ParticleEmitter created"
end
function F.exCreatePath(a)
	if type(a.nodes)~="table" or #a.nodes<2 or #a.nodes>MEGA_EXT_LIMITS.nodes then error("Path requires 2..200 nodes") end
	local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_Path"); local ok,err=pcall(function() for i,node in ipairs(a.nodes) do local p=Instance.new("Part"); p.Name=F.safeName(node.name,string.format("Node_%03d",i)); p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(0.8,0.8,0.8); p.Position=F.exVec(node.position or node); p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.Transparency=0.35; p.Color=F.exColor(node.color,COLORS.Orange); p:SetAttribute("MEGA_PathIndex",i); p.Parent=root end end); F.exRollback(root,ok,err,"CREATE_PATH"); root:SetAttribute("MEGA_PathNodeCount",#a.nodes); Selection:Set({root}); return "Path created: "..#a.nodes.." nodes"
end
function F.exCreateZone(a)
	local p=F.exPart(F.exParent(a.parent,"Workspace"),{name=a.name or "MEGA_Zone",size=a.size or {20,8,20},position=a.position or {0,5,0},color=a.color or {55,130,255},anchored=true,canCollide=false,transparency=a.transparency or 0.85,material="ForceField"}); p.CanTouch=true; p:SetAttribute("MEGA_Zone",true); p:SetAttribute("MEGA_ZonePurpose",F.safeName(a.purpose,"Generic")); p:SetAttribute("MEGA_ZoneId",HttpService:GenerateGUID(false)); if type(a.tags)=="table" then for _,tag in ipairs(a.tags) do if type(tag)=="string" and #tag<=64 then CollectionService:AddTag(p,tag) end end end; return "Zone volume created; connect server Touched logic"
end
function F.exCreateSoundGroup(a)
	local group=Instance.new("SoundGroup"); group.Name=F.safeName(a.name,"MEGA_SoundGroup"); group.Volume=F.exNumber(a.volume,1,0,10); group.Parent=F.exParent(a.parent,"SoundService"); return "SoundGroup created"
end
function F.exCreateSoundscape(a)
	local root=F.exFolder(F.exParent(a.parent,"SoundService"),a.name or "MEGA_Soundscape"); for _,name in ipairs({"Music","Ambience","SFX"}) do F.exFolder(root,name) end
	if type(a.sounds)=="table" then local ok,err=pcall(function() if #a.sounds>150 then error("max 150 sounds") end; for i,spec in ipairs(a.sounds) do local category=spec.category=="Music" and "Music" or spec.category=="Ambience" and "Ambience" or "SFX"; local sound=Instance.new("Sound"); sound.Name=F.safeName(spec.name,"Sound_"..i); sound.SoundId=F.exAssetId(spec.soundId,"SoundId"); sound.Volume=F.exNumber(spec.volume,0.5,0,10); sound.Looped=spec.looped==true; sound.Parent=root[category] end end); F.exRollback(root,ok,err,"CREATE_SOUNDSCAPE") end
	return "Soundscape created; asset permissions/playback need Studio test"
end
function F.exCreateAnimationSet(a)
	if type(a.animations)~="table" or #a.animations>200 then error("animations must contain at most 200 entries") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_Animations"); local ok,err=pcall(function() for i,spec in ipairs(a.animations) do local anim=Instance.new("Animation"); anim.Name=F.safeName(spec.name,"Animation_"..i); anim.AnimationId=F.exAssetId(spec.animationId,"AnimationId"); anim.Parent=root end end); F.exRollback(root,ok,err,"CREATE_ANIMATION_SET"); return "Animation set created: "..#a.animations
end
function F.exCreateRemoteBundle(a)
	local specs=a.remotes or {{name="Request",className="RemoteEvent"}}; if type(specs)~="table" or #specs<1 or #specs>100 then error("remotes must contain 1..100 entries") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_Remotes"); local ok,err=pcall(function() for i,spec in ipairs(specs) do local c=spec.className or "RemoteEvent"; if c~="RemoteEvent" and c~="RemoteFunction" and c~="BindableEvent" and c~="BindableFunction" then error("Unsupported remote class: "..tostring(c)) end; local r=Instance.new(c); r.Name=F.safeName(spec.name,c.."_"..i); r.Parent=root end end); F.exRollback(root,ok,err,"CREATE_REMOTE_BUNDLE"); return "Remote bundle created: "..#specs
end
function F.exCreateValueBundle(a)
	if type(a.values)~="table" or #a.values<1 or #a.values>200 then error("values must contain 1..200 entries") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_Values"); local ok,err=pcall(function() for i,spec in ipairs(a.values) do local c=spec.className or "StringValue"; if c~="StringValue" and c~="BoolValue" and c~="IntValue" and c~="NumberValue" then error("Unsupported Value class: "..c) end; local v=Instance.new(c); v.Name=F.safeName(spec.name,"Value_"..i); if c=="StringValue" then v.Value=tostring(spec.value or "") elseif c=="BoolValue" then v.Value=spec.value==true elseif c=="IntValue" then v.Value=math.floor(F.exNumber(tonumber(spec.value),0,-2147483647,2147483647)) else v.Value=F.exNumber(tonumber(spec.value),0,-1e12,1e12) end; v.Parent=root end end); F.exRollback(root,ok,err,"CREATE_VALUE_BUNDLE"); return "Value bundle created: "..#a.values
end
function F.exCreateAttributes(a)
	local target=F.exTarget(a.target); if type(a.attributes)~="table" then error("attributes must be a table") end; local count=0; for key,value in pairs(a.attributes) do count+=1; if count>100 then error("max 100 attributes") end; if type(key)~="string" or #key>100 then error("invalid attribute name") end; local t=typeof(value); if t~="string" and t~="number" and t~="boolean" and t~="Vector3" and t~="Color3" and t~="CFrame" and t~="UDim2" and t~="BrickColor" then error("unsupported attribute type: "..t) end; if t=="number" then F.exNumber(value,nil,nil,nil,key) end end; for key,value in pairs(a.attributes) do target:SetAttribute(key,value) end; return "Attributes applied: "..count
end
function F.exBatchProperties(a)
	if type(a.targets)~="table" or #a.targets<1 or #a.targets>MEGA_EXT_LIMITS.targets then error("targets must contain 1..500 paths") end; if type(a.properties)~="table" then error("properties must be table") end; local targets={}; for i,path in ipairs(a.targets) do targets[i]=F.exTarget(path) end; local applied,errors=0,{}; for i,target in ipairs(targets) do local ok,err=pcall(F.setProperties,target,a.properties); if ok then applied+=1 else table.insert(errors,i..":"..tostring(err)) end end; return "BATCH_SET_PROPERTIES: "..applied.."/"..#targets.." applied; "..#errors.." errors"
end
function F.exPivotModel(a)
	local model=F.exTarget(a.target,"Model"); local pos=F.exVec(a.position,model:GetPivot().Position); local rot=F.exVec(a.rotation,Vector3.zero); model:PivotTo(CFrame.new(pos)*CFrame.Angles(math.rad(rot.X),math.rad(rot.Y),math.rad(rot.Z))); return "Model pivot updated"
end
function F.exSetPrimaryPart(a)
	local model=F.exTarget(a.target,"Model"); local part=F.exTarget(a.primaryPart,"BasePart"); if not part:IsDescendantOf(model) then error("primaryPart must be a descendant of model") end; model.PrimaryPart=part; return "PrimaryPart assigned"
end
function F.exCollisionGroup(a)
	local groupName=F.exText(a.groupName,nil,100,"groupName"); local physics=game:GetService("PhysicsService"); local exists=false; for _,info in ipairs(physics:GetRegisteredCollisionGroups()) do if info.name==groupName then exists=true end end; if not exists then physics:RegisterCollisionGroup(groupName) end; if type(a.targets)~="table" or #a.targets>500 then error("targets must be <=500 paths") end; local changed=0; for _,path in ipairs(a.targets) do local target=F.findTarget(path); if target and target:IsA("BasePart") then target.CollisionGroup=groupName; changed+=1 end end; return "Collision group applied to "..changed.." parts"
end
function F.exCollisionRelation(a)
	local physics=game:GetService("PhysicsService"); local ok,err=pcall(function() physics:CollisionGroupSetCollidable(F.exText(a.group0,nil,100),F.exText(a.group1,nil,100),a.collidable~=false) end); if not ok then error(err) end; return "Collision relationship updated"
end
function F.exCreateUIStroke(a)
	local target=F.exTarget(a.target,"GuiObject"); local s=Instance.new("UIStroke"); s.Name=F.safeName(a.name,"MEGA_Stroke"); s.Color=F.exColor(a.color,COLORS.Blue); s.Thickness=F.exNumber(a.thickness,1.5,0,20); s.Transparency=F.exNumber(a.transparency,0,0,1); s.Parent=target; return "UIStroke applied"
end
function F.exCreateGradient(a)
	local target=F.exTarget(a.target,"GuiObject"); local g=Instance.new("UIGradient"); g.Name=F.safeName(a.name,"MEGA_Gradient"); g.Color=ColorSequence.new(F.exColor(a.color0,COLORS.Blue),F.exColor(a.color1,COLORS.Orange)); g.Rotation=F.exNumber(a.rotation,0,0,360); g.Parent=target; return "UIGradient applied"
end
function F.exCreatePadding(a)
	local target=F.exTarget(a.target,"GuiObject"); local p=Instance.new("UIPadding"); p.Name=F.safeName(a.name,"MEGA_Padding"); local function udim(v) if type(v)=="table" then return UDim.new(F.exNumber(v.scale,0,-1,1),F.exNumber(v.offset,0,-500,500)) end; return UDim.new(0,F.exNumber(v,8,-500,500)) end; p.PaddingLeft=udim(a.left); p.PaddingRight=udim(a.right); p.PaddingTop=udim(a.top); p.PaddingBottom=udim(a.bottom); p.Parent=target; return "UIPadding applied"
end
function F.exCreateLayout(a)
	local target=F.exTarget(a.target,"GuiObject"); local kind=a.layoutType or "List"; local class=kind=="Grid" and "UIGridLayout" or "UIListLayout"; local l=Instance.new(class); l.Name=F.safeName(a.name,"MEGA_Layout"); if class=="UIListLayout" then l.FillDirection=a.horizontal==true and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical; l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,F.exNumber(a.padding,8,0,200)) else l.CellSize=UDim2.fromOffset(F.exNumber(a.cellWidth,120,1,1000),F.exNumber(a.cellHeight,80,1,1000)); l.CellPadding=UDim2.fromOffset(F.exNumber(a.paddingX,8,0,200),F.exNumber(a.paddingY,8,0,200)) end; l.Parent=target; return class.." applied"
end
function F.exCreateCorner(a)
	local target=F.exTarget(a.target,"GuiObject"); local c=Instance.new("UICorner"); c.Name=F.safeName(a.name,"MEGA_Corner"); c.CornerRadius=UDim.new(F.exNumber(a.scale,0,0,0.5),F.exNumber(a.offset,10,0,100)); c.Parent=target; return "UICorner applied"
end
function F.exCreateUIButton(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local b=Instance.new("TextButton"); b.Name=F.safeName(a.name,"MEGA_Button"); b.Size=UDim2.fromOffset(F.exNumber(a.width,160,40,1000),F.exNumber(a.height,44,24,300)); b.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Blue); b.TextColor3=F.exColor(a.textColor,COLORS.White); b.Text=F.exText(a.text,"Button",100); b.TextSize=F.exNumber(a.textSize,14,8,48); b.Font=Enum.Font.GothamBold; b.Parent=parent; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=b; return "TextButton created; connect Activated in LocalScript"
end
function F.exCreateUICard(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local f=Instance.new("Frame"); f.Name=F.safeName(a.name,"MEGA_Card"); f.Size=UDim2.fromOffset(F.exNumber(a.width,260,40,1200),F.exNumber(a.height,140,40,1200)); f.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); f.BorderSizePixel=0; f.Parent=parent; local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=f; local s=Instance.new("UIStroke"); s.Color=F.exColor(a.strokeColor,COLORS.Blue); s.Parent=f; local title=Instance.new("TextLabel"); title.Name="Title"; title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,28); title.Text=F.exText(a.title,"Card",120); title.TextColor3=COLORS.White; title.Font=Enum.Font.GothamBold; title.TextSize=16; title.Parent=f; local body=Instance.new("TextLabel"); body.Name="Description"; body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(12,40); body.Size=UDim2.new(1,-24,1,-50); body.Text=tostring(a.description or ""); body.TextColor3=COLORS.Muted; body.TextWrapped=true; body.TextXAlignment=Enum.TextXAlignment.Left; body.Parent=f; return "UI card created"
end
function F.exCreateProgressBar(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local root=Instance.new("Frame"); root.Name=F.safeName(a.name,"MEGA_ProgressBar"); root.Size=UDim2.fromOffset(F.exNumber(a.width,240,40,1200),F.exNumber(a.height,22,8,200)); root.BackgroundColor3=F.exColor(a.trackColor,COLORS.Dark); root.Parent=parent; local fill=Instance.new("Frame"); fill.Name="Fill"; fill.Size=UDim2.fromScale(F.exNumber(a.value,0.5,0,1),1); fill.BackgroundColor3=F.exColor(a.fillColor,COLORS.Blue); fill.Parent=root; root:SetAttribute("MEGA_ProgressValue",F.exNumber(a.value,0.5,0,1)); return "Progress bar created; update Fill.Size from game logic"
end
function F.exCreateStatCard(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local frame=Instance.new("Frame"); frame.Name=F.safeName(a.name,"MEGA_StatCard"); frame.Size=UDim2.fromOffset(F.exNumber(a.width,180,60,800),F.exNumber(a.height,90,40,400)); frame.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); frame.Parent=parent; local label=Instance.new("TextLabel"); label.Name="Label"; label.BackgroundTransparency=1; label.Size=UDim2.new(1,-20,0,24); label.Position=UDim2.fromOffset(10,6); label.Text=F.exText(a.label,"STAT",80); label.TextColor3=COLORS.Muted; label.Parent=frame; local value=Instance.new("TextLabel"); value.Name="Value"; value.BackgroundTransparency=1; value.Position=UDim2.fromOffset(10,30); value.Size=UDim2.new(1,-20,1,-36); value.Text=tostring(a.value or "0"); value.TextColor3=COLORS.White; value.TextSize=24; value.Font=Enum.Font.GothamBold; value.Parent=frame; return "Stat card created"
end
function F.exCreateUIInput(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local box=Instance.new("TextBox"); box.Name=F.safeName(a.name,"MEGA_Input"); box.Size=UDim2.fromOffset(F.exNumber(a.width,220,60,1000),F.exNumber(a.height,40,24,200)); box.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Dark); box.TextColor3=COLORS.White; box.PlaceholderColor3=COLORS.Muted; box.PlaceholderText=F.exText(a.placeholder,"Enter text",150); box.Text=tostring(a.text or ""); box.ClearTextOnFocus=false; box.Parent=parent; return "TextBox created; validate submitted data on server"
end
function F.exCreateImage(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local image=Instance.new("ImageLabel"); image.Name=F.safeName(a.name,"MEGA_Image"); image.Size=UDim2.fromOffset(F.exNumber(a.width,128,1,1200),F.exNumber(a.height,128,1,1200)); image.BackgroundTransparency=1; image.Image=F.exAssetId(a.image,"ImageId"); image.ScaleType=Enum.ScaleType[a.scaleType or "Fit"] or Enum.ScaleType.Fit; image.Parent=parent; return "ImageLabel created"
end
function F.exCreateUIOverlay(a)
	local screen=Instance.new("ScreenGui"); screen.Name=F.safeName(a.name,"MEGA_Overlay"); screen.DisplayOrder=F.exNumber(a.displayOrder,50,0,1000); screen.Parent=F.exParent(a.parent,"StarterGui"); local frame=Instance.new("Frame"); frame.Name="Overlay"; frame.Size=UDim2.fromScale(1,1); frame.BackgroundColor3=F.exColor(a.color,Color3.new(0,0,0)); frame.BackgroundTransparency=F.exNumber(a.transparency,0.35,0,1); frame.Parent=screen; return "Overlay created; visibility animation requires client logic"
end
function F.exCreateUIScroll(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local scroll=Instance.new("ScrollingFrame"); scroll.Name=F.safeName(a.name,"MEGA_ScrollList"); scroll.Size=UDim2.fromScale(1,1); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=F.exNumber(a.scrollBarThickness,6,2,20); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll.Parent=parent; local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,6); layout.Parent=scroll; return "ScrollingFrame created"
end
function F.exCreatePanel(a)
	local screen=Instance.new("ScreenGui"); screen.Name=F.safeName(a.name,"MEGA_Panel"); screen.Parent=F.exParent(a.parent,"StarterGui"); local frame=Instance.new("Frame"); frame.Name="MainPanel"; frame.AnchorPoint=Vector2.new(0.5,0.5); frame.Position=UDim2.fromScale(0.5,0.5); frame.Size=UDim2.fromOffset(F.exNumber(a.width,520,200,1400),F.exNumber(a.height,420,120,1200)); frame.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); frame.Parent=screen; local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,14); corner.Parent=frame; local title=Instance.new("TextLabel"); title.Name="Title"; title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(16,10); title.Size=UDim2.new(1,-32,0,32); title.Text=F.exText(a.title,"MEGA Panel",100); title.TextColor3=COLORS.White; title.Font=Enum.Font.GothamBold; title.TextSize=18; title.Parent=frame; local content=Instance.new("Frame"); content.Name="Content"; content.BackgroundTransparency=1; content.Position=UDim2.fromOffset(16,52); content.Size=UDim2.new(1,-32,1,-68); content.Parent=frame; local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.Parent=content; return "Responsive panel skeleton created"
end
function F.exCreatePostEffect(a)
	local className=a.className or "BloomEffect"; local allowed={BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,SunRaysEffect=true,DepthOfFieldEffect=true}; if not allowed[className] then error("Unsupported post effect") end; local effect=Instance.new(className); effect.Name=F.safeName(a.name,"MEGA_"..className); if className=="BloomEffect" then effect.Intensity=F.exNumber(a.intensity,0.5,0,10); effect.Size=F.exNumber(a.size,24,0,56); effect.Threshold=F.exNumber(a.threshold,1,0,10) elseif className=="BlurEffect" then effect.Size=F.exNumber(a.size,8,0,56) elseif className=="ColorCorrectionEffect" then effect.Brightness=F.exNumber(a.brightness,0,-1,1); effect.Contrast=F.exNumber(a.contrast,0,-1,1); effect.Saturation=F.exNumber(a.saturation,0,-1,1); effect.TintColor=F.exColor(a.tintColor,Color3.new(1,1,1)) elseif className=="SunRaysEffect" then effect.Intensity=F.exNumber(a.intensity,0.1,0,1); effect.Spread=F.exNumber(a.spread,0.5,0,1) end; effect.Parent=game:GetService("Lighting"); return className.." applied"
end
function F.exAtmosphere(a)
	local lighting=game:GetService("Lighting"); local at=lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere"); at.Name=F.safeName(a.name,"MEGA_Atmosphere"); at.Density=F.exNumber(a.density,0.3,0,1); at.Offset=F.exNumber(a.offset,0,-1,1); at.Haze=F.exNumber(a.haze,0,0,10); at.Glare=F.exNumber(a.glare,0,0,10); at.Color=F.exColor(a.color,Color3.fromRGB(199,210,255)); at.Decay=F.exColor(a.decay,Color3.fromRGB(106,112,125)); at.Parent=lighting; return "Atmosphere applied"
end
function F.exCreatePartGrid(a)
	local rows=math.floor(F.exNumber(a.rows,3,1,30)); local cols=math.floor(F.exNumber(a.columns,3,1,30)); if rows*cols>500 then error("grid exceeds 500 parts") end; local origin=F.exVec(a.origin,Vector3.new(0,5,0)); local spacing=F.exVec(a.spacing,Vector3.new(8,0,8)); local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_Grid"); root.Parent=F.exParent(a.parent,"Workspace"); local ok,err=pcall(function() for r=1,rows do for c=1,cols do F.exPart(root,{name=string.format("Grid_%02d_%02d",r,c),size=a.partSize or {6,1,6},position=origin+Vector3.new((c-1)*spacing.X,(r-1)*spacing.Y,(r-1)*spacing.Z),color=a.color,material=a.material,anchored=a.anchored~=false}) end end end); F.exRollback(root,ok,err,"CREATE_PART_GRID"); Selection:Set({root}); return "Grid created: "..rows.."x"..cols
end
function F.exCreateStairs(a)
	local count=math.floor(F.exNumber(a.count,10,1,200)); local origin=F.exVec(a.origin,Vector3.new(0,1,0)); local rise=F.exNumber(a.rise,1,0.1,20); local run=F.exNumber(a.run,2,0.1,50); local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_Stairs"); root.Parent=F.exParent(a.parent,"Workspace"); for i=1,count do F.exPart(root,{name=string.format("Step_%03d",i),size=a.stepSize or {4,1,2},position=origin+Vector3.new(0,(i-1)*rise,(i-1)*run),color=a.color,material=a.material or "Concrete",anchored=true}) end; return "Staircase created: "..count.." steps"
end
function F.exCreateRing(a)
	local count=math.floor(F.exNumber(a.count,16,3,200)); local radius=F.exNumber(a.radius,20,1,10000); local center=F.exVec(a.center,Vector3.new(0,5,0)); local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_Ring"); root.Parent=F.exParent(a.parent,"Workspace"); for i=1,count do local angle=math.pi*2*(i-1)/count; local pos=center+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius); local part=F.exPart(root,{name=string.format("Ring_%03d",i),size=a.partSize or {3,2,1},position=pos,color=a.color or {255,155,65},material=a.material or "Neon",anchored=true}); part.CFrame=CFrame.lookAt(pos,center) end; return "Ring created: "..count.." parts"
end
function F.exCreateWall(a)
	local count=math.floor(F.exNumber(a.count,10,1,200)); local origin=F.exVec(a.origin,Vector3.new(0,5,0)); local direction=F.exVec(a.direction,Vector3.new(1,0,0)); if direction.Magnitude<0.001 then error("direction cannot be zero") end; direction=direction.Unit; local size=F.exVec(a.partSize,Vector3.new(4,4,1)); local gap=F.exNumber(a.gap,0,0,100); local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_Wall"); root.Parent=F.exParent(a.parent,"Workspace"); for i=1,count do F.exPart(root,{name=string.format("Wall_%03d",i),size=size,position=origin+direction*((i-1)*(size.X+gap)),color=a.color,material=a.material or "Concrete",anchored=true}) end; return "Wall created: "..count.." parts"
end
function F.exCreateCollectibles(a)
	if type(a.items)~="table" or #a.items<1 or #a.items>300 then error("items must contain 1..300 collectibles") end; local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_Collectibles"); local ok,err=pcall(function() for i,item in ipairs(a.items) do local p=F.exPart(root,{name=item.name or "Collectible_"..i,className="Part",size=item.size or {2,2,2},position=item.position or {0,3,i*5},color=item.color or {255,155,65},material="Neon",anchored=true,canCollide=false}); p.Shape=Enum.PartType.Ball; p:SetAttribute("MEGA_Collectible",true); p:SetAttribute("MEGA_Reward",F.exNumber(item.reward,1,0,1e8)); p:SetAttribute("MEGA_RespawnSeconds",F.exNumber(item.respawnSeconds,0,0,86400)) end end); F.exRollback(root,ok,err,"CREATE_COLLECTIBLES"); return "Collectible markers created: "..#a.items.."; rewards must be server-authoritative"
end
function F.exCreateShopCatalog(a)
	if type(a.items)~="table" or #a.items<1 or #a.items>500 then error("items must contain 1..500 entries") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_ShopCatalog"); for i,item in ipairs(a.items) do local entry=Instance.new("Configuration"); entry.Name=F.safeName(item.id or item.name,"Item_"..i); entry:SetAttribute("DisplayName",F.exText(item.displayName,entry.Name,100)); entry:SetAttribute("Price",F.exNumber(item.price,0,0,2147483647)); entry:SetAttribute("Currency",F.safeName(item.currency,"Coins")); entry:SetAttribute("Enabled",item.enabled~=false); entry.Parent=root end; root:SetAttribute("MEGA_CatalogOnly",true); root:SetAttribute("MEGA_PurchaseMustValidateOnServer",true); return "Shop catalog created; no purchases are executed"
end
function F.exCreateQuestCatalog(a)
	if type(a.quests)~="table" or #a.quests>300 then error("quests must be <=300") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_QuestCatalog"); for i,q in ipairs(a.quests) do local item=Instance.new("Configuration"); item.Name=F.safeName(q.id or q.name,"Quest_"..i); item:SetAttribute("Title",F.exText(q.title,item.Name,150)); item:SetAttribute("Description",tostring(q.description or ""):sub(1,1000)); item:SetAttribute("Goal",F.exNumber(q.goal,1,1,1e6)); item:SetAttribute("Reward",F.exNumber(q.reward,0,0,2147483647)); item:SetAttribute("Currency",F.safeName(q.currency,"Coins")); item.Parent=root end; root:SetAttribute("MEGA_CatalogOnly",true); return "Quest catalog created: "..#a.quests
end
function F.exCreateRoundConfig(a)
	local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_RoundConfig"); local values={{"NumberValue","Intermission",F.exNumber(a.intermission,15,0,3600)},{"NumberValue","Duration",F.exNumber(a.duration,180,1,86400)},{"IntValue","MinimumPlayers",math.floor(F.exNumber(a.minimumPlayers,2,1,100))},{"IntValue","MaximumPlayers",math.floor(F.exNumber(a.maximumPlayers,20,1,100))}}; if values[4][3]<values[3][3] then root:Destroy(); error("maximumPlayers < minimumPlayers") end; for _,spec in ipairs(values) do local v=Instance.new(spec[1]); v.Name=spec[2]; v.Value=spec[3]; v.Parent=root end; root:SetAttribute("MEGA_ConfigOnly",true); return "Round configuration created; requires server round manager"
end
function F.exCreateCurrencyConfig(a)
	local currencies=a.currencies or {{name="Coins",startingAmount=0}}; if type(currencies)~="table" or #currencies<1 or #currencies>50 then error("currencies must be 1..50") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_Currencies"); for i,c in ipairs(currencies) do local item=Instance.new("Configuration"); item.Name=F.safeName(c.name,"Currency_"..i); item:SetAttribute("StartingAmount",F.exNumber(c.startingAmount,0,0,2147483647)); item:SetAttribute("DisplayName",F.exText(c.displayName,item.Name,80)); item.Parent=root end; root:SetAttribute("MEGA_ServerAuthorityRequired",true); return "Currency definitions created; server must own balances"
end
function F.exCreateProgressionConfig(a)
	local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_Progression"); local specs={{"IntValue","StartingLevel",math.floor(F.exNumber(a.startingLevel,1,1,1e6))},{"IntValue","StartingXP",math.floor(F.exNumber(a.startingXP,0,0,2147483647))},{"NumberValue","XPPerLevel",F.exNumber(a.xpPerLevel,100,1,1e8)},{"NumberValue","Multiplier",F.exNumber(a.multiplier,1.25,1,100)}}; for _,s in ipairs(specs) do local v=Instance.new(s[1]); v.Name=s[2]; v.Value=s[3]; v.Parent=root end; root:SetAttribute("MEGA_ConfigOnly",true); return "Progression configuration created"
end
function F.exCreateCheckpointMarkers(a)
	if type(a.points)~="table" or #a.points<1 or #a.points>200 then error("points must be 1..200") end; local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_Checkpoints"); local ok,err=pcall(function() for i,point in ipairs(a.points) do local p=F.exPart(root,{name=string.format("Checkpoint_%03d",i),size=point.size or {10,1,10},position=point.position or point,color=point.color or {55,130,255},material="Neon",anchored=true}); p:SetAttribute("MEGA_CheckpointIndex",i); p:SetAttribute("MEGA_CheckpointId",HttpService:GenerateGUID(false)) end end); F.exRollback(root,ok,err,"CREATE_CHECKPOINT_MARKERS"); return "Checkpoint markers created: "..#a.points.."; persistence requires server logic"
end
function F.exCreateMovingPlatform(a)
	if type(a.nodes)~="table" or #a.nodes<2 or #a.nodes>50 then error("nodes must be 2..50") end; local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_MovingPlatform"); root.Parent=F.exParent(a.parent,"Workspace"); local platform=F.exPart(root,{name="Platform",size=a.size or {12,1,12},position=a.position or {0,5,0},color=a.color,material="Metal",anchored=true}); local path=F.exFolder(root,"PathNodes"); for i,node in ipairs(a.nodes) do F.exPart(path,{name="Node_"..i,size={0.5,0.5,0.5},position=node.position or node,color={255,155,65},anchored=true,canCollide=false,transparency=0.4}) end; root:SetAttribute("MEGA_Duration",F.exNumber(a.duration,5,0.1,600)); root:SetAttribute("MEGA_Loop",a.loop~=false); return "Moving platform scaffold created; add server movement controller"
end
function F.exCreatePortalPair(a)
	local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_PortalPair"); local p0=F.exPart(root,{name="Portal_A",size=a.size or {8,12,1},position=a.positionA or {0,6,0},color=a.color or {55,130,255},material="Neon",anchored=true,canCollide=false}); local p1=F.exPart(root,{name="Portal_B",size=a.size or {8,12,1},position=a.positionB or {40,6,0},color=a.color or {255,155,65},material="Neon",anchored=true,canCollide=false}); p0:SetAttribute("MEGA_Destination","Portal_B"); p1:SetAttribute("MEGA_Destination","Portal_A"); return "Portal pair created; server must validate destination and player state"
end
function F.exCreateTeamSet(a)
	if type(a.teams)~="table" or #a.teams<1 or #a.teams>50 then error("teams must be 1..50") end; local service=game:GetService("Teams"); local made=0; for i,spec in ipairs(a.teams) do local t=Instance.new("Team"); t.Name=F.safeName(spec.name,"Team_"..i); t.TeamColor=BrickColor.new(F.exColor(spec.color,Color3.fromRGB(55+i*8,130,255))); t.AutoAssignable=spec.autoAssignable==true; t.Parent=service; made+=1 end; return "Teams created: "..made
end
function F.exCreateTeamSpawns(a)
	if type(a.teams)~="table" or #a.teams>50 then error("teams must be <=50") end; local parent=F.exParent(a.parent,"Workspace"); local made=0; for i,spec in ipairs(a.teams) do local team=game:GetService("Teams"):FindFirstChild(tostring(spec.name)); if team and team:IsA("Team") then local s=Instance.new("SpawnLocation"); s.Name=F.safeName(spec.spawnName,team.Name.."Spawn"); s.Size=F.exVec(spec.size,Vector3.new(8,1,8)); s.Position=F.exVec(spec.position,Vector3.new(i*12,2,0)); s.Anchored=true; s.Neutral=false; s.TeamColor=team.TeamColor; s.Parent=parent; made+=1 end end; return "Team spawns created: "..made
end
function F.exCreateSoundEmitter(a)
	local target=F.exTarget(a.target); if not (target:IsA("BasePart") or target:IsA("Attachment")) then error("Sound target must be BasePart/Attachment") end; local s=Instance.new("Sound"); s.Name=F.safeName(a.name,"MEGA_Sound"); s.SoundId=F.exAssetId(a.soundId,"SoundId"); s.Volume=F.exNumber(a.volume,0.5,0,10); s.Looped=a.looped==true; s.PlaybackSpeed=F.exNumber(a.playbackSpeed,1,0.1,3); s.RollOffMinDistance=F.exNumber(a.minDistance,10,0,10000); s.RollOffMaxDistance=F.exNumber(a.maxDistance,100,1,10000); if s.RollOffMinDistance>s.RollOffMaxDistance then error("minDistance > maxDistance") end; s.Parent=target; return "Sound emitter created"
end
function F.exCreateDecal(a)
	local target=F.exTarget(a.target,"BasePart"); local face=Enum.NormalId[a.face or "Front"]; if not face then error("Invalid face") end; local d=Instance.new("Decal"); d.Name=F.safeName(a.name,"MEGA_Decal"); d.Texture=F.exAssetId(a.texture,"Texture"); d.Face=face; d.Transparency=F.exNumber(a.transparency,0,0,1); d.Parent=target; return "Decal created"
end
function F.exCreateTexture(a)
	local target=F.exTarget(a.target,"BasePart"); local face=Enum.NormalId[a.face or "Top"]; if not face then error("Invalid face") end; local t=Instance.new("Texture"); t.Name=F.safeName(a.name,"MEGA_Texture"); t.Texture=F.exAssetId(a.texture,"Texture"); t.Face=face; t.StudsPerTileU=F.exNumber(a.tileU,4,0.1,1000); t.StudsPerTileV=F.exNumber(a.tileV,4,0.1,1000); t.Parent=target; return "Texture created"
end
function F.exSetSelectionMaterial(a)
	local material=Enum.Material[tostring(a.material or "SmoothPlastic")]; if not material then error("Invalid material") end; local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.Material=material; if a.color then p.Color=F.exColor(a.color) end end; return "Material applied to "..#parts.." selected parts"
end
function F.exSetSelectionColor(a)
	local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); local color=F.exColor(a.color,COLORS.Blue); for _,p in ipairs(parts) do p.Color=color end; return "Color applied to "..#parts.." parts"
end
function F.exSetSelectionAnchored(a)
	local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.Anchored=a.anchored==true end; return "Anchored updated on "..#parts.." parts"
end
function F.exSetSelectionCollision(a)
	local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.CanCollide=a.canCollide==true; if a.canTouch~=nil then p.CanTouch=a.canTouch==true end; if a.canQuery~=nil then p.CanQuery=a.canQuery==true end end; return "Collision flags updated on "..#parts.." parts"
end
function F.exSetSelectionTransparency(a)
	local value=F.exNumber(a.transparency,nil,0,1); local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.Transparency=value end; return "Transparency updated on "..#parts.." parts"
end
function F.exSetSelectionReflectance(a)
	local value=F.exNumber(a.reflectance,nil,0,1); local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.Reflectance=value end; return "Reflectance updated on "..#parts.." parts"
end
function F.exSetSelectionScale(a)
	local factor=F.exNumber(a.factor,nil,0.01,100); local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); if #parts<1 then error("No BaseParts selected") end; local center=parts[1].Position; for _,p in ipairs(parts) do local offset=p.Position-center; p.Size=Vector3.new(math.max(0.05,p.Size.X*factor),math.max(0.05,p.Size.Y*factor),math.max(0.05,p.Size.Z*factor)); p.Position=center+offset*factor end; return "Scale applied to "..#parts.." parts"
end
function F.exOffsetSelection(a)
	local offset=F.exVec(a.offset,Vector3.zero); local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); for _,p in ipairs(parts) do p.Position+=offset end; return "Offset applied to "..#parts.." parts"
end
function F.exRotateSelection(a)
	local degrees=F.exVec(a.degrees,Vector3.zero); local parts=F.getSelectedBaseParts(MEGA_EXT_LIMITS.selection); if #parts<1 then error("No BaseParts selected") end; local center=parts[1].Position; local rotation=CFrame.Angles(math.rad(degrees.X),math.rad(degrees.Y),math.rad(degrees.Z)); for _,p in ipairs(parts) do local relative=CFrame.new(center):ToObjectSpace(p.CFrame); p.CFrame=CFrame.new(center)*rotation*relative end; return "Rotation applied to "..#parts.." parts"
end
function F.exDuplicateSelection(a)
	local selected=Selection:Get(); if #selected<1 or #selected>200 then error("Select 1..200 instances") end; local offset=F.exVec(a.offset,Vector3.new(4,0,0)); local clones={}; local ok,err=pcall(function() for i,obj in ipairs(selected) do local clone=obj:Clone(); clone.Name=F.safeName(a.prefix,"Copy").."_"..i.."_"..obj.Name; clone.Parent=obj.Parent; if clone:IsA("Model") then clone:PivotTo(clone:GetPivot()+offset) elseif clone:IsA("BasePart") then clone.Position+=offset end; table.insert(clones,clone) end end); if not ok then for _,c in ipairs(clones) do c:Destroy() end; error(err) end; Selection:Set(clones); return "Duplicated "..#clones.." objects"
end
function F.exRenameTargets(a)
	if type(a.targets)~="table" or #a.targets<1 or #a.targets>500 then error("targets must be 1..500") end; local changed=0; for i,path in ipairs(a.targets) do local obj=F.findTarget(path); if obj then obj.Name=F.safeName((a.prefix or "")..(a.useIndex and string.format("%03d",i) or obj.Name)..(a.suffix or ""),obj.Name); changed+=1 end end; return "Renamed "..changed.." instances"
end
function F.exFindByAttribute(a)
	local key=F.exText(a.attribute,nil,100); local roots=a.roots or {"Workspace"}; local matches={}; local limit=math.floor(F.exNumber(a.limit,200,1,2000)); for _,path in ipairs(roots) do local root=F.findTarget(path); if root then for _,obj in ipairs(root:GetDescendants()) do local value=obj:GetAttribute(key); if value~=nil and (a.value==nil or value==a.value) then table.insert(matches,{path=obj:GetFullName(),className=obj.ClassName,value=value}); if #matches>=limit then break end end end end; if #matches>=limit then break end end; F.showJSON({attribute=key,count=#matches,matches=matches}); return "Attribute search: "..#matches
end
function F.exInspectHierarchy(a)
	local root=F.exTarget(a.target or a.path); local rows={}; local limit=math.floor(F.exNumber(a.limit,1000,1,10000)); local function walk(node,depth) if #rows>=limit or depth>20 then return end; table.insert(rows,{path=node:GetFullName(),className=node.ClassName,depth=depth,attributes=node:GetAttributes()}); for _,child in ipairs(node:GetChildren()) do walk(child,depth+1) end end; walk(root,0); F.showJSON({root=root:GetFullName(),count=#rows,truncated=#root:GetDescendants()+1>#rows,objects=rows}); return "Hierarchy inspected: "..#rows
end
function F.exPerformanceReport(a)
	local root=F.exTarget(a.root or "Workspace"); local counts={parts=0,unanchored=0,scripts=0,emitters=0,highRateEmitters=0,sounds=0,gui=0,lights=0,meshes=0}; local samples={unanchored={},emitters={}}; for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("BasePart") then counts.parts+=1; if not obj.Anchored then counts.unanchored+=1; if #samples.unanchored<30 then table.insert(samples.unanchored,obj:GetFullName()) end end; if obj:IsA("MeshPart") then counts.meshes+=1 end elseif obj:IsA("LuaSourceContainer") then counts.scripts+=1 elseif obj:IsA("ParticleEmitter") then counts.emitters+=1; if obj.Rate>100 then counts.highRateEmitters+=1; if #samples.emitters<30 then table.insert(samples.emitters,{path=obj:GetFullName(),rate=obj.Rate}) end end elseif obj:IsA("Sound") then counts.sounds+=1 elseif obj:IsA("GuiObject") then counts.gui+=1 elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then counts.lights+=1 end end; F.showJSON({counts=counts,samples=samples,note="Structural estimates only; not FPS or memory telemetry"}); return "Performance structure report ready"
end
function F.exScriptAudit(a)
	local root=F.exTarget(a.root or "Workspace"); local rows={}; local counts={Script=0,LocalScript=0,ModuleScript=0,disabled=0}; for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("LuaSourceContainer") then counts[obj.ClassName]=(counts[obj.ClassName] or 0)+1; if obj:IsA("BaseScript") and obj.Disabled then counts.disabled+=1 end; if #rows<500 then local ok,source=pcall(function() return obj.Source end); table.insert(rows,{path=obj:GetFullName(),className=obj.ClassName,sourceLength=ok and #source or -1,disabled=obj:IsA("BaseScript") and obj.Disabled or false}) end end end; F.showJSON({counts=counts,scripts=rows,note="Static inventory, not malware proof or runtime test"}); return "Script inventory complete"
end
function F.exGuiResponsiveAudit(a)
	local root=F.exTarget(a.root or "StarterGui"); local warnings={}; for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("GuiObject") then if obj.Size.X.Scale==0 and obj.Size.X.Offset>1000 then table.insert(warnings,{path=obj:GetFullName(),issue="Fixed width > 1000px"}) end; if obj.Size.Y.Scale==0 and obj.Size.Y.Offset>1000 then table.insert(warnings,{path=obj:GetFullName(),issue="Fixed height > 1000px"}) end; if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and not obj.TextScaled and obj.TextSize<10 then table.insert(warnings,{path=obj:GetFullName(),issue="TextSize below 10"}) end end end; F.showJSON({warningCount=#warnings,warnings=warnings,note="Structural audit; inspect actual viewport manually"}); return "Responsive GUI audit complete"
end
function F.exProjectManifest(a)
	local report={version=VERSION,placeId=game.PlaceId,gameId=game.GameId,services={}}; for _,name in ipairs({"Workspace","ReplicatedStorage","ServerStorage","ServerScriptService","StarterGui","StarterPlayer","Lighting","SoundService","Teams"}) do local service=game:GetService(name); table.insert(report.services,{name=name,children=#service:GetChildren(),descendants=#service:GetDescendants()}) end; F.showJSON(report); return "Project manifest generated"
end
function F.exModelBounds(a)
	local model=F.exTarget(a.target,"Model"); local cf,size=model:GetBoundingBox(); F.showJSON({path=model:GetFullName(),size={size.X,size.Y,size.Z},center={cf.Position.X,cf.Position.Y,cf.Position.Z},pivot={model:GetPivot():GetComponents()},primaryPart=model.PrimaryPart and model.PrimaryPart:GetFullName() or nil}); return "Model bounds inspected"
end
function F.exSetModelPivot(a)
	local model=F.exTarget(a.target,"Model"); local target=F.exTarget(a.reference,"BasePart"); model:PivotTo(target.CFrame*CFrame.new(F.exVec(a.offset,Vector3.zero))); return "Model pivot aligned to reference"
end
function F.exCreateModelFromSelection(a)
	local selected=Selection:Get(); if #selected<1 or #selected>500 then error("Select 1..500 instances") end; local parent=F.exParent(a.parent,"Workspace"); local model=Instance.new("Model"); model.Name=F.safeName(a.name,"MEGA_Model"); model.Parent=parent; local moved={}; local originals={}; local ok,err=pcall(function() for _,obj in ipairs(selected) do if obj==model or parent:IsDescendantOf(obj) then error("Circular hierarchy") end; originals[obj]=obj.Parent; obj.Parent=model; table.insert(moved,obj) end end); if not ok then for _,obj in ipairs(moved) do obj.Parent=originals[obj] end; model:Destroy(); error(err) end; Selection:Set({model}); return "Model grouped from selection: "..#moved
end
function F.exCreateFolderTree(a)
	if type(a.tree)~="table" then error("tree must be table") end; local parent=F.exParent(a.parent,"Workspace"); local count=0; local max=math.floor(F.exNumber(a.maxNodes,200,1,500)); local root; local created={}
	local function build(node,container,depth) if depth>12 then error("Folder tree depth >12") end; count+=1; if count>max then error("Folder tree node limit exceeded") end; local f=Instance.new("Folder"); table.insert(created,f); f.Name=F.safeName(node.name,"Folder_"..count); f.Parent=container; if node.children~=nil then if type(node.children)~="table" then error("children must be table") end; for _,child in ipairs(node.children) do build(child,f,depth+1) end end; return f end
	local ok,err=pcall(function() root=build(a.tree,parent,1) end); if not ok then for i=#created,1,-1 do if created[i].Parent then created[i]:Destroy() end end; error(err) end; return "Folder tree created: "..count.." nodes"
end
function F.exCreateSystemScaffold(a)
	local parent=F.exParent(a.parent,"ReplicatedStorage"); local root=F.exFolder(parent,a.name or "MEGA_System"); local names=a.folders or {"Config","Remotes","Shared","Assets","Data"}; if type(names)~="table" or #names>50 then root:Destroy(); error("folders max 50") end; local seen={}; for _,name in ipairs(names) do local clean=F.safeName(name,"Folder"); if seen[clean] then root:Destroy(); error("Duplicate folder: "..clean) end; seen[clean]=true; F.exFolder(root,clean) end; root:SetAttribute("MEGA_ScaffoldOnly",true); return "System scaffold created: "..#names.." folders; scripts must be generated separately"
end
function F.exCreateServerClientScaffold(a)
	local base=F.safeName(a.name,"MEGA_System"); F.exFolder(F.exParent(a.sharedParent,"ReplicatedStorage"),base.."Shared"); F.exFolder(F.exParent(a.serverParent,"ServerScriptService"),base.."Server"); F.exFolder(F.exParent(a.clientParent,"StarterPlayer.StarterPlayerScripts"),base.."Client"); F.exFolder(F.exParent(a.remoteParent,"ReplicatedStorage"),base.."Remotes"); return "Server/Client/Shared/Remotes architecture folders created"
end
function F.exCreateDataSchema(a)
	if type(a.fields)~="table" or #a.fields>200 then error("fields max 200") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_DataSchema"); for i,spec in ipairs(a.fields) do local item=Instance.new("Configuration"); item.Name=F.safeName(spec.name,"Field_"..i); item:SetAttribute("Type",F.safeName(spec.valueType,"string")); item:SetAttribute("Required",spec.required==true); item:SetAttribute("Default",tostring(spec.default or "")); item:SetAttribute("Min",tonumber(spec.min) or 0); item:SetAttribute("Max",tonumber(spec.max) or 0); item.Parent=root end; root:SetAttribute("MEGA_SchemaOnly",true); return "Data schema created: "..#a.fields
end
function F.exCreateTimerConfig(a)
	local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_TimerConfig"); local values={{"NumberValue","Duration",F.exNumber(a.duration,60,0.1,86400)},{"NumberValue","WarningAt",F.exNumber(a.warningAt,10,0,86400)},{"BoolValue","AutoStart",a.autoStart==true},{"BoolValue","Loop",a.loop==true}}; for _,spec in ipairs(values) do local v=Instance.new(spec[1]); v.Name=spec[2]; v.Value=spec[3]; v.Parent=root end; root:SetAttribute("MEGA_ConfigOnly",true); return "Timer configuration created; add timer controller"
end
function F.exCreateLeaderboardConfig(a)
	local stats=a.stats or {{name="Coins",className="IntValue",default=0}}; if type(stats)~="table" or #stats<1 or #stats>20 then error("stats must be 1..20") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_LeaderboardConfig"); for i,spec in ipairs(stats) do local c=spec.className or "IntValue"; if c~="IntValue" and c~="NumberValue" and c~="StringValue" then root:Destroy(); error("Invalid stat type") end; local v=Instance.new(c); v.Name=F.safeName(spec.name,"Stat_"..i); if c=="StringValue" then v.Value=tostring(spec.default or "") elseif c=="IntValue" then v.Value=math.floor(F.exNumber(tonumber(spec.default),0,-2147483647,2147483647)) else v.Value=F.exNumber(tonumber(spec.default),0,-1e12,1e12) end; v.Parent=root end; root:SetAttribute("MEGA_ConfigOnly",true); return "Leaderboard schema created"
end
function F.exCreateNPCMarker(a)
	local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_NPCMarker"); root.Parent=F.exParent(a.parent,"Workspace"); local part=F.exPart(root,{name="HumanoidRootPart",size={2,2,1},position=a.position or {0,3,0},color=a.color,anchored=true,transparency=0.5}); local humanoid=Instance.new("Humanoid"); humanoid.DisplayName=F.exText(a.displayName,root.Name,100); humanoid.Parent=root; root.PrimaryPart=part; return "NPC placeholder created; no rig or navigation AI included"
end
function F.exCreateSeat(a)
	local class=a.vehicle==true and "VehicleSeat" or "Seat"; local seat=Instance.new(class); seat.Name=F.safeName(a.name,"MEGA_Seat"); seat.Size=F.exVec(a.size,Vector3.new(2,1,2)); seat.Position=F.exVec(a.position,Vector3.new(0,3,0)); seat.Anchored=a.anchored~=false; seat.Color=F.exColor(a.color,COLORS.Blue); if class=="VehicleSeat" then seat.MaxSpeed=F.exNumber(a.maxSpeed,50,0,500); seat.Torque=F.exNumber(a.torque,10,0,10000); seat.TurnSpeed=F.exNumber(a.turnSpeed,1,0,100) end; seat.Parent=F.exParent(a.parent,"Workspace"); return class.." created"
end
function F.exCreateCamera(a)
	local camera=Instance.new("Camera"); camera.Name=F.safeName(a.name,"MEGA_Camera"); camera.CFrame=CFrame.lookAt(F.exVec(a.position,Vector3.new(0,10,20)),F.exVec(a.lookAt,Vector3.zero)); camera.FieldOfView=F.exNumber(a.fieldOfView,70,1,120); camera.Parent=F.exParent(a.parent,"Workspace"); return "Camera marker created; LocalScript must assign CurrentCamera"
end
function F.exCreateWorldModel(a)
	local world=Instance.new("WorldModel"); world.Name=F.safeName(a.name,"MEGA_WorldModel"); world.Parent=F.exParent(a.parent,"Workspace"); return "WorldModel created"
end
function F.exCreateSurfaceAppearance(a)
	local target=F.exTarget(a.target,"MeshPart"); local surface=Instance.new("SurfaceAppearance"); surface.Name=F.safeName(a.name,"MEGA_SurfaceAppearance"); for prop,key in pairs({ColorMap="colorMap",MetalnessMap="metalnessMap",NormalMap="normalMap",RoughnessMap="roughnessMap"}) do if a[key]~=nil then surface[prop]=F.exAssetId(a[key],prop) end end; surface.Parent=target; return "SurfaceAppearance assigned; verify texture permissions"
end
function F.exCreateToolboxManifest(a)
	if type(a.assets)~="table" or #a.assets>500 then error("assets max 500") end; local root=F.exFolder(F.exParent(a.parent,"ReplicatedStorage"),a.name or "MEGA_AssetManifest"); for i,spec in ipairs(a.assets) do local item=Instance.new("Configuration"); item.Name=F.safeName(spec.name,"Asset_"..i); item:SetAttribute("AssetId",tostring(spec.assetId or "")); item:SetAttribute("AssetType",F.safeName(spec.assetType,"Unknown")); item:SetAttribute("UserVerified",spec.verified==true); item.Parent=root end; root:SetAttribute("MEGA_ManifestOnly",true); return "Asset manifest created; no asset was downloaded"
end
function F.exStreamingSettings(a)
	local ws=game:GetService("Workspace"); if a.enabled~=nil then ws.StreamingEnabled=a.enabled==true end; if a.minRadius~=nil then ws.StreamingMinRadius=math.floor(F.exNumber(a.minRadius,ws.StreamingMinRadius,64,1024)) end; return "Workspace streaming settings updated; test client streaming"
end
function F.exSelectionBounds(a)
	local selected=Selection:Get(); if #selected<1 then error("Selection is empty") end; local minV,maxV; local function add(low,high) minV=minV and Vector3.new(math.min(minV.X,low.X),math.min(minV.Y,low.Y),math.min(minV.Z,low.Z)) or low; maxV=maxV and Vector3.new(math.max(maxV.X,high.X),math.max(maxV.Y,high.Y),math.max(maxV.Z,high.Z)) or high end; for _,obj in ipairs(selected) do if obj:IsA("BasePart") then add(obj.Position-obj.Size/2,obj.Position+obj.Size/2) elseif obj:IsA("Model") then local cf,size=obj:GetBoundingBox(); add(cf.Position-size/2,cf.Position+size/2) end end; if not minV then error("Selection has no physical bounds") end; local p=Instance.new("Part"); p.Name=F.safeName(a.name,"MEGA_SelectionBounds"); p.Size=maxV-minV+F.exVec(a.padding,Vector3.zero); p.Position=(minV+maxV)/2; p.Anchored=true; p.CanCollide=false; p.Transparency=F.exNumber(a.transparency,0.85,0,1); p.Color=F.exColor(a.color,COLORS.Orange); p.Parent=F.exParent(a.parent,"Workspace"); return "Selection bounds helper created"
end
function F.exSelectionTag(a)
	local tag=F.exText(a.tag,nil,64); local selected=Selection:Get(); if #selected<1 or #selected>500 then error("Select 1..500 instances") end; for _,obj in ipairs(selected) do CollectionService:AddTag(obj,tag) end; return "Tag applied to "..#selected
end
function F.exSelectionAttribute(a)
	local key=F.exText(a.name,nil,100); local value=a.value; local t=typeof(value); if t~="string" and t~="number" and t~="boolean" and t~="Vector3" and t~="Color3" then error("Unsupported attribute value") end; local selected=Selection:Get(); if #selected<1 or #selected>500 then error("Select 1..500") end; for _,obj in ipairs(selected) do obj:SetAttribute(key,value) end; return "Attribute applied to "..#selected
end
function F.exCreateUISection(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local frame=Instance.new("Frame"); frame.Name=F.safeName(a.name,"MEGA_Section"); frame.Size=UDim2.new(1,0,0,F.exNumber(a.height,120,30,1000)); frame.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); frame.Parent=parent; local title=Instance.new("TextLabel"); title.Name="Title"; title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,6); title.Size=UDim2.new(1,-24,0,24); title.Text=F.exText(a.title,"Section",100); title.TextColor3=COLORS.White; title.Font=Enum.Font.GothamBold; title.Parent=frame; local content=Instance.new("Frame"); content.Name="Content"; content.BackgroundTransparency=1; content.Position=UDim2.fromOffset(12,34); content.Size=UDim2.new(1,-24,1,-42); content.Parent=frame; local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,6); layout.Parent=content; return "UI section created"
end
function F.exCreateUIStatHud(a)
	local parent=F.exParent(a.parent,"StarterGui"); local screen=Instance.new("ScreenGui"); screen.Name=F.safeName(a.name,"MEGA_StatsHUD"); screen.ResetOnSpawn=a.resetOnSpawn~=false; screen.Parent=parent; local root=Instance.new("Frame"); root.Name="HUDRoot"; root.Size=UDim2.fromScale(1,1); root.BackgroundTransparency=1; root.Parent=screen; local layout=Instance.new("UIListLayout"); layout.FillDirection=Enum.FillDirection.Horizontal; layout.Padding=UDim.new(0,8); layout.Parent=root; local padding=Instance.new("UIPadding"); padding.PaddingTop=UDim.new(0,16); padding.PaddingLeft=UDim.new(0,16); padding.Parent=root; return "Stats HUD root created; bind values through LocalScript"
end
function F.exCreateToast(a)
	local parent=F.exParent(a.parent,"StarterGui"); local screen=Instance.new("ScreenGui"); screen.Name=F.safeName(a.name,"MEGA_Toast"); screen.DisplayOrder=100; screen.Parent=parent; local frame=Instance.new("Frame"); frame.Name="Toast"; frame.AnchorPoint=Vector2.new(0.5,0); frame.Position=UDim2.fromScale(0.5,0.04); frame.Size=UDim2.fromOffset(F.exNumber(a.width,340,120,900),F.exNumber(a.height,64,32,200)); frame.BackgroundColor3=F.exColor(a.backgroundColor,COLORS.Panel); frame.Parent=screen; local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Size=UDim2.new(1,-24,1,-12); label.Position=UDim2.fromOffset(12,6); label.Text=F.exText(a.message,"Notification",300); label.TextColor3=COLORS.White; label.TextWrapped=true; label.Parent=frame; return "Toast visual created; timed dismissal requires LocalScript"
end

function F.exCreateConfirmDialog(a)
	local screen=Instance.new("ScreenGui"); screen.Name=F.safeName(a.name,"MEGA_ConfirmDialog"); screen.DisplayOrder=200; screen.Parent=F.exParent(a.parent,"StarterGui"); local overlay=Instance.new("Frame"); overlay.Name="Overlay"; overlay.Size=UDim2.fromScale(1,1); overlay.BackgroundColor3=Color3.new(0,0,0); overlay.BackgroundTransparency=0.4; overlay.Parent=screen; local dialog=Instance.new("Frame"); dialog.Name="Dialog"; dialog.AnchorPoint=Vector2.new(0.5,0.5); dialog.Position=UDim2.fromScale(0.5,0.5); dialog.Size=UDim2.fromOffset(360,180); dialog.BackgroundColor3=COLORS.Panel; dialog.Parent=overlay; local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,12); corner.Parent=dialog; local title=Instance.new("TextLabel"); title.Name="Title"; title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(16,12); title.Size=UDim2.new(1,-32,0,28); title.Text=F.exText(a.title,"Confirm",100); title.TextColor3=COLORS.White; title.Font=Enum.Font.GothamBold; title.TextSize=17; title.Parent=dialog; local body=Instance.new("TextLabel"); body.Name="Body"; body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(16,44); body.Size=UDim2.new(1,-32,0,60); body.Text=F.exText(a.message,"Review this action",300); body.TextColor3=COLORS.Muted; body.TextWrapped=true; body.Parent=dialog; local yes=Instance.new("TextButton"); yes.Name="Confirm"; yes.Position=UDim2.new(0,16,1,-48); yes.Size=UDim2.new(0.5,-22,0,34); yes.BackgroundColor3=COLORS.Blue; yes.Text="Confirm"; yes.TextColor3=COLORS.White; yes.Parent=dialog; local no=Instance.new("TextButton"); no.Name="Cancel"; no.Position=UDim2.new(0.5,6,1,-48); no.Size=UDim2.new(0.5,-22,0,34); no.BackgroundColor3=COLORS.PanelLight; no.Text="Cancel"; no.TextColor3=COLORS.White; no.Parent=dialog; return "Confirm dialog visual created; wire buttons in LocalScript"
end

function F.exCreateTabs(a)
	local parent=F.exTarget(a.parent,"GuiObject"); if type(a.tabs)~="table" or #a.tabs<1 or #a.tabs>20 then error("tabs must be 1..20") end; local root=Instance.new("Frame"); root.Name=F.safeName(a.name,"MEGA_Tabs"); root.Size=UDim2.fromScale(1,1); root.BackgroundTransparency=1; root.Parent=parent; local bar=Instance.new("Frame"); bar.Name="TabBar"; bar.Size=UDim2.new(1,0,0,36); bar.BackgroundTransparency=1; bar.Parent=root; local list=Instance.new("UIListLayout"); list.FillDirection=Enum.FillDirection.Horizontal; list.Padding=UDim.new(0,6); list.Parent=bar; local content=Instance.new("Frame"); content.Name="Content"; content.Position=UDim2.fromOffset(0,42); content.Size=UDim2.new(1,0,1,-42); content.BackgroundColor3=COLORS.Panel; content.Parent=root; for i,name in ipairs(a.tabs) do local b=Instance.new("TextButton"); b.Name="Tab_"..i; b.Size=UDim2.fromOffset(100,32); b.Text=F.exText(name,"Tab",50); b.TextColor3=COLORS.White; b.BackgroundColor3=i==1 and COLORS.Blue or COLORS.PanelLight; b.Parent=bar end; return "Tab bar created; navigation requires LocalScript"
end
function F.exCreateUIGrid(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local grid=Instance.new("UIGridLayout"); grid.Name=F.safeName(a.name,"MEGA_GridLayout"); grid.CellSize=UDim2.fromOffset(F.exNumber(a.cellWidth,120,20,800),F.exNumber(a.cellHeight,90,20,800)); grid.CellPadding=UDim2.fromOffset(F.exNumber(a.paddingX,8,0,100),F.exNumber(a.paddingY,8,0,100)); grid.SortOrder=Enum.SortOrder.LayoutOrder; grid.Parent=parent; return "UIGridLayout applied"
end
function F.exCreateUIConstraint(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local c=Instance.new("UISizeConstraint"); c.Name=F.safeName(a.name,"MEGA_SizeConstraint"); c.MinSize=Vector2.new(F.exNumber(a.minWidth,0,0,2000),F.exNumber(a.minHeight,0,0,2000)); c.MaxSize=Vector2.new(F.exNumber(a.maxWidth,2000,1,4000),F.exNumber(a.maxHeight,2000,1,4000)); c.Parent=parent; return "UISizeConstraint applied"
end
function F.exCreateUIAspect(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local c=Instance.new("UIAspectRatioConstraint"); c.Name=F.safeName(a.name,"MEGA_AspectRatio"); c.AspectRatio=F.exNumber(a.ratio,1,0.1,10); c.Parent=parent; return "UIAspectRatioConstraint applied"
end
function F.exCreateUIScale(a)
	local parent=F.exTarget(a.parent,"GuiObject"); local s=Instance.new("UIScale"); s.Name=F.safeName(a.name,"MEGA_UIScale"); s.Scale=F.exNumber(a.scale,1,0.1,5); s.Parent=parent; return "UIScale applied"
end
function F.exSetUIVisibility(a)
	local target=F.exTarget(a.target,"GuiObject"); target.Visible=a.visible~=false; return "UI visibility updated"
end
function F.exSetUIOrder(a)
	local target=F.exTarget(a.target,"GuiObject"); target.LayoutOrder=math.floor(F.exNumber(a.order,0,-100000,100000)); return "LayoutOrder updated"
end
function F.exSetUIZIndex(a)
	local target=F.exTarget(a.target,"GuiObject"); target.ZIndex=math.floor(F.exNumber(a.zIndex,1,1,100)); return "ZIndex updated"
end
function F.exSetUIAutoSize(a)
	local target=F.exTarget(a.target,"GuiObject"); target.AutomaticSize=Enum.AutomaticSize[a.axis or "Y"] or Enum.AutomaticSize.Y; return "AutomaticSize updated"
end
function F.exCreatePartSet(a)
	if type(a.parts)~="table" or #a.parts<1 or #a.parts>500 then error("parts must be 1..500") end; local root=Instance.new("Model"); root.Name=F.safeName(a.name,"MEGA_PartSet"); root.Parent=F.exParent(a.parent,"Workspace"); local ok,err=pcall(function() for i,spec in ipairs(a.parts) do local class=spec.className or "Part"; if class~="Part" and class~="WedgePart" and class~="CornerWedgePart" and class~="TrussPart" then error("Unsupported part class") end; F.exPart(root,spec,"Part_"..i) end end); F.exRollback(root,ok,err,"CREATE_PART_SET"); return "Part set created: "..#a.parts
end
function F.exCreateFolderBatch(a)
	if type(a.names)~="table" or #a.names>100 then error("names max 100") end; local root=F.exFolder(F.exParent(a.parent,"Workspace"),a.name or "MEGA_Folders"); local seen={}; for _,name in ipairs(a.names) do local clean=F.safeName(name,"Folder"); if seen[clean] then root:Destroy(); error("Duplicate folder name") end; seen[clean]=true; F.exFolder(root,clean) end; return "Folder batch created: "..#a.names
end
function F.exCreatePartFromBounds(a)
	local model=F.exTarget(a.target,"Model"); local cf,size=model:GetBoundingBox(); local part=F.exPart(F.exParent(a.parent,model.Parent),{name=a.name or model.Name.."_Bounds",size=size+F.exVec(a.padding,Vector3.zero),position=cf.Position,color=a.color or {255,155,65},anchored=true,canCollide=false,transparency=0.85}); part.CFrame=cf; return "Bounds helper created"
end
function F.exCreateSelectionReport(a)
	local rows={}; for i,obj in ipairs(Selection:Get()) do local row={index=i,path=obj:GetFullName(),className=obj.ClassName,children=#obj:GetChildren(),descendants=#obj:GetDescendants(),attributes=obj:GetAttributes()}; if obj:IsA("BasePart") then row.position={obj.Position.X,obj.Position.Y,obj.Position.Z}; row.size={obj.Size.X,obj.Size.Y,obj.Size.Z}; row.anchored=obj.Anchored end; table.insert(rows,row) end; F.showJSON({count=#rows,selection=rows}); return "Selection report ready"
end
function F.exWorldBoundsReport(a)
	local root=F.exTarget(a.root or "Workspace"); local minV,maxV,count=nil,nil,0; for _,p in ipairs(root:GetDescendants()) do if p:IsA("BasePart") then local low=p.Position-p.Size/2; local high=p.Position+p.Size/2; minV=minV and Vector3.new(math.min(minV.X,low.X),math.min(minV.Y,low.Y),math.min(minV.Z,low.Z)) or low; maxV=maxV and Vector3.new(math.max(maxV.X,high.X),math.max(maxV.Y,high.Y),math.max(maxV.Z,high.Z)) or high; count+=1 end end; F.showJSON({count=count,min=minV and {minV.X,minV.Y,minV.Z},max=maxV and {maxV.X,maxV.Y,maxV.Z}}); return "World bounds report ready"
end
function F.exTagReport(a)
	local rows={}; for _,tag in ipairs(CollectionService:GetAllTags()) do local objects=CollectionService:GetTagged(tag); table.insert(rows,{tag=tag,count=#objects}) end; table.sort(rows,function(x,y) return x.tag<y.tag end); F.showJSON({count=#rows,tags=rows}); return "CollectionService report ready"
end
function F.exLightingReport(a)
	local l=game:GetService("Lighting"); local report={clockTime=l.ClockTime,brightness=l.Brightness,exposure=l.ExposureCompensation,ambient=tostring(l.Ambient),outdoorAmbient=tostring(l.OutdoorAmbient),effects={}}; for _,obj in ipairs(l:GetChildren()) do table.insert(report.effects,{name=obj.Name,className=obj.ClassName}) end; F.showJSON(report); return "Lighting report ready"
end
function F.exSoundReport(a)
	local root=F.exTarget(a.root or "SoundService"); local rows={}; for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then table.insert(rows,{path=obj:GetFullName(),soundId=obj.SoundId,volume=obj.Volume,looped=obj.Looped}) end end; F.showJSON({count=#rows,sounds=rows}); return "Sound report ready"
end
function F.exTerrainReport(a)
	local t=game:GetService("Workspace"):FindFirstChildOfClass("Terrain"); if not t then error("Terrain missing") end; F.showJSON({waterColor=tostring(t.WaterColor),waterTransparency=t.WaterTransparency,waterReflectance=t.WaterReflectance,waterWaveSize=t.WaterWaveSize,waterWaveSpeed=t.WaterWaveSpeed,decoration=t.Decoration}); return "Terrain report ready"
end
function F.exCapabilities()
	local names={}; for name in pairs(MEGA_EXT_ACTION_HANDLERS) do table.insert(names,name) end; table.sort(names); F.showJSON({version=VERSION,extendedActionCount=#names,actions=names,limits=MEGA_EXT_LIMITS,notes={"Scaffolds are not complete game systems","Server validates rewards, purchases, combat and teleports","Asset IDs and permissions must be verified","Structural reports are not Play Test evidence"}}); return "Extended capability catalog: "..#names
end

local MEGA_EXT_ACTION_HANDLERS = {
	CREATE_SPAWN_SET=F.exCreateSpawnSet, CREATE_HIGHLIGHT=F.exCreateHighlight, CREATE_CLICK_DETECTOR=F.exCreateClickDetector,
	CREATE_BILLBOARD_GUI=F.exCreateBillboard, CREATE_SURFACE_GUI=F.exCreateSurfaceGui, CREATE_WELD=F.exCreateWeld,
	CREATE_BEAM=function(a) return F.exCreateBeam(a,false) end, CREATE_TRAIL=function(a) return F.exCreateBeam(a,true) end,
	CREATE_PARTICLE_EMITTER=F.exCreateParticles, CREATE_PATH_NODES=F.exCreatePath, CREATE_ZONE=F.exCreateZone,
	CREATE_SOUND_GROUP=F.exCreateSoundGroup, CREATE_SOUNDSCAPE=F.exCreateSoundscape, CREATE_ANIMATION_SET=F.exCreateAnimationSet,
	CREATE_REMOTE_BUNDLE=F.exCreateRemoteBundle, CREATE_VALUE_BUNDLE=F.exCreateValueBundle, CREATE_ATTRIBUTE_SET=F.exCreateAttributes,
	BATCH_SET_PROPERTIES=F.exBatchProperties, PIVOT_MODEL=F.exPivotModel, SET_MODEL_PRIMARY_PART=F.exSetPrimaryPart,
	SET_COLLISION_GROUP=F.exCollisionGroup, SET_COLLISION_RELATIONSHIP=F.exCollisionRelation,
	CREATE_UI_STROKE=F.exCreateUIStroke, CREATE_UI_GRADIENT=F.exCreateGradient, CREATE_UI_PADDING=F.exCreatePadding,
	CREATE_UI_LAYOUT=F.exCreateLayout, CREATE_UI_CORNER=F.exCreateCorner, CREATE_UI_BUTTON=F.exCreateUIButton,
	CREATE_UI_CARD=F.exCreateUICard, CREATE_UI_PROGRESS_BAR=F.exCreateProgressBar, CREATE_UI_STAT_CARD=F.exCreateStatCard,
	CREATE_UI_INPUT=F.exCreateUIInput, CREATE_UI_IMAGE=F.exCreateImage, CREATE_UI_OVERLAY=F.exCreateUIOverlay,
	CREATE_UI_SCROLL_LIST=F.exCreateUIScroll, CREATE_UI_PANEL=F.exCreatePanel, CREATE_UI_SECTION=F.exCreateUISection,
	CREATE_UI_TABS=F.exCreateTabs, CREATE_UI_GRID=F.exCreateUIGrid, CREATE_UI_SIZE_CONSTRAINT=F.exCreateUIConstraint,
	CREATE_UI_ASPECT_RATIO=F.exCreateUIAspect, CREATE_UI_SCALE=F.exCreateUIScale, SET_UI_VISIBILITY=F.exSetUIVisibility,
	SET_UI_LAYOUT_ORDER=F.exSetUIOrder, SET_UI_ZINDEX=F.exSetUIZIndex, SET_UI_AUTOMATIC_SIZE=F.exSetUIAutoSize,
	CREATE_PART_GRID=F.exCreatePartGrid, CREATE_STAIRS=F.exCreateStairs, CREATE_RING=F.exCreateRing, CREATE_WALL=F.exCreateWall,
	CREATE_COLLECTIBLES=F.exCreateCollectibles, CREATE_SHOP_CATALOG=F.exCreateShopCatalog, CREATE_QUEST_CATALOG=F.exCreateQuestCatalog,
	CREATE_ROUND_CONFIG=F.exCreateRoundConfig, CREATE_CURRENCY_CONFIG=F.exCreateCurrencyConfig, CREATE_PROGRESSION_CONFIG=F.exCreateProgressionConfig,
	CREATE_CHECKPOINT_MARKERS=F.exCreateCheckpointMarkers, CREATE_MOVING_PLATFORM=F.exCreateMovingPlatform, CREATE_PORTAL_PAIR=F.exCreatePortalPair,
	CREATE_TEAM_SET=F.exCreateTeamSet, CREATE_TEAM_SPAWNS=F.exCreateTeamSpawns, CREATE_SOUND_EMITTER=F.exCreateSoundEmitter,
	CREATE_DECAL=F.exCreateDecal, CREATE_TEXTURE=F.exCreateTexture, SET_SELECTION_MATERIAL=F.exSetSelectionMaterial,
	SET_SELECTION_COLOR=F.exSetSelectionColor, SET_SELECTION_ANCHORED=F.exSetSelectionAnchored, SET_SELECTION_COLLISION=F.exSetSelectionCollision,
	SET_SELECTION_TRANSPARENCY=F.exSetSelectionTransparency, SET_SELECTION_REFLECTANCE=F.exSetSelectionReflectance,
	SET_SELECTION_SCALE=F.exSetSelectionScale, OFFSET_SELECTION=F.exOffsetSelection, ROTATE_SELECTION=F.exRotateSelection,
	DUPLICATE_SELECTION=F.exDuplicateSelection, RENAME_INSTANCES=F.exRenameTargets, FIND_BY_ATTRIBUTE=F.exFindByAttribute,
	INSPECT_HIERARCHY=F.exInspectHierarchy, REPORT_PERFORMANCE=F.exPerformanceReport, AUDIT_SCRIPTS_EXTENDED=F.exScriptAudit,
	AUDIT_GUI_RESPONSIVE=F.exGuiResponsiveAudit, CREATE_PROJECT_MANIFEST=F.exProjectManifest, INSPECT_MODEL_BOUNDS=F.exModelBounds,
	PIVOT_MODEL_TO_TARGET=F.exSetModelPivot, CREATE_MODEL_FROM_SELECTION=F.exCreateModelFromSelection,
	CREATE_FOLDER_TREE=F.exCreateFolderTree, CREATE_SYSTEM_SCAFFOLD=F.exCreateSystemScaffold,
	CREATE_SERVER_CLIENT_SCAFFOLD=F.exCreateServerClientScaffold, CREATE_DATA_SCHEMA=F.exCreateDataSchema,
	CREATE_TIMER_CONFIG=F.exCreateTimerConfig, CREATE_LEADERBOARD_CONFIG=F.exCreateLeaderboardConfig,
	CREATE_NPC_MARKER=F.exCreateNPCMarker, CREATE_SEAT=F.exCreateSeat, CREATE_CAMERA=F.exCreateCamera, CREATE_WORLD_MODEL=F.exCreateWorldModel,
	CREATE_SURFACE_APPEARANCE=F.exCreateSurfaceAppearance, CREATE_ASSET_MANIFEST=F.exCreateToolboxManifest,
	SET_STREAMING_SETTINGS=F.exStreamingSettings, CREATE_SELECTION_BOUNDS=F.exSelectionBounds,
	ADD_TAG_TO_SELECTION=F.exSelectionTag, ADD_ATTRIBUTE_TO_SELECTION=F.exSelectionAttribute,
	CREATE_UI_STAT_HUD=F.exCreateUIStatHud, CREATE_UI_TOAST=F.exCreateToast,
	CREATE_UI_CONFIRM_DIALOG=F.exCreateConfirmDialog, CREATE_POST_EFFECT=F.exCreatePostEffect, CREATE_ATMOSPHERE=F.exAtmosphere,
	CREATE_PART_SET=F.exCreatePartSet, CREATE_FOLDER_BATCH=F.exCreateFolderBatch, CREATE_PART_FROM_BOUNDS=F.exCreatePartFromBounds,
	INSPECT_SELECTION_REPORT=F.exCreateSelectionReport, REPORT_WORLD_BOUNDS=F.exWorldBoundsReport, REPORT_COLLECTION_TAGS=F.exTagReport,
	REPORT_LIGHTING=F.exLightingReport, REPORT_SOUNDS=F.exSoundReport, REPORT_TERRAIN=F.exTerrainReport,
	LIST_EXTENDED_CAPABILITIES=F.exCapabilities,
	LIST_EXTENDED_CONTRACTS=F.listExtendedActionContracts,	LIST_EXTENDED_PLAYBOOKS=F.getExtendedSpecialistPlaybook,	LIST_EXTENDED_RECIPES=F.getExtendedPlannerRecipes,	REPORT_EXTENDED_CONTRACT_SUMMARY=F.getExtendedContractSummary,
}

function F.executeExtendedAction(action)
	if validateExtendedActionContract then validateExtendedActionContract(action) end
	local handler=MEGA_EXT_ACTION_HANDLERS[action.type]
	if not handler then return false,"Unsupported extended action: "..tostring(action.type) end
	local ok,result=pcall(handler,action)
	if not ok then error(tostring(result)) end
	return true,result
end

function F.runExtendedSelfTests()
	local results={}; local passed,failed=0,0
	local function test(name,callback) local ok,err=pcall(callback); if ok then passed+=1; table.insert(results,{name=name,status="passed"}) else failed+=1; table.insert(results,{name=name,status="failed",error=tostring(err):sub(1,250)}) end end
	test("finite rejects NaN",function() assert(not pcall(F.exNumber,0/0,nil,nil,nil,"nan")) end)
	test("finite rejects infinity",function() assert(not pcall(F.exNumber,math.huge,nil,nil,nil,"inf")) end)
	test("minimum enforced",function() assert(not pcall(F.exNumber,0,nil,1,5,"min")) end)
	test("maximum enforced",function() assert(not pcall(F.exNumber,6,nil,1,5,"max")) end)
	test("text rejects empty",function() assert(not pcall(F.exText,"",nil,10,"empty")) end)
	test("text max enforced",function() assert(not pcall(F.exText,string.rep("x",11),nil,10,"long")) end)
	test("vector accepts Vector3",function() assert(F.exVec(Vector3.new(1,2,3),nil)==Vector3.new(1,2,3)) end)
	test("vector converts array",function() assert(F.exVec({1,2,3},nil)==Vector3.new(1,2,3)) end)
	test("color converts RGB",function() assert(F.exColor({255,0,128})==Color3.fromRGB(255,0,128)) end)
	test("class allowlist contains Part",function() assert(MEGA_EXT_CLASSES.Part==true) end)
	test("class allowlist excludes arbitrary Script",function() assert(MEGA_EXT_CLASSES.Script~=true) end)
	test("action registry populated",function() assert(next(MEGA_EXT_ACTION_HANDLERS)~=nil) end)
	test("every handler callable",function() for name,handler in pairs(MEGA_EXT_ACTION_HANDLERS) do assert(type(name)=="string" and type(handler)=="function") end end)
	test("limit nodes <=200",function() assert(MEGA_EXT_LIMITS.nodes==200) end)
	test("limit selection <=2000",function() assert(MEGA_EXT_LIMITS.selection==2000) end)
	test("server-sensitive economy has config label",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_CURRENCY_CONFIG~=nil) end)
	test("UI panel action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_UI_PANEL~=nil) end)
	test("VFX beam action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_BEAM~=nil) end)
	test("physics group action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.SET_COLLISION_GROUP~=nil) end)
	test("inspection action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.INSPECT_HIERARCHY~=nil) end)
	test("asset manifest action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_ASSET_MANIFEST~=nil) end)
	test("portal action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_PORTAL_PAIR~=nil) end)
	test("collection action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_COLLECTIBLES~=nil) end)
	test("catalog action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_SHOP_CATALOG~=nil) end)
	test("quest action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_QUEST_CATALOG~=nil) end)
	test("streaming action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.SET_STREAMING_SETTINGS~=nil) end)
	test("surface appearance action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_SURFACE_APPEARANCE~=nil) end)
	test("soundscape action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_SOUNDSCAPE~=nil) end)
	test("checkpoint action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_CHECKPOINT_MARKERS~=nil) end)
	test("model bounds action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.INSPECT_MODEL_BOUNDS~=nil) end)
	test("data schema action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.CREATE_DATA_SCHEMA~=nil) end)
	test("duplicate selection action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.DUPLICATE_SELECTION~=nil) end)
	test("batch property action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.BATCH_SET_PROPERTIES~=nil) end)
	test("script audit action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.AUDIT_SCRIPTS_EXTENDED~=nil) end)
	test("GUI audit action exists",function() assert(MEGA_EXT_ACTION_HANDLERS.AUDIT_GUI_RESPONSIVE~=nil) end)
	F.showJSON({version=VERSION,passed=passed,failed=failed,total=passed+failed,results=results})
	if failed>0 then error("Extended self-tests failed: "..failed) end
	return "Extended tests: "..passed.." passed, 0 failed"
end

-- ACTION CONTRACT REFERENCE FOR MEGA DIRECTOR AND SPECIALISTS
-- Action type names are case-sensitive. JSON keys below are contract keys.
-- Every path resolves inside the current Studio DataModel, never an arbitrary OS path.
-- Do not use placeholder asset IDs. Only user-authorized and verified IDs are valid.
-- Do not claim a created scaffold is a complete working gameplay system.
-- All rewards, purchases, damage, inventory, progression and teleports require server authority.
-- All UI interactions need client event wiring; visual objects alone are not interactive.
-- All generated scripts remain reviewable source and require Studio Play Test.
-- Large actions should be split into ordered BATCH_ACTIONS with parent dependencies first.
-- Do not delete or replace unrelated project content unless the user explicitly requests it.
-- Inspect before editing; preserve existing names, paths, scripts and behavior.
-- Prefer incremental changes and explicit targets over broad workspace reconstruction.
-- If a path is ambiguous, request INSPECT_PROJECT or INSPECT_HIERARCHY before mutation.
-- If a feature depends on external assets, request an asset manifest and report permission limits.
-- For models, establish a pivot and primary part when the asset requires movement.
-- For physical assemblies, set Anchored and collision groups deliberately.
-- For GUI, prefer scale-based sizing, layouts, padding and constraints over arbitrary offsets.
-- For VFX, cap particle rates and lifetimes to avoid uncontrolled client performance costs.
-- For sound, organize Music, Ambience and SFX and never fabricate asset IDs.
-- For multiplayer systems, separate ReplicatedStorage contracts from server authority.
-- For debugging, return exact action type, path, property and failing index in errors.
-- The plugin's self-test suite verifies contracts and helper logic, not a live multiplayer game.


-- Machine-readable action contracts. These are consumed by MEGA specialists before emitting actions.
local MEGA_EXT_ACTION_CONTRACTS = {
	["CREATE_SPAWN_SET"] = {
		domain = "create",
		required = {"points"},
		optional = {"parent", "name"},
		behavior = "Workspace; 1..100 SpawnLocation objects; server assigns team spawn policy",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_HIGHLIGHT"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "fillColor", "outlineColor", "fillTransparency", "outlineTransparency", "depthMode", "parent"},
		behavior = "Highlight visual only; does not change gameplay state",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_CLICK_DETECTOR"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "maxDistance", "cursorIcon"},
		behavior = "BasePart target; connect MouseClick in server Script",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_BILLBOARD_GUI"] = {
		domain = "create",
		required = {"target", "text"},
		optional = {"name", "width", "height", "offset", "maxDistance", "textColor", "backgroundColor", "parent"},
		behavior = "Target BasePart, Model or Attachment; UI interaction requires client logic",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SURFACE_GUI"] = {
		domain = "create",
		required = {"target", "text"},
		optional = {"name", "face", "pixelsPerStud", "backgroundColor", "textColor"},
		behavior = "BasePart target; one surface face",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_WELD"] = {
		domain = "create",
		required = {"part0", "part1"},
		optional = {"name", "parent"},
		behavior = "Two distinct BaseParts; constraint only",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_BEAM"] = {
		domain = "create",
		required = {"part0", "part1"},
		optional = {"name", "attachment0", "attachment1", "offset0", "offset1", "width0", "width1", "color0", "color1"},
		behavior = "Creates attachments when missing; keep endpoints valid",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_TRAIL"] = {
		domain = "create",
		required = {"part0"},
		optional = {"name", "attachment0", "attachment1", "offset0", "offset1", "lifetime", "minLength", "color0", "color1"},
		behavior = "Trail needs two attachments; particle cost depends on lifetime",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PARTICLE_EMITTER"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "rate", "lifeMin", "lifeMax", "speedMin", "speedMax", "size", "color0", "color1"},
		behavior = "BasePart or Attachment; rate max 500",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PATH_NODES"] = {
		domain = "create",
		required = {"nodes"},
		optional = {"name", "parent", "purpose"},
		behavior = "2..200 ordered positions; markers only, not NPC pathfinding",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ZONE"] = {
		domain = "create",
		required = {"size", "position"},
		optional = {"name", "parent", "purpose", "tags", "transparency", "color"},
		behavior = "Noncollidable touch volume; server must handle events",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SOUND_GROUP"] = {
		domain = "create",
		required = {"name"},
		optional = {"parent", "volume"},
		behavior = "SoundService group; assign Sound.SoundGroup separately",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SOUNDSCAPE"] = {
		domain = "create",
		required = {"sounds"},
		optional = {"name", "parent"},
		behavior = "Sound entries use verified IDs; creates Music/Ambience/SFX folders",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ANIMATION_SET"] = {
		domain = "create",
		required = {"animations"},
		optional = {"name", "parent"},
		behavior = "Animation instances only; rig compatibility and permissions need testing",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_REMOTE_BUNDLE"] = {
		domain = "create",
		required = {"remotes"},
		optional = {"name", "parent"},
		behavior = "1..100 RemoteEvent/RemoteFunction/Bindable objects",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_VALUE_BUNDLE"] = {
		domain = "create",
		required = {"values"},
		optional = {"name", "parent"},
		behavior = "1..200 typed Value objects; never authoritative for client economy",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ATTRIBUTE_SET"] = {
		domain = "create",
		required = {"target", "attributes"},
		optional = {},
		behavior = "Up to 100 supported attributes; no arbitrary Instance references",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["BATCH_SET_PROPERTIES"] = {
		domain = "batch",
		required = {"targets", "properties"},
		optional = {},
		behavior = "Resolve every target first; individual property failures are reported",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["PIVOT_MODEL"] = {
		domain = "pivot",
		required = {"target"},
		optional = {"position", "rotation"},
		behavior = "Model target; applies PivotTo",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_MODEL_PRIMARY_PART"] = {
		domain = "set",
		required = {"target", "primaryPart"},
		optional = {},
		behavior = "primaryPart must be a BasePart descendant of target Model",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_COLLISION_GROUP"] = {
		domain = "set",
		required = {"groupName", "targets"},
		optional = {},
		behavior = "Registers group if needed; applies only to BaseParts",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_COLLISION_RELATIONSHIP"] = {
		domain = "set",
		required = {"group0", "group1"},
		optional = {"collidable"},
		behavior = "Both groups must exist",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_STROKE"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "color", "thickness", "transparency"},
		behavior = "GuiObject target",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_GRADIENT"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "color0", "color1", "rotation"},
		behavior = "GuiObject target",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_PADDING"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "left", "right", "top", "bottom"},
		behavior = "GuiObject target; values may be pixel offsets or UDim tables",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_LAYOUT"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "layoutType", "horizontal", "padding", "cellWidth", "cellHeight"},
		behavior = "List or Grid layout; layout controls child positions",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_CORNER"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "scale", "offset"},
		behavior = "GuiObject target",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_BUTTON"] = {
		domain = "create",
		required = {"parent", "text"},
		optional = {"name", "width", "height", "backgroundColor", "textColor", "textSize"},
		behavior = "Visual TextButton; Activated needs LocalScript",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_CARD"] = {
		domain = "create",
		required = {"parent", "title"},
		optional = {"name", "width", "height", "description", "backgroundColor", "strokeColor"},
		behavior = "Creates title and description labels",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_PROGRESS_BAR"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "width", "height", "value", "trackColor", "fillColor"},
		behavior = "value 0..1; gameplay updates Fill.Size",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_STAT_CARD"] = {
		domain = "create",
		required = {"parent", "label"},
		optional = {"name", "width", "height", "value", "backgroundColor", "valueColor"},
		behavior = "Creates distinct label and value labels",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_INPUT"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "width", "height", "placeholder", "text", "backgroundColor", "textColor"},
		behavior = "TextBox; validate all submitted values",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_IMAGE"] = {
		domain = "create",
		required = {"parent", "image"},
		optional = {"name", "width", "height", "scaleType"},
		behavior = "Image asset ID must be verified and permitted",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_OVERLAY"] = {
		domain = "create",
		required = {"name"},
		optional = {"parent", "displayOrder", "color", "transparency"},
		behavior = "ScreenGui overlay; show/hide animation needs LocalScript",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_SCROLL_LIST"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "scrollBarThickness"},
		behavior = "ScrollingFrame with AutomaticCanvasSize",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_PANEL"] = {
		domain = "create",
		required = {"name"},
		optional = {"parent", "title", "width", "height", "backgroundColor"},
		behavior = "StarterGui ScreenGui with centered content frame",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_SECTION"] = {
		domain = "create",
		required = {"parent", "title"},
		optional = {"name", "height", "backgroundColor"},
		behavior = "Frame with title and content area",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_TABS"] = {
		domain = "create",
		required = {"parent", "tabs"},
		optional = {"name"},
		behavior = "Creates tab buttons; switching content needs LocalScript",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_GRID"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "cellWidth", "cellHeight", "paddingX", "paddingY"},
		behavior = "UIGridLayout; parent child layout becomes controlled",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_SIZE_CONSTRAINT"] = {
		domain = "create",
		required = {"parent"},
		optional = {"minWidth", "minHeight", "maxWidth", "maxHeight"},
		behavior = "GuiObject parent",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_ASPECT_RATIO"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "ratio"},
		behavior = "GuiObject parent",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_SCALE"] = {
		domain = "create",
		required = {"parent"},
		optional = {"name", "scale"},
		behavior = "GuiObject parent; scale 0.1..5",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_UI_VISIBILITY"] = {
		domain = "set",
		required = {"target"},
		optional = {"visible"},
		behavior = "GuiObject target",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_UI_LAYOUT_ORDER"] = {
		domain = "set",
		required = {"target", "order"},
		optional = {},
		behavior = "GuiObject target",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_UI_ZINDEX"] = {
		domain = "set",
		required = {"target", "zIndex"},
		optional = {},
		behavior = "GuiObject target; ZIndex 1..100",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_UI_AUTOMATIC_SIZE"] = {
		domain = "set",
		required = {"target"},
		optional = {"axis"},
		behavior = "GuiObject target; axis X/Y/XY/None",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PART_GRID"] = {
		domain = "create",
		required = {"rows", "columns"},
		optional = {"name", "parent", "origin", "spacing", "partSize", "color", "material", "anchored"},
		behavior = "Maximum 500 parts; grouped in Model",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_STAIRS"] = {
		domain = "create",
		required = {"count"},
		optional = {"name", "parent", "origin", "stepSize", "rise", "run", "color", "material"},
		behavior = "1..200 steps; deterministic ascending placement",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_RING"] = {
		domain = "create",
		required = {"count", "radius"},
		optional = {"name", "parent", "center", "partSize", "color", "material"},
		behavior = "3..200 parts distributed around center",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_WALL"] = {
		domain = "create",
		required = {"count"},
		optional = {"name", "parent", "origin", "direction", "partSize", "gap", "color", "material"},
		behavior = "Direction cannot be zero",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_COLLECTIBLES"] = {
		domain = "create",
		required = {"items"},
		optional = {"name", "parent"},
		behavior = "1..300 visual markers; rewards must be granted on server",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SHOP_CATALOG"] = {
		domain = "create",
		required = {"items"},
		optional = {"name", "parent"},
		behavior = "1..500 product definitions; never processes purchases",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_QUEST_CATALOG"] = {
		domain = "create",
		required = {"quests"},
		optional = {"name", "parent"},
		behavior = "Up to 300 quest definitions; progression needs server controller",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ROUND_CONFIG"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "intermission", "duration", "minimumPlayers", "maximumPlayers"},
		behavior = "maximumPlayers must be >= minimumPlayers",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_CURRENCY_CONFIG"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "currencies"},
		behavior = "Currency definitions only; balances server-owned",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PROGRESSION_CONFIG"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "startingLevel", "startingXP", "xpPerLevel", "multiplier"},
		behavior = "Configuration only; persistence/controller not included",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_CHECKPOINT_MARKERS"] = {
		domain = "create",
		required = {"points"},
		optional = {"name", "parent"},
		behavior = "1..200 markers; save checkpoint state on server",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_MOVING_PLATFORM"] = {
		domain = "create",
		required = {"nodes"},
		optional = {"name", "parent", "size", "position", "duration", "loop"},
		behavior = "2..50 path nodes; requires movement controller",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PORTAL_PAIR"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "size", "positionA", "positionB"},
		behavior = "Visual pair only; server validates safe destination",
		mutation = "create_or_update",
		serverAuthority = true,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_TEAM_SET"] = {
		domain = "create",
		required = {"teams"},
		optional = {},
		behavior = "1..50 Team objects",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_TEAM_SPAWNS"] = {
		domain = "create",
		required = {"teams"},
		optional = {"parent"},
		behavior = "Only creates spawn for existing team names",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SOUND_EMITTER"] = {
		domain = "create",
		required = {"target", "soundId"},
		optional = {"name", "volume", "looped", "playbackSpeed", "minDistance", "maxDistance"},
		behavior = "BasePart or Attachment; asset permissions may block playback",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_DECAL"] = {
		domain = "create",
		required = {"target", "texture"},
		optional = {"name", "face", "transparency"},
		behavior = "BasePart target and verified texture ID",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_TEXTURE"] = {
		domain = "create",
		required = {"target", "texture"},
		optional = {"name", "face", "tileU", "tileV"},
		behavior = "BasePart target and verified texture ID",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_MATERIAL"] = {
		domain = "set",
		required = {"material"},
		optional = {"color"},
		behavior = "Uses current selected BaseParts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_COLOR"] = {
		domain = "set",
		required = {"color"},
		optional = {},
		behavior = "Uses current selected BaseParts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_ANCHORED"] = {
		domain = "set",
		required = {"anchored"},
		optional = {},
		behavior = "Uses current selected BaseParts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_COLLISION"] = {
		domain = "set",
		required = {"canCollide"},
		optional = {"canTouch", "canQuery"},
		behavior = "Uses current selected BaseParts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_TRANSPARENCY"] = {
		domain = "set",
		required = {"transparency"},
		optional = {},
		behavior = "Uses current selected BaseParts; 0..1",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_REFLECTANCE"] = {
		domain = "set",
		required = {"reflectance"},
		optional = {},
		behavior = "Uses current selected BaseParts; 0..1",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_SELECTION_SCALE"] = {
		domain = "set",
		required = {"factor"},
		optional = {},
		behavior = "Scales selected BaseParts around first selected part; 0.01..100",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["OFFSET_SELECTION"] = {
		domain = "offset",
		required = {"offset"},
		optional = {},
		behavior = "Uses current selected BaseParts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["ROTATE_SELECTION"] = {
		domain = "rotate",
		required = {"degrees"},
		optional = {},
		behavior = "Uses current selected BaseParts around first selected part",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["DUPLICATE_SELECTION"] = {
		domain = "duplicate",
		required = {},
		optional = {"offset", "prefix"},
		behavior = "1..200 selected objects; clones only",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["RENAME_INSTANCES"] = {
		domain = "rename",
		required = {"targets"},
		optional = {"prefix", "suffix", "useIndex"},
		behavior = "1..500 resolvable paths",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["FIND_BY_ATTRIBUTE"] = {
		domain = "find",
		required = {"attribute"},
		optional = {"value", "roots", "limit"},
		behavior = "Returns bounded list of matching descendants",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["INSPECT_HIERARCHY"] = {
		domain = "inspect",
		required = {"target"},
		optional = {"limit"},
		behavior = "Bounded hierarchy snapshot; does not read script source",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_PERFORMANCE"] = {
		domain = "report",
		required = {},
		optional = {"root"},
		behavior = "Structural counts only, not FPS or memory telemetry",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["AUDIT_SCRIPTS_EXTENDED"] = {
		domain = "audit",
		required = {},
		optional = {"root"},
		behavior = "Static inventory; not malware verdict",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["AUDIT_GUI_RESPONSIVE"] = {
		domain = "audit",
		required = {},
		optional = {"root"},
		behavior = "Structural heuristics; not screenshot/viewport validation",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PROJECT_MANIFEST"] = {
		domain = "create",
		required = {},
		optional = {},
		behavior = "Counts key services; does not export secrets or script source",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["INSPECT_MODEL_BOUNDS"] = {
		domain = "inspect",
		required = {"target"},
		optional = {},
		behavior = "Model BoundingBox, pivot and PrimaryPart",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["PIVOT_MODEL_TO_TARGET"] = {
		domain = "pivot",
		required = {"target", "reference"},
		optional = {"offset"},
		behavior = "Aligns Model pivot to BasePart CFrame",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_MODEL_FROM_SELECTION"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent"},
		behavior = "Groups current selection; restores original parents if operation fails",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_FOLDER_TREE"] = {
		domain = "create",
		required = {"tree"},
		optional = {"name", "parent", "maxNodes"},
		behavior = "Max depth 12; max nodes 500",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SYSTEM_SCAFFOLD"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "folders"},
		behavior = "Folders only; no scripts or runtime behavior",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SERVER_CLIENT_SCAFFOLD"] = {
		domain = "create",
		required = {},
		optional = {"name", "sharedParent", "serverParent", "clientParent", "remoteParent"},
		behavior = "Creates Shared/Server/Client/Remotes folders",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_DATA_SCHEMA"] = {
		domain = "create",
		required = {"fields"},
		optional = {"name", "parent"},
		behavior = "Up to 200 schema descriptors; runtime validation separate",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_TIMER_CONFIG"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "duration", "warningAt", "autoStart", "loop"},
		behavior = "Configuration only; timer controller separate",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_LEADERBOARD_CONFIG"] = {
		domain = "create",
		required = {"stats"},
		optional = {"name", "parent"},
		behavior = "1..20 typed stat definitions; no DataStore setup",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_NPC_MARKER"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "position", "displayName", "color"},
		behavior = "Marker Humanoid is not a complete rig or NPC AI",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SEAT"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "position", "size", "vehicle", "maxSpeed", "torque", "turnSpeed"},
		behavior = "Creates Seat or VehicleSeat",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_CAMERA"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "position", "lookAt", "fieldOfView"},
		behavior = "Camera instance; LocalScript assigns CurrentCamera",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_WORLD_MODEL"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent"},
		behavior = "WorldModel container; usually useful in ViewportFrame",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SURFACE_APPEARANCE"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "colorMap", "metalnessMap", "normalMap", "roughnessMap"},
		behavior = "MeshPart target; texture permissions must be checked",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ASSET_MANIFEST"] = {
		domain = "create",
		required = {"assets"},
		optional = {"name", "parent"},
		behavior = "Metadata only; does not download or grant asset access",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["SET_STREAMING_SETTINGS"] = {
		domain = "set",
		required = {},
		optional = {"enabled", "minRadius"},
		behavior = "Workspace streaming settings; verify Studio writable properties",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_SELECTION_BOUNDS"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "padding", "transparency", "color"},
		behavior = "Creates helper part around selected models/parts",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["ADD_TAG_TO_SELECTION"] = {
		domain = "add",
		required = {"tag"},
		optional = {},
		behavior = "Adds CollectionService tag to current selection",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["ADD_ATTRIBUTE_TO_SELECTION"] = {
		domain = "add",
		required = {"name", "value"},
		optional = {},
		behavior = "Adds supported attribute to current selection",
		mutation = "selection",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_STAT_HUD"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "resetOnSpawn"},
		behavior = "ScreenGui root; bind stat values with LocalScript",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_TOAST"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent", "message", "width", "height"},
		behavior = "Visual toast only; timed dismissal requires LocalScript",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_UI_CONFIRM_DIALOG"] = {
		domain = "create",
		required = {},
		optional = {"name", "parent"},
		behavior = "Handler validates additional fields; inspect exact action handler before use",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_POST_EFFECT"] = {
		domain = "create",
		required = {"className"},
		optional = {"name", "intensity", "size", "threshold", "brightness", "contrast", "saturation", "tintColor"},
		behavior = "Lighting post effect; supported classes only",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_ATMOSPHERE"] = {
		domain = "create",
		required = {},
		optional = {"name", "density", "offset", "haze", "glare", "color", "decay"},
		behavior = "Creates or updates Lighting Atmosphere",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PART_SET"] = {
		domain = "create",
		required = {"parts"},
		optional = {"name", "parent"},
		behavior = "1..500 Part/WedgePart/CornerWedgePart/TrussPart items",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_FOLDER_BATCH"] = {
		domain = "create",
		required = {"names"},
		optional = {"name", "parent"},
		behavior = "Up to 100 unique folder names",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["CREATE_PART_FROM_BOUNDS"] = {
		domain = "create",
		required = {"target"},
		optional = {"name", "parent", "padding", "color", "transparency"},
		behavior = "Creates noncollidable bounds helper around Model",
		mutation = "create_or_update",
		serverAuthority = false,
		needsPlayTest = true,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["INSPECT_SELECTION_REPORT"] = {
		domain = "inspect",
		required = {},
		optional = {},
		behavior = "Reports current selection paths, classes, attributes and part transforms",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_WORLD_BOUNDS"] = {
		domain = "report",
		required = {},
		optional = {"root"},
		behavior = "Approximate axis-aligned bounds for BaseParts",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_COLLECTION_TAGS"] = {
		domain = "report",
		required = {},
		optional = {},
		behavior = "Lists CollectionService tags and counts",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_LIGHTING"] = {
		domain = "report",
		required = {},
		optional = {},
		behavior = "Lighting properties and child effects",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_SOUNDS"] = {
		domain = "report",
		required = {},
		optional = {"root"},
		behavior = "Sound IDs and basic properties; no playback test",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["REPORT_TERRAIN"] = {
		domain = "report",
		required = {},
		optional = {},
		behavior = "Terrain water and decoration properties",
		mutation = "inspect",
		serverAuthority = false,
		needsPlayTest = false,
		limits = "Use the plugin global limits and the handler-specific numeric bounds.",
	},
	["LIST_EXTENDED_CAPABILITIES"] = { domain="meta", required={}, optional={}, behavior="Lists executable extended actions and limits", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["LIST_EXTENDED_CONTRACTS"] = { domain="meta", required={}, optional={}, behavior="Returns machine-readable action schemas and required fields", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["LIST_EXTENDED_PLAYBOOKS"] = { domain="meta", required={}, optional={}, behavior="Returns specialist responsibilities and safety boundaries", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["LIST_EXTENDED_RECIPES"] = { domain="meta", required={}, optional={}, behavior="Returns ordered build/edit/repair planning recipes", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["REPORT_EXTENDED_CONTRACT_SUMMARY"] = { domain="meta", required={}, optional={}, behavior="Returns compact mutation and server-authority summary", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["RUN_EXTENDED_SELF_TESTS"] = { domain="qa", required={}, optional={}, behavior="Executes local pure helper and registry assertions", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
	["REPORT_EXTENDED_REGRESSION_MATRIX"] = { domain="qa", required={}, optional={}, behavior="Lists scenarios; does not mark unexecuted tests as passed", mutation="inspect", serverAuthority=false, needsPlayTest=false, limits="No project mutation" },
}

validateExtendedActionContract = function(action)
	if type(action) ~= "table" or type(action.type) ~= "string" then error("Extended action must be an object with string type") end
	local contract = MEGA_EXT_ACTION_CONTRACTS[action.type]
	if not contract then error("No schema contract for extended action: " .. tostring(action.type)) end
	for _, key in ipairs(contract.required) do
		if action[key] == nil then error("Missing required field: " .. tostring(key) .. " for " .. action.type) end
	end
	return contract
end

function F.listExtendedActionContracts()
	local result = {}
	for name, contract in pairs(MEGA_EXT_ACTION_CONTRACTS) do
		result[name] = contract
	end
	F.showJSON({version=VERSION, count=(function() local n=0 for _ in pairs(result) do n+=1 end return n end)(), contracts=result})
	return "Extended action contracts listed"
end

-- Specialist playbooks are part of the machine-readable generation contract.
local MEGA_EXT_SPECIALIST_PLAYBOOKS = {
	DIRECTOR = {
		"Interpret the user goal before choosing operations.",
		"Inspect current project context before changing existing content.",
		"Break complex requests into ordered build, script, UI, VFX and QA tasks.",
		"Assign stable names and paths before creating dependent objects.",
		"Prefer the smallest change that fully satisfies the request.",
		"Never add unrelated shops, pets, rebirths, maps or monetization systems.",
		"For new games, coordinate specialists and define a coherent playable loop.",
		"For edits, preserve existing hierarchy, scripts, UI and working behavior.",
		"For repairs, target the exact failing object and avoid rebuilding the project.",
		"Ask for inspection when paths, ownership or current architecture are ambiguous.",
		"Keep action batches small and order parent creation before child creation.",
		"Use explicit dependencies between folders, remotes, scripts and UI.",
		"Require server authority for rewards, purchases, damage, inventory and teleports.",
		"Require client scripts for input, HUD animation, camera and local feedback.",
		"Distinguish generated structure from implemented runtime behavior.",
		"Request QA reports after mutations and do not claim tests that were not run.",
		"If a requested capability is absent, report the missing action instead of guessing.",
		"Never invent Toolbox IDs, SoundIds, AnimationIds or texture IDs.",
		"Use existing project colors and conventions when the user has established them.",
		"Prefer professional placement based on pivots, bounds, surfaces and map context.",
	},
	BUILD = {
		"Inspect Workspace, target model bounds and existing construction before placement.",
		"Use Model containers for coherent assemblies and assign PrimaryPart when useful.",
		"Plan dimensions, pivots, CFrames, ground clearance and collision before creation.",
		"Place structures relative to a known anchor instead of arbitrary world coordinates.",
		"Choose materials and colors intentionally; avoid default gray for finished assets.",
		"Use a consistent palette across connected parts and UI elements.",
		"Anchor static scenery and keep moving assemblies intentionally unanchored.",
		"Use WeldConstraint or Motor6D only when the assembly needs a physical connection.",
		"Use grid alignment and distribution to improve repeatable placement.",
		"Check bounding boxes for overlap and out-of-map placement.",
		"Prefer meshes or authorized Toolbox assets for detailed organic geometry.",
		"Use placeholders only when an asset is unavailable and label them clearly.",
		"Keep part counts bounded and use unions/meshes or streaming where appropriate.",
		"Never replace a complete map when the request changes one building.",
		"Create safe spawn surfaces and ensure player destinations are grounded.",
		"Group related decorative pieces into named Models.",
		"Keep collision, touch and query flags appropriate for each object.",
		"Use terrain tools for large landscapes instead of thousands of tiny parts.",
		"Inspect the final hierarchy and report created model paths.",
		"Run visual inspection in Studio; structural checks cannot guarantee appearance.",
	},
	SCRIPTING = {
		"Place server authority in ServerScriptService and shared modules in ReplicatedStorage.",
		"Place LocalScripts only in valid client containers such as StarterPlayerScripts or PlayerGui.",
		"Use ModuleScripts for reusable logic and keep dependencies explicit.",
		"Validate all RemoteEvent and RemoteFunction inputs on the server.",
		"Rate-limit remote requests and reject malformed or oversized payloads.",
		"Never trust client-supplied currency, damage, ownership or progression values.",
		"Use server-side proximity and state validation before granting rewards.",
		"Use event-driven logic instead of per-frame polling for simple triggers.",
		"Use task.wait only when timing is actually required; avoid unbounded loops.",
		"Connect and disconnect event handlers deliberately.",
		"Handle missing characters, Humanoids and PrimaryParts safely.",
		"Use pcall around external or failure-prone operations with useful errors.",
		"Keep scripts focused and name functions and variables descriptively.",
		"Never put API keys, passwords or private tokens into game scripts.",
		"Use DataStoreService only from server scripts and handle throttling/retries.",
		"Use UpdateAsync where concurrent data writes need safe merging.",
		"Add idempotency or duplicate-event protection for rewards and purchases.",
		"Do not claim persistence until a real server test verifies it.",
		"Keep scripts disabled for review when creating blank templates.",
		"Inspect script placement and static warnings after creation.",
	},
	UI = {
		"Use ScreenGui under StarterGui and runtime clones under PlayerGui.",
		"Use scale-based sizes and positions for responsive layouts.",
		"Use UIListLayout or UIGridLayout when child ordering should be automatic.",
		"Use UIPadding, UICorner, UIStroke and UIGradient for coherent styling.",
		"Keep text readable and avoid tiny font sizes.",
		"Use TextScaled selectively; constraints may be needed for stable text.",
		"Use AnchorPoint to align elements around intentional visual anchors.",
		"Use ZIndex consistently and avoid accidental overlap.",
		"Use AutomaticCanvasSize for scrolling content.",
		"Use UIAspectRatioConstraint for icons and cards that must retain shape.",
		"Create separate labels for stat names and values so updates do not overwrite context.",
		"Use clear feedback for rewards, errors, loading and disabled states.",
		"Use TweenService in LocalScripts for animation and feedback.",
		"Connect Activated/MouseButton events in LocalScripts, not by visual creation alone.",
		"Keep sensitive purchase and inventory decisions on the server.",
		"Check GUI parent paths and ResetOnSpawn behavior.",
		"Use mobile-friendly hit targets and safe screen margins.",
		"Use layouts instead of manually positioning every repeated item.",
		"Run structural responsive audits and inspect multiple viewport sizes.",
		"Never claim pixel-perfect layout from structural inspection alone.",
	},
	VFX = {
		"Use attachments as stable endpoints for Beam and Trail effects.",
		"Keep particle rate, lifetime, speed and spread within deliberate budgets.",
		"Use NumberSequence and ColorSequence for controlled visual transitions.",
		"Use Highlights for selection or state feedback, not as a substitute for geometry.",
		"Use Lighting post effects sparingly and check stacking with existing effects.",
		"Use Atmosphere and Sky settings consistently with the environment.",
		"Use sound groups to organize Music, Ambience and SFX.",
		"Never fabricate sound or texture asset IDs.",
		"Check asset permissions and moderation state before claiming an asset works.",
		"Prefer event-triggered bursts over continuously high-rate emitters.",
		"Keep VFX local when only the triggering player needs to see them.",
		"Use server replication only when all players need the effect.",
		"Inspect effect parent and attachment ownership.",
		"Keep loops and persistent emitters disabled when they are not needed.",
		"Profile high-rate effects on lower-end devices.",
	},
	GAMEPLAY = {
		"Define player objective, inputs, feedback, reward and failure states.",
		"Use server-side event handlers for authoritative gameplay state.",
		"Validate touch distance and player identity before rewarding.",
		"Prevent repeated trigger spam with cooldowns or per-player state.",
		"Keep round timers and progression values in one clear configuration source.",
		"Use explicit state machines for rounds, shops, quests and checkpoints.",
		"Use unique IDs for collectibles, quests and checkpoint progression.",
		"Use server-side purchase validation and never subtract client-reported balances.",
		"Keep leaderstats as display values, not the authoritative persistence database.",
		"Use CollectionService tags for discoverable categories when appropriate.",
		"Ensure teleport destinations are safe, grounded and inside allowed map bounds.",
		"Ensure checkpoints are ordered and progress cannot be spoofed by clients.",
		"Ensure rewards are idempotent so duplicate events do not double grant.",
		"Provide UI feedback without making the UI the authority.",
		"Test single-player and multiplayer replication separately.",
	},
	QA = {
		"Run structural validation after every multi-action build.",
		"Inspect exact paths for objects created by the current operation.",
		"Check missing references, invalid parents and unsupported classes.",
		"Check BasePart sizes, anchoring, collision and transparency bounds.",
		"Check Model PrimaryPart and bounding boxes when movement is expected.",
		"Check GUI hierarchy, text sizes, layouts and visibility properties.",
		"Check scripts are in valid server/client containers.",
		"Check remotes have corresponding server-side validation.",
		"Check rewards, purchases, damage and teleports cannot be client-authoritative.",
		"Check sound and animation IDs are present and verified by the user.",
		"Check VFX rates and lifetimes for performance risks.",
		"Check that unrelated project objects were not deleted or renamed.",
		"Check that the plugin reports applied, failed or rejected outcomes accurately.",
		"Distinguish static audit from live runtime test.",
		"Run Play Test for gameplay, then multi-client test for replication.",
		"Record exact failure, action type, object path and reproduction steps.",
		"Never report a pass when the test was skipped or blocked.",
		"Keep a backup before destructive or large-scale operations.",
		"Use undo waypoints around logical action batches.",
		"Report limitations honestly and suggest the next targeted test.",
	},
}

-- Additional QA case inventory. These are scenarios, not claimed execution results.
local MEGA_EXT_QA_CASES = {
	{ id="MEGA-QA-001", area="geometry", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-002", area="geometry", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-003", area="geometry", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-004", area="geometry", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-005", area="geometry", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-006", area="geometry", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-007", area="geometry", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-008", area="geometry", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-009", area="geometry", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-010", area="geometry", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-011", area="geometry", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-012", area="geometry", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-013", area="geometry", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-014", area="geometry", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-015", area="geometry", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-016", area="geometry", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-017", area="geometry", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-018", area="geometry", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-019", area="geometry", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-020", area="geometry", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-021", area="placement", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-022", area="placement", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-023", area="placement", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-024", area="placement", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-025", area="placement", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-026", area="placement", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-027", area="placement", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-028", area="placement", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-029", area="placement", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-030", area="placement", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-031", area="placement", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-032", area="placement", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-033", area="placement", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-034", area="placement", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-035", area="placement", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-036", area="placement", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-037", area="placement", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-038", area="placement", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-039", area="placement", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-040", area="placement", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-041", area="hierarchy", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-042", area="hierarchy", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-043", area="hierarchy", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-044", area="hierarchy", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-045", area="hierarchy", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-046", area="hierarchy", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-047", area="hierarchy", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-048", area="hierarchy", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-049", area="hierarchy", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-050", area="hierarchy", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-051", area="hierarchy", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-052", area="hierarchy", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-053", area="hierarchy", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-054", area="hierarchy", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-055", area="hierarchy", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-056", area="hierarchy", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-057", area="hierarchy", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-058", area="hierarchy", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-059", area="hierarchy", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-060", area="hierarchy", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-061", area="physics", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-062", area="physics", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-063", area="physics", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-064", area="physics", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-065", area="physics", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-066", area="physics", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-067", area="physics", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-068", area="physics", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-069", area="physics", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-070", area="physics", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-071", area="physics", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-072", area="physics", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-073", area="physics", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-074", area="physics", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-075", area="physics", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-076", area="physics", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-077", area="physics", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-078", area="physics", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-079", area="physics", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-080", area="physics", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-081", area="ui", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-082", area="ui", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-083", area="ui", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-084", area="ui", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-085", area="ui", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-086", area="ui", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-087", area="ui", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-088", area="ui", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-089", area="ui", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-090", area="ui", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-091", area="ui", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-092", area="ui", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-093", area="ui", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-094", area="ui", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-095", area="ui", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-096", area="ui", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-097", area="ui", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-098", area="ui", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-099", area="ui", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-100", area="ui", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-101", area="vfx", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-102", area="vfx", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-103", area="vfx", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-104", area="vfx", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-105", area="vfx", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-106", area="vfx", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-107", area="vfx", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-108", area="vfx", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-109", area="vfx", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-110", area="vfx", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-111", area="vfx", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-112", area="vfx", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-113", area="vfx", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-114", area="vfx", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-115", area="vfx", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-116", area="vfx", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-117", area="vfx", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-118", area="vfx", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-119", area="vfx", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-120", area="vfx", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-121", area="audio", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-122", area="audio", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-123", area="audio", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-124", area="audio", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-125", area="audio", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-126", area="audio", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-127", area="audio", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-128", area="audio", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-129", area="audio", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-130", area="audio", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-131", area="audio", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-132", area="audio", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-133", area="audio", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-134", area="audio", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-135", area="audio", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-136", area="audio", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-137", area="audio", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-138", area="audio", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-139", area="audio", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-140", area="audio", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-141", area="assets", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-142", area="assets", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-143", area="assets", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-144", area="assets", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-145", area="assets", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-146", area="assets", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-147", area="assets", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-148", area="assets", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-149", area="assets", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-150", area="assets", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-151", area="assets", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-152", area="assets", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-153", area="assets", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-154", area="assets", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-155", area="assets", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-156", area="assets", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-157", area="assets", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-158", area="assets", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-159", area="assets", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-160", area="assets", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-161", area="remotes", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-162", area="remotes", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-163", area="remotes", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-164", area="remotes", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-165", area="remotes", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-166", area="remotes", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-167", area="remotes", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-168", area="remotes", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-169", area="remotes", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-170", area="remotes", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-171", area="remotes", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-172", area="remotes", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-173", area="remotes", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-174", area="remotes", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-175", area="remotes", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-176", area="remotes", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-177", area="remotes", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-178", area="remotes", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-179", area="remotes", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-180", area="remotes", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-181", area="attributes", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-182", area="attributes", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-183", area="attributes", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-184", area="attributes", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-185", area="attributes", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-186", area="attributes", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-187", area="attributes", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-188", area="attributes", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-189", area="attributes", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-190", area="attributes", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-191", area="attributes", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-192", area="attributes", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-193", area="attributes", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-194", area="attributes", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-195", area="attributes", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-196", area="attributes", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-197", area="attributes", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-198", area="attributes", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-199", area="attributes", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-200", area="attributes", scenario="verify created object class after mutation", expected="documented_behavior" },
	{ id="MEGA-QA-201", area="selection", scenario="reject malformed required field", expected="documented_behavior" },
	{ id="MEGA-QA-202", area="selection", scenario="reject invalid enum name", expected="documented_behavior" },
	{ id="MEGA-QA-203", area="selection", scenario="reject non-finite numeric input", expected="documented_behavior" },
	{ id="MEGA-QA-204", area="selection", scenario="enforce documented upper bound", expected="documented_behavior" },
	{ id="MEGA-QA-205", area="selection", scenario="enforce documented lower bound", expected="documented_behavior" },
	{ id="MEGA-QA-206", area="selection", scenario="preserve unrelated siblings", expected="documented_behavior" },
	{ id="MEGA-QA-207", area="selection", scenario="return precise target path", expected="documented_behavior" },
	{ id="MEGA-QA-208", area="selection", scenario="avoid partial instances after failure", expected="documented_behavior" },
	{ id="MEGA-QA-209", area="selection", scenario="keep operation within selection limit", expected="documented_behavior" },
	{ id="MEGA-QA-210", area="selection", scenario="use a stable parent path", expected="documented_behavior" },
	{ id="MEGA-QA-211", area="selection", scenario="report unavailable asset permission", expected="documented_behavior" },
	{ id="MEGA-QA-212", area="selection", scenario="avoid claiming runtime behavior", expected="documented_behavior" },
	{ id="MEGA-QA-213", area="selection", scenario="require server authority for rewards", expected="documented_behavior" },
	{ id="MEGA-QA-214", area="selection", scenario="preserve existing script source", expected="documented_behavior" },
	{ id="MEGA-QA-215", area="selection", scenario="avoid deleting unrelated objects", expected="documented_behavior" },
	{ id="MEGA-QA-216", area="selection", scenario="use a deterministic instance name", expected="documented_behavior" },
	{ id="MEGA-QA-217", area="selection", scenario="return actionable error context", expected="documented_behavior" },
	{ id="MEGA-QA-218", area="selection", scenario="validate parent class before mutation", expected="documented_behavior" },
	{ id="MEGA-QA-219", area="selection", scenario="use an undo waypoint around mutation", expected="documented_behavior" },
	{ id="MEGA-QA-220", area="selection", scenario="verify created object class after mutation", expected="documented_behavior" },
}

-- Planner recipes describe dependency order; the Director still chooses only requested features.
local MEGA_EXT_PLANNER_RECIPES = {
	NEW_GAME = {
		"INSPECT_PROJECT before any creation.",
		"Create a named root Model or folders only when useful.",
		"Build a playable map layout with stable anchors and safe spawns.",
		"Create server/shared/client folder architecture.",
		"Create required remotes and configuration values.",
		"Generate server scripts for authoritative state and validation.",
		"Generate client scripts for input, HUD and visual feedback.",
		"Create responsive UI and connect its runtime data bindings.",
		"Add VFX/audio with verified assets and bounded rates.",
		"Run structural QA and report the exact paths and remaining Play Test needs.",
	},
	INCREMENTAL_EDIT = {
		"Inspect the named target and its parent hierarchy.",
		"Identify the smallest object/property/script that satisfies the request.",
		"Preserve all unrelated siblings and existing object names.",
		"Apply only requested property or child changes.",
		"Keep existing script behavior unless the request changes it.",
		"Inspect the modified target after mutation.",
		"Report any behavior that still needs Play Test.",
	},
	REPAIR = {
		"Inspect the exact failing path and capture current properties.",
		"Read the relevant script only when the repair requires code context.",
		"Identify root cause before editing.",
		"Create a backup or use a Studio undo waypoint.",
		"Patch the smallest responsible section.",
		"Run static checks and inspect output.",
		"Reproduce the failure in Play Test before marking fixed.",
	},
	REWARD_SYSTEM = {
		"Create authoritative server currency state.",
		"Create server-side trigger detection for the requested action.",
		"Add cooldown or event de-duplication where necessary.",
		"Validate player and character state before awarding.",
		"Update server-owned balance and replicate display values.",
		"Create HUD labels and positive feedback animation.",
		"Keep purchase/shop features out unless requested.",
		"Test repeated triggers and multiplayer behavior.",
	},
	SHOP_SYSTEM = {
		"Inspect existing currency and inventory systems first.",
		"Create catalog definitions without trusting client prices.",
		"Build responsive item cards and purchase feedback.",
		"Create RemoteEvent contract for purchase requests.",
		"Validate item ID, price, balance and ownership on server.",
		"Apply transaction exactly once and return server result.",
		"Add rate limiting and audit logging.",
		"Test insufficient funds, duplicate request and invalid item cases.",
	},
	CHECKPOINT_SYSTEM = {
		"Inspect existing spawn and progression structures.",
		"Create ordered checkpoint markers with stable IDs.",
		"Create server-owned checkpoint state per player.",
		"Validate touched character belongs to a player.",
		"Prevent checkpoint index regression unless explicitly allowed.",
		"Update respawn destination only after server validation.",
		"Create HUD feedback for checkpoint activation.",
		"Test reset, respawn and multiplayer cases.",
	},
	VFX_SYSTEM = {
		"Inspect target part/model and attachment layout.",
		"Create attachment endpoints with stable names.",
		"Create particle, beam, trail or highlight instances.",
		"Apply bounded rates, lifetimes and widths.",
		"Use verified texture IDs only when requested.",
		"Connect activation to the correct client/server event.",
		"Check performance on lower-end device settings.",
	},
	UI_SYSTEM = {
		"Inspect existing ScreenGui and parent paths.",
		"Create ScreenGui under StarterGui when needed.",
		"Use a root frame with responsive scale and anchors.",
		"Add layouts, padding, size constraints and consistent styling.",
		"Create stat labels, buttons, progress bars and cards as requested.",
		"Connect button events in LocalScripts.",
		"Bind values from replicated state without client authority.",
		"Run responsive audit and inspect multiple viewports.",
	},
}

function F.getExtendedSpecialistPlaybook()
	F.showJSON(MEGA_EXT_SPECIALIST_PLAYBOOKS)
	return "Specialist playbooks listed"
end

function F.getExtendedPlannerRecipes()
	F.showJSON(MEGA_EXT_PLANNER_RECIPES)
	return "Planner recipes listed"
end

function F.getExtendedContractSummary()
	local summary = {}
	for name, contract in pairs(MEGA_EXT_ACTION_CONTRACTS) do
		table.insert(summary, {type=name, domain=contract.domain, required=contract.required, mutation=contract.mutation, serverAuthority=contract.serverAuthority, needsPlayTest=contract.needsPlayTest})
	end
	table.sort(summary, function(a,b) return a.type < b.type end)
	F.showJSON({count=#summary, contracts=summary})
	return "Extended contract summary ready: " .. #summary
end

-- Regression scenarios are data-driven so future plugin changes can add coverage without
-- disguising an unexecuted test as a pass. The runtime suite above executes only assertions
-- that can be proven from the local module and Studio API surface.
local MEGA_EXT_REGRESSION_MATRIX = {
	{ id="EX001", area="numeric", purpose="reject NaN values", expected="reject" },
	{ id="EX002", area="numeric", purpose="reject positive infinity", expected="reject" },
	{ id="EX003", area="numeric", purpose="reject negative infinity", expected="reject" },
	{ id="EX004", area="numeric", purpose="accept lower inclusive bound", expected="accept" },
	{ id="EX005", area="numeric", purpose="accept upper inclusive bound", expected="accept" },
	{ id="EX006", area="numeric", purpose="reject below minimum", expected="reject" },
	{ id="EX007", area="numeric", purpose="reject above maximum", expected="reject" },
	{ id="EX008", area="numeric", purpose="reject numeric strings without conversion", expected="reject" },
	{ id="EX009", area="strings", purpose="reject empty instance name", expected="reject" },
	{ id="EX010", area="strings", purpose="reject oversized UI text", expected="reject" },
	{ id="EX011", area="strings", purpose="preserve valid Unicode text", expected="accept" },
	{ id="EX012", area="vectors", purpose="convert Vector3 array", expected="accept" },
	{ id="EX013", area="vectors", purpose="reject missing vector coordinates", expected="reject" },
	{ id="EX014", area="vectors", purpose="reject infinite vector coordinate", expected="reject" },
	{ id="EX015", area="colors", purpose="convert RGB integer triple", expected="accept" },
	{ id="EX016", area="colors", purpose="reject RGB component above 255", expected="reject" },
	{ id="EX017", area="assets", purpose="accept empty optional asset id", expected="accept" },
	{ id="EX018", area="assets", purpose="accept verified rbxassetid URI format", expected="accept" },
	{ id="EX019", area="assets", purpose="reject arbitrary web URL as asset id", expected="reject" },
	{ id="EX020", area="assets", purpose="reject fabricated nonnumeric asset suffix", expected="reject" },
	{ id="paths", purpose="reject missing target path", expected="reject" },
	{ id="paths", purpose="reject target with wrong class", expected="reject" },
	{ id="paths", purpose="resolve service-root path", expected="accept" },
	{ id="paths", purpose="resolve nested child path", expected="accept" },
	{ id="parts", purpose="reject zero-sized part", expected="reject" },
	{ id="parts", purpose="reject negative-sized part", expected="reject" },
	{ id="parts", purpose="accept positive part dimensions", expected="accept" },
	{ id="parts", purpose="respect material enum", expected="accept" },
	{ id="parts", purpose="use safe material fallback for unknown optional material", expected="fallback" },
	{ id="spawns", purpose="reject empty spawn list", expected="reject" },
	{ id="spawns", purpose="reject more than 100 spawn points", expected="reject" },
	{ id="spawns", purpose="create neutral spawn", expected="accept" },
	{ id="spawns", purpose="create team spawn with team color", expected="accept" },
	{ id="spawns", purpose="reject invalid spawn duration", expected="reject" },
	{ id="paths", purpose="reject path with fewer than two nodes", expected="reject" },
	{ id="paths", purpose="reject path over node limit", expected="reject" },
	{ id="paths", purpose="number nodes in deterministic order", expected="accept" },
	{ id="zones", purpose="create noncollidable touch zone", expected="accept" },
	{ id="zones", purpose="preserve explicit zone purpose attribute", expected="accept" },
	{ id="zones", purpose="reject nonpositive zone dimensions", expected="reject" },
	{ id="welds", purpose="reject same part on both sides", expected="reject" },
	{ id="welds", purpose="reject non-BasePart endpoint", expected="reject" },
	{ id="welds", purpose="connect two distinct BaseParts", expected="accept" },
	{ id="beams", purpose="create required attachments", expected="accept" },
	{ id="beams", purpose="reject invalid width", expected="reject" },
	{ id="trails", purpose="respect lifetime bounds", expected="accept" },
	{ id="particles", purpose="cap emitter rate at 500", expected="accept" },
	{ id="particles", purpose="reject emitter rate above 500", expected="reject" },
	{ id="particles", purpose="reject inverted lifetime interval", expected="reject" },
	{ id="particles", purpose="reject invalid particle transparency", expected="reject" },
	{ id="sound", purpose="reject invalid sound id", expected="reject" },
	{ id="sound", purpose="reject minimum rolloff above maximum", expected="reject" },
	{ id="sound", purpose="create organized sound groups", expected="accept" },
	{ id="sound", purpose="do not auto-play imported sound", expected="accept" },
	{ id="animation", purpose="reject malformed animation id", expected="reject" },
	{ id="animation", purpose="create animation objects without auto-playing", expected="accept" },
	{ id="remotes", purpose="reject unsupported remote class", expected="reject" },
	{ id="remotes", purpose="create RemoteEvent", expected="accept" },
	{ id="remotes", purpose="create RemoteFunction", expected="accept" },
	{ id="remotes", purpose="cap remote bundle at 100", expected="accept" },
	{ id="values", purpose="reject unsupported Value class", expected="reject" },
	{ id="values", purpose="reject integer overflow", expected="reject" },
	{ id="values", purpose="create typed value bundle", expected="accept" },
	{ id="attributes", purpose="reject oversized attribute name", expected="reject" },
	{ id="attributes", purpose="reject unsupported attribute datatype", expected="reject" },
	{ id="attributes", purpose="accept Boolean attribute", expected="accept" },
	{ id="attributes", purpose="accept finite Number attribute", expected="accept" },
	{ id="batch", purpose="resolve all paths before first mutation", expected="accept" },
	{ id="batch", purpose="report individual property failures", expected="accept" },
	{ id="batch", purpose="cap target count at 500", expected="reject" },
	{ id="physics", purpose="register collision group if absent", expected="accept" },
	{ id="physics", purpose="reject invalid collision group relationship", expected="reject" },
	{ id="ui", purpose="require GuiObject parent", expected="reject" },
	{ id="ui", purpose="create UIStroke", expected="accept" },
	{ id="ui", purpose="create UIGradient", expected="accept" },
	{ id="ui", purpose="create UIPadding", expected="accept" },
	{ id="ui", purpose="create UIListLayout", expected="accept" },
	{ id="ui", purpose="create UIGridLayout", expected="accept" },
	{ id="ui", purpose="create UICorner", expected="accept" },
	{ id="ui", purpose="reject negative panel width", expected="reject" },
	{ id="ui", purpose="reject text size below minimum", expected="reject" },
	{ id="ui", purpose="preserve parent layout when adding children", expected="accept" },
	{ id="ui", purpose="create progress fill between zero and one", expected="accept" },
	{ id="ui", purpose="create stat card with independent label/value", expected="accept" },
	{ id="ui", purpose="do not claim visual click behavior without LocalScript", expected="accept" },
	{ id="build", purpose="create bounded part grid", expected="accept" },
	{ id="build", purpose="reject grid over 500 pieces", expected="reject" },
	{ id="build", purpose="create stair steps with positive rise", expected="accept" },
	{ id="build", purpose="reject zero direction vector for wall", expected="reject" },
	{ id="build", purpose="create circular ring with at least three parts", expected="accept" },
	{ id="build", purpose="group selected instances and restore on failure", expected="accept" },
	{ id="build", purpose="preserve selected object names during grouping", expected="accept" },
	{ id="selection", purpose="cap duplicate selection count", expected="reject" },
	{ id="selection", purpose="offset cloned models with PivotTo", expected="accept" },
	{ id="selection", purpose="reject scaling factor zero", expected="reject" },
	{ id="selection", purpose="apply material only to selected BaseParts", expected="accept" },
	{ id="selection", purpose="apply color only to selected BaseParts", expected="accept" },
	{ id="selection", purpose="apply anchoring only to selected BaseParts", expected="accept" },
	{ id="catalog", purpose="create shop definitions without purchase logic", expected="accept" },
	{ id="catalog", purpose="reject negative item price", expected="reject" },
	{ id="catalog", purpose="create quest definitions without granting rewards", expected="accept" },
	{ id="catalog", purpose="reject zero quest goal", expected="reject" },
	{ id="progression", purpose="create XP configuration values", expected="accept" },
	{ id="progression", purpose="reject multiplier below one", expected="reject" },
	{ id="rounds", purpose="reject maximum players below minimum", expected="reject" },
	{ id="rounds", purpose="create round timing config", expected="accept" },
	{ id="checkpoints", purpose="create ordered checkpoint markers", expected="accept" },
	{ id="checkpoints", purpose="reject over 200 markers", expected="reject" },
	{ id="platforms", purpose="require at least two movement nodes", expected="reject" },
	{ id="portals", purpose="create linked portal markers", expected="accept" },
	{ id="teams", purpose="create Team instances", expected="accept" },
	{ id="teams", purpose="ignore missing team when generating team spawns", expected="accept" },
	{ id="assets", purpose="record asset manifest without downloading content", expected="accept" },
	{ id="assets", purpose="flag user verification metadata", expected="accept" },
	{ id="scripts", purpose="inventory scripts without executing them", expected="accept" },
	{ id="scripts", purpose="do not label static heuristics as malware verdict", expected="accept" },
	{ id="performance", purpose="report structural counts only", expected="accept" },
	{ id="performance", purpose="do not claim measured FPS", expected="accept" },
	{ id="project", purpose="report service hierarchy counts", expected="accept" },
	{ id="project", purpose="do not serialize script source in project manifest", expected="accept" },
	{ id="security", purpose="require server authority for rewards", expected="accept" },
	{ id="security", purpose="require server authority for purchases", expected="accept" },
	{ id="security", purpose="require server authority for damage", expected="accept" },
	{ id="security", purpose="require server authority for teleports", expected="accept" },
	{ id="security", purpose="reject arbitrary class names", expected="reject" },
	{ id="security", purpose="keep destructive operations explicit", expected="accept" },
	{ id="continuity", purpose="inspect target before incremental edit", expected="accept" },
	{ id="continuity", purpose="preserve unrelated scripts and GUI", expected="accept" },
	{ id="continuity", purpose="avoid rebuilding whole map for a small edit", expected="accept" },
	{ id="continuity", purpose="report exact path of applied object", expected="accept" },
	{ id="continuity", purpose="distinguish failed action from unapplied action", expected="accept" },
	{ id="runtime", purpose="require Play Test for runtime behavior", expected="accept" },
	{ id="runtime", purpose="require multiplayer test for replication", expected="accept" },
	{ id="runtime", purpose="require device test for responsive GUI", expected="accept" },
	{ id="runtime", purpose="require permission test for Toolbox assets", expected="accept" },
}


-- Meta-actions are attached after their local handlers and contracts are declared.
MEGA_EXT_ACTION_HANDLERS.LIST_EXTENDED_CAPABILITIES = F.exCapabilities
MEGA_EXT_ACTION_HANDLERS.LIST_EXTENDED_CONTRACTS = F.listExtendedActionContracts
MEGA_EXT_ACTION_HANDLERS.LIST_EXTENDED_PLAYBOOKS = F.getExtendedSpecialistPlaybook
MEGA_EXT_ACTION_HANDLERS.LIST_EXTENDED_RECIPES = F.getExtendedPlannerRecipes
MEGA_EXT_ACTION_HANDLERS.REPORT_EXTENDED_CONTRACT_SUMMARY = F.getExtendedContractSummary
MEGA_EXT_ACTION_HANDLERS.RUN_EXTENDED_SELF_TESTS = F.runExtendedSelfTests
MEGA_EXT_ACTION_HANDLERS.REPORT_EXTENDED_REGRESSION_MATRIX = F.reportExtendedRegressionMatrix

function F.getExtendedRegressionMatrix()
	local copy={}; for index,case in ipairs(MEGA_EXT_REGRESSION_MATRIX) do copy[index]={id=case.id or ("EX"..string.format("%03d",index)),area=case.area,purpose=case.purpose,expected=case.expected} end; return copy
end
function F.reportExtendedRegressionMatrix()
	local matrix=F.getExtendedRegressionMatrix(); local counts={total=#matrix,accept=0,reject=0,fallback=0}; for _,case in ipairs(matrix) do counts[case.expected]=(counts[case.expected] or 0)+1 end; F.showJSON({matrix=counts,cases=matrix,note="Scenario inventory; only runExtendedSelfTests results are actual executed tests."}); return "Regression matrix listed: "..#matrix.." scenarios"
end
MEGA_EXT_ACTION_HANDLERS.REPORT_EXTENDED_REGRESSION_MATRIX = F.reportExtendedRegressionMatrix



local ACTION_TYPES = {
	"CREATE_PART", "CREATE_STRUCTURE", "CREATE_MODEL_BLUEPRINT", "CREATE_TREE",
	"CREATE_GUI", "CREATE_FOLDER", "CREATE_VALUE", "CREATE_REMOTE", "CREATE_OBJECT",
	"CREATE_SYSTEM", "CREATE_SCRIPT", "CREATE_CONSTRAINT", "CREATE_TERRAIN",
	"SET_TERRAIN_WATER", "APPLY_LIGHTING_PRESET", "CREATE_SOUND", "CREATE_EFFECT",
	"SET_ATTRIBUTES", "MANAGE_TAGS", "CREATE_TEAM", "CREATE_TOOL", "CREATE_CHECKPOINT_SET",
	"CREATE_ATTACHMENT", "CREATE_PROXIMITY_PROMPT", "CREATE_DECORATION_SET",
	"IMPORT_TOOLBOX_ASSET", "LIST_MATERIALS", "LIST_COLOR_PALETTE", "CREATE_COLOR_SWATCH_SET", "CREATE_UI_PRESET",
	"SET_PROPERTIES", "SET_ATTRIBUTE", "DELETE_INSTANCE", "MOVE_INSTANCE",
	"DUPLICATE_INSTANCE", "INSPECT_PATH", "INSPECT_SELECTION", "INSPECT_PROJECT",
	"INSPECT_GUI", "GUI_QUALITY_REPORT", "INSPECT_SCRIPT", "VALIDATE_PROJECT", "FIND_INSTANCES",
	"LIST_CAPABILITIES", "ALIGN_SELECTION", "GROUND_SELECTION", "SET_SELECTION_PHYSICS", "APPLY_SELECTION_STYLE",
	"GROUP_SELECTION", "DISTRIBUTE_SELECTION", "RENAME_SELECTION_PATTERN", "SELECT_DESCENDANTS",
	"BATCH_ACTIONS",
}

local actionTypeSeen = {}
for _, actionType in ipairs(ACTION_TYPES) do actionTypeSeen[actionType] = true end
for actionType in pairs(MEGA_EXT_ACTION_HANDLERS) do
	if not actionTypeSeen[actionType] then
		table.insert(ACTION_TYPES, actionType)
		actionTypeSeen[actionType] = true
	end
end

table.sort(ACTION_TYPES)

local SUPPORTED_ACTION_TYPES = {}
for _, actionType in ipairs(ACTION_TYPES) do
	SUPPORTED_ACTION_TYPES[actionType] = true
end

function F.listCapabilities()
	F.showJSON({
		pluginVersion = VERSION,
		actionTypes = ACTION_TYPES,
		count = #ACTION_TYPES,
		extendedActionCount = (function() local n = 0; for _ in pairs(MEGA_EXT_ACTION_HANDLERS) do n += 1 end; return n end)(),
		extendedContractCount = (function() local n = 0; for _ in pairs(MEGA_EXT_ACTION_CONTRACTS) do n += 1 end; return n end)(),
		qaScenarioCount = #MEGA_EXT_QA_CASES + #MEGA_EXT_REGRESSION_MATRIX,
		extendedSelfTestCount = 35,
		capabilities = {
			projectInspection = true,
			staticAuditing = true,
			selectionWorkflow = true,
			protectedScriptProperties = true,
			atomicTreeCreation = true,
			serverActionReporting = true,
		extendedActionLayer = true,
		extendedContracts = true,
		specialistPlaybooks = true,
		selectionEditing = true,
		uiConstruction = true,
		vfxAudioConstruction = true,
		physicsTools = true,
		gameplayConfiguration = true,
		staticPerformanceReports = true,
		regressionScenarioInventory = true,
		},
		notes = {
			"Las funciones dependen de los permisos de Studio y del contrato del backend.",
			"No existe acceso automático a todas las operaciones internas de Studio.",
			"Las inspecciones son estáticas y no sustituyen Play Test ni revisión visual.",
			"Las acciones destructivas requieren una confirmación explícita.",
		},
	})
	return "Catálogo de " .. #ACTION_TYPES .. " tipos de acción mostrado."
end


--==============================================================
-- 9. EJECUTOR DE ACCIONES DEL BACKEND
--==============================================================

function F.executeAction(action)
	if type(action) == "table" and action.type == "BATCH_ACTIONS" then
		local actions = action.actions
		if type(actions) ~= "table" or #actions < 1 or #actions > 80 then
			error("BATCH_ACTIONS requiere entre 1 y 80 acciones.")
		end
		local results = {}
		-- Prevalidación completa: no comenzar un lote si hay una acción inválida.
		-- Las acciones destructivas se permiten solo si el lote lo declara explícitamente.
		local destructive = {DELETE_INSTANCE=true, CREATE_TERRAIN=true, SET_TERRAIN_WATER=true}
		for index, childAction in ipairs(actions) do
			if type(childAction) ~= "table" or type(childAction.type) ~= "string" or childAction.type == "BATCH_ACTIONS" then
				error("Acción de lote inválida en índice " .. tostring(index))
			end
			if not SUPPORTED_ACTION_TYPES[childAction.type] or childAction.type == "BATCH_ACTIONS" then
				error("Tipo de acción no compatible en índice " .. tostring(index) .. ": " .. tostring(childAction.type))
			end
			if destructive[childAction.type] and action.allowDestructive ~= true then
				error("El lote contiene una acción destructiva en índice " .. tostring(index) .. ". Añade allowDestructive=true después de revisar la vista previa.")
			end
		end
		ChangeHistoryService:SetWaypoint("Antes de lote MEGA")
		for index, childAction in ipairs(actions) do
			local ok, result = pcall(F.executeAction, childAction)
			if not ok then
				error("Lote detenido en acción " .. tostring(index) .. " (" .. tostring(childAction.type) .. "): " .. tostring(result) .. ". Las acciones anteriores podrían haberse aplicado; usa Deshacer si hace falta.")
			end
			table.insert(results, tostring(index) .. ". " .. tostring(result))
		end
		ChangeHistoryService:SetWaypoint("Después de lote MEGA")
		return "Lote aplicado (" .. tostring(#results) .. " acciones):\n" .. table.concat(results, "\n")
	end
	if type(action) ~= "table" or type(action.type) ~= "string" then
		error("Acción inválida.")
	end

	local kind = action.type

	if kind == "CREATE_PART" then
		local object = F.createPart(
			action,
			F.resolvePath(action.parent, "Workspace")
		)

		Selection:Set({ object })
		return "Pieza creada: " .. object:GetFullName()

	elseif kind == "CREATE_STRUCTURE" then
		if type(action.parts) ~= "table"
			or #action.parts < 1
			or #action.parts > 60 then
			error("La estructura debe contener entre 1 y 60 piezas.")
		end

		local model = Instance.new("Model")
		model.Name = F.safeName(action.name, "ABX_Structure")
		model.Parent = F.resolvePath(action.parent, "Workspace")

		local success, err = pcall(function()
			for _, partData in ipairs(action.parts) do
				F.createPart(partData, model)
			end
		end)

		if not success then
			model:Destroy()
			error(err)
		end

		Selection:Set({ model })
		return "Estructura creada con " .. #action.parts .. " piezas."

	elseif kind == "CREATE_GUI" then
		return F.createGui(action)

	elseif kind == "CREATE_TREE" then
		local parent = F.resolvePath(action.parent, "Workspace")
		local node = action.root or action.tree or action.node

		if type(node) ~= "table" then
			error("No se recibió el árbol de instancias.")
		end

		local ok, createdOrError = pcall(F.createTree, node, parent)
		if not ok then
			error("No se creó el árbol; las instancias parciales fueron limpiadas: " .. tostring(createdOrError))
		end
		local created = createdOrError
		Selection:Set({ created })

		return "Árbol creado: " .. created:GetFullName()

	elseif kind == "CREATE_FOLDER" then
		local folder = Instance.new("Folder")
		folder.Name = F.safeName(action.name, "ABX_Folder")
		folder.Parent = F.resolvePath(action.parent, "ReplicatedStorage")

		Selection:Set({ folder })
		return "Carpeta creada."

	elseif kind == "CREATE_VALUE" then
		local allowed = {
			StringValue = true,
			BoolValue = true,
			IntValue = true,
			NumberValue = true,
		}

		if not allowed[action.valueType] then
			error("Tipo de valor no admitido.")
		end

		local object = Instance.new(action.valueType)
		object.Name = F.safeName(action.name, "ABX_Value")

		if action.valueType == "StringValue" then
			object.Value = tostring(action.value or ""):sub(1, 500)

		elseif action.valueType == "BoolValue" then
			object.Value = action.value == true

		elseif action.valueType == "IntValue" then
			object.Value = math.clamp(
				math.floor(tonumber(action.value) or 0),
				-1000000000,
				1000000000
			)

		else
			object.Value = math.clamp(
				tonumber(action.value) or 0,
				-1000000000,
				1000000000
			)
		end

		object.Parent = F.resolvePath(action.parent, "ReplicatedStorage")
		Selection:Set({ object })

		return action.valueType .. " creado."

	elseif kind == "CREATE_REMOTE" then
		local allowed = {
			RemoteEvent = true,
			RemoteFunction = true,
			BindableEvent = true,
			BindableFunction = true,
		}

		if not allowed[action.remoteType] then
			error("Tipo remoto no admitido.")
		end

		local object = Instance.new(action.remoteType)
		object.Name = F.safeName(action.name, "ABX_Remote")
		object.Parent = F.resolvePath(action.parent, "ReplicatedStorage")

		Selection:Set({ object })
		return action.remoteType .. " creado."

	elseif kind == "CREATE_OBJECT" then
		if not ALLOWED_TREE_CLASSES[action.className] then
			error("Clase no admitida: " .. tostring(action.className))
		end

		local object = Instance.new(action.className)
		object.Name = F.safeName(action.name, "ABX_Object")
		object.Parent = F.resolvePath(action.parent, "Workspace")

		Selection:Set({ object })
		return action.className .. " creado."

	elseif kind == "CREATE_SYSTEM" then
		local allowed = {
			COINS = "Coins",
			CHECKPOINTS = "Checkpoint",
			REBIRTHS = "Rebirths",
		}

		local valueName = allowed[action.system]

		if not valueName then
			error("Plantilla de sistema no admitida.")
		end

		local parent = game:GetService("ReplicatedStorage")
		local folderName = "ABX_" .. action.system

		if parent:FindFirstChild(folderName) then
			error("Ya existe " .. folderName .. ". No se creó un duplicado.")
		end

		local folder = Instance.new("Folder")
		folder.Name = folderName

		local value = Instance.new("IntValue")
		value.Name = valueName
		value.Value = 0
		value.Parent = folder

		folder.Parent = parent
		Selection:Set({ folder })

		return "Plantilla inicial creada: " .. folderName
			.. ". No es un sistema completo de juego."

	elseif kind == "SET_PROPERTIES" then
		local target = F.findTarget(action.target or action.path)

		F.setProperties(target, action.properties)
		Selection:Set({ target })

		return "Propiedades actualizadas: " .. target:GetFullName()

	elseif kind == "SET_ATTRIBUTE" then
		local target = F.findTarget(action.target or action.path)

		if type(action.attribute) ~= "string" or action.attribute == "" then
			error("Nombre de atributo inválido.")
		end

		local value = action.value

		if type(value) ~= "string"
			and type(value) ~= "number"
			and type(value) ~= "boolean" then
			error("Tipo de atributo no admitido.")
		end

		target:SetAttribute(action.attribute, value)
		Selection:Set({ target })

		return "Atributo actualizado: " .. action.attribute

	elseif kind == "DELETE_INSTANCE" then
		local target = F.findTarget(action.target or action.path)

		if target == game or target == workspace then
			error("No se permite eliminar el juego o Workspace.")
		end

		local path = target:GetFullName()
		target:Destroy()
		Selection:Set({})

		return "Instancia eliminada: " .. path

	elseif kind == "MOVE_INSTANCE" then
		local target = F.findTarget(action.path)
		local newParent = F.findTarget(action.parentPath or action.newParent)

		if target == game or target == workspace then
			error("No se permite mover el juego o Workspace.")
		end

		if newParent == target or newParent:IsDescendantOf(target) then
			error("No se puede mover una instancia dentro de sí misma.")
		end

		target.Parent = newParent
		-- Posición física opcional: no confundir cambiar el padre con mover coordenadas.
		if action.position and target:IsA("BasePart") then
			target.Position = Vector3.new(tonumber(action.position[1]) or target.Position.X, tonumber(action.position[2]) or target.Position.Y, tonumber(action.position[3]) or target.Position.Z)
		elseif action.position and target:IsA("Model") then
			target:PivotTo(CFrame.new(tonumber(action.position[1]) or target:GetPivot().Position.X, tonumber(action.position[2]) or target:GetPivot().Position.Y, tonumber(action.position[3]) or target:GetPivot().Position.Z) * (target:GetPivot() - target:GetPivot().Position))
		end
		if action.rotation and target:IsA("BasePart") then
			target.Orientation = Vector3.new(tonumber(action.rotation[1]) or 0, tonumber(action.rotation[2]) or 0, tonumber(action.rotation[3]) or 0)
		end
		Selection:Set({ target })

		return "Instancia movida a " .. newParent:GetFullName() .. (action.position and " y reposicionada" or "")

	elseif kind == "DUPLICATE_INSTANCE" then
		local target = F.findTarget(action.path)

		if not target.Archivable then
			error("La instancia no permite duplicación (Archivable=false).")
		end

		local clone = target:Clone()
		clone.Name = F.safeName(action.name, target.Name .. "_Copy")
		clone.Parent = target.Parent

		Selection:Set({ clone })
		return "Duplicado creado: " .. clone:GetFullName()

	elseif kind == "INSPECT_PATH" then
		local target = F.findTarget(action.target or action.path)
		F.showJSON(F.inspectInstance(target, 0, 4))

		return "Inspección completada: " .. target:GetFullName()

	elseif kind == "INSPECT_SELECTION" then
		F.showJSON(F.inspectSelection())
		return "Inspección de selección completada."

	elseif kind == "INSPECT_PROJECT" then
		F.showJSON(F.inspectProject())
		return "Resumen del proyecto mostrado en la vista previa."

	elseif kind == "INSPECT_GUI" or kind == "GUI_QUALITY_REPORT" then
		F.showJSON(F.getGuiQualityReport())
		return "Informe estructural de interfaces listo. Esto no reemplaza una inspección visual en Play/Test."

	elseif kind == "FIND_INSTANCES" then
		F.showJSON(F.findInstances(action.query, action.className))
		return "Búsqueda completada. Se muestran hasta 100 resultados."

	elseif kind == "CREATE_SCRIPT" then
		local allowedLocations = {
			ServerScriptService = true,
			StarterPlayerScripts = true,
			StarterCharacterScripts = true,
			StarterGui = true,
			Workspace = true,
			ServerStorage = true,
			ReplicatedStorage = true,
			StarterPack = true,
		}

		if not allowedLocations[action.location] then
			error("Ubicación de script no permitida.")
		end

		if type(action.source) ~= "string"
			or action.source:match("^%s*$")
			or #action.source > 10000 then
			error("El código está vacío o supera 10000 caracteres.")
		end

		local lowerSource = string.lower(action.source)

		for _, blocked in ipairs({
			"loadstring",
			"getfenv",
			"setfenv",
			"insertservice",
			"httpservice",
			}) do
			if lowerSource:find(blocked, 1, true) then
				error("Código bloqueado por seguridad: " .. blocked)
			end
		end

		if lowerSource:match("require%s*%(") then
			error("El código enviado que contiene require() está bloqueado.")
		end

		local isLocal =
			action.location == "StarterPlayerScripts"
			or action.location == "StarterCharacterScripts"
			or action.location == "StarterGui"

		local scriptObject = Instance.new(
			isLocal and "LocalScript" or "Script"
		)

		scriptObject.Name = F.safeName(action.name, "ABX_GeneratedScript")
		scriptObject.Source = action.source
		scriptObject.Parent = F.resolvePath(action.location, "Workspace")

		Selection:Set({ scriptObject })

		return "Script insertado en " .. action.location
			.. ". Revísalo y pruébalo antes de publicar."

	elseif kind == "CREATE_MODEL_BLUEPRINT" then
		return F.createModelBlueprint(action)
	elseif kind == "CREATE_CONSTRAINT" then
		return F.createConstraint(action)
	elseif kind == "APPLY_LIGHTING_PRESET" then
		return F.applyLightingPreset(action)
	elseif kind == "CREATE_TERRAIN" then
		return F.createTerrainPrimitive(action)
	elseif kind == "SET_TERRAIN_WATER" then
		return F.setTerrainWater(action)
	elseif kind == "CREATE_SOUND" then
		return F.createSoundObject(action)
	elseif kind == "CREATE_EFFECT" then
		return F.createEffect(action)
	elseif kind == "SET_ATTRIBUTES" then
		return F.setAttributesBulk(action)
	elseif kind == "MANAGE_TAGS" then
		return F.manageTags(action)
	elseif kind == "CREATE_TEAM" then
		return F.createTeam(action)
	elseif kind == "CREATE_TOOL" then
		return F.createTool(action)
	elseif kind == "CREATE_CHECKPOINT_SET" then
		return F.createCheckpointSet(action)
	elseif kind == "INSPECT_SCRIPT" then
		return F.inspectScript(action)
	elseif kind == "VALIDATE_PROJECT" then
		return F.validateProjectDeep(action)
	elseif kind == "CREATE_ATTACHMENT" then
		return F.createAttachment(action)
	elseif kind == "CREATE_PROXIMITY_PROMPT" then
		return F.createProximityPrompt(action)
	elseif kind == "CREATE_DECORATION_SET" then
		return F.setTerrainDecoration(action)
	elseif kind == "IMPORT_TOOLBOX_ASSET" then
		return F.importToolboxAsset(action)
	elseif kind == "LIST_MATERIALS" then
		return F.listMaterials()
	elseif kind == "LIST_COLOR_PALETTE" then
		return F.listColorPalette()
	elseif kind == "CREATE_COLOR_SWATCH_SET" then
		return F.createColorSwatchSet(action)
	elseif kind == "CREATE_UI_PRESET" then
		return F.createUiPreset(action)
	elseif kind == "LIST_CAPABILITIES" then
		return F.listCapabilities()
	elseif kind == "ALIGN_SELECTION" then
		return F.alignSelectionToGrid(action)
	elseif kind == "GROUND_SELECTION" then
		return F.groundSelection(action)
	elseif kind == "SET_SELECTION_PHYSICS" then
		return F.setSelectionPhysics(action)
	elseif kind == "APPLY_SELECTION_STYLE" then
		return F.styleSelection(action)
	elseif kind == "GROUP_SELECTION" then
		return F.groupSelection(action)
	elseif kind == "DISTRIBUTE_SELECTION" then
		return F.distributeSelection(action)
	elseif kind == "RENAME_SELECTION_PATTERN" then
		return F.renameSelectionPattern(action)
	elseif kind == "SELECT_DESCENDANTS" then
		return F.selectDescendants(action)
	elseif MEGA_EXT_ACTION_HANDLERS[kind] then
		local handled, result = F.executeExtendedAction(action)
		if handled then return result end
		error(result)
	else
		error("Acción desconocida: " .. kind)
	end
end

--==============================================================
-- MEGA V10.2: IN-STUDIO REGRESSION SELF TESTS
--==============================================================

function F.runMegaSelfTests()
	local previousSelection = Selection:Get()
	local testFolder = Instance.new("Folder")
	testFolder.Name = "__MEGA_SelfTest_" .. tostring(math.random(10000, 99999))
	testFolder.Parent = game:GetService("ServerStorage")
	local results = {}
	local passed = 0
	local failed = 0
	local sampleParts = {}

	local function runCase(name, callback)
		local ok, err = pcall(callback)
		if ok then
			passed += 1
			table.insert(results, {name=name, status="passed"})
		else
			failed += 1
			table.insert(results, {name=name, status="failed", error=tostring(err):sub(1, 400)})
		end
	end

	local function makeTestPart(name, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(2, 2, 2)
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.Parent = testFolder
		return part
	end


	runCase("CREATE_PART: pieza anclada y con tamaño", function()
		local part = F.createPart({name="PartTest", size={3, 4, 5}, position={0, 10, 0}}, testFolder)
		assert(part:IsA("BasePart"), "No creó una pieza física.")
		assert(part.Anchored == true, "La pieza no quedó anclada por defecto.")
		assert(part.Size == Vector3.new(3, 4, 5), "El tamaño no coincide.")
		table.insert(sampleParts, part)
	end)

	runCase("CREATE_TREE: jerarquía válida", function()
		local tree = F.createTree({
			className="Model", name="TreeTest", children={
				{className="Part", name="ChildPart", properties={Size={2, 2, 2}}},
				{className="Folder", name="ChildFolder"},
				{className="Folder", name="Nested", children={{className="BoolValue", name="Enabled", properties={Value=true}}}},
			},
		}, testFolder)
		assert(tree:IsA("Model"), "La raíz no es Model.")
		assert(#tree:GetDescendants() == 4, "La cantidad de descendientes no coincide.")
	end)

	runCase("CREATE_TREE: rollback de jerarquía inválida", function()
		local before = #testFolder:GetChildren()
		local ok = pcall(F.createTree, {className="Model", name="RollbackTest", children={{className="MEGA_InvalidClass"}}}, testFolder)
		assert(not ok, "La clase inválida fue aceptada.")
		assert(#testFolder:GetChildren() == before, "Quedaron instancias parciales tras el error.")
	end)

	runCase("SET_PROPERTIES: protección de Source", function()
		local target = Instance.new("Script")
		target.Name = "SourceProtectionTest"
		target.Parent = testFolder
		local ok = pcall(F.setProperties, target, {Source="print('blocked')"})
		assert(not ok, "SET_PROPERTIES permitió la propiedad Source.")
	end)

	runCase("SET_PROPERTIES: protección de Parent", function()
		local target = sampleParts[1] or makeTestPart("ParentTest", Vector3.new(0, 5, 0))
		local ok = pcall(F.setProperties, target, {{name="Parent", value=testFolder}})
		assert(not ok, "SET_PROPERTIES permitió cambiar Parent.")
	end)

	runCase("SET_PROPERTIES: propiedad física válida", function()
		local target = sampleParts[1] or makeTestPart("PhysicsTest", Vector3.new(0, 5, 0))
		F.setProperties(target, {Anchored=false, CanCollide=false})
		assert(target.Anchored == false and target.CanCollide == false, "Las propiedades válidas no se aplicaron.")
		target.Anchored = true
		target.CanCollide = true
	end)

	runCase("ALIGN_SELECTION: snap y conserva orientación", function()
		local part = makeTestPart("GridTest", Vector3.new(1.3, 2.7, -3.2))
		part.Orientation = Vector3.new(0, 30, 0)
		Selection:Set({part})
		F.alignSelectionToGrid({gridSize=1})
		assert((part.Position - Vector3.new(1, 3, -3)).Magnitude < 0.001, "No ajustó las coordenadas a la rejilla.")
		assert(math.abs(part.Orientation.Y - 30) < 0.1, "No conservó la orientación.")
	end)

	runCase("PALETA MEGA: nombres normalizados", function()
		local color = F.resolveMegaColor("megaOrange")
		assert(color == Color3.fromRGB(255, 155, 65), "La paleta no resolvió megaOrange.")
	end)

	runCase("APPLY_SELECTION_STYLE: color y material", function()
		local part = makeTestPart("StyleTest", Vector3.new(0, 8, 0))
		Selection:Set({part})
		F.styleSelection({color="megaOrange", material="Neon"})
		assert(part.Material == Enum.Material.Neon, "No aplicó el material.")
		assert(part.Color == Color3.fromRGB(255, 155, 65), "No aplicó el color.")
	end)

	runCase("SET_SELECTION_PHYSICS: anclaje y colisión", function()
		local part = makeTestPart("PhysicsSelectionTest", Vector3.new(0, 12, 0))
		Selection:Set({part})
		F.setSelectionPhysics({anchored=false, canCollide=false})
		assert(not part.Anchored and not part.CanCollide, "No aplicó las propiedades físicas.")
	end)

	runCase("DISTRIBUTE_SELECTION: separación uniforme", function()
		local a = makeTestPart("DistributeA", Vector3.new(0, 20, 0))
		local b = makeTestPart("DistributeB", Vector3.new(10, 20, 0))
		local c = makeTestPart("DistributeC", Vector3.new(20, 20, 0))
		Selection:Set({a, b, c})
		F.distributeSelection({axis="X", spacing=4})
		assert(math.abs((b.Position.X - a.Position.X) - 4) < 0.001, "La primera separación no es uniforme.")
		assert(math.abs((c.Position.X - b.Position.X) - 4) < 0.001, "La segunda separación no es uniforme.")
	end)

	runCase("RENAME_SELECTION_PATTERN: sustituye marcadores", function()
		local a = makeTestPart("Runner%One", Vector3.new(0, 30, 0))
		local b = makeTestPart("RunnerTwo", Vector3.new(4, 30, 0))
		Selection:Set({a, b})
		F.renameSelectionPattern({template="{name}_{index}"})
		assert(a.Name == "Runner%One_1", "No conservó correctamente un nombre con porcentaje.")
		assert(b.Name == "RunnerTwo_2", "No sustituyó el índice.")
	end)

	runCase("GROUP_SELECTION: mantiene objetos dentro del modelo", function()
		local a = makeTestPart("GroupA", Vector3.new(0, 40, 0))
		local b = makeTestPart("GroupB", Vector3.new(4, 40, 0))
		Selection:Set({a, b})
		F.groupSelection({name="GroupTest"})
		local selected = Selection:Get()
		assert(#selected == 1 and selected[1]:IsA("Model"), "No seleccionó el modelo creado.")
		assert(selected[1]:FindFirstChild("GroupA") and selected[1]:FindFirstChild("GroupB"), "No movió ambos objetos al modelo.")
	end)

	runCase("BATCH_ACTIONS: prevalidación antes de mutar", function()
		local before = #game:GetService("ServerStorage"):GetChildren()
		local ok = pcall(F.executeAction, {type="BATCH_ACTIONS", actions={
			{type="CREATE_FOLDER", name="MustNotExist", parent="ServerStorage"},
			{type="MEGA_UNKNOWN_TEST_ACTION"},
		}})
		assert(not ok, "El lote con acción desconocida no fue rechazado.")
		assert(#game:GetService("ServerStorage"):GetChildren() == before, "El lote mutó el proyecto antes de fallar.")
		assert(not game:GetService("ServerStorage"):FindFirstChild("MustNotExist"), "El primer paso del lote se ejecutó antes de la prevalidación.")
	end)

	pcall(function() Selection:Set(previousSelection) end)
	pcall(function() testFolder:Destroy() end)

	local report = {
		pluginVersion = VERSION,
		passed = passed,
		failed = failed,
		total = passed + failed,
		allPassed = failed == 0,
		note = "Pruebas locales de regresión del plugin; no ejecutan Play Test ni validan el backend en producción.",
		results = results,
	}
	F.showJSON(report)
	return "Autopruebas MEGA: " .. passed .. "/" .. (passed + failed) .. " aprobadas; " .. failed .. " fallidas."
end

--==============================================================
-- 10. SESIÓN, SONDEO Y CONFIRMACIÓN
--==============================================================

function F.pollOnce()
	if not sessionCode then
		F.setStatus(false, "Genera un código para comenzar.")
		return
	end

	-- No solicitar otra acción mientras una esté pendiente.
	-- Así no se reemplaza una acción que aún no has revisado.
	if pendingAction then
		return
	end

	local data = F.request("GET", "/poll/" .. sessionCode)

	F.setStatus(
		data.connected == true,
		data.connected
			and "Página conectada. Esperando instrucciones."
			or "Esperando que conectes el código en la página."
	)

	if type(data.script) ~= "string" or data.script == "" then
		return
	end
	if #data.script > 250000 then
		F.setLog("La acción supera el límite seguro de 250 KB y fue rechazada.", COLORS.Red)
		return
	end

	local ok, action = pcall(function()
		return HttpService:JSONDecode(data.script)
	end)

	if not ok or type(action) ~= "table" or type(action.type) ~= "string" then
		F.setLog("El backend envió una acción inválida.", COLORS.Red)
		return
	end

	pendingAction = action
	previewBox.Text = HttpService:JSONEncode(action)

	confirmButton.Visible = true
	rejectButton.Visible = true

	F.setLog(
		"Acción recibida: " .. action.type .. ". Revisa antes de aplicar.",
		COLORS.Orange
	)
end

function F.generateCode()
	local code = tostring(math.random(10000, 99999))

	local ok, result = pcall(function()
		return F.request("POST", "/register", { code = code })
	end)

	if not ok or not result or result.ok ~= true then
		sessionCode = nil
		codeLabel.Text = "Código: error"

		F.setStatus(
			false,
			"No se pudo registrar el código. Comprueba la conexión."
		)

		return
	end

	sessionCode = code
	pendingAction = nil
	pollDelay = 3
	pollFailures = 0

	previewBox.Text = ""
	confirmButton.Visible = false
	rejectButton.Visible = false

	codeLabel.Text = "Código: " .. code

	F.setStatus(
		false,
		"Código generado. Introdúcelo en la página de MEGA."
	)

	local pollOK, pollError = pcall(F.pollOnce)

	if not pollOK then
		F.setLog("Código generado; error de conexión: " .. tostring(pollError))
	end
end

generateButton.MouseButton1Click:Connect(F.generateCode)

checkButton.MouseButton1Click:Connect(function()
	local ok, err = pcall(F.pollOnce)

	if not ok then
		F.setStatus(false, "Error de conexión: " .. tostring(err))
	end
end)

confirmButton.MouseButton1Click:Connect(function()
	if not pendingAction then
		F.setLog("No hay ninguna acción pendiente.", COLORS.Orange)
		return
	end

	local action = pendingAction

	local ok, result = pcall(function()
		ChangeHistoryService:SetWaypoint("Antes de MEGA v" .. VERSION)

		local message = F.executeAction(action)

		ChangeHistoryService:SetWaypoint("Después de MEGA v" .. VERSION)

		return message
	end)

	if ok then
		F.reportActionResult("applied", action, result)
		pendingAction = nil
		confirmButton.Visible = false
		rejectButton.Visible = false

		F.setLog(result, COLORS.Green)
	else
		F.reportActionResult("failed", action, result)
		-- Conserva la acción para que puedas revisar el error
		-- y decidir si quieres volver a intentarlo o rechazarla.
		F.setLog("No se pudo aplicar: " .. tostring(result), COLORS.Red)
	end
end)

rejectButton.MouseButton1Click:Connect(function()
	if pendingAction then
		F.reportActionResult("rejected", pendingAction, "El usuario rechazó la acción en la vista previa.")
	end
	pendingAction = nil
	confirmButton.Visible = false
	rejectButton.Visible = false
	previewBox.Text = ""

	F.setLog("Acción rechazada. No se aplicó.", COLORS.Orange)
end)

--==============================================================
-- 11. HERRAMIENTAS LOCALES DEL EXPLORADOR
--==============================================================

refreshButton.MouseButton1Click:Connect(function()
	local query = searchBox.Text

	local ok, results = pcall(function()
		return F.findInstances(query, "")
	end)

	if not ok then
		explorerOutput.Text = "Error al buscar: " .. tostring(results)
		return
	end

	explorerOutput.Text = HttpService:JSONEncode(results)

	F.setLog(
		"Búsqueda local completada: " .. #results .. " resultado(s).",
		COLORS.Green
	)
end)

renameButton.MouseButton1Click:Connect(function()
	local selected = Selection:Get()
	local newName = F.safeName(renameBox.Text, nil)

	if #selected == 0 then
		F.setLog("Selecciona una instancia primero.", COLORS.Orange)
		return
	end

	if not newName then
		F.setLog("Escribe un nombre válido.", COLORS.Orange)
		return
	end

	local ok, err = pcall(function()
		ChangeHistoryService:SetWaypoint("Antes de renombrar con MEGA")

		for _, object in ipairs(selected) do
			object.Name = newName
		end

		ChangeHistoryService:SetWaypoint("Después de renombrar con MEGA")
	end)

	if ok then
		F.setLog("Selección renombrada.", COLORS.Green)
	else
		F.setLog("No se pudo renombrar: " .. tostring(err), COLORS.Red)
	end
end)

duplicateButton.MouseButton1Click:Connect(function()
	local selected = Selection:Get()

	if #selected == 0 then
		F.setLog("Selecciona una instancia para duplicarla.", COLORS.Orange)
		return
	end

	local clones = {}

	local ok, err = pcall(function()
		ChangeHistoryService:SetWaypoint("Antes de duplicar con MEGA")

		for _, object in ipairs(selected) do
			if object.Archivable then
				local clone = object:Clone()
				clone.Name = object.Name .. "_Copy"
				clone.Parent = object.Parent
				table.insert(clones, clone)
			end
		end

		ChangeHistoryService:SetWaypoint("Después de duplicar con MEGA")
	end)

	if ok and #clones > 0 then
		Selection:Set(clones)
		F.setLog("Duplicados creados: " .. #clones, COLORS.Green)
	elseif ok then
		F.setLog("No había instancias duplicables.", COLORS.Orange)
	else
		F.setLog("Error al duplicar: " .. tostring(err), COLORS.Red)
	end
end)

-- MEGA asset/catalog local controls
importAssetButton.MouseButton1Click:Connect(function()
	local action = {type="IMPORT_TOOLBOX_ASSET", assetId=assetIdBox.Text, parent=assetParentBox.Text}
	local ok, result = pcall(function()
		ChangeHistoryService:SetWaypoint("Antes de importar asset MEGA")
		local message = F.executeAction(action)
		ChangeHistoryService:SetWaypoint("Después de importar asset MEGA")
		return message
	end)
	F.setLog(ok and result or ("No se pudo importar: " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
end)

materialsButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(F.listMaterials)
	F.setLog(ok and result or ("Error de catálogo: " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
end)

function F.runLocalTool(action, label)
	local ok, result = pcall(function()
		ChangeHistoryService:SetWaypoint("Antes de MEGA: " .. tostring(label))
		local message = F.executeAction(action)
		ChangeHistoryService:SetWaypoint("Después de MEGA: " .. tostring(label))
		return message
	end)
	F.setLog(ok and tostring(result) or ("No se pudo " .. tostring(label) .. ": " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
	return ok, result
end

alignSelectionButton.MouseButton1Click:Connect(function()
	F.runLocalTool({type="ALIGN_SELECTION", gridSize=tonumber(gridSizeBox.Text) or 1}, "alinear selección")
end)

groundSelectionButton.MouseButton1Click:Connect(function()
	F.runLocalTool({type="GROUND_SELECTION", clearance=0.05}, "apoyar selección en el suelo")
end)

anchorSelectionButton.MouseButton1Click:Connect(function()
	local ok, partsOrError = pcall(F.getSelectedBaseParts, 2000)
	if not ok then F.setLog("No se pudo leer la selección: " .. tostring(partsOrError), COLORS.Red); return end
	local allAnchored = true
	for _, part in ipairs(partsOrError) do
		if not part.Anchored then allAnchored = false; break end
	end
	F.runLocalTool({type="SET_SELECTION_PHYSICS", anchored=not allAnchored}, "cambiar anclaje")
end)

groupSelectionButton.MouseButton1Click:Connect(function()
	F.runLocalTool({type="GROUP_SELECTION", name="MEGA_Group"}, "agrupar selección")
end)

auditProjectButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(F.validateProjectDeep, {maxObjects=30000})
	F.setLog(ok and result or ("Error de auditoría: " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
end)

inspectSelectionButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(function()
		F.showJSON(F.inspectSelection())
		return "Inspección de selección lista."
	end)
	F.setLog(ok and result or ("Error de inspección: " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
end)

inspectProjectButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(function()
		F.showJSON(F.inspectProject())
		return "Resumen del proyecto listo."
	end)
	F.setLog(ok and result or ("Error de resumen: " .. tostring(result)), ok and COLORS.Green or COLORS.Red)
end)

selfTestButton.MouseButton1Click:Connect(function()
	local ok, result = pcall(F.runMegaSelfTests)
	local extendedOk, extendedResult = pcall(F.runExtendedSelfTests)
	local allOk = ok and extendedOk
	local message = tostring(result) .. " | " .. tostring(extendedResult)
	F.setLog(allOk and message or ("Error en autopruebas: " .. message), allOk and COLORS.Green or COLORS.Red)
end)

--==============================================================
-- 12. INICIO Y SONDEO AUTOMÁTICO
--==============================================================

openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

task.spawn(function()
	while true do
		task.wait(pollDelay)
		if sessionCode and not polling and not pendingAction then
			polling = true
			local ok, err = pcall(F.pollOnce)
			if ok then
				pollFailures = 0
				pollDelay = 3
			else
				pollFailures = math.min(pollFailures + 1, 5)
				pollDelay = math.min(3 * (2 ^ pollFailures), 30)
				F.setStatus(false, "Error de conexión; nuevo intento en " .. tostring(pollDelay) .. " s.")
				warn("[MEGA] " .. tostring(err))
			end
			polling = false
		end
	end
end)

F.setStatus(false, "Genera un código para conectar la página web.")
F.setLog("MEGA v" .. VERSION .. " listo.", COLORS.Green)

--[[
===============================================================================
MEGA V8.0 — GUÍA TÉCNICA Y MATRIZ DE CONTROL DE CALIDAD
===============================================================================

Este apéndice es documentación ejecutable como referencia para futuras mejoras.
No ejecuta acciones al cargar el plugin. Describe los contratos de datos que el
backend debe respetar y las comprobaciones que el desarrollador debe realizar.

PRINCIPIOS MULTIDOMINIO
-----------------------

1. Interpretar la petición antes de crear objetos.
2. Inspeccionar el contexto existente antes de editar.
3. Elegir el tipo de acción más pequeño que resuelva el objetivo.
4. Planificar dependencias entre instancias.
5. Validar los datos antes de modificar Studio.
6. Aplicar cambios dentro de un punto de deshacer.
7. Inspeccionar el resultado después de la modificación.
8. Informar de límites y errores reales, sin afirmar que se probó lo que no se probó.

La IA no debe considerar que una petición de “hacer una tienda” significa crear
únicamente un Frame. Una tienda puede requerir jerarquía de UI, datos de artículos,
validación de compra en servidor, remotos, actualización de saldo, estados visuales,
retroalimentación al jugador y pruebas. El constructor debe describir qué piezas
se crearán y distinguir entre el diseño visual y la lógica de juego.

CONTRATO DE ACCIÓN CREATE_GUI AVANZADA
--------------------------------------

{
  "type": "CREATE_GUI",
  "name": "ShopGui",
  "parent": "StarterGui",
  "displayOrder": 20,
  "ignoreGuiInset": false,
  "resetOnSpawn": false,
  "uiTree": {
    "className": "Frame",
    "name": "MainPanel",
    "properties": {
      "AnchorPoint": [0.5, 0.5],
      "Position": [0.5, 0, 0.5, 0],
      "Size": [0, 680, 0, 460],
      "BackgroundColor3": [24, 31, 49]
    },
    "style": {"cornerRadius": 16, "stroke": [55, 130, 255], "padding": 16},
    "children": []
  }
}

Las matrices de UDim2 se representan en el orden X.Scale, X.Offset, Y.Scale,
Y.Offset. Color3 se representa con tres componentes RGB de 0 a 255, excepto
cuando se especifica explícitamente un valor normalizado entre 0 y 1.

CONTRATO DE ACCIONES EN LOTE
----------------------------

{
  "type": "BATCH_ACTIONS",
  "actions": [
    {"type": "CREATE_FOLDER", "name": "ABX_Data", "parent": "ReplicatedStorage"},
    {"type": "CREATE_VALUE", "valueType": "IntValue", "name": "Coins", "value": 0, "parent": "ReplicatedStorage.ABX_Data"}
  ]
}

Los lotes deben ser pequeños y ordenados por dependencia. Un lote no debe intentar
crear hijos antes de crear sus padres. El límite de acciones evita que una respuesta
malformada bloquee Studio o produzca un volumen excesivo de instancias.

IMPORTANTE SOBRE LA REVERSIÓN
-----------------------------

Los puntos de deshacer de Studio no equivalen a una transacción de base de datos.
Si una acción del lote falla después de que otras se aplicaron, el plugin detiene
el lote e informa qué índice falló. El usuario puede usar Deshacer en Studio. Una
versión futura puede registrar un diario explícito de instancias creadas para una
reversión automática más completa.

REVISIÓN DE INTERFACES
----------------------

La revisión estructural puede detectar propiedades inválidas, dimensiones no
positivas, texto demasiado pequeño y botones sin texto. No puede garantizar que
no haya superposición visual porque eso depende del viewport, las restricciones,
los layouts, los textos reales y el estado del juego. La comprobación visual debe
realizarse con Play/Test y con varios tamaños de ventana.

REVISIÓN DE CONSTRUCCIONES FÍSICAS
---------------------------------

Antes de crear una construcción, el plan debe definir dimensiones, orientación,
materiales, anclaje, colisiones, pivote, ubicación y relación con el suelo. Los
modelos deben agruparse en Model cuando formen una unidad lógica. Las partes deben
colocarse respecto de una referencia conocida y no usando coordenadas arbitrarias
sin inspeccionar el proyecto.

REVISIÓN DE MOVIMIENTO
----------------------

Cambiar Parent cambia la jerarquía, no necesariamente las coordenadas físicas.
Para mover BasePart se usa Position/CFrame. Para mover Model se usa PivotTo. Para
mover una jerarquía de GUI se modifican Position, AnchorPoint y/o Size, respetando
sus layouts y constraints. Mover un hijo administrado por UIListLayout puede no
producir el resultado visual esperado si el layout controla su posición.

REVISIÓN DE SCRIPTS
-------------------

Los scripts generados deben tener responsabilidades claras, manejo de errores,
validación de entradas, separación cliente/servidor y nombres descriptivos. Las
compras, la moneda, los premios y cualquier dato importante deben validarse en el
servidor. Un LocalScript no debe ser la autoridad final sobre el saldo del jugador.

REVISIÓN DE SEGURIDAD
---------------------

Las listas de bloqueo textual son comprobaciones básicas y no constituyen un
sandbox completo para código arbitrario. El código debe revisarse, probarse y
mantenerse dentro de las APIs previstas para Roblox. No debe aceptarse una
respuesta del backend como si fuese confiable solo porque está bien formada.

MATRIZ DE PRUEBAS MANUALES
--------------------------

A. CONEXIÓN
   - Generar un código de sesión.
   - Introducirlo en la web.
   - Comprobar que la conexión se refleja en el plugin.
   - Confirmar que no se reemplaza una acción pendiente.
   - Probar un error HTTP y verificar que se informa sin bloquear la UI.

B. CREACIÓN DE PIEZAS
   - Crear una Part con tamaño y posición explícitos.
   - Crear una estructura con varias partes.
   - Confirmar nombres, padres, orientación y anclaje.
   - Verificar que un fallo no deja una estructura parcialmente creada cuando la
     acción usa su propia protección de errores.

C. CREACIÓN DE INTERFACES
   - Crear una ScreenGui con un Frame centrado.
   - Añadir título, descripción y botones.
   - Añadir UIListLayout y UIPadding a una lista.
   - Crear una cuadrícula de artículos con UIGridLayout.
   - Comprobar que las propiedades UDim2 conservan el orden de componentes.
   - Comprobar que los colores RGB se interpretan correctamente.
   - Abrir Play/Test y verificar visibilidad, escala y legibilidad.
   - Redimensionar el viewport y verificar anclajes.
   - Confirmar que los botones requieren scripts si deben ejecutar acciones.

D. EDICIÓN Y MOVIMIENTO
   - Editar una propiedad existente.
   - Mover una pieza sin cambiar su padre.
   - Cambiar el padre de una instancia sin confundirlo con su posición.
   - Mover un modelo conservando su orientación.
   - Intentar una ruta inexistente y verificar un error legible.
   - Confirmar que no se puede mover un objeto dentro de sí mismo.

E. BÚSQUEDA E INSPECCIÓN
   - Buscar por nombre parcial.
   - Inspeccionar selección múltiple.
   - Inspeccionar una ScreenGui.
   - Revisar el informe de calidad de GUI.
   - Confirmar que el texto de TextLabel se devuelve como cadena y no booleano.

F. LOTE DE ACCIONES
   - Aplicar dos acciones válidas en orden.
   - Probar una acción inválida intermedia.
   - Verificar que el lote se detiene y comunica el índice fallido.
   - Verificar el punto de deshacer antes y después.
   - Confirmar que un lote no puede anidarse recursivamente.
   - Confirmar el límite de 80 acciones por lote.

G. SCRIPTS
   - Insertar un script pequeño en una ubicación permitida.
   - Probar una ubicación prohibida.
   - Probar código vacío y código demasiado largo.
   - Revisar las limitaciones de los filtros textuales.
   - Ejecutar la experiencia en modo de prueba antes de publicar.

H. ROBUSTEZ
   - Probar propiedades incompatibles con una clase.
   - Probar una tabla de propiedades mal formada.
   - Probar nombres vacíos.
   - Probar una ruta que no existe.
   - Probar una jerarquía excesivamente profunda.
   - Probar más instancias que el límite admitido.
   - Verificar que cada error se presenta en el registro.

CHECKLIST DE ACEPTACIÓN DE UI
-----------------------------

[ ] La raíz está en StarterGui (o PlayerGui cuando corresponde).
[ ] La ScreenGui tiene nombre descriptivo.
[ ] DisplayOrder evita quedar detrás de otras interfaces relevantes.
[ ] IgnoreGuiInset se eligió deliberadamente.
[ ] El panel principal tiene AnchorPoint y Position coherentes.
[ ] Los tamaños son razonables para el viewport esperado.
[ ] Se usan layouts para listas y cuadrículas repetitivas.
[ ] Se usan UIPadding y separación entre elementos.
[ ] Los textos tienen contraste y tamaños legibles.
[ ] Los botones tienen estados y etiquetas claras.
[ ] Los iconos tienen Image y ScaleType correctos.
[ ] Los elementos interactivos tienen scripts cuando se necesitan.
[ ] Las operaciones importantes se validan en servidor.
[ ] Se probó la interfaz dentro de Play/Test.
[ ] Se probó al menos una resolución diferente.
[ ] Se revisó el orden de capas ZIndex.
[ ] Se verificó que no haya objetos fuera del panel accidentalmente.
[ ] Se confirmó que no se duplicó la ScreenGui por error.

CHECKLIST DE ACEPTACIÓN DE CONSTRUCCIÓN
---------------------------------------

[ ] La construcción tiene un propósito y una silueta identificable.
[ ] Las piezas principales están agrupadas en un Model cuando corresponde.
[ ] El pivote del Model permite mover la construcción de forma coherente.
[ ] Las piezas tienen tamaño y orientación apropiados.
[ ] Las piezas no están accidentalmente enterradas en el suelo.
[ ] Las piezas no flotan sin intención.
[ ] Las colisiones son apropiadas para el gameplay.
[ ] Las piezas estáticas están ancladas.
[ ] Los materiales y colores son consistentes.
[ ] Las zonas transitables no están bloqueadas accidentalmente.
[ ] El SpawnLocation es accesible y seguro.
[ ] Los nombres ayudan a entender la jerarquía.
[ ] La construcción no excede los límites de instancias establecidos.
[ ] Se comprobó la escena desde la cámara del jugador.

CHECKLIST DE ACEPTACIÓN DE LÓGICA DE JUEGO
------------------------------------------

[ ] El objetivo principal está definido.
[ ] Los estados de juego están definidos.
[ ] Los datos persistentes se manejan de forma segura si aplica.
[ ] Los RemoteEvents se validan en servidor.
[ ] Se comprueban los tipos y rangos de los datos recibidos.
[ ] Las recompensas no dependen únicamente del cliente.
[ ] Los jugadores que se desconectan no rompen el estado compartido.
[ ] Se evitan conexiones repetidas a eventos sin limpieza.
[ ] Los scripts usan nombres y responsabilidades claras.
[ ] Se muestran errores accionables en lugar de fallos silenciosos.
[ ] Se prueban los casos normales y los casos límite.

CHECKLIST DE CALIDAD DE CÓDIGO
------------------------------

[ ] Las funciones tienen una responsabilidad clara.
[ ] Las variables locales se usan siempre que sea posible.
[ ] Las rutas se validan antes de acceder a una instancia.
[ ] Las operaciones arriesgadas se envuelven en pcall cuando procede.
[ ] Los valores numéricos se convierten y limitan.
[ ] Los tipos de datos se validan antes de usarse.
[ ] No se asume que una propiedad existe en todas las clases.
[ ] Los errores contienen contexto suficiente para depurarlos.
[ ] No se informa éxito cuando la operación falló.
[ ] Se conserva la identidad de los objetos editados cuando sea posible.

CONTRATO DE RESPUESTA DEL BACKEND
---------------------------------

La respuesta debe ser JSON válido y debe contener un objeto de acción. El campo
"type" es obligatorio. Cada tipo de acción tiene sus propios campos obligatorios.
No se debe enviar texto explicativo mezclado dentro de la estructura JSON. La
vista previa muestra la acción para que el usuario la revise antes de ejecutarla.

TIPOS DE ACCIÓN PRINCIPALES
---------------------------

CREATE_PART: crea una pieza física.
CREATE_STRUCTURE: crea un modelo con piezas.
CREATE_GUI: crea una interfaz simple o un árbol UI declarativo.
CREATE_TREE: crea una jerarquía de clases permitidas.
CREATE_FOLDER: crea una carpeta.
CREATE_VALUE: crea un valor de datos.
CREATE_REMOTE: crea un objeto remoto.
CREATE_OBJECT: crea una instancia permitida.
CREATE_SYSTEM: crea una plantilla inicial de sistema.
SET_PROPERTIES: modifica propiedades.
SET_ATTRIBUTE: modifica un atributo.
DELETE_INSTANCE: elimina una instancia.
MOVE_INSTANCE: cambia de padre y opcionalmente reposiciona una pieza/modelo.
DUPLICATE_INSTANCE: duplica una instancia.
INSPECT_PATH: inspecciona una ruta.
INSPECT_SELECTION: inspecciona la selección actual.
INSPECT_PROJECT: devuelve un resumen del proyecto.
FIND_INSTANCES: busca objetos por nombre o clase.
INSPECT_GUI: produce un informe estructural de GUIs.
GUI_QUALITY_REPORT: alias del informe estructural de GUIs.
CREATE_SCRIPT: crea un Script o LocalScript en una ubicación permitida.
BATCH_ACTIONS: ejecuta una lista limitada de acciones no anidadas.

LIMITACIONES CONOCIDAS DE ESTA VERSIÓN
--------------------------------------

1. La revisión de GUI es estructural; no realiza captura de pantalla ni visión
   computacional de la escena renderizada.
2. La conexión web debe producir los nuevos campos para activar el constructor UI
   avanzado y las acciones por lotes.
3. Un lote no constituye una transacción atómica; los cambios anteriores a un
   error pueden permanecer en Studio.
4. Los scripts generados requieren pruebas dentro de la experiencia.
5. Las comprobaciones de seguridad de código son básicas, no una auditoría formal.
6. No todos los valores de propiedades se pueden representar de forma genérica.
7. Algunas propiedades son de solo lectura y serán rechazadas por Roblox.
8. Los objetos de interfaz gobernados por layouts pueden ignorar Position manual.
9. Un ScreenGui puede existir en Studio sin ser visible si se coloca en un contenedor
   equivocado o si sus propiedades de visibilidad y tamaño son incorrectas.
10. Los botones creados visualmente no adquieren comportamiento automáticamente.

RECOMENDACIÓN DE DESPLIEGUE
---------------------------

Instalar primero en una copia de prueba del proyecto. Verificar que la configuración
HTTP esté habilitada si se usa el backend. Probar cada tipo de acción individual antes
de permitir lotes más grandes. Mantener una copia de seguridad antes de usar acciones
de borrado o modificación masiva. Revisar el código de scripts que genere la IA.

FIN DE LA GUÍA TÉCNICA
===============================================================================
]]

--[[
===============================================================================
MANUAL DE OPERACIÓN PROFESIONAL — CASOS DE USO Y CRITERIOS POR DOMINIO
===============================================================================

Esta sección amplía el contrato funcional para que la persona que mantiene el
plugin pueda revisar solicitudes complejas sin confundir construcción con diseño,
ni creación de instancias con comportamiento de juego. Cada caso incluye criterios
mínimos de éxito. No se ejecuta automáticamente y no pretende simular pruebas.

CASO 01 — CREAR UNA TIENDA DE ARTÍCULOS
---------------------------------------

La solicitud debe descomponerse en al menos cuatro partes: interfaz, catálogo de
artículos, comportamiento de compra y estado del jugador. La interfaz incluye un
panel principal, encabezado, botón de cierre, saldo visible, contenedor de tarjetas,
plantilla visual de artículo, etiqueta de precio y botón de compra. El diseño debe
usar UIGridLayout o UIListLayout según el tipo de presentación, no coordenadas
arbitrarias para cada tarjeta. El tamaño del panel debe adaptarse al área visible.

La lógica de compra debe ejecutarse en servidor. El cliente puede solicitar una
compra, pero el servidor debe comprobar que el artículo existe, que el precio es
válido, que el jugador tiene fondos suficientes y que no se está duplicando una
solicitud. Si la compra se acepta, el servidor actualiza el saldo y entrega el
artículo. La interfaz escucha la respuesta y presenta el nuevo saldo o un mensaje
comprensible. El plugin no debe afirmar que la tienda es funcional si solo creó
los elementos visuales.

CASO 02 — CREAR UN INVENTARIO
-----------------------------

Definir si el inventario muestra herramientas, objetos coleccionables, mejoras o
cosméticos. Elegir el tamaño de cuadrícula, número de columnas, orden, estados de
selección y tratamiento de inventario vacío. Cada tarjeta necesita un identificador
estable de artículo. No usar el texto visible como única fuente de verdad para la
lógica. El servidor controla la propiedad real de los objetos cuando corresponda.

La interfaz debe mostrar claramente selección, cantidad y descripción. El estado
seleccionado necesita contraste visible. Si el inventario admite desplazamiento,
CanvasSize debe actualizarse o AutomaticCanvasSize debe estar correctamente
configurado. Un ScrollingFrame debe tener un tamaño útil y una dirección de scroll
coherente. Deben probarse inventarios pequeños y grandes.

CASO 03 — HUD DE MONEDAS Y PROGRESO
----------------------------------

Un HUD debe priorizar la información necesaria durante el juego. Evitar cubrir el
centro de la pantalla si el jugador necesita ver el escenario. Usar anclajes que
mantengan el HUD cerca de las esquinas elegidas. La etiqueta de moneda debe tener
formato consistente y actualizarse sin crear conexiones repetidas. Una barra de
progreso debe tener un contenedor y un relleno; el ancho del relleno se deriva de
un valor normalizado entre cero y uno. No se debe permitir que el valor visual
supere el rango definido.

CASO 04 — MENÚ PRINCIPAL
------------------------

El menú principal necesita una jerarquía visual: título, acción primaria, acciones
secundarias y ajustes. El botón primario debe ser fácil de identificar, pero no
necesita ocupar todo el panel. Las áreas clicables deben tener suficiente tamaño.
La interfaz debe manejar transición a juego, configuración, créditos y salida del
menú si esas funciones existen. Si la lógica todavía no se implementó, el botón no
debe fingir que hizo algo; puede mostrar un mensaje de función pendiente.

CASO 05 — NOTIFICACIONES
------------------------

Las notificaciones deben ser breves, contrastadas y no bloquear acciones esenciales.
Definir posición, anchura máxima, tiempo de permanencia y prioridad. No crear una
nueva pantalla completa por cada notificación. Una lista de notificaciones puede
usar UIListLayout. El sistema debe limpiar las notificaciones antiguas y evitar que
la cantidad crezca sin límite. Los mensajes críticos deben distinguirse de los
mensajes informativos, pero el color no debe ser el único indicador de significado.

CASO 06 — DIÁLOGOS DE CONFIRMACIÓN
----------------------------------

Los diálogos se usan para decisiones importantes, por ejemplo confirmar una compra
costosa o eliminar un objeto. Deben incluir una descripción clara de la acción y
botones con verbos específicos. Evitar dos botones que digan “Sí” sin explicar qué
confirman. El botón de cancelación debe cerrar el diálogo sin realizar la acción.
La acción irreversible debe validarse de nuevo en el servidor si afecta datos del
juego. El diseño no debe atrapar al usuario en un diálogo sin forma de cerrarlo.

CASO 07 — TABLAS DE CLASIFICACIÓN
---------------------------------

Definir columnas, encabezados, alineación numérica, truncamiento de nombres largos
y orden de clasificación. Si los datos se actualizan en tiempo real, evitar recrear
la interfaz completa en cada actualización. Las filas repetidas deben usar una
plantilla o un layout. Los datos globales requieren una fuente confiable; el plugin
no debe inventar clasificaciones o puntuaciones para llenar el panel.

CASO 08 — INTERFACES PARA MÓVIL
-------------------------------

Las zonas táctiles deben tener tamaño suficiente. No depender de hover. El contenido
no debe quedar pegado a bordes difíciles de tocar. Evitar texto demasiado pequeño.
UIScale puede ser útil, pero no debe ser la única técnica de adaptación: los anclajes,
los tamaños relativos, los constraints y los layouts deben diseñarse correctamente.
Probar orientación y relación de aspecto si el juego lo permite.

CASO 09 — INTERFACES PARA PC Y CONSOLA
--------------------------------------

En PC puede haber más espacio, pero la UI no debe estirarse sin límite. Usar
UISizeConstraint o proporciones razonables para mantener la legibilidad. En consola,
los controles deben ser navegables con selección y foco si la experiencia requiere
navegación por gamepad. Un diseño visualmente correcto no garantiza navegación
accesible. Deben definirse estados enfocado, seleccionado, activado y deshabilitado.

CASO 10 — CONSTRUCCIÓN DE UNA TIENDA FÍSICA EN EL MAPA
-----------------------------------------------------

Una tienda física puede incluir edificio, mostrador, letrero, iluminación y un punto
de interacción. El diseño debe diferenciar elementos decorativos de elementos con
colisión. El mostrador no debe bloquear al jugador. El punto de interacción debe
estar al alcance y tener una orientación razonable. Si se usa ProximityPrompt, el
texto de acción y objeto debe describir lo que realmente hace. No crear un botón
visual que no esté conectado a ninguna acción real.

CASO 11 — CONSTRUIR UNA TORRE DE OBSTÁCULOS
-------------------------------------------

Definir altura total, número de pisos, dificultad y punto de reaparición. Cada piso
debe tener un propósito jugable. Los obstáculos deben tener espacio de salto y
colisiones verificables. Los checkpoints deben colocarse en superficies seguras.
La progresión vertical debe ser coherente, con rutas visibles y sin piezas que
bloqueen accidentalmente el siguiente tramo. La estructura debe inspeccionarse desde
la cámara del jugador, no solo desde una vista aérea.

CASO 12 — SISTEMA DE MEJORAS
-----------------------------

Definir cada mejora con un identificador, precio, efecto, nivel máximo y regla de
acumulación. El servidor valida las compras y los límites. La UI presenta precio,
nivel actual, siguiente nivel y estado de compra. El botón debe estar deshabilitado
si el jugador no puede comprar, pero el servidor vuelve a validar la condición. No
confiar en una propiedad Visible o Active del cliente como medida de seguridad.

CASO 13 — REBIRTH / RENACIMIENTO
--------------------------------

La mecánica debe definir requisitos, reinicios, recompensas y elementos que se
conservan. La interfaz explica el costo y el beneficio antes de confirmar. El
servidor valida los requisitos y aplica el cambio de estado. La UI debe reflejar
el nuevo progreso sin depender de un valor enviado libremente por el cliente.

CASO 14 — TELETRANSPORTE Y PORTALES
-----------------------------------

Definir destinos válidos, condiciones de acceso y posición de llegada. La posición
de llegada debe estar libre y sobre una superficie segura. Evitar que el personaje
aparezca dentro de una pared o fuera del mapa. El servidor valida el destino. La UI
muestra una transición o mensaje si el teletransporte está cargando o no disponible.

CASO 15 — SISTEMAS DE RECOLECCIÓN
---------------------------------

Definir objetos recolectables, distancia válida, tiempo de reaparición y recompensa.
El servidor valida que el jugador está suficientemente cerca y que el objeto puede
recolectarse. La interfaz debe mostrar feedback consistente. No crear un sistema que
permita recoger un objeto repetidamente enviando eventos sin límite.

CASO 16 — ANIMACIONES DE INTERFAZ
---------------------------------

Las transiciones deben ser breves y funcionales. No animar todas las propiedades a
la vez si eso perjudica legibilidad. Las animaciones deben poder cancelarse o no
interferir con acciones repetidas. La creación de tweens requiere scripts y no es
una propiedad visual que el constructor de instancias resuelva por sí solo.

CASO 17 — AUDIO Y FEEDBACK
--------------------------

El audio debe tener un propósito claro: confirmación, error, ambiente o evento. El
volumen debe ser razonable y el sistema debe evitar reproducir sonidos en exceso.
La UI puede tener feedback visual además del sonido para usuarios que juegan sin
audio. Los IDs de audio deben ser válidos y tener permisos adecuados en Roblox.

CASO 18 — EFECTOS Y PARTÍCULAS
------------------------------

Los efectos visuales deben usarse con moderación. Definir tasa de emisión, duración,
velocidad y tamaño según el efecto. Evitar emisores que creen demasiadas partículas
por segundo. Los efectos deben estar colocados en attachments o piezas apropiadas.
Si el efecto depende de un evento del juego, se necesita lógica que lo active.

CASO 19 — OPTIMIZACIÓN
----------------------

No crear miles de instancias innecesarias. Agrupar elementos relacionados y evitar
actualizaciones continuas si no son necesarias. Usar layouts con cuidado, porque
muchos cambios de tamaño y posición pueden causar recálculos. Para grandes listas,
considerar reutilizar filas o crear solo elementos visibles. No asumir que una
interfaz es eficiente únicamente porque se ve bien en un proyecto pequeño.

CASO 20 — ACCESIBILIDAD Y LEGIBILIDAD
-------------------------------------

Usar contraste suficiente entre texto y fondo. No comunicar estados únicamente con
color. Mantener etiquetas claras y consistentes. Evitar texto excesivo dentro de
botones. Los mensajes de error deben explicar qué puede hacer el usuario. Revisar
que el texto no quede recortado en diferentes escalas de pantalla.

CASO 21 — MODIFICAR UN PROYECTO EXISTENTE
-----------------------------------------

Antes de editar, inspeccionar la selección y las rutas relevantes. Mantener nombres,
identificadores, atributos y propiedades no solicitadas. No reconstruir todo el
objeto si basta con cambiar una propiedad. Si se cambia una jerarquía, comprobar que
los scripts que referencian la ruta sigan funcionando. No borrar instancias sin una
razón explícita. En operaciones de borrado, mostrar claramente el objetivo.

CASO 22 — REUBICAR OBJETOS
---------------------------

Distinguir mover en el Explorer de mover en el mundo 3D. Para una pieza, definir si
se conserva orientación o si debe rotarse. Para un modelo, usar el pivote y mantener
las relaciones internas entre piezas. Para GUI, comprobar si un layout controla la
posición. Evitar trasladar una parte individual cuando la solicitud se refiere a un
modelo completo. Si falta una referencia espacial crítica, preguntar antes de actuar.

CASO 23 — DUPLICAR OBJETOS
--------------------------

Comprobar Archivable, nombre nuevo y padre. Evitar duplicados con nombres ambiguos.
Si se duplica una GUI, revisar DisplayOrder, Enabled y scripts. Si se duplica un
modelo físico, comprobar si la copia debe desplazarse para no quedar exactamente
superpuesta. No duplicar scripts que puedan crear conexiones o estados duplicados
sin entender su propósito.

CASO 24 — ELIMINAR OBJETOS
--------------------------

Verificar la ruta exacta y la clase antes de borrar. No eliminar Workspace ni el
DataModel. Si la petición es ambigua, inspeccionar primero. Si se elimina una
carpeta con muchos descendientes, informar del alcance. Mantener un punto de deshacer
antes de eliminar. No usar eliminación para “ocultar” una interfaz si basta con
cambiar Visible o Enabled.

CASO 25 — CAMBIAR PROPIEDADES
-----------------------------

Validar que la propiedad pertenece a la clase. Convertir correctamente Vector3,
CFrame, UDim2, Color3 y Enum. Para colores RGB, aclarar si los componentes son 0–255
o normalizados. No silenciar todas las asignaciones fallidas: registrar el nombre de
la propiedad y el error. Para una petición con muchas propiedades, informar cuáles
se aplicaron y cuáles no.

CASO 26 — RUTAS Y NOMBRES
-------------------------

Las rutas son sensibles a la jerarquía y a los nombres exactos. Si el nombre contiene
puntos, la notación separada por puntos puede ser ambigua; una versión futura debería
admitir rutas por segmentos o identificadores. No inventar una ruta si la instancia
no existe. Buscar primero por nombre y clase, inspeccionar resultados y pedir
aclaración si hay varios objetos con nombres similares.

CASO 27 — DATOS DEL PROYECTO
----------------------------

No suponer que todos los servicios son equivalentes a carpetas normales. Algunos
servicios tienen reglas de ubicación. Los scripts de servidor deben ubicarse donde
se ejecuten en servidor y los LocalScripts en contenedores compatibles. Un objeto
puede existir en Explorer sin ejecutarse si está en el servicio equivocado.

CASO 28 — ESTILO VISUAL COHERENTE
---------------------------------

Elegir una paleta limitada, tipografía consistente, radios de esquina similares y
espaciado repetible. El color primario debe reservarse para acciones principales.
El color de error debe comunicar error real, no decoración constante. Los fondos y
bordes deben mantener contraste con texto e iconos. Evitar mezclar muchos estilos
de botones en la misma pantalla sin motivo.

CASO 29 — ESTADOS DE COMPONENTES
--------------------------------

Cada botón puede tener estado normal, hover cuando exista, presionado, deshabilitado
y enfocado. Cada tarjeta puede tener normal, seleccionado y bloqueado. Una barra de
progreso puede tener vacío, parcial y completo. Una tienda puede tener cargando,
lista, error y vacío. Estos estados requieren tanto diseño visual como lógica que
los actualice.

CASO 30 — CARGA Y ERRORES
-------------------------

La interfaz debe diferenciar carga de ausencia de datos. Si la petición falla, no
mostrar una lista vacía como si fuera el resultado correcto. Proporcionar un mensaje
que permita reintentar cuando sea apropiado. Evitar crear nuevas peticiones en cada
frame. Si se reciben datos de servidor, validar sus tipos antes de mostrarlos.

CASO 31 — PRUEBAS DE REGRESIÓN
------------------------------

Después de una mejora del plugin, volver a probar acciones ya soportadas. Un cambio
al constructor de GUI no debe romper creación de piezas. Un cambio al sistema de
rutas no debe romper inspección. Un nuevo lote no debe permitir anidamiento infinito.
Una corrección en colores no debe convertir valores válidos en blancos o negros.

CASO 32 — COMUNICACIÓN CON EL USUARIO
-------------------------------------

La vista previa debe resumir tipo de acción, objetivo, padre, cantidad de objetos y
riesgo cuando se pueda conocer. Los errores deben señalar el índice de acción y la
ruta. No mostrar un JSON enorme sin contexto cuando se puede resumir, aunque el JSON
completo siga disponible para inspección. El mensaje de éxito debe describir lo que
se hizo realmente.

CASO 33 — CONSTRUCCIÓN POR FASES
--------------------------------

Para solicitudes grandes, dividir el trabajo en fases: inspección, plan, creación de
estructura, configuración, scripts, pruebas y revisión. Aplicar cada fase con una
confirmación clara. Si el backend solo puede producir una acción, el plugin puede
seguir funcionando de manera incremental; para una experiencia profesional, el
backend debe entregar lotes pequeños y coherentes.

CASO 34 — LÍMITES DE CONTEXTO
-----------------------------

La inspección del proyecto debe limitar la cantidad de descendientes para no enviar
una respuesta excesiva. Priorizar la selección actual y las rutas relevantes. Si
faltan datos, pedir inspección adicional. No inferir que una instancia no existe
solo porque no apareció en un resumen truncado.

CASO 35 — RESPETO POR EL PROYECTO
---------------------------------

Mantener nombres y estructuras existentes cuando sean útiles. No sustituir un
sistema completo por una plantilla básica sin permiso. Evitar crear duplicados de
RemoteEvents, carpetas o ScreenGuis. Si ya existe un objeto con el nombre solicitado,
inspeccionarlo antes de crear otro. Si el objetivo es actualizarlo, editarlo en lugar
de duplicarlo.

CASO 36 — CRITERIO DE “LISTO”
-----------------------------

Una función solo está lista cuando se ha creado, configurado, probado y revisado en
el contexto adecuado. Crear un ScreenGui no significa que la tienda esté terminada.
Crear un script no significa que la mecánica funcione. Crear un modelo no significa
que el mapa sea jugable. El plugin debe usar lenguaje preciso y no prometer una
calidad que no ha verificado.

CASO 37 — FUTURAS MEJORAS DEL PLUGIN
------------------------------------

- Vista de árbol para previsualizar jerarquías antes de crearlas.
- Comparación de propiedades antes/después.
- Reversión de lote basada en un diario de instancias.
- Captura visual de GUI en Play/Test cuando exista una API apropiada.
- Detección de solapamiento visual basada en límites absolutos.
- Editor de tokens de estilo compartidos.
- Plantillas verificadas para tienda, inventario, HUD y menú.
- Pruebas automáticas para conversiones de tipos.
- Registro exportable de acciones y errores.
- Verificación de scripts con reglas por tipo de sistema.
- Inspección selectiva por ruta para reducir datos.
- Confirmación reforzada para eliminación masiva.
- Detección de cambios externos entre inspección y aplicación.
- Vista previa de movimiento de modelos y GUI.
- Validación del orden de dependencias en lotes.

CASO 38 — REQUISITOS PARA EL BACKEND
------------------------------------

El backend debe reconocer la intención del usuario, inspeccionar el contexto,
seleccionar una acción compatible, construir los campos obligatorios y comprobar
que el JSON sea válido. Para GUI avanzada debe generar uiTree con nombres estables,
clases permitidas, propiedades compatibles y estilos coherentes. Para lotes debe
ordenar la creación de padres antes que hijos, limitar el número de acciones y evitar
acciones destructivas inesperadas. Si una acción no es compatible con el plugin,
debe pedir una alternativa o generar una secuencia compatible.

CASO 39 — COMPATIBILIDAD DE VERSIONES
-------------------------------------

El plugin y el backend deben acordar el contrato de acciones. El plugin V8 puede
aceptar acciones nuevas, pero una página web que solo genera acciones antiguas no
aprovecha automáticamente las capacidades nuevas. Antes de publicar, comparar los
tipos de acción en ambos lados y probar una operación real. Mantener una versión
visible en el plugin ayuda a diagnosticar diferencias entre el código instalado y
el código esperado.

CASO 40 — EXPECTATIVAS REALISTAS
--------------------------------

Este plugin es una herramienta de construcción asistida. Las mejoras del ejecutor
no convierten automáticamente al modelo en un desarrollador con experiencia real,
ni garantizan que todas las creaciones funcionen a la primera. La calidad depende
del modelo, las instrucciones del backend, la inspección, las acciones disponibles,
el contexto enviado y las pruebas. El objetivo del diseño es dar al modelo mejores
herramientas, límites claros y un ciclo de revisión verificable.

===============================================================================
FIN DEL MANUAL DE OPERACIÓN
===============================================================================
]]

--[[
===============================================================================
CATÁLOGO DE PRUEBAS Y DIAGNÓSTICO PARA MANTENIMIENTO
===============================================================================

Cada prueba debe ejecutarse en una copia del lugar. La salida esperada se expresa
como criterio observable, no como una afirmación de que la prueba ya se ejecutó.

PRUEBA 01: ScreenGui simple
Entrada: CREATE_GUI con un árbol Frame + TextLabel.
Esperado: ScreenGui bajo StarterGui, Frame hijo y etiqueta dentro del Frame.

PRUEBA 02: Panel centrado
Entrada: AnchorPoint {0.5,0.5}, Position {0.5,0,0.5,0}.
Esperado: panel centrado dentro del área de contenido.

PRUEBA 03: Panel de tamaño relativo
Entrada: Size {0.8,0,0.7,0}.
Esperado: ancho 80% y alto 70% del contenedor padre.

PRUEBA 04: Panel de tamaño fijo
Entrada: Size {0,600,0,400}.
Esperado: 600x400 píxeles de offset, sujeto al viewport.

PRUEBA 05: Botón con estilo
Entrada: TextButton, BackgroundColor3, TextColor3, UICorner.
Esperado: botón visible y legible.

PRUEBA 06: Lista vertical
Entrada: Frame con UIListLayout y varios botones.
Esperado: elementos ordenados según SortOrder y Padding.

PRUEBA 07: Cuadrícula
Entrada: Frame con UIGridLayout, CellSize y CellPadding.
Esperado: tarjetas distribuidas en celdas.

PRUEBA 08: Colores RGB
Entrada: [255,0,0].
Esperado: rojo puro, no un valor normalizado fuera de rango.

PRUEBA 09: Colores normalizados
Entrada: {r=1,g=0,b=0}.
Esperado: rojo puro.

PRUEBA 10: Propiedad desconocida
Entrada: propiedad fuera de GUI_PROPERTY_ALLOWLIST.
Esperado: acción rechazada antes de crear la interfaz.

PRUEBA 11: Clase no permitida
Entrada: clase que no está en GUI_ALLOWED_CLASSES.
Esperado: rechazo explícito.

PRUEBA 12: Árbol demasiado profundo
Entrada: más de 18 niveles.
Esperado: rechazo de validación.

PRUEBA 13: Árbol demasiado grande
Entrada: más de 450 objetos UI.
Esperado: rechazo de validación.

PRUEBA 14: Error durante la construcción
Entrada: propiedad incompatible con la clase.
Esperado: ScreenGui temporal destruida y error claro.

PRUEBA 15: Informe GUI
Entrada: INSPECT_GUI.
Esperado: lista de ScreenGui con cantidad de descendientes y advertencias.

PRUEBA 16: Lote correcto
Entrada: dos acciones válidas independientes.
Esperado: resultados en orden y waypoint antes/después.

PRUEBA 17: Lote anidado
Entrada: BATCH_ACTIONS dentro de BATCH_ACTIONS.
Esperado: rechazo explícito.

PRUEBA 18: Lote grande
Entrada: 81 acciones.
Esperado: rechazo por límite.

PRUEBA 19: Ruta inválida
Entrada: ruta de destino inexistente.
Esperado: error con ruta.

PRUEBA 20: Mover una pieza
Entrada: MOVE_INSTANCE con path y position.
Esperado: cambio de padre si se especifica y reposicionamiento físico.

PRUEBA 21: Mover un modelo
Entrada: MOVE_INSTANCE con Model y position.
Esperado: PivotTo conserva la orientación existente.

PRUEBA 22: Mover una GUI administrada por layout
Entrada: GUI dentro de UIListLayout y cambio de Position.
Esperado: comprobar que el layout puede controlar la posición final.

PRUEBA 23: Inspección de texto
Entrada: seleccionar TextLabel con texto.
Esperado: result.text contiene cadena, no true/false.

PRUEBA 24: Inspección de pieza
Entrada: seleccionar BasePart.
Esperado: posición, tamaño, anclaje, colisión y material disponibles.

PRUEBA 25: Propiedad de solo lectura
Entrada: intentar cambiar una propiedad no asignable.
Esperado: error o advertencia contextual.

PRUEBA 26: Nombre vacío
Entrada: nombre vacío.
Esperado: nombre alternativo seguro.

PRUEBA 27: Duplicación
Entrada: instancia Archivable.
Esperado: clon bajo el padre correcto con nombre alternativo.

PRUEBA 28: Eliminación
Entrada: DELETE_INSTANCE de un objeto específico.
Esperado: objeto eliminado y waypoint de deshacer.

PRUEBA 29: Script permitido
Entrada: Script corto en ServerScriptService.
Esperado: Script insertado y seleccionado.

PRUEBA 30: Script prohibido
Entrada: ubicación no permitida.
Esperado: acción rechazada.

PRUEBA 31: Script excesivo
Entrada: source mayor que el límite.
Esperado: acción rechazada.

PRUEBA 32: Error HTTP
Entrada: backend no disponible.
Esperado: plugin registra el fallo y vuelve a intentar después.

PRUEBA 33: Sesión sin página
Entrada: código registrado pero página no conectada.
Esperado: estado desconectado/esperando sin crear acciones.

PRUEBA 34: Acción pendiente
Entrada: llega una acción mientras otra espera confirmación.
Esperado: no sobrescribir la acción pendiente.

PRUEBA 35: Rechazo de acción
Entrada: usuario pulsa Rechazar.
Esperado: no se modifica el proyecto.

PRUEBA 36: Confirmación de acción
Entrada: usuario pulsa Confirmar.
Esperado: ejecutar la acción y registrar el resultado.

PRUEBA 37: Duplicados de UI
Entrada: crear dos ScreenGui con mismo nombre.
Esperado: comportamiento documentado; una mejora futura puede prevenir duplicados.

PRUEBA 38: Orden de capas
Entrada: varias ScreenGui con DisplayOrder distinto.
Esperado: la interfaz con orden superior se muestra por encima cuando corresponde.

PRUEBA 39: Texto largo
Entrada: título con muchas palabras.
Esperado: TextWrapped y dimensiones suficientes; verificar clipping en Play/Test.

PRUEBA 40: Tamaño móvil
Entrada: viewport estrecho.
Esperado: interfaz no queda fuera de pantalla; ajustar escalado y constraints.

PRUEBA 41: UI con botón solo icono
Entrada: ImageButton sin texto.
Esperado: no se trata como error si el icono es intencional.

PRUEBA 42: Panel invisible
Entrada: Visible=false intencional.
Esperado: la revisión no lo considera automáticamente un fallo de construcción.

PRUEBA 43: Scroll vacío
Entrada: ScrollingFrame sin hijos.
Esperado: panel visible con estado vacío si el diseño lo requiere.

PRUEBA 44: Reutilización de nombres
Entrada: actualizar UI existente.
Esperado: backend inspecciona y decide entre editar y crear para evitar duplicados.

PRUEBA 45: Cambio de padre
Entrada: MOVE_INSTANCE con parentPath válido.
Esperado: nueva jerarquía y mensaje de éxito exacto.

PRUEBA 46: Ciclo de jerarquía
Entrada: intentar colocar padre dentro de descendiente.
Esperado: rechazo antes de mutar la jerarquía.

PRUEBA 47: Color incorrecto
Entrada: tabla incompleta de color.
Esperado: conversión segura o error claro, nunca fallo silencioso sin registro.

PRUEBA 48: Enum inválido
Entrada: nombre de enum inexistente.
Esperado: conversión rechazada con contexto.

PRUEBA 49: Posición parcial
Entrada: coordenadas con componente omitido.
Esperado: conservar la coordenada actual para el componente omitido.

PRUEBA 50: Auditoría final
Entrada: ejecutar una tarea con varios tipos de objeto.
Esperado: inspeccionar cada dominio solicitado y comunicar lo que no se pudo probar.

REGISTRO DE RESULTADOS SUGERIDO
-------------------------------

Para cada prueba, anotar fecha, versión de Studio, versión del plugin, contrato de
backend, resultado observado, error exacto y pasos para reproducir. No marcar una
prueba como aprobada solo porque no apareció un error visible. Revisar el resultado
en Explorer y en la experiencia ejecutándose. Si una prueba falla, aislar la función
responsable antes de modificar varias partes al mismo tiempo.

===============================================================================
FIN DEL CATÁLOGO DE PRUEBAS
===============================================================================
]]

--[[
APÉNDICE FINAL: REGLAS DE PUBLICACIÓN
- Actualizar el backend para que emita CREATE_GUI con uiTree cuando corresponda.
- Actualizar el backend para que emita BATCH_ACTIONS solo con acciones compatibles.
- Probar en un lugar de desarrollo, no en el único archivo de producción.
- Guardar el lugar antes de probar acciones destructivas.
- Verificar las jerarquías en Explorer después de cada fase.
- Probar la interfaz en Play/Test, no solo en el editor.
- Revisar el código generado antes de publicarlo.
- Registrar fallos reproducibles con la versión exacta del plugin.
- No considerar los comentarios de este archivo como evidencia de pruebas aprobadas.
- El resultado depende también de la calidad y compatibilidad del backend.
]]
-- Lista de comprobación antes de compartir una versión:
-- 01. Confirmar que el archivo empieza con el encabezado V8.
-- 02. Confirmar que no contiene el envoltorio XML de Roblox.
-- 03. Confirmar que todas las funciones llamadas están declaradas.
-- 04. Confirmar que las rutas permitidas coinciden con los servicios disponibles.
-- 05. Confirmar que las conversiones de Enum aceptan tablas enum/name.
-- 06. Confirmar que UDim2 usa cuatro componentes en el orden documentado.
-- 07. Confirmar que los colores son RGB o normalizados de forma explícita.
-- 08. Confirmar que las acciones de borrado no se ejecutan sin confirmación.
-- 09. Confirmar que un lote tiene límite y no permite anidamiento.
-- 10. Confirmar que el informe estructural no se presenta como análisis visual.
-- 11. Confirmar que la interfaz del plugin no bloquea el hilo principal.
-- 12. Confirmar que el polling no reemplaza una acción pendiente.
-- 13. Confirmar que las respuestas del servidor se decodifican como JSON.
-- 14. Confirmar que los errores HTTP se registran sin detener el plugin.
-- 15. Confirmar que los mensajes de éxito describen la acción real.
-- 16. Confirmar que las rutas a instancias nuevas se crean en el orden correcto.
-- 17. Confirmar que el usuario puede rechazar cualquier acción pendiente.
-- 18. Confirmar que la selección de Studio refleja el objeto recién creado.
-- 19. Confirmar que la creación fallida limpia las instancias temporales.
-- 20. Confirmar que el script se prueba en una copia del lugar.
-- 21. Confirmar que el backend documenta los nuevos tipos de acción.
-- 22. Confirmar que las pruebas se repiten tras cambios importantes.
-- 23. Confirmar que los límites se mantienen aunque el backend sea defectuoso.
-- 24. Confirmar que las acciones que no admite el plugin no se prometen.
-- 25. Confirmar que la versión publicada coincide con la versión instalada.
-- 26. Confirmar que el usuario conserva control de cambios destructivos.
-- 27. Confirmar que el rendimiento se revisa con proyectos de tamaño realista.
-- 28. Confirmar que los errores contienen ruta, tipo y contexto útil.
-- 29. Confirmar que no se da por funcional una UI solo por existir en Explorer.
-- 30. Confirmar que no se da por correcta una construcción solo por tener piezas.


--[[
===============================================================================
MEGA V9.0 — CONTRATOS DE ACCIONES, LÍMITES Y PRUEBAS DE ACEPTACIÓN
===============================================================================
Este apéndice sirve como contrato legible por el equipo de backend. No se ejecuta.
Cada acción debe validarse en el plugin aunque el modelo afirme que ya está validada.
El modelo no obtiene poderes nuevos por cambiar su prompt: solo puede usar las
operaciones implementadas en este archivo y las APIs disponibles para un plugin.

CATÁLOGO DE ACCIONES NUEVAS
---------------------------

CREATE_MODEL_BLUEPRINT
  name: string
  parent: ruta existente, por ejemplo Workspace
  objects: lista de hasta 250 piezas con name, shape, size, position, rotation,
           color, material, anchored, canCollide, transparency y reflectance
  primaryPart: nombre opcional de una BasePart hija
  pivot: [x,y,z] opcional
  Resultado: un Model con las piezas solicitadas. No crea lógica de juego.

CREATE_CONSTRAINT
  className: WeldConstraint, Weld, Motor6D, HingeConstraint, BallSocketConstraint,
              RopeConstraint, SpringConstraint, RodConstraint, CylindricalConstraint,
              PrismaticConstraint, AlignPosition, AlignOrientation, NoCollisionConstraint,
              VectorForce, LinearVelocity, AngularVelocity, Torque o LineForce
  parent: ruta destino
  attachment0 / attachment1: rutas opcionales a Attachment
  part0 / part1: rutas opcionales a BasePart para tipos compatibles
  properties: propiedades adicionales convertibles
  Nota: algunos constraints requieren attachments, límites o configuración física.

APPLY_LIGHTING_PRESET
  preset: BrightDay | Sunset | Night | Horror | Cartoon | StudioNeutral
  atmosphere: false para no crear/editar Atmosphere
  density, offset, atmosphereColor, decayColor, glare, haze: opcionales
  colorCorrection: true para habilitar ColorCorrectionEffect de ABX
  ccBrightness, contrast, saturation, tint: opcionales
  Nota: la iluminación es una base artística; revisa el mapa completo en Play/Test.

CREATE_TERRAIN
  operation: FillBlock | FillBall | FillCylinder | ReplaceMaterial | Clear
  position: [x,y,z]
  size: [x,y,z] para bloque o región de reemplazo
  radius: número para bola/cilindro
  height: número para cilindro
  material: nombre de Enum.Material
  sourceMaterial: material que se sustituye en ReplaceMaterial
  confirmClear: true obligatorio para Clear
  Nota: usa regiones pequeñas primero; el terreno afecta una zona amplia del mundo.

SET_TERRAIN_WATER
  position, size, water: false para rellenar con Air; de lo contrario Water
  Nota: esta acción es deliberadamente explícita y puede alterar terreno existente.

CREATE_SOUND
  parent, name, soundId, volume, playbackSpeed, looped, rollOffMaxDistance,
  rollOffMinDistance, play
  Nota: un SoundId no garantiza que el asset exista o que la experiencia tenga permiso.

CREATE_EFFECT
  className: ParticleEmitter, Trail, Beam, Smoke, Fire, Sparkles, PointLight,
              SpotLight, SurfaceLight, Highlight, BloomEffect, BlurEffect,
              ColorCorrectionEffect, DepthOfFieldEffect, SunRaysEffect o Atmosphere
  parent, name, properties y parámetros de conveniencia
  Nota: Trail y Beam suelen requerir Attachment0 y Attachment1; el plugin no inventa
  referencias sin recibirlas. Los efectos en Lighting deben tener padre Lighting.

SET_ATTRIBUTES
  target o path, attributes: tabla de valores string/number/boolean
  Límite de valor string: 2000 caracteres. No se admiten tablas anidadas ni Instances.

MANAGE_TAGS
  target o path, operation: Add | Remove | List, tag
  CollectionService conserva etiquetas útiles para scripts de gameplay y organización.

CREATE_TEAM
  name, teamColor, autoAssignable
  Crea un Team en Teams; no genera reglas de puntuación o spawn por sí solo.

CREATE_TOOL
  name, parent, requiresHandle, createHandle, handleSize, handleColor, handleMaterial,
  canBeDropped, tooltip
  La lógica de Activated/Equipped debe escribirse aparte y probarse en cliente/servidor.

CREATE_CHECKPOINT_SET
  count (1-100), startPosition, spacing, size, color, parent, neutral
  Crea SpawnLocations etiquetados con atributo CheckpointIndex. No configura por sí
  solo el sistema de progreso ni el respawn por checkpoint.

CREATE_ATTACHMENT
  parent debe ser BasePart o Bone; position y orientation opcionales

CREATE_PROXIMITY_PROMPT
  parent, name, actionText, objectText, keyCode, holdDuration, maxDistance,
  requiresLineOfSight, enabled
  No conecta Triggered automáticamente a una economía ni a lógica del servidor.

CREATE_DECORATION_SET
  center, count (1-200), radius, height, width, color, material, canCollide, parent
  Crea cilindros decorativos genéricos; no sustituye modelos artísticos específicos.

INSPECT_SCRIPT
  target o path, includeSource opcional
  Devuelve conteos estáticos aproximados. No ejecuta el script, no analiza todas las
  rutas de control ni demuestra ausencia de errores o vulnerabilidades.

VALIDATE_PROJECT
  maxObjects opcional (100-100000)
  Revisa algunos errores estructurales evidentes en servicios conocidos. No reemplaza
  pruebas funcionales, pruebas de red, pruebas de seguridad ni Play Solo/Start Server.

LIST_CAPABILITIES
  No necesita parámetros. Devuelve el catálogo que reconoce este plugin. El backend
  debe consultar o mantener una copia sincronizada de este catálogo.

REGLAS DE PLANIFICACIÓN PARA EL MODELO
-------------------------------------
1. Si la petición cambia una instancia existente, inspecciona la ruta antes de editar.
2. Si una ruta no existe, crea el padre primero; nunca asumas que una ruta se creará sola.
3. Si se solicita un juego completo, separa mapa, UI, datos, lógica de servidor, lógica
   de cliente, remotos, feedback, pruebas y pulido visual en fases verificables.
4. La UI y la lógica deben tener contratos compatibles: nombres de RemoteEvent,
   atributos, nombres de objetos, clases y rutas deben coincidir exactamente.
5. Nunca confíes en una cantidad de monedas, precio o recompensa enviada por el cliente.
6. Valida compras, recompensas, progreso y cooldowns en servidor cuando corresponda.
7. No generes un RemoteEvent sin planear quién lo escucha y qué valida.
8. No declares que DataStore funciona sin probar la experiencia publicada y permisos.
9. No declares que una UI es profesional solo porque sus instancias se crearon.
10. Usa layouts, constraints y escalado en interfaces que deban adaptarse a móvil.
11. Evita construir cientos de piezas individuales cuando un modelo o terreno sea mejor.
12. Usa nombres claros y carpetas por sistema; no llenes Workspace con objetos sueltos.
13. No repitas acciones de creación si una inspección muestra que ya existen los objetos.
14. Si una acción falla, detén la fase dependiente y reporta la ruta y el error exacto.
15. Después de construir, inspecciona el resultado y compara contra requisitos explícitos.
16. Distingue entre completado, parcialmente completado, pendiente de prueba y bloqueado.
17. Nunca describas una operación no implementada como si el plugin la soportara.
18. No ocultes errores con pcall sin registrar un mensaje útil para el usuario.
19. Usa BATCH_ACTIONS para operaciones pequeñas con dependencias claras, no para todo.
20. Mantén acciones destructivas fuera de lotes salvo autorización explícita revisada.
21. No elimines una instancia si no se ha comprobado la ruta y el propósito.
22. Para crear scripts, indica su ubicación y su autoridad esperada (cliente/servidor).
23. Los LocalScripts no son adecuados para validar economía ni otorgar recompensas.
24. Los ModuleScripts necesitan una estrategia de require compatible con la seguridad.
25. Si el backend no entiende una acción, no la envíes repetidamente en un bucle.
26. Si el backend entrega un árbol enorme, divídelo en fases respetando dependencias.
27. Los assets de audio, imagen y malla requieren IDs válidos y permisos del creador.
28. Los Terrain operations deben usar regiones pequeñas y coordenadas revisadas.
29. Las luces y efectos deben respetar rendimiento y legibilidad de la escena.
30. En proyectos grandes, limita las inspecciones a una ruta o servicio concreto.

MATRIZ DE PRUEBAS NUEVAS
------------------------
Las pruebas siguientes son propuestas de aceptación. No están marcadas como ejecutadas.

T01. LIST_CAPABILITIES devuelve un objeto JSON con actionTypes y count coherente.
T02. CREATE_MODEL_BLUEPRINT crea un Model y todas las piezas dentro del modelo.
T03. CREATE_MODEL_BLUEPRINT con 0 piezas falla sin dejar un modelo vacío.
T04. CREATE_MODEL_BLUEPRINT con más de 250 piezas se rechaza antes de mutar Studio.
T05. CREATE_MODEL_BLUEPRINT con un dato de pieza mal formado elimina el modelo temporal.
T06. CREATE_MODEL_BLUEPRINT con primaryPart inexistente crea el modelo sin asignar PrimaryPart.
T07. CREATE_MODEL_BLUEPRINT con pivot reposiciona el modelo completo.
T08. CREATE_CONSTRAINT con clase no permitida falla sin crear instancia persistente.
T09. CREATE_CONSTRAINT con attachment inexistente devuelve error de ruta.
T10. CREATE_CONSTRAINT con Parent inválido limpia la instancia temporal.
T11. APPLY_LIGHTING_PRESET BrightDay ajusta ClockTime y valores base.
T12. APPLY_LIGHTING_PRESET con preset inválido no cambia Lighting.
T13. APPLY_LIGHTING_PRESET crea o reutiliza Atmosphere sin duplicados.
T14. APPLY_LIGHTING_PRESET con atmosphere=false no altera Atmosphere existente.
T15. APPLY_LIGHTING_PRESET con colorCorrection=true crea o reutiliza el efecto.
T16. CREATE_TERRAIN FillBlock rellena una región pequeña con el material pedido.
T17. CREATE_TERRAIN FillBall limita radio a valores seguros.
T18. CREATE_TERRAIN ReplaceMaterial rechaza material de origen desconocido.
T19. CREATE_TERRAIN Clear sin confirmClear falla antes de editar.
T20. CREATE_TERRAIN con Enum.Material inexistente falla con mensaje entendible.
T21. SET_TERRAIN_WATER usa Air cuando water=false.
T22. CREATE_SOUND conserva SoundId y parámetros de volumen válidos.
T23. CREATE_SOUND con volumen negativo se limita a cero.
T24. CREATE_EFFECT con clase no permitida se rechaza.
T25. CREATE_EFFECT con propiedad inválida limpia el efecto parcial.
T26. CREATE_EFFECT PointLight establece color, rango y brillo.
T27. SET_ATTRIBUTES cambia varios atributos simples en una misma acción.
T28. SET_ATTRIBUTES rechaza una tabla anidada sin aplicar ese valor.
T29. MANAGE_TAGS Add agrega la etiqueta esperada.
T30. MANAGE_TAGS Remove elimina la etiqueta esperada.
T31. MANAGE_TAGS List devuelve las etiquetas actuales en vista previa.
T32. CREATE_TEAM crea Team en el servicio Teams.
T33. CREATE_TEAM con color inválido devuelve error sin equipo huérfano.
T34. CREATE_TOOL con RequiresHandle y sin handle falla claramente.
T35. CREATE_TOOL con createHandle genera una pieza llamada Handle.
T36. CREATE_TOOL con requiresHandle=false no exige Handle.
T37. CREATE_CHECKPOINT_SET limita count a 100.
T38. CREATE_CHECKPOINT_SET asigna CheckpointIndex creciente a cada SpawnLocation.
T39. CREATE_CHECKPOINT_SET con error intermedio elimina el modelo temporal.
T40. CREATE_ATTACHMENT rechaza padre que no sea BasePart o Bone.
T41. CREATE_PROXIMITY_PROMPT aplica duración y distancia dentro de límites.
T42. CREATE_DECORATION_SET limita cantidad y crea una sola carpeta-modelo de agrupación.
T43. INSPECT_SCRIPT rechaza un objeto que no sea LuaSourceContainer.
T44. INSPECT_SCRIPT sin includeSource no expone el código completo en la vista previa.
T45. INSPECT_SCRIPT con Source inaccesible muestra un error contextual.
T46. VALIDATE_PROJECT limita el total de objetos inspeccionados.
T47. VALIDATE_PROJECT encuentra una pieza con dimensiones inválidas si Studio permite el caso.
T48. VALIDATE_PROJECT marca scripts vacíos como advertencia, no como prueba de fallo total.
T49. BATCH_ACTIONS rechaza un lote anidado.
T50. BATCH_ACTIONS prevalidará la forma de todas las acciones antes de iniciar el lote.
T51. BATCH_ACTIONS rechaza DELETE_INSTANCE si no se autoriza allowDestructive.
T52. BATCH_ACTIONS se detiene en el primer fallo y comunica el índice.
T53. BATCH_ACTIONS crea waypoints antes y después de un lote completado.
T54. Una acción rechazada desde la UI no modifica el proyecto.
T55. Un error de red no bloquea permanentemente el polling.
T56. El polling no sustituye una acción que sigue pendiente de confirmación.
T57. Una acción desconocida devuelve error y no realiza cambios.
T58. Una ruta con padre inexistente se rechaza sin crear un árbol alternativo.
T59. El usuario puede deshacer un cambio simple con Undo de Studio.
T60. La revisión de interfaz se repite en viewport grande y pequeño.
T61. Las piezas ancladas no se mueven por física durante la prueba visual.
T62. Los modelos que requieren física tienen colisiones verificadas.
T63. Las luces no se colocan en servicios equivocados.
T64. Los sonidos se revisan por permisos y moderación de assets.
T65. Los prompts no otorgan recompensas sin validación de servidor.
T66. Los remotos se revisan para que el cliente no controle valores sensibles.
T67. Los scripts generados se leen y prueban antes de publicar.
T68. La auditoría de proyecto se ejecuta en una copia de desarrollo.
T69. Las operaciones de terreno se revisan en regiones limitadas.
T70. Las funciones se validan en una versión real de Studio antes de anunciarse.

LÍMITES QUE NO DEBE OCULTAR EL BACKEND
--------------------------------------
- Un plugin no dispone automáticamente de cada función de Roblox Studio como una API.
- El plugin no puede confirmar visualmente que un mapa es bonito sin una inspección visual.
- La API de Terrain es destructiva por región y debe usarse con cuidado.
- La lectura/escritura de Source puede depender de permisos y contexto del plugin.
- Un punto de deshacer no es una transacción atómica con rollback garantizado.
- Un script generado puede tener errores de sintaxis, lógica, seguridad o rendimiento.
- Crear RemoteEvents no crea el contrato cliente-servidor ni sus validaciones.
- Crear una UI no conecta automáticamente sus botones a sistemas de juego.
- Un modelo 3D requiere assets o geometría disponible; no se puede inventar un asset ID válido.
- Los DataStores y otras APIs de runtime requieren pruebas en el entorno adecuado.
- Las operaciones de publicación, monetización y permisos no se simulan como completadas.
- El backend debe sincronizar los tipos de acción con la versión instalada del plugin.

GUÍA DE RESPUESTA DEL AGENTE
----------------------------
Al terminar una fase, el agente debe devolver:
1. Resumen corto de lo que creó o modificó.
2. Rutas exactas de las instancias creadas.
3. Sistemas todavía pendientes de conectar.
4. Errores de acciones con índice y causa.
5. Pruebas que aún deben ejecutarse en Play/Test.
6. Si se cambió código, ubicación exacta y autoridad cliente/servidor.
7. Si hay riesgos de rendimiento o seguridad que requieren revisión.
8. La siguiente fase mínima que desbloquea la petición original.

No se debe confundir una respuesta extensa con una solución completa. El éxito se mide
por consistencia de jerarquía, código compatible, pruebas reproducibles, facilidad de
mantenimiento, seguridad de la experiencia y fidelidad a la petición del creador.

FIN DEL APÉNDICE V9.0
===============================================================================
]]

--[[
===============================================================================
MEGA V9.0 ULTRA — GUÍA DE INTEGRACIÓN DEL BACKEND Y REGRESIÓN
===============================================================================
Este bloque documenta cómo debe hablar el backend con el plugin. La documentación
no ejecuta llamadas de red y no concede permisos adicionales a la IA.

PROTOCOLO DE SESIÓN
-------------------
1. El usuario pulsa Generar código en Studio.
2. El plugin envía POST /register con un código de cinco dígitos.
3. La página web vincula ese código con la sesión de trabajo del usuario.
4. El plugin sondea GET /poll/<code> aproximadamente cada tres segundos.
5. La respuesta puede indicar que no hay acción o incluir un JSON de acción.
6. El plugin muestra el JSON en la vista previa y espera la confirmación del usuario.
7. Al confirmar, se ejecuta la acción y se informa el resultado en el panel.
8. Si se rechaza, no se ejecuta esa acción y el polling puede continuar.
9. No se debe aceptar una segunda acción que reemplace una acción pendiente.
10. El backend debe tratar los códigos como identificadores temporales, no como claves secretas.

ESQUEMA GENERAL DE ACCIÓN
-------------------------
{
  "type": "TIPO_DE_ACCION",
  "name": "NombreOpcional",
  "parent": "Ruta.Existente",
  "metadata": {
    "requestId": "identificador-opcional",
    "phase": "fase-opcional",
    "reason": "motivo-breve"
  }
}

El campo type es obligatorio y distingue mayúsculas/minúsculas. Las propiedades
adicionales dependen del tipo. No enviar funciones, userdata, instancias ni objetos
JSON circulares. Las rutas son cadenas de nombres separadas por puntos y deben existir
antes de que una acción intente utilizarlas.

ORDEN RECOMENDADO PARA CONSTRUIR UN JUEGO
----------------------------------------
Fase 1 — Reconocimiento
- Ejecutar INSPECT_PROJECT para obtener el tamaño aproximado del proyecto.
- Ejecutar FIND_INSTANCES para localizar sistemas existentes por nombre.
- Ejecutar INSPECT_PATH en modelos y scripts importantes.
- Evitar crear duplicados de carpetas, UI, remotos o scripts.

Fase 2 — Plan de jerarquía
- Definir carpetas de Workspace, ReplicatedStorage, ServerScriptService y StarterGui.
- Definir nombres de remotos y valores compartidos.
- Definir qué código es autoritativo en servidor y qué código es de presentación.
- Definir las dependencias que deben crearse primero.

Fase 3 — Mundo físico
- Crear el suelo y los límites antes de decoraciones pequeñas.
- Usar modelos agrupados para estructuras relacionadas.
- Usar Terrain solo cuando sea apropiado para terreno orgánico.
- Revisar tamaño, anclaje, colisiones y orientación.
- Mantener un SpawnLocation válido y una ruta de prueba despejada.

Fase 4 — Datos y comunicación
- Crear remotos con nombres consistentes.
- Validar parámetros de cualquier RemoteEvent en el servidor.
- No confiar en el cliente para precio, saldo, premio o permisos.
- Crear valores de demostración solo si no se presentan como guardado persistente.
- Evitar guardar datos sensibles o confiar en datos manipulados por el cliente.

Fase 5 — Interfaz
- Crear ScreenGui y un árbol UI declarativo.
- Usar AnchorPoint, Scale, constraints y layouts cuando ayuden a la adaptación.
- Dar nombres inequívocos a botones, etiquetas, contenedores y campos de texto.
- Proporcionar estados de carga, éxito, error, vacío y falta de recursos.
- Comprobar contraste, recorte, texto largo, navegación y tamaños pequeños.
- Conectar cada botón con un contrato de gameplay que realmente exista.

Fase 6 — Código
- Crear scripts pequeños por responsabilidad.
- No colocar lógica sensible de economía en LocalScripts.
- No insertar dependencias desconocidas ni require() externo no revisado.
- Añadir validaciones, límites, cooldowns y mensajes de error.
- Inspeccionar el código fuente generado cuando sea posible.

Fase 7 — Verificación
- Ejecutar VALIDATE_PROJECT para detectar algunas anomalías estructurales.
- Revisar jerarquías y propiedades en Explorer.
- Ejecutar Play Solo y luego pruebas de servidor/cliente si el sistema es multijugador.
- Comprobar interacciones reales, respawn, muerte, reingreso y errores de red.
- No declarar terminado un sistema que solo fue creado en Explorer.

Fase 8 — Optimización
- Reducir piezas innecesarias y efectos demasiado frecuentes.
- Evitar loops de alta frecuencia que no necesitan ejecutarse cada frame.
- Usar eventos en lugar de polling local cuando sea apropiado.
- Medir rendimiento con el juego en ejecución y varios jugadores de prueba.
- Mantener nombres y estructura fáciles de depurar.

Fase 9 — Entrega
- Informar rutas creadas, scripts modificados y pruebas realizadas.
- Separar las pruebas ejecutadas de las pruebas recomendadas.
- Mencionar assets que requieren IDs válidos o permisos.
- Guardar una copia antes de acciones destructivas importantes.
- No afirmar que el juego está listo para publicar sin una prueba completa.

GUÍA DE DIAGNÓSTICO POR SÍNTOMA
-------------------------------
Síntoma: la acción no aparece en Studio.
- Revisar si el código de sesión está conectado.
- Revisar la respuesta de /poll y el JSON recibido.
- Comprobar si hay una acción pendiente que impide otro sondeo.
- Revisar el registro del plugin y la salida de Studio.
- Confirmar que el backend usa un tipo de acción compatible con esta versión.

Síntoma: la instancia se crea, pero no está en el lugar esperado.
- Comprobar parent y la ruta real.
- Comprobar si el objeto es BasePart, Model o GuiObject.
- Comprobar si se envió posición en coordenadas del mundo o de un contenedor.
- Para Model, preferir PivotTo cuando el objetivo es mover el conjunto.
- En GUI, comprobar si UIListLayout/UIGridLayout controla la posición.

Síntoma: los colores son incorrectos.
- Confirmar si la entrada usa RGB 0–255 o canales normalizados 0–1.
- Confirmar que se envían tres componentes y no un valor hex como texto.
- Comprobar que las propiedades son Color3, BrickColor o un Enum válido.
- Comprobar que no se sobrescribe el color con una propiedad de estilo posterior.

Síntoma: una interfaz está creada pero no se ve bien.
- Revisar Visible, Enabled, DisplayOrder y ZIndex.
- Revisar el tamaño real del viewport.
- Revisar AnchorPoint, Position, Size y constraints.
- Revisar si un layout gestiona la posición de los hijos.
- Revisar TextWrapped, TextScaled y límites de tamaño de texto.
- Revisar clipping, CanvasSize, AutomaticCanvasSize y el área segura.
- Probar con un texto más largo y una ventana más estrecha.

Síntoma: el botón no hace nada.
- Confirmar que existe una conexión Activated/MouseButton1Click.
- Confirmar que el script está en una ubicación que puede ejecutarse.
- Confirmar que el botón no está tapado por otra instancia.
- Confirmar que no está Active=false, Visible=false o bloqueado por un overlay.
- Confirmar que el remoto existe y que cliente y servidor usan el mismo nombre.
- Confirmar que el servidor escucha el remoto y valida la solicitud.

Síntoma: las monedas pueden falsificarse.
- Mover la autoridad del saldo al servidor.
- El cliente debe pedir una operación, no informar el nuevo saldo.
- El servidor debe validar precio, saldo, cooldown, propiedad y elegibilidad.
- Rechazar números negativos, NaN, infinito, strings inesperados y cantidades enormes.
- Añadir límites de frecuencia para eventos remotos.
- Probar con dos clientes y solicitudes repetidas.

Síntoma: el juego no conserva el progreso.
- Confirmar que se implementó DataStoreService en código de runtime.
- Revisar permisos y configuración de Studio para pruebas.
- Manejar errores y límites de solicitudes.
- Guardar de forma controlada y evitar escrituras constantes.
- Probar entrada, salida, reingreso y fallos temporales.
- No presentar un IntValue como si fuera guardado persistente.

Síntoma: un modelo se cae o atraviesa el suelo.
- Revisar Anchored y CanCollide en cada pieza.
- Revisar si el suelo tiene colisión y grosor suficiente.
- Revisar constraints y uniones del modelo.
- Revisar si hay piezas muy pequeñas o con posiciones superpuestas.
- Probar en Play, no solo en el editor.

Síntoma: el terreno cambia demasiado.
- Usar una región menor.
- Revisar posición, tamaño y radio antes de confirmar.
- No usar Clear salvo con autorización explícita.
- Crear una copia del lugar antes de editar una región crítica.
- Verificar que ReplaceMaterial usa el material de origen esperado.

Síntoma: el audio no se reproduce.
- Confirmar que SoundId está en formato rbxassetid://ID cuando corresponde.
- Confirmar que el creador tiene permiso para usar el audio.
- Revisar Volume, Playing, RollOff y el padre del Sound.
- Revisar si el sonido es local o global según la intención.
- Comprobar Output por errores de asset/moderación.

Síntoma: un efecto no se ve.
- Confirmar el padre correcto.
- Para Beam/Trail, asignar los attachments requeridos.
- Revisar Enabled, Rate, Lifetime, Speed, Transparency y tamaño.
- Comprobar si un ParticleEmitter está dentro de Attachment o BasePart.
- Revisar Lighting effects en el contexto de la escena.

Síntoma: una acción de lote se detiene.
- Leer el índice de la acción fallida.
- Revisar las acciones anteriores: pueden haberse aplicado.
- Usar Undo si corresponde, sin asumir rollback automático.
- Corregir el dato que falló antes de repetir el lote completo.
- No reintentar un lote destructivo sin inspeccionar el estado actual.

Síntoma: la IA repite acciones o crea duplicados.
- Consultar INSPECT_PROJECT y FIND_INSTANCES antes de crear.
- Comprobar el nombre y la ruta objetivo.
- Usar SET_PROPERTIES si se necesita modificar una instancia existente.
- Crear nombres de carpeta estables y verificar si ya existen.
- Mantener un registro de fases completadas en el backend.

MATRIZ DE REGRESIÓN: OPERACIONES EXISTENTES
-------------------------------------------
R001. CREATE_PART con tamaño estándar crea una Part en Workspace.
R002. CREATE_PART con forma Ball crea una esfera.
R003. CREATE_PART con forma Cylinder crea un cilindro.
R004. CREATE_PART con forma Wedge usa WedgePart.
R005. CREATE_PART con tamaño fuera de rango aplica límites.
R006. CREATE_PART con posición muy distante aplica límites de coordenadas.
R007. CREATE_PART con material desconocido conserva material predeterminado o falla claramente.
R008. CREATE_STRUCTURE crea el número solicitado de piezas.
R009. CREATE_STRUCTURE rechaza una lista vacía.
R010. CREATE_STRUCTURE rechaza más de 60 piezas en una sola estructura.
R011. CREATE_STRUCTURE elimina el modelo temporal si una pieza falla.
R012. CREATE_TREE rechaza una clase fuera de ALLOWED_TREE_CLASSES.
R013. CREATE_TREE limita profundidad y número de instancias.
R014. CREATE_TREE aplica propiedades antes de asignar la jerarquía final.
R015. CREATE_TREE limpia el nodo si children tiene formato inválido.
R016. CREATE_FOLDER crea una carpeta en el servicio indicado.
R017. CREATE_VALUE valida StringValue, BoolValue, IntValue y NumberValue.
R018. CREATE_VALUE limita números a los rangos documentados.
R019. CREATE_REMOTE admite solo remotos conocidos.
R020. CREATE_OBJECT rechaza clases no incluidas en la lista permitida.
R021. CREATE_SYSTEM advierte que las plantillas son solo estructuras iniciales.
R022. SET_PROPERTIES acepta la lista normalizada del backend.
R023. SET_PROPERTIES convierte Vector3 en propiedades compatibles.
R024. SET_PROPERTIES convierte UDim2 con cuatro componentes.
R025. SET_PROPERTIES omite propiedades que no pueden asignarse con advertencia.
R026. SET_ATTRIBUTE acepta string, number y boolean.
R027. DELETE_INSTANCE protege game y Workspace.
R028. MOVE_INSTANCE rechaza ciclos en la jerarquía.
R029. MOVE_INSTANCE puede cambiar el padre y reposicionar una BasePart.
R030. MOVE_INSTANCE puede reposicionar un Model con PivotTo.
R031. DUPLICATE_INSTANCE respeta Archivable.
R032. INSPECT_PATH muestra la jerarquía de un destino.
R033. INSPECT_SELECTION inspecciona las instancias seleccionadas.
R034. INSPECT_PROJECT devuelve un resumen de servicios.
R035. INSPECT_GUI genera un informe estructural de ScreenGui.
R036. FIND_INSTANCES limita el número de resultados.
R037. CREATE_SCRIPT rechaza ubicaciones no permitidas.
R038. CREATE_SCRIPT rechaza código vacío.
R039. CREATE_SCRIPT limita el tamaño de fuente.
R040. CREATE_SCRIPT bloquea APIs de alto riesgo indicadas en la lista.
R041. CREATE_SCRIPT informa que el código debe revisarse y probarse.
R042. El polling no sobrescribe pendingAction.
R043. El botón Rechazar limpia la acción pendiente.
R044. El botón Confirmar registra waypoints alrededor de la acción.
R045. Los errores del backend se muestran en el panel.
R046. La búsqueda local no cambia el proyecto.
R047. El renombrado local exige una selección.
R048. La duplicación local registra waypoints.
R049. La interfaz del plugin conserva la vista previa de la acción.
R050. El usuario puede ocultar y volver a mostrar el widget del plugin.

MATRIZ DE REGRESIÓN: INTERFACES
-------------------------------
U001. CREATE_GUI crea ScreenGui bajo StarterGui cuando la ruta es válida.
U002. CREATE_GUI acepta uiTree, root o tree como entrada declarativa.
U003. La validación rechaza clases UI no permitidas.
U004. La validación rechaza propiedades fuera de GUI_PROPERTY_ALLOWLIST.
U005. La creación falla sin dejar un ScreenGui parcial.
U006. Los valores predeterminados dan contraste inicial a controles comunes.
U007. UICorner solo se aplica a tipos compatibles.
U008. UIStroke usa un color y grosor válidos.
U009. UIPadding tiene valores dentro de límites.
U010. Los hijos se crean después de validar el árbol.
U011. Los nombres vacíos reciben un fallback seguro.
U012. Los botones con icono pueden no tener texto.
U013. Las etiquetas pueden usar RichText solo si se solicita explícitamente.
U014. Las propiedades de texto se revisan por tamaño mínimo.
U015. Los layouts deben probarse con elementos que cambian de tamaño.
U016. ScreenGui DisplayOrder se mantiene dentro del rango configurado.
U017. IgnoreGuiInset se respeta según la acción.
U018. ResetOnSpawn se respeta según la acción.
U019. UIScale se limita a un rango razonable.
U020. La auditoría no afirma ausencia de superposición visual.
U021. La UI se prueba en viewport pequeño.
U022. La UI se prueba en viewport grande.
U023. La UI se prueba con strings largos.
U024. La UI se prueba con botones deshabilitados.
U025. La UI se prueba con listas vacías y listas llenas.
U026. La UI se prueba con controles de texto editable.
U027. La UI se prueba después de respawn.
U028. La UI se prueba con distintas escalas de pantalla.
U029. La UI se prueba cuando un panel se oculta y se vuelve a mostrar.
U030. La UI se prueba con teclado y dispositivos táctiles cuando corresponda.

MATRIZ DE REGRESIÓN: SEGURIDAD Y MANTENIBILIDAD
------------------------------------------------
S001. La acción destructiva siempre aparece en la vista previa.
S002. DELETE_INSTANCE no se agrega a lotes sin autorización explícita.
S003. CREATE_TERRAIN Clear requiere confirmación explícita.
S004. El plugin no evalúa texto del modelo como código del plugin.
S005. Las rutas se resuelven dentro de contenedores permitidos.
S006. Los nombres se limitan a longitud razonable.
S007. Los valores numéricos se acotan antes de usarse en geometría.
S008. Los árboles tienen límites de profundidad y cantidad.
S009. Los lotes tienen límite máximo de acciones.
S010. Los lotes anidados se rechazan.
S011. Los errores deben incluir tipo de acción y contexto útil.
S012. El plugin no reporta pruebas que no se ejecutaron.
S013. El backend no puede ampliar la allowlist de clases sin una actualización del plugin.
S014. Las acciones desconocidas se rechazan.
S015. El usuario conserva control sobre la confirmación.
S016. Los scripts creados se revisan por ubicación y autoridad.
S017. El código generado no debe incluir secretos ni credenciales.
S018. El código de cliente no debe autorizar premios o compras.
S019. Las solicitudes de red no deben bloquear indefinidamente el hilo de UI.
S020. Los límites de tamaño se mantienen aunque el backend falle.
S021. Los assets externos se validan por ID y permisos.
S022. El Terrain se modifica en regiones acotadas.
S023. Las instancias temporales se limpian cuando la creación falla.
S024. Los cambios grandes se dividen en fases.
S025. Los proyectos se respaldan antes de pruebas destructivas.

PLAN DE VERSIONADO
------------------
- Cada cambio de contrato de acción debe incrementar la versión del plugin o del API.
- El backend debe detectar qué versión de plugin está conectada cuando sea posible.
- Una acción nueva debe documentar sus campos, valores predeterminados y errores.
- Una acción que cambia de significado debe tener un nuevo nombre o versión de contrato.
- No se debe asumir que los plugins instalados se actualizan solos.
- La página web debe avisar cuando la acción solicitada no existe en el plugin conectado.
- Las pruebas de regresión deben ejecutarse después de cambios de conversión o rutas.
- Las versiones deben probarse en un lugar de desarrollo con copia de seguridad.
- Los resultados deben indicar la versión de Studio y el plugin usados en la prueba.
- Un cambio que solo agrega documentación no debe presentarse como una nueva capacidad.

CIERRE
------
La inteligencia efectiva de MEGA depende de cuatro capas: el modelo que planifica,
el backend que valida y traduce, el plugin que aplica operaciones permitidas y las
pruebas que verifican el resultado. Mejorar solo el prompt no convierte una API
inexistente en una herramienta. La ruta fiable es sincronizar contratos, ampliar
operaciones reales, limitar acciones peligrosas, inspeccionar los resultados y probar
cada cambio en Roblox Studio.
===============================================================================
FIN DE LA GUÍA DE INTEGRACIÓN
===============================================================================
]]

--[[
MATRIZ EXTENDIDA DE PRUEBAS POR DOMINIO
------------------------------------------
Cada caso debe ejecutarse en una copia de desarrollo y registrar el resultado real.
No convertir un caso escrito en un resultado aprobado.

DOMINIO: CREACIÓN GEOMÉTRICA / ACCIÓN: CREATE_PART
------------------------------------------
Caso 001: pieza cúbica de tamaño normal.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 002: esfera con color RGB.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 003: cilindro rotado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 004: cuña inclinada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 005: pieza parcialmente transparente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 006: pieza reflectante.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 007: pieza sin colisión.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 008: pieza sin anclaje.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 009: pieza en coordenadas negativas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 010: pieza cerca del límite de coordenadas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 011: material Neon.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 012: material Wood.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 013: color normalizado 0–1.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 014: color RGB 0–255.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 015: nombre vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 016: nombre de 100 caracteres.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 017: tamaño inferior al mínimo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 018: tamaño superior al máximo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 019: material inexistente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 020: forma inexistente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_PART con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: ÁRBOLES Y MODELOS / ACCIÓN: CREATE_TREE
----------------------------------------
Caso 021: árbol con un Folder raíz.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 022: modelo con tres piezas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 023: árbol con attachment.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 024: árbol con ProximityPrompt.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 025: árbol con UI simple.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 026: árbol con RemoteEvent.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 027: árbol con valor NumberValue.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 028: árbol con clase no permitida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 029: árbol con profundidad límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 030: árbol por encima de profundidad.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 031: árbol con cantidad límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 032: árbol por encima de cantidad.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 033: hijo con propiedades inválidas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 034: children que no es lista.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 035: lista children vacía.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 036: nombre de nodo ausente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 037: propiedad de enum válida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 038: propiedad de enum inválida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 039: Color3 como tabla RGB.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 040: UDim2 de cuatro valores.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TREE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: INTERFACES / ACCIÓN: CREATE_GUI
--------------------------------
Caso 041: ScreenGui con Frame centrado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 042: panel con UICorner.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 043: panel con UIStroke.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 044: ScrollingFrame con AutomaticCanvasSize.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 045: UIListLayout vertical.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 046: UIGridLayout de tarjetas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 047: TextButton con texto.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 048: ImageButton sin texto.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 049: TextBox multilinea.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 050: TextLabel con RichText.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 051: ScreenGui con DisplayOrder alto.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 052: UI con escala móvil.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 053: UI con AnchorPoint central.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 054: UI con Size basada en Scale.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 055: UI con Size basada en Offset.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 056: propiedad GUI fuera de allowlist.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 057: clase GUI fuera de allowlist.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 058: texto superior a límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 059: UI con más de 450 objetos.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 060: UI con profundidad superior al límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_GUI con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: TERRENO / ACCIÓN: CREATE_TERRAIN
---------------------------------
Caso 061: FillBlock pequeño de Grass.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 062: FillBlock de Sand.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 063: FillBall de Rock.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 064: FillCylinder de Ground.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 065: ReplaceMaterial Grass a Sand.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 066: ReplaceMaterial con origen inválido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 067: Clear sin confirmación.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 068: Clear con confirmación explícita.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 069: radio inferior al límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 070: radio superior al límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 071: tamaño regional mínimo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 072: tamaño regional máximo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 073: posición de terreno negativa.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 074: material desconocido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 075: operación desconocida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TERRAIN con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: ILUMINACIÓN / ACCIÓN: APPLY_LIGHTING_PRESET
--------------------------------------------
Caso 076: preset BrightDay.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 077: preset Sunset.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 078: preset Night.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 079: preset Horror.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 080: preset Cartoon.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 081: preset StudioNeutral.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 082: preset desconocido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 083: atmósfera desactivada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 084: atmósfera reutilizada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 085: corrección de color activada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 086: contraste limitado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 087: saturación negativa.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 088: glare limitado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 089: haze limitado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción APPLY_LIGHTING_PRESET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: EFECTOS Y AUDIO / ACCIÓN: CREATE_EFFECT
----------------------------------------
Caso 090: ParticleEmitter con tasa moderada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 091: ParticleEmitter con lifetime válido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 092: PointLight con color personalizado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 093: SpotLight con rango.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 094: Highlight con colores.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 095: BloomEffect en Lighting.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 096: Atmosphere en Lighting.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 097: clase de efecto no permitida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 098: propiedad incompatible.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 099: efecto con nombre existente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_EFFECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: EFECTOS Y AUDIO / ACCIÓN: CREATE_SOUND
---------------------------------------
Caso 100: SoundId válido con volumen medio.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 101: volumen negativo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 102: volumen muy alto.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 103: velocidad de reproducción baja.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 104: velocidad de reproducción alta.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 105: sonido en Workspace.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 106: sonido en una pieza.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 107: sonido en SoundService.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 108: sonido en bucle.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 109: intento de Play sin permiso.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 110: distancia mínima mayor que máxima.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SOUND con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: ATRIBUTOS Y ETIQUETAS / ACCIÓN: SET_ATTRIBUTES
-----------------------------------------------
Caso 111: un atributo string.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 112: un atributo boolean.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 113: un atributo numérico.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 114: varios atributos simples.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 115: atributo con nombre vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 116: atributo string muy largo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 117: atributo con tabla anidada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 118: atributo con instancia.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 119: atributo con número infinito.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción SET_ATTRIBUTES con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: ATRIBUTOS Y ETIQUETAS / ACCIÓN: MANAGE_TAGS
--------------------------------------------
Caso 120: agregar etiqueta nueva.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 121: agregar etiqueta existente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 122: eliminar etiqueta existente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 123: eliminar etiqueta ausente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 124: listar etiquetas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 125: operación inválida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 126: etiqueta vacía.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 127: etiqueta excesivamente larga.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MANAGE_TAGS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: SISTEMAS DE JUEGO / ACCIÓN: CREATE_CHECKPOINT_SET
--------------------------------------------------
Caso 128: un checkpoint.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 129: cinco checkpoints.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 130: cien checkpoints.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 131: más de cien checkpoints.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 132: posición inicial custom.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 133: espaciado en X.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 134: espaciado en Y.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 135: espaciado en Z.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 136: atributo CheckpointIndex.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 137: modelo padre personalizado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CHECKPOINT_SET con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: SISTEMAS DE JUEGO / ACCIÓN: CREATE_TOOL
----------------------------------------
Caso 138: Tool con Handle creado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 139: Tool sin Handle y RequiresHandle=false.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 140: Tool sin Handle y RequiresHandle=true.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 141: Tool con handle de color custom.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 142: Tool con material inválido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 143: Tool con nombre vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 144: Tool con tooltip largo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 145: Tool en StarterPack.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 146: Tool en carpeta personalizada.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TOOL con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: SISTEMAS DE JUEGO / ACCIÓN: CREATE_TEAM
----------------------------------------
Caso 147: equipo azul autoasignable.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 148: equipo rojo manual.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 149: color válido de BrickColor.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 150: color inválido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 151: nombre vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 152: equipo en servicio Teams.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_TEAM con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: CONSTRAINTS / ACCIÓN: CREATE_CONSTRAINT
----------------------------------------
Caso 153: WeldConstraint con Part0 y Part1.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 154: Motor6D sin piezas.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 155: HingeConstraint con attachments.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 156: BallSocketConstraint con attachments.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 157: RopeConstraint sin attachments.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 158: AlignPosition con attachments.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 159: constraint con clase no permitida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 160: attachment0 no encontrado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 161: attachment0 que no es Attachment.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 162: part0 que no es BasePart.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_CONSTRAINT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: INSPECCIÓN / ACCIÓN: INSPECT_SCRIPT
------------------------------------
Caso 163: Script con funciones.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 164: LocalScript con eventos.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 165: ModuleScript vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 166: objeto que no es script.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 167: Source legible.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 168: Source inaccesible.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 169: includeSource activado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 170: includeSource desactivado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 171: script con comentarios TODO.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 172: script con múltiples conexiones.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción INSPECT_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: AUDITORÍA / ACCIÓN: VALIDATE_PROJECT
-------------------------------------
Caso 173: proyecto vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 174: proyecto pequeño.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 175: proyecto cercano al límite de objetos.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 176: proyecto superior al límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 177: pieza con velocidad alta.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 178: Script vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 179: TextButton sin texto ni imagen.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 180: proyecto con varios servicios.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 181: proyecto con una GUI.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 182: auditoría repetida sin modificar proyecto.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción VALIDATE_PROJECT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: COMUNICACIÓN / ACCIÓN: POLLING
-------------------------------
Caso 183: sesión sin código.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 184: sesión con código válido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 185: backend responde sin acción.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 186: backend responde acción válida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 187: JSON mal formado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 188: acción sin type.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 189: acción de tipo no string.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 190: acción pendiente durante polling.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 191: error HTTP temporal.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 192: registro de sesión fallido.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción POLLING con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: LOTES / ACCIÓN: BATCH_ACTIONS
------------------------------
Caso 193: lote de una acción.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 194: lote de 40 acciones.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 195: lote de 80 acciones.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 196: lote vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 197: lote por encima del máximo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 198: lote anidado.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 199: hijo que no es tabla.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 200: acción hija sin type.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 201: borrado sin allowDestructive.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 202: borrado con allowDestructive.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 203: fallo en primera acción.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 204: fallo en acción intermedia.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 205: lote de acciones dependientes.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 206: lote con padre creado antes del hijo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción BATCH_ACTIONS con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: MOVIMIENTO Y EDICIÓN / ACCIÓN: MOVE_INSTANCE
---------------------------------------------
Caso 207: mover Part a carpeta.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 208: mover Model a carpeta.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 209: reposicionar BasePart.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 210: reposicionar Model con PivotTo.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 211: mover a su propio descendiente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 212: ruta padre inexistente.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 213: proteger Workspace.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 214: rotar una pieza.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 215: cambiar padre sin cambiar posición.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción MOVE_INSTANCE con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

DOMINIO: SCRIPTING / ACCIÓN: CREATE_SCRIPT
----------------------------------
Caso 216: Script en ServerScriptService.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 217: LocalScript en StarterPlayerScripts.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 218: LocalScript en StarterGui.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 219: ubicación no permitida.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 220: código vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 221: código mayor al límite.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 222: texto que contiene loadstring.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 223: texto que contiene getfenv.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 224: texto que contiene require.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

Caso 225: script con nombre vacío.
Preparación: crear una copia del lugar y comprobar la versión instalada del plugin.
Ejecución: enviar una acción CREATE_SCRIPT con los datos específicos del escenario.
Esperado: resultado determinista, mensaje útil y ausencia de instancias parciales inesperadas.
Verificación: inspeccionar Explorer/propiedades/Output y repetir la prueba si cambia el contrato.
Registro: anotar aprobado, fallido o bloqueado; añadir error exacto y pasos de reproducción.

REGLA DE CIERRE DE PRUEBAS
--------------------------
Una prueba solo se considera aprobada si fue ejecutada en la versión declarada de Studio,
se verificó el estado final y se guardó evidencia reproducible. La ausencia de errores
visibles no demuestra por sí sola que la lógica de juego funcione correctamente.

FIN DE MATRIZ EXTENDIDA
]]

