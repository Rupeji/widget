-- widget.luau
-- Dibuja las barras de audio en la barra de Noctalia

-- 1. Función que se llama periódicamente para actualizar el widget.
--    Ajustamos el intervalo a ~30 FPS (33ms) para una animación fluida.
function update()
    noctalia.setUpdateInterval(33)

    -- Leemos los datos que el servicio ha publicado.
    local bars = noctalia.state.audio_bars

    -- Si no hay datos (CAVA no está corriendo o no hay audio), mostramos un placeholder.
    if not bars or #bars == 0 then
        barWidget.setText(" ♪ ") -- Un icono simple
        return
    end

    -- 2. Construimos la cadena de texto que simula las barras.
    --    Usamos una escala de bloques para representar la altura.
    local block_chars = { " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
    local max_height = 4 -- Altura máxima en "bloques" dentro de la barra
    local display = ""

    for i = 1, #bars do
        -- Normalizamos el valor (0-100) a la altura máxima.
        -- El valor 100 de CAVA se convierte en la altura máxima de bloque.
        local normalized = math.min(bars[i] / 100 * max_height, max_height)
        -- Redondeamos al bloque más cercano y nos aseguramos de que sea al menos 1.
        local level = math.max(1, math.floor(normalized + 0.5))

        -- Añadimos el carácter de bloque correspondiente.
        -- Usamos un carácter por barra, pero podríamos añadir un espacio para separarlas.
        display = display .. block_chars[level + 1]
    end

    -- 3. Actualizamos el texto del widget en la barra.
    barWidget.setText(display)
end
