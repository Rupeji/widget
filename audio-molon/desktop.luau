--!strict

-- ── Configuración base ───────────────────────────────────────────────────────
local CAVA_BANDS = 64 -- CAVA captura 64 bandas para interpolar cualquier ancho con suavidad
local sensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
local barColor = tostring(noctalia.getConfig("color") or "primary")
local MIN_HEIGHT = 4

-- ── Estado interno ───────────────────────────────────────────────────────────
local rawBands: { number } = table.create(CAVA_BANDS, 0)
local widgetWidth: number = tonumber(noctalia.getConfig("bars") and (noctalia.getConfig("bars") * 12)) or 300
local widgetHeight: number = tonumber(noctalia.getConfig("max_height")) or 120

-- Interpola las 64 bandas de CAVA a cualquier número de barras visibles
local function sampleBand(index: number, totalVisible: number): number
	if totalVisible <= 1 then
		return rawBands[1] or 0
	end
	local pos = ((index - 1) / (totalVisible - 1)) * (CAVA_BANDS - 1) + 1
	local lowIdx = math.floor(pos)
	local highIdx = math.min(CAVA_BANDS, lowIdx + 1)
	local frac = pos - lowIdx

	local v1 = rawBands[lowIdx] or 0
	local v2 = rawBands[highIdx] or 0
	return v1 + (v2 - v1) * frac
end

local function buildUi(): UiNode
	local usableW = math.max(40, widgetWidth - 16)
	local usableH = math.max(24, widgetHeight - 16)

	-- 1. El ALTO determina el grosor y separación proporcional de las barras
	local barWidth = math.clamp(math.floor(usableH / 16), 4, 24)
	local barGap = math.max(2, math.floor(barWidth * 0.5))
	local barRadius = math.floor(barWidth / 2) -- Puntas totalmente redondeadas tipo cápsula

	-- 2. El ANCHO determina cuántas barras caben para rellenar el 100% sin deformarse
	local visibleBars = math.max(4, math.floor((usableW + barGap) / (barWidth + barGap)))

	local children: { UiNode } = {}
	for i = 1, visibleBars do
		local val = sampleBand(i, visibleBars)
		local barH = math.floor(MIN_HEIGHT + (val * math.max(0, usableH - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = barWidth,
			height = barH,
			fill = barColor,
			radius = barRadius,
		}))
	end

	return ui.row({
		height = usableH,
		gap = barGap,
		justify = "center",
		align = "end",
		padding = 8,
	}, children)
end

-- Se ejecuta automáticamente al estirar o encoger el widget en el escritorio
function onResize(w: number, h: number)
	if w > 0 and h > 0 then
		widgetWidth = w
		widgetHeight = h
		desktopWidget.render(buildUi())
	end
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
]], CAVA_BANDS, sensitivity)

local ok, writeErr = noctalia.writeFile(configPath, cfg)
if not ok then
	noctalia.notifyError("Audio Molon", "Error writeFile: " .. tostring(writeErr))
	return
end

local started = noctalia.runStream(string.format("cava -p %q 2>&1", configPath), function(line: string)
	if string.match(line, "^%d+;") then
		local idx = 1
		for valStr in string.gmatch(line, "([^;]+)") do
			if idx <= CAVA_BANDS then
				rawBands[idx] = math.clamp((tonumber(valStr) or 0) / 1000, 0, 1)
				idx += 1
			end
		end
		desktopWidget.render(buildUi())
	end
end)

if not started then
	noctalia.notifyError("Audio Molon", "No se pudo arrancar cava")
end
