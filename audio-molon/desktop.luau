--!strict

-- ── Constantes visuales fijas ────────────────────────────────────────────────
local MIN_HEIGHT = 4

-- ── Estado local ─────────────────────────────────────────────────────────────
local numBars = tonumber(noctalia.getConfig("bars")) or 24
local bars: { number } = table.create(numBars, 0)

local function buildUi(): UiNode
	local barWidth = tonumber(noctalia.getConfig("bar_width")) or 8
	local barGap = tonumber(noctalia.getConfig("bar_gap")) or 4
	local maxHeight = tonumber(noctalia.getConfig("max_height")) or 120
	local barColor = tostring(noctalia.getConfig("color") or "primary")
	-- Redondeo proporcional al ancho de barra (máximo 4px)
	local barRadius = math.min(4, math.floor(barWidth / 2))

	local children: { UiNode } = {}

	for i = 1, numBars do
		local val = bars[i] or 0
		local h = math.floor(MIN_HEIGHT + (val * math.max(0, maxHeight - MIN_HEIGHT)))
		table.insert(children, ui.box({
			key = "bar_" .. tostring(i),
			width = barWidth,
			height = h,
			fill = barColor,
			radius = barRadius,
		}))
	end

	return ui.row({
		height = maxHeight,
		gap = barGap,
		align = "end",
		padding = 8,
	}, children)
end

-- Actualiza la cantidad de barras si cambia en la configuración
noctalia.state.watch("bars_count", function(count: any)
	if type(count) == "number" and count ~= numBars then
		numBars = count
		bars = table.create(numBars, 0)
		desktopWidget.render(buildUi())
	end
end)

-- Recibe cada fotograma de audio desde service.luau
noctalia.state.watch("cava_line", function(line: any)
	if type(line) ~= "string" then
		return
	end

	local idx = 1
	local changed = false

	for valStr in string.gmatch(line, "([^;]+)") do
		if idx <= numBars then
			local n = tonumber(valStr)
			if n then
				local normalized = math.clamp(n / 1000, 0, 1)
				local prev = bars[idx] or 0
				if math.abs(normalized - prev) > 0.002 then
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
end)

-- Renderizado inicial en reposo
desktopWidget.render(buildUi())
