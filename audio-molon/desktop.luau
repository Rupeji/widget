--!strict

-- ── Configuración base ───────────────────────────────────────────────────────
local numBars = math.clamp(tonumber(noctalia.getConfig("bars")) or 48, 8, 160)
local barGap = math.clamp(tonumber(noctalia.getConfig("bar_gap")) or 4, 1, 20)
local sensitivity = tonumber(noctalia.getConfig("sensitivity")) or 100
local barColor = tostring(noctalia.getConfig("color") or "primary")
local hideWhenIdleCfg = noctalia.getConfig("hide_when_idle")
local hideWhenIdle = (hideWhenIdleCfg == nil or hideWhenIdleCfg == true)

local SILENCE_FRAMES_THRESHOLD = 45 -- ~0.75 segundos a 60 FPS

-- ── Estado interno ───────────────────────────────────────────────────────────
local bars: { number } = table.create(numBars, 0)
local silentFrames = 0
local isVisible = true

local function buildUi(): UiNode
	local children: { UiNode } = {}

	for i = 1, numBars do
		local val = bars[i] or 0
		-- Cada barra es una columna flexible que llena el 100% del alto y ancho del rectángulo
		table.insert(children, ui.column({
			key = "col_" .. tostring(i),
			flexGrow = 1,
		}, {
			ui.spacer({
				flexGrow = math.max(0.001, 1 - val),
			}),
			ui.box({
				key = "bar_" .. tostring(i),
				flexGrow = math.max(0.015, val),
				fill = barColor,
				radius = 4,
			}),
		}))
	end

	return ui.row({
		minWidth = 320,
		minHeight = 80,
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
		local hasAudio = false

		for valStr in string.gmatch(line, "([^;]+)") do
			if idx <= numBars then
				local val = math.clamp((tonumber(valStr) or 0) / 1000, 0, 1)
				bars[idx] = val
				if val > 0.005 then
					hasAudio = true
				end
				idx += 1
			end
		end

		-- Control de visibilidad automática al pausar o haber silencio
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
		end

		if isVisible then
			desktopWidget.render(buildUi())
		end
	end
end)

if not started then
	noctalia.notifyError("Audio Molon", "No se pudo arrancar cava")
end
