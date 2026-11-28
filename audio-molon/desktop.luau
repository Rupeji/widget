--!strict

local MIN_HEIGHT = 4
local numBars = tonumber(noctalia.getConfig("bars")) or 24
local bars: { number } = table.create(numBars, 0)

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

desktopWidget.render(buildUi())

-- DIAGNÓSTICO PASO A PASO
local dataDir, dirErr = noctalia.pluginDataDir()
if not dataDir then
	noctalia.notifyError("Paso 1 Falló", "pluginDataDir: " .. tostring(dirErr))
	return
end

local configPath = dataDir .. "/cava.conf"
local cfg = [[
[general]
framerate = 60
bars = 24
sensitivity = 100

[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
]]

local ok, writeErr = noctalia.writeFile(configPath, cfg)
if not ok then
	noctalia.notifyError("Paso 2 Falló", "writeFile: " .. tostring(writeErr))
	return
end

noctalia.notify("Paso 3 OK", "Config escrita en: " .. configPath)

local gotData = false
local started = noctalia.runStream(string.format("cava -p %q 2>&1", configPath), function(line: string)
	if not gotData then
		gotData = true
		noctalia.notify("Paso 5 (Datos)", "Recibido: " .. string.sub(line, 1, 60))
	end

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
	noctalia.notifyError("Paso 4 Falló", "runStream devolvió FALSE (posible permiso faltante en plugin.toml)")
else
	noctalia.notify("Paso 4 OK", "runStream arrancó cava correctamente")
end
