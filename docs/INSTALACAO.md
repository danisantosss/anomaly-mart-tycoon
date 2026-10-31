# Passo a passo de instalação

Guia para deixar o PC pronto para testar o jogo e revisar o código. Feito pensando em Windows; no Mac os
passos são os mesmos, só muda o instalador do Rokit (indicado abaixo). Leva uns 20 a 30 minutos.

> **Já configurou o PC para o The Inbetween?** Então os programas, o Rokit, o plugin do Rojo e as extensões já
> estão instalados. Faça só o passo 2 (baixar este repositório), rode `rokit install` dentro da pasta dele e
> siga para o passo 6.

## Como as peças se encaixam

```
 GitHub (repo)  <-- git pull/push -->  pasta no seu PC  <-- Rojo -->  Roblox Studio
   código revisado                      src/*.luau                     o jogo rodando
```

- O **código** mora em arquivos `.luau` neste repositório, não dentro do arquivo do Studio.
- O **Rojo** é um pequeno servidor que fica vigiando a pasta `src/` e empurra cada arquivo para o lugar certo
  no Studio (através de um plugin). Você edita no VS Code, salva, e o Studio atualiza sozinho.
- O **Rokit** instala as versões exatas das ferramentas que o projeto usa (Rojo, Selene, StyLua), para todo
  mundo e o CI usarem as mesmas.

## 1. Programas

1. **Roblox Studio**: <https://create.roblox.com> → "Start Creating". Entre com sua conta Roblox.
2. **Git**: <https://git-scm.com/download/win> (pode aceitar as opções padrão do instalador).
3. **VS Code**: <https://code.visualstudio.com>.

## 2. Baixar o repositório

Abra o **PowerShell** (ou o terminal do VS Code) e rode:

```powershell
cd ~\Documents
git clone https://github.com/danisantosss/anomaly-mart-tycoon.git
cd anomaly-mart-tycoon
```

Se o Git pedir login, entre com sua conta do GitHub (o repositório é privado).

## 3. Rokit e as ferramentas

**Windows**

1. Baixe o arquivo `rokit-...-windows-x86_64.zip` da última versão em
   <https://github.com/rojo-rbx/rokit/releases>.
2. Extraia o zip, abra o PowerShell **na pasta extraída** e rode:

   ```powershell
   .\rokit.exe self-install
   ```

3. **Feche e abra o terminal de novo** (para ele enxergar o comando `rokit`).

**Mac** (só para referência)

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
```

Depois, **dentro da pasta do repositório**:

```powershell
rokit install
```

Ele vai perguntar se você confia nas ferramentas (rojo, selene, stylua): responda que sim. Confira:

```powershell
rojo --version     # deve mostrar 7.7.1
```

## 4. Plugin do Rojo no Studio

Com o Studio **fechado**, rode na pasta do repo:

```powershell
rojo plugin install
```

Ao abrir o Studio, a aba **Plugins** terá um botão **Rojo**.

## 5. Extensões do VS Code

Abra a pasta do repositório no VS Code (**File → Open Folder → anomaly-mart-tycoon**). Ele vai sugerir as extensões
recomendadas do projeto; clique em **Install All**. São elas:

| Extensão                          | Para quê |
| --------------------------------- | -------- |
| **Luau Language Server**          | autocompletar, erros de tipo, documentação da API do Roblox ao passar o mouse |
| **Rojo**                          | ligar/desligar o `rojo serve` com um clique |
| **StyLua**                        | formata o código ao salvar |
| **Selene**                        | aponta erros comuns enquanto você lê |

## 6. Primeiro teste (o "olá mundo")

1. Gere o arquivo do jogo a partir do código:

   ```powershell
   rojo build -o AnomalyMart.rbxl
   ```

2. Abra o `AnomalyMart.rbxl` no Studio (clique duplo ou **File → Open from File**). Ele está no `.gitignore`;
   é só uma cópia local, o original é o código.
3. No terminal, ligue a sincronização:

   ```powershell
   rojo serve
   ```

4. No Studio: **Plugins → Rojo → Connect**. Deve aparecer "Connected".
5. Abra a janela **Output** (aba **View → Output**) e aperte **Play** (F5). Você deve ver:

   ```
   [Anomaly Mart] servidor iniciado (v0.0.1)
   [Anomaly Mart] cliente iniciado para SeuNome (v0.0.1)
   ```

6. Teste a sincronização: pare o jogo, mude o `VERSION` em `src/shared/Config.luau` para `"0.0.2"`, salve, e
   aperte Play de novo. A versão nova aparece sem você tocar no Studio. Depois desfaça a mudança
   (`git checkout src/shared/Config.luau`).

Se tudo isso funcionou, está pronto. 🎉

## 7. Revisando e testando um pull request

Quando eu abrir um PR, você pode ler as mudanças no GitHub (aba **Files changed**) e testar no Studio:

```powershell
git fetch
git switch nome-da-branch-do-pr      # o nome aparece no topo do PR
rojo build -o AnomalyMart.rbxl       # só quando o PR mexer em default.project.json
rojo serve
```

Conecte no Studio e jogue. Ao terminar, volte para a `main` com `git switch main` e `git pull`.

Para testar com vários jogadores no próprio PC: aba **Test → Clients and Servers**, escolha 2 jogadores e
**Start**. Abre um servidor e duas janelas de jogador.

O CI do GitHub roda as checagens (formatação, lint e build) em todo PR; se aparecer um ❌, eu corrijo.

## 8. (Opcional, mais à frente) Roblox Studio MCP

O Roblox tem um servidor **MCP** oficial que deixa um assistente de IA (Claude Code ou Claude Desktop rodando
no seu PC) enxergar e mexer no Studio aberto: inspecionar o Explorer, criar e posicionar peças, rodar
comandos no Studio. Para o Anomaly Mart isso ajuda nas partes visuais (montar e conferir a rua, as lojas e a
iluminação) sem você ter que arrastar peças à mão.

Não é necessário agora: o código chega por PR e o Rojo resolve. Quando chegarmos na parte de montagem visual,
eu passo o passo a passo (projeto oficial: <https://github.com/Roblox/studio-rust-mcp-server>; vale conferir lá
a instalação atual, porque ela muda com frequência).

## Problemas comuns

| Sintoma | Solução |
| ------- | ------- |
| `rokit` / `rojo` "não é reconhecido" | Feche e abra o terminal. Se continuar, rode `.\rokit.exe self-install` de novo. |
| Plugin Rojo não aparece no Studio | Rode `rojo plugin install` com o Studio fechado. |
| "Connect" falha | Confira se o `rojo serve` está rodando e mostra a porta `34872`. |
| Mudança não aparece no Studio | O jogo precisa ser parado e iniciado de novo; scripts não recarregam no meio do Play. |
| Versões diferentes do Rojo | O plugin e o `rojo` precisam ser da mesma versão: rode `rojo plugin install` de novo. |
