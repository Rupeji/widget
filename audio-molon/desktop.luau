--!strict

-- Leemos la configuración UNA sola vez al arrancar
local numBars = tonumber(noctalia.getConfig("bars")) or 24
local defaultBarWidth = tonumber(noctalia.getConfig("bar_width")) or 8
local barGap = tonumber(noctalia.getConfig("bar_gap")) or 4
local defaultMaxHeight = tonumber(noctalia.getConfig("max_height")) or 120
local sensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
local barColor = tostring(noctalia.getConfig("color") or "primary")
local MIN_HEIGHT = 4

local bars: { number } = table.create(numBars, 0)
local widgetWidth: number? = nil
local widgetHeight: number? = nil

local function buildUi(): UiNode
	-- Calculamos el ancho de cada barra según el ancho del widget (si se redimensionó)
	local currentBarWidth = defaultBarWidth
	if widgetWidth and widgetWidth > 32 then
		local usableWidth = widgetWidth - 16 - (barGap * (numBars - 1))
		currentBarWidth = math.max(2, math.floor(usableWidth / numBars))
	end

	-- Calculamos la altura máxima según la altura del widget (si se redimensionó)
	local currentMaxHeight = defaultMaxHeight
	if widgetHeight and widgetHeight > 24 then
		currentMaxHeight = widgetHeight - 16
	end

	local barRadius = math.min(4, math.floor(currentBarWidth / 2))

	local children: { UiNode } = {}
	for i = 1, numBars do
		local val = bars[i] or 0
		local h = math.floor(MIN_HEIGHT + (val * math.max(0, currentMaxHeight - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = currentBarWidth, -- Siempre tiene un ancho numérico válido (> 0)
			height = h,
			fill = barColor,
			radius = barRadius,
		}))
	end

	return ui.row({
		height = currentMaxHeight,
		gap = barGap,
		align = "end",
		padding = 8,
	}, children)
end

-- Se dispara si Noctalia notifica cambio de tamaño del widget en el escritorio
function onResize(w: number, h: number)
	widgetWidth = w
	widgetHeight = h
	desktopWidget.render(buildUi())
end

-- Render inicial
desktopWidget.render(buildUi())

local dataDir, dirErr = noctalia.pluginDataDir()
if not dataDir then
	noctalia.notifyError("Audio Molon", "Error pluginDataDir: " .. tostring(dirErr))
	return
end

local configPath = dataDir .. "/cava.conf"
local cfg = string.format([[
[general]
framerate = 60
bars = %d
sensitivity = %d

[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
]], numBars, sensitivity)

local ok, writeErr = noctalia.writeFile(configPath, cfg)
if not ok then
	noctalia.notifyError("Audio Molon", "Error writeFile: " .. tostring(writeErr))
	return
end

local started = noctalia.runStream(string.format("cava -p %q 2>&1", configPath), function(line: string)
	if string.match(line, "^%d+;") then
		local idx = 1
		for valStr in string.gmatch(line, "([^;]+)") do
			if idx <= numBars then
				bars[idx] = math.clamp((tonumber(valStr) or 0) / 1000, 0, 1)
				idx += 1
			end
		end
		desktopWidget.render(buildUi())
	end
end)

if not started then
	noctalia.notifyError("Audio Molon", "No se pudo arrancar cava")
end
