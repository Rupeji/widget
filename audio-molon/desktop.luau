--!strict

-- ── Constantes ───────────────────────────────────────────────────────────────
local CAVA_BANDS = 64
local SILENCE_FRAMES_THRESHOLD = 45 -- ~0.75 segundos a 60 FPS
local MIN_BAR_HEIGHT = 4

-- ── Estado interno ───────────────────────────────────────────────────────────
local rawBands: { number } = table.create(CAVA_BANDS, 0)
local silentFrames = 0
local isVisible = true
local lastSensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
local configPath: string? = nil

-- Interpola las 64 bandas de CAVA a cualquier cantidad de barras visibles
local function sampleBand(index: number, totalVisible: number): number
	if totalVisible <= 1 then
		return rawBands or 0
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
	local totalWidth = math.max(200, tonumber(noctalia.getConfig("width")) or 1920)
	local barMaxHeight = math.max(30, tonumber(noctalia.getConfig("bar_height")) or 180)
	local canvasHeight = math.max(barMaxHeight, tonumber(noctalia.getConfig("canvas_height")) or 600)
	local growUpwardsCfg = noctalia.getConfig("grow_upwards")
	local growUpwards = (growUpwardsCfg == nil or growUpwardsCfg == true)

	local barWidth = math.clamp(tonumber(noctalia.getConfig("bar_width")) or 6, 2, 40)
	local barGap = math.clamp(tonumber(noctalia.getConfig("bar_gap")) or 3, 1, 20)
	local barColor = tostring(noctalia.getConfig("color") or "primary")
	local barRadius = math.floor(barWidth / 2)

	-- Calcula cuántas barras exactas caben en el ancho total según el grosor elegido
	local visibleBars = math.max(4, math.floor((totalWidth + barGap) / (barWidth + barGap)))

	local children: { UiNode } = {}
	for i = 1, visibleBars do
		local val = sampleBand(i, visibleBars)
		local currentBarH = math.floor(MIN_BAR_HEIGHT + (val * (barMaxHeight - MIN_BAR_HEIGHT)))

		local barNode = ui.box({
			key = "bar_" .. tostring(i),
			height = currentBarH,
			fill = barColor,
			radius = barRadius,
		})

		local spacerNode = ui.spacer({
			flexGrow = 1,
		})

		-- Si crece hacia arriba, el espaciador va arriba y la barra se ancla al borde inferior;
		-- si crece hacia abajo, la barra se ancla arriba y el espaciador empuja desde abajo.
		local colChildren = if growUpwards then { spacerNode, barNode } else { barNode, spacerNode }

		table.insert(children, ui.column({
			key = "col_" .. tostring(i),
			flexGrow = 1,
		}, colChildren))
	end

	return ui.row({
		width = totalWidth,
		height = canvasHeight,
		gap = barGap,
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

configPath = dataDir .. "/cava.conf"

local function startCava()
	if not configPath then
		return
	end

	local sensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
	lastSensitivity = sensitivity

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
		local currentSens = tonumber(noctalia.getConfig("sensitivity")) or 100
		if currentSens ~= lastSensitivity then
			noctalia.runAsync({ "pkill", "-f", "audio-molon/cava.conf" })
			startCava()
			return
		end

		if string.match(line, "^%d+;") then
			local idx = 1
			local hasAudio = false

			for valStr in string.gmatch(line, "([^;]+)") do
				if idx <= CAVA_BANDS then
					local val = math.clamp((tonumber(valStr) or 0) / 1000, 0, 1)
					rawBands[idx] = val
					if val > 0.005 then
						hasAudio = true
					end
					idx += 1
				end
			end

			local hideWhenIdleCfg = noctalia.getConfig("hide_when_idle")
			local hideWhenIdle = (hideWhenIdleCfg == nil or hideWhenIdleCfg == true)

			if hideWhenIdle then
				if hasAudio then
					silentFrames = 0
					if not isVisible then
						isVisible = true
						desktopWidget.setVisible(true)
					end
				else
					silentFrames += 1
					if silentFrames >= SILENCE_FRAMES_THRESHOLD and isVisible then
						isVisible = false
						desktopWidget.setVisible(false)
						return
					end
				end
			elseif not isVisible then
				isVisible = true
				desktopWidget.setVisible(true)
			end

			if isVisible then
				desktopWidget.render(buildUi())
			end
		end
	end)

	if not started then
		noctalia.notifyError("Audio Molon", "No se pudo arrancar cava")
	end
end

startCava()
