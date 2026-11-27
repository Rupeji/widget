function render_ui()
    local s = noctalia.settings.get()
    local levels = noctalia.state.get("levels") or {}
    local num_bars = s.bars or 24
    local bar_w = s.bar_width or 5
    local gap = s.bar_gap or 4
    local radius = s.bar_radius or 2
    local total_h = s.height or 72
    local pad_x = s.padding_x or 14
    local pad_y = s.padding_y or 10
    local card_r = s.card_radius or 12
    local inner_h = math.max(12, total_h - (pad_y * 2))

    local children = {}
    for i = 1, num_bars do
        local lvl = levels[i] or 0.05
        local h = math.max(3, math.floor(inner_h * lvl))
        table.insert(children, ui.box({
            width = bar_w,
            height = h,
            background = "primary",
            borderRadius = radius,
        }))
    end

    return ui.box({
        height = total_h,
        paddingLeft = pad_x,
        paddingRight = pad_x,
        paddingTop = pad_y,
        paddingBottom = pad_y,
        background = "surfaceContainerHigh",
        borderRadius = card_r,
        ui.row({
            spacing = gap,
            align = "end",
            height = inner_h,
            table.unpack(children)
        })
    })
end
