--!strict

-- ── Configuración base ───────────────────────────────────────────────────────
local CAVA_BANDS = 64
local sensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
local MIN_HEIGHT = 4

-- ── Estado interno ───────────────────────────────────────────────────────────
local rawBands: { number } = table.create(CAVA_BANDS, 0)

-- Interpola las 64 bandas de CAVA a cualquier cantidad de barras visibles
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
	local currentW = math.max(120, tonumber(noctalia.getConfig("widget_width")) or 600)
	local currentH = math.max(30, tonumber(noctalia.getConfig("max_height")) or 140)
	local barColor = tostring(noctalia.getConfig("color") or "primary")

	-- 1. La ALTURA (Max height) determina el grosor y separación de las barras
	local barWidth = math.clamp(math.floor(currentH / 16), 3, 32)
	local barGap = math.max(2, math.floor(barWidth * 0.5))
	local barRadius = math.floor(barWidth / 2)

	-- 2. El ANCHO (Total width) determina cuántas barras caben para cubrirlo
	local visibleBars = math.max(4, math.floor((currentW + barGap) / (barWidth + barGap)))

	local children: { UiNode } = {}
	for i = 1, visibleBars do
		local val = sampleBand(i, visibleBars)
		local barH = math.floor(MIN_HEIGHT + (val * math.max(0, currentH - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = barWidth,
			height = barH,
			fill = barColor,
			radius = barRadius,
		}))
	end

	return ui.row({
		height = currentH,
		gap = barGap,
		justify = "center",
		align = "end",
		padding = 0,
	}, children)
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
