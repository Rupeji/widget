-- service.luau
-- Lanza CAVA y publica los datos en el estado compartido

-- 1. Verificamos que CAVA esté instalado antes de intentar nada
if not noctalia.commandExists("cava") then
    noctalia.notify("Audio Molon", "CAVA no está instalado. Instálalo con: sudo dnf install cava")
    return
end

-- 2. Definimos el comando de CAVA con la configuración de salida "raw"
--    para que escriba los valores numéricos en stdout, separados por ';'.
--    El rango (ascii_max_range) determina la altura máxima de las barras.
local cava_cmd = "cava -p /dev/stdin <<'EOF'\n" ..
    "[general]\n" ..
    "bars = 20\n" .. -- Número de barras que dibujaremos
    "[output]\n" ..
    "method = raw\n" ..
    "raw_target = /dev/stdout\n" ..
    "data_format = ascii\n" ..
    "ascii_max_range = 100\n" .. -- Altura máxima de cada barra
    "EOF"

-- 3. Función que procesa cada línea que CAVA escribe en stdout
local function on_cava_line(line)
    -- CAVA escribe los valores separados por ';'. Ejemplo: "12;45;78;..."
    -- Los dividimos en una tabla de números.
    local bars = {}
    for value in line:gmatch("([^;]+)") do
        local num = tonumber(value)
        if num then
            table.insert(bars, num)
        end
    end

    -- Publicamos la tabla de barras en el estado compartido.
    -- El widget leerá 'noctalia.state.audio_bars' para dibujar.
    noctalia.state.audio_bars = bars
end

-- 4. Lanzamos CAVA como un stream.
--    Noctalia se encarga de terminar el proceso cuando el plugin se descarga.
noctalia.runStream(cava_cmd, on_cava_line)

-- 5. (Opcional) Podemos definir un onExit para hacer limpieza,
--    aunque runStream ya debería manejar el cierre del proceso.
function onExit(signal, reason)
    noctalia.state.audio_bars = nil
end
