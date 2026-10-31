--!strict
-- Formata números grandes do jeito dos tycoons: 950, 1.2K, 3.4M, 5.6B...
-- Usado no placar, na HUD e no cofre.

local NumberFormat = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function NumberFormat.short(value: number): string
	local sign = if value < 0 then "-" else ""
	local number = math.floor(math.abs(value))
	if number < 1000 then
		return sign .. tostring(number)
	end

	local index = 0
	while number >= 1000 and index < #SUFFIXES do
		number /= 1000
		index += 1
	end

	-- Uma casa decimal só quando ajuda a ler (1.2K, mas 120K). Trunca em vez de arredondar, para nunca
	-- mostrar mais dinheiro do que o jogador tem.
	local text
	if number >= 100 then
		text = tostring(math.floor(number))
	else
		local truncated = math.floor(number * 10) / 10
		text = if truncated % 1 == 0
			then tostring(math.floor(truncated))
			else string.format("%.1f", truncated)
	end
	return sign .. text .. SUFFIXES[index]
end

function NumberFormat.cash(value: number): string
	return "$" .. NumberFormat.short(value)
end

return NumberFormat
