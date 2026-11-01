# Ícones da interface

PNGs do **Free Icon Pack v3.1 (Basic)** de @gvesster (variante "1st Outline", 256 px),
enviados pelo Daniel. A licença do pacote permite uso comercial em jogos, mas **não** permite revender ou
redistribuir os ícones como pacote. Crédito: Icons by @gvesster.

| Arquivo | Onde aparece |
| --- | --- |
| Cash.png | saldo no topo da tela |
| Safe.png | linha do cofre embaixo do saldo |
| Event.png | faixa do evento aleatório |
| Shop.png, Index.png, Lure.png, Gifts.png, Franchise.png | botões do menu lateral |
| Robux.png | botões de compra com Robux (LURE e gamepasses) |
| Baton.png | Shock Baton na barra de ferramentas |
| Close.png | botão de fechar das janelas |

## Como colocar no jogo

O Roblox só mostra imagens que foram enviadas para ele, então cada PNG precisa de um ID:

1. No Studio, abra **View → Asset Manager**.
2. Clique em **Bulk Import** e escolha todos os PNGs desta pasta.
3. Para cada imagem, clique com o botão direito → **Copy Asset ID**.
4. Cole o número no ícone correspondente em `src/shared/Icons.luau` (ou mande a lista para o Claude).

Enquanto um ID for `0`, aquele lugar continua só com texto (nada quebra).
