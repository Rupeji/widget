--!strict

local cavaRunning = false

local function getConfigPath(): string?
	local dataDir, err = noctalia.pluginDataDir()
	if not dataDir then
		noctalia.log("[audio-molon] Error obteniendo pluginDataDir: " .. tostring(err))
		return nil
	end
	return dataDir .. "/cava.conf"
end

local function stopCava()
	if cavaRunning then
		noctalia.runAsync({ "pkill", "-f", "audio-molon/cava.conf" })
		cavaRunning = false
	end
end

local function buildConfig(): string
	local bars = tonumber(noctalia.getConfig("bars")) or 24
	local gravity = tonumber(noctalia.getConfig("gravity")) or 200
	local sens = tonumber(noctalia.getConfig("sensitivity")) or 100
	local monstercatCfg = noctalia.getConfig("monstercat")
	local monstercat = (monstercatCfg == nil or monstercatCfg == true) and 1 or 0

	return string.format([[
[general]
framerate = 60
bars = %d
sensitivity = %d

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = %d
gravity = %d
]], bars, sens, monstercat, gravity)
end

local function startCava()
	stopCava()

	if not noctalia.commandExists("cava") then
		noctalia.notifyError("Audio Molon", "No se encontró 'cava' instalado en el sistema.")
		return
	end

	local configPath = getConfigPath()
	if not configPath then
		return
	end

	local ok, writeErr = noctalia.writeFile(configPath, buildConfig())
	if not ok then
		noctalia.log("[audio-molon] Error escribiendo cava.conf: " .. tostring(writeErr))
		return
	end

	-- Compartimos el número de barras actual con el desktop_widget
	local numBars = tonumber(noctalia.getConfig("bars")) or 24
	noctalia.state.set("bars_count", numBars)

	local cmd = string.format("cava -p %q", configPath)
	cavaRunning = noctalia.runStream(cmd, function(line: string)
		-- Enviamos la línea cruda por state para evitar crear tablas cada 16ms
		noctalia.state.set("cava_line", line)
	end)
end

-- Se ejecuta automáticamente cuando cambias los ajustes en Noctalia
function onConfigChanged()
	startCava()
end

-- Se ejecuta al recargar, desactivar o cerrar Noctalia
function onExit(signal: number, reason: string)
	stopCava()
end

-- Arranque inicial del servicio
startCava()
