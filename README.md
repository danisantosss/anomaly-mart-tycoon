# Anomaly Mart Tycoon

> Nome provisório. De dia você transforma uma lojinha 24h no maior mercado da rua. De madrugada, alguns
> clientes não são humanos.

Tycoon de loja + anomalias, feito no Roblox. Todo o código Luau vive neste repositório e é sincronizado com o
Roblox Studio pelo [Rojo](https://rojo.space).

- **Primeira vez aqui?** Siga o [passo a passo de instalação](docs/INSTALACAO.md).
- **O que é o jogo:** [GDD v0.1](https://claude.ai/artifact/A811F2n3bTXoEB72r5mBBa) (documento vivo, pode
  comentar por lá).

## Estrutura

```
default.project.json   mapa "pasta do repo -> lugar no Studio" (o Rojo lê isto)
rokit.toml             versões das ferramentas (rojo, selene, stylua)
src/
  server/   -> ServerScriptService.Server              (só roda no servidor)
  client/   -> StarterPlayer.StarterPlayerScripts.Client (roda em cada jogador)
  shared/   -> ReplicatedStorage.Shared               (código usado pelos dois lados)
docs/                  instalação, especificações e decisões
```

Convenções de arquivo do Rojo:

| Arquivo                       | Vira no Studio |
| ----------------------------- | -------------- |
| `Nome.server.luau`            | `Script`       |
| `Nome.client.luau`            | `LocalScript`  |
| `Nome.luau`                   | `ModuleScript` |
| `init.server.luau` numa pasta | a própria pasta vira um `Script` e os arquivos dela viram filhos |

## Dia a dia

```bash
git pull                                   # pega o que foi aprovado
rojo serve                                 # liga a sincronização
```

No Studio: aba **Plugins → Rojo → Connect**. Toda mudança salva em `src/` aparece no Studio na hora.

Antes de abrir um PR, as mesmas checagens do CI:

```bash
stylua src        # formata
selene src        # procura erros comuns
rojo build -o AnomalyMart.rbxl
```

## Regras do projeto

- Código Luau com `--!strict`. Nomes no código em inglês, comentários em português.
- Textos que o jogador vê: em inglês.
- **Nunca confiar no cliente**: dinheiro, compras, upgrades e anomalias capturadas são decididos no servidor.
- **Sem caixinha de sorte paga** (proibida para jogadores do Brasil). Qualquer recompensa aleatória se
  consegue jogando, nunca com Robux.
- Terror leve: estranho e engraçado, sem sangue nem gore.
- Toda mudança entra por pull request revisado pelo Daniel.
