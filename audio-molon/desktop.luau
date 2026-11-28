--!strict

-- ── Constantes visuales ──────────────────────────────────────────────────────
local MIN_HEIGHT = 4

-- ── Estado interno ───────────────────────────────────────────────────────────
local numBars = tonumber(noctalia.getConfig("bars")) or 24
local bars: { number } = table.create(numBars, 0)
local cavaRunning = false
local receivedFirstLine = false

local function getConfigPath(): string?
	local dataDir, err = noctalia.pluginDataDir()
	if not dataDir then
		noctalia.notifyError("Audio Molon", "Error pluginDataDir: " .. tostring(err))
		return nil
	end
	return dataDir .. "/cava.conf"
end

local function stopCava()
	if cavaRunning then
		noctalia.runAsync({ "pkill", "-f", "cava.conf" })
		cavaRunning = false
	end
end

local function buildCavaConfig(): string
	local count = tonumber(noctalia.getConfig("bars")) or 24
	local sens = tonumber(noctalia.getConfig("sensitivity")) or 100
	local gravity = tonumber(noctalia.getConfig("gravity")) or 200
	local monstercatCfg = noctalia.getConfig("monstercat")
	local monstercat = (monstercatCfg == nil or monstercatCfg == true) and 1 or 0

	return string.format([[
[general]
framerate = 60
bars = %d
sensitivity = %d

[input]
method = pulse
source = auto

[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = %d
gravity = %d
]], count, sens, monstercat, gravity)
end

local function buildUi(): UiNode
	local barWidth = tonumber(noctalia.getConfig("bar_width")) or 8
	local barGap = tonumber(noctalia.getConfig("bar_gap")) or 4
	local maxHeight = tonumber(noctalia.getConfig("max_height")) or 120
	local barColor = tostring(noctalia.getConfig("color") or "primary")
	local barRadius = math.min(4, math.floor(barWidth / 2))

	local children: { UiNode } = {}

	for i = 1, numBars do
		local val = bars[i] or 0
		local h = math.floor(MIN_HEIGHT + (val * math.max(0, maxHeight - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = barWidth,
			height = h,
			fill = barColor,
			radius = barRadius,
		}))
	end

	return ui.row({
		height = maxHeight,
		gap = barGap,
		align = "end",
		padding = 8,
	}, children)
end

local function onCavaLine(line: string)
	if not string.match(line, "^%d+;") then
		if not receivedFirstLine and line ~= "" then
			noctalia.notifyError("Audio Molon (CAVA)", line)
		end
		return
	end

	receivedFirstLine = true
	local idx = 1
	local changed = false

	for valStr in string.gmatch(line, "([^;]+)") do
		if idx <= numBars then
			local n = tonumber(valStr)
			if n then
				local normalized = math.clamp(n / 1000, 0, 1)
				local prev = bars[idx] or 0
				if math.abs(normalized - prev) > 0.002 then
					bars[idx] = normalized
					changed = true
				end
			end
			idx += 1
		end
	end

	if changed then
		desktopWidget.render(buildUi())
	end
end

local function startCava()
	stopCava()
	receivedFirstLine = false

	numBars = tonumber(noctalia.getConfig("bars")) or 24
	bars = table.create(numBars, 0)
	desktopWidget.render(buildUi())

	if not noctalia.commandExists("cava") then
		noctalia.notifyError("Audio Molon", "No se encontró 'cava' en el sistema.")
		return
	end

	local configPath = getConfigPath()
	if not configPath then
		return
	end

	local ok, writeErr = noctalia.writeFile(configPath, buildCavaConfig())
	if not ok then
		noctalia.notifyError("Audio Molon", "Error escribiendo cava.conf: " .. tostring(writeErr))
		return
	end

	local cmd = string.format("cava -p %q 2>&1", configPath)
	cavaRunning = noctalia.runStream(cmd, onCavaLine)
end

-- Se ejecuta si cambian los ajustes mientras el widget está activo
function onConfigChanged()
	startCava()
end

-- Limpieza al cerrar o recargar el widget
function onExit(signal: number, reason: string)
	stopCava()
end

-- Inicio inmediato al cargar el widget en el escritorio
startCava()
