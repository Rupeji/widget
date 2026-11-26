-- widget.luau
function update()
    noctalia.setUpdateInterval(33) -- ~30 FPS

    -- CLAVE: Leer el estado compartido
    local bars = noctalia.state.get("audio_bars")

    if not bars or #bars == 0 then
        barWidget.setText(" ♪ ")
        return
    end

    -- Un truco visual más compacto para la barra: usar bloques verticales
    local block_chars = { " ", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
    local display = ""
    for i = 1, #bars do
        -- Normalizar de 0-100 a 1-8
        local level = math.max(1, math.floor((bars[i] / 100) * 8) + 1)
        if level > 8 then level = 8 end
        display = display .. block_chars[level]
    end

    barWidget.setText(display)
end
