local CONFIG_PATH = "/tmp/noctalia-audio-molon.ini"
local proc = nil
local current_bars = 0

local function build_config(settings)
    local bars = settings.bars or 24
    local gravity = settings.gravity or 200
    local sens = settings.sensitivity or 100
    local monstercat = settings.monstercat and 1 or 0

    return string.format([[
[general]
framerate = 60
bars = %d
sensitivity = %d

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100

[smoothing]
monstercat = %d
gravity = %d
]], bars, sens, monstercat, gravity)
end

local function restart_cava(settings)
    if proc then
        proc:kill()
        proc = nil
    end

    local f = io.open(CONFIG_PATH, "w")
    if f then
        f:write(build_config(settings))
        f:close()
    end

    current_bars = settings.bars or 24
    proc = noctalia.process.spawn({ "cava", "-p", CONFIG_PATH }, {
        on_stdout = function(line)
            local values = {}
            for num in string.gmatch(line, "(%d+)") do
                table.insert(values, math.clamp((tonumber(num) or 0) / 100, 0.04, 1.0))
            end
            if #values > 0 then
                noctalia.state.set("levels", values)
            end
        end
    })
end

function init()
    restart_cava(noctalia.settings.get())
end

function on_settings_changed(settings)
    restart_cava(settings)
end

function cleanup()
    if proc then proc:kill() end
end
