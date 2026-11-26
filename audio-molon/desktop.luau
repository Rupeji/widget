-- desktop.luau
function draw()
    noctalia.setUpdateInterval(33) -- ~30 FPS

    local bars = noctalia.state.get("audio_bars")
    if not bars or #bars == 0 then
        ui.text({ text = "♪", size = 48, color = "#ffffff" })
        return
    end

    -- Simular barras grandes con texto espaciado
    local block_chars = { " ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
    local display = ""
    for i = 1, #bars do
        local level = math.max(1, math.floor((bars[i] / 100) * 8) + 1)
        if level > 8 then level = 8 end
        display = display .. block_chars[level] .. " " -- Espacio entre barras
    end

    ui.text({ text = display, size = 32, color = "#ffaa00" })
end
