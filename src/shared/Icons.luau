--!strict
-- Ícones da interface (pacote "Free Icon Pack" de @gvesster, enviado pelo Daniel). Os arquivos PNG ficam em
-- assets/icons/ no repositório; para aparecerem no jogo, cada um precisa ser enviado ao Roblox e ter o ID
-- colado aqui (passo a passo em assets/icons/README.md). Com ID 0, a interface continua só com texto.

local Icons = {}

local IDS: { [string]: number } = {
	Cash = 0, -- saldo no topo da tela
	Safe = 0, -- cofre (linha embaixo do saldo)
	Shop = 0, -- botão SHOP
	Index = 0, -- botão INDEX
	Lure = 0, -- botão LURE (Isca da Fenda)
	Gifts = 0, -- botão GIFTS
	Franchise = 0, -- botão FRANCHISE
	Baton = 0, -- ícone do Shock Baton na barra de ferramentas
	Robux = 0, -- botões de compra com Robux
	Event = 0, -- faixa do evento aleatório
	Close = 0, -- botão de fechar das janelas
}

-- "rbxassetid://..." do ícone, ou nil se o ID ainda não foi colado.
function Icons.get(name: string): string?
	local id = IDS[name]
	return if id and id > 0 then `rbxassetid://{id}` else nil
end

return Icons
