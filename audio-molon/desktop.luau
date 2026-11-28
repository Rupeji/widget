--!strict

-- ── Configuración visual y de CAVA ───────────────────────────────────────────
local NUM_BARS = 24
local BAR_WIDTH = 8
local BAR_GAP = 4
local MAX_HEIGHT = 120
local MIN_HEIGHT = 4
local BAR_RADIUS = 4
local BAR_COLOR = "primary" -- Color del tema activo ("primary", "secondary", "#RRGGBB")
local CAVA_FRAMERATE = 60
local SENSITIVITY = 100 -- Porcentaje de ganancia en CAVA (100 = normal)

-- ── Estado interno ───────────────────────────────────────────────────────────
local bars: { number } = table.create(NUM_BARS, 0)
local cavaRunning = false

-- Genera el archivo de configuración de CAVA en el directorio persistente del plugin
local function ensureCavaConfig(): string?
	local dataDir, err = noctalia.pluginDataDir()
	if not dataDir then
		noctalia.log("[audio-molon] Error obteniendo pluginDataDir: " .. tostring(err))
		return nil
	end

	local configPath = dataDir .. "/cava.conf"
	local configContent = string.format([[
[general]
framerate = %d
bars = %d
sensitivity = %d

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
]], CAVA_FRAMERATE, NUM_BARS, SENSITIVITY)

	local ok, writeErr = noctalia.writeFile(configPath, configContent)
	if not ok then
		noctalia.log("[audio-molon] Error escribiendo cava.conf: " .. tostring(writeErr))
		return nil
	end

	return configPath
end

-- Construye el árbol de UI con barras verticales
local function buildUi(): UiNode
	local children: { UiNode } = {}

	for i = 1, NUM_BARS do
		local val = bars[i] or 0
		local h = math.floor(MIN_HEIGHT + (val * (MAX_HEIGHT - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = BAR_WIDTH,
			height = h,
			fill = BAR_COLOR,
			radius = BAR_RADIUS,
		}))
	end

	return ui.row({
		height = MAX_HEIGHT,
		gap = BAR_GAP,
		align = "end",
		padding = 8,
	}, children)
end

-- Procesa cada línea enviada por CAVA (ej. "120;450;890;...")
local function onCavaLine(line: string)
	local idx = 1
	local changed = false

	for valStr in string.gmatch(line, "([^;]+)") do
		if idx <= NUM_BARS then
			local n = tonumber(valStr)
			if n then
				local normalized = math.clamp(n / 1000, 0, 1)
				if math.abs(normalized - bars[idx]) > 0.002 then
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

-- Arranca el proceso de CAVA
local function startCava()
	if not noctalia.commandExists("cava") then
		noctalia.notifyError("audio-molon", "No se encontró 'cava' instalado en el sistema.")
		return
	end

	local configPath = ensureCavaConfig()
	if not configPath then
		return
	end

	local cmd = string.format("cava -p %q", configPath)
	cavaRunning = noctalia.runStream(cmd, onCavaLine)
end

-- Asegura que no queden procesos huérfanos de cava al recargar o quitar el widget
function onExit(signal: number, reason: string)
	if cavaRunning then
		noctalia.runAsync({ "pkill", "-f", "audio-molon/cava.conf" })
	end
end

-- Renderizado inicial e inicio del flujo
desktopWidget.render(buildUi())
startCava()
