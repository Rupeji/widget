--!strict

local cavaRunning = false
local receivedFirstLine = false

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

[input]
method = pipewire
source = auto

[output]
method = raw
channels = mono
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
monstercat = %d
gravity = %d
]], bars, sens, monstercat, gravity)
end

local function startCava()
	stopCava()
	receivedFirstLine = false

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
		noctalia.notifyError("Audio Molon", "Error escribiendo cava.conf: " .. tostring(writeErr))
		return
	end

	local numBars = tonumber(noctalia.getConfig("bars")) or 24
	noctalia.state.set("bars_count", numBars)

	-- Redirigimos stderr a stdout (2>&1) para capturar cualquier error de cava en los logs
	local cmd = string.format("cava -p %q 2>&1", configPath)
	cavaRunning = noctalia.runStream(cmd, function(line: string)
		if not receivedFirstLine then
			receivedFirstLine = true
			noctalia.log("[audio-molon] Primera línea de CAVA: " .. line)
		end

		-- Si la línea empieza por un número, es un frame de audio válido; si no, es un error de CAVA
		if string.match(line, "^%d+;") then
			noctalia.state.set("cava_line", line)
		else
			noctalia.log("[audio-molon] CAVA output: " .. line)
		end
	end)

	if not cavaRunning then
		noctalia.notifyError("Audio Molon", "No se pudo iniciar el proceso CAVA.")
	end
end

function onConfigChanged()
	startCava()
end

function onExit(signal: number, reason: string)
	stopCava()
end

startCava()
