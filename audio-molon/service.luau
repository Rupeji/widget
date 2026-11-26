-- service.luau
if not noctalia.commandExists("cava") then
    noctalia.notify("Audio Molon", "CAVA no está instalado. Instálalo con: sudo dnf install cava")
    return
end

-- Usamos una configuración de CAVA más simple y directa
local cava_cmd = "cava -p /dev/stdin <<'EOF'\n" ..
    "[general]\n" ..
    "bars = 20\n" ..
    "[output]\n" ..
    "method = raw\n" ..
    "raw_target = /dev/stdout\n" ..
    "data_format = ascii\n" ..
    "ascii_max_range = 100\n" ..
    "EOF"

local function on_cava_line(line)
    local bars = {}
    -- CAVA separa los valores con ';'
    for value in line:gmatch("([^;]+)") do
        local num = tonumber(value)
        if num then
            table.insert(bars, num)
        end
    end

    -- CLAVE: Guardar los datos en el estado compartido con un nombre claro
    noctalia.state.set("audio_bars", bars)
end

noctalia.runStream(cava_cmd, on_cava_line)
