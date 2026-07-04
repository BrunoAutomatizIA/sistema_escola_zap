# Escola Digital — Bot WhatsApp para Colégio Raio de Luz

Produto da **Automatiz.ia** que automatiza a comunicação escola-família via WhatsApp. Composto por três artefatos:

---

## Spec Driven Development

Este projeto segue o modelo **SDD**: toda feature tem um spec antes de ter código.

| Arquivo | Papel |
|---|---|
| `specs/_template.md` | Template com os 10 campos obrigatórios de todo spec |
| `specs/bot-*.md` | Specs dos fluxos do bot WhatsApp |
| `specs/dashboard-*.md` | Specs das páginas do dashboard admin |
| `tasks.md` | Backlog de pendências com referência ao spec de cada task |

**Fluxo de trabalho:**
1. Antes de implementar qualquer feature: escrever ou atualizar o spec em `specs/`.
2. Ao implementar: ler o spec correspondente e seguir as seções 5 (Regras), 7 (Critérios) e 10 (Agent behavior).
3. Ao concluir: marcar os critérios da seção 7 como `[x]` e mover a task em `tasks.md` para "Concluído".

---

## Rotina de commit e publicação

Toda alteração solicitada pelo usuário é implementada e, em seguida, **já commitada e enviada (`git push`) para o GitHub** (`origin/main`) — sem pedir confirmação adicional para esse push especificamente. O fluxo é commit direto em `main` (sem Pull Request).

- Fazer stage apenas dos arquivos relacionados ao pedido (nunca `git add -A`/`git add .` às cegas), para não arrastar mudanças não relacionadas que estejam soltas no working tree.
- Mensagens de commit seguem o padrão já usado no histórico (`tipo: descrição curta`, ex. `fix:`, `feat:`, `docs:`).
- Continuam exigindo confirmação explícita do usuário (não entram nessa rotina automática): force-push, `reset --hard`, reescrita de histórico, ou qualquer operação destrutiva/irreversível.

---

| Arquivo | O que é |
|---|---|
| `bot_escola.json` | Workflow n8n principal (bot WhatsApp) |
| `notificacao_webhook.json` | Workflow n8n auxiliar — webhook de notificações |
| `index_2.html` | Dashboard admin SPA (HTML/CSS/JS puro, sem build) |
| `schema.sql` | Script DDL completo para o Supabase |

---

## Infraestrutura

| Serviço | Uso | Credencial no projeto |
|---|---|---|
| **n8n** | Plataforma de automação que roda os workflows | host: `n8n.automacaopme.com.br` |
| **Evolution API** | Gateway WhatsApp | `apikey: F5E45E6A06AC-4857-807A-923D226DE8E1` (host: `evolution.automacaopme.com.br`, instance: `Bot_Escola`) |
| **Supabase** | Banco PostgreSQL via REST | projeto `AutomatizIA` — `ywsobgbpwhykkfolvoml` (anon key hardcoded em `index_2.html`) |

> As credenciais estão hardcoded nos arquivos. Em produção com múltiplos clientes, extraí-las para variáveis de ambiente do n8n.

> **ATENÇÃO:** `bot_escola.json` ainda aponta para o projeto Supabase antigo (`rcghqqwbwxbhrxjwutqu`). Todos os nós HTTP do bot precisam ter a URL e chave atualizadas para `ywsobgbpwhykkfolvoml`. O dashboard (`index_2.html`) já usa o projeto correto.

---

## Schema do Banco (Supabase — projeto `ywsobgbpwhykkfolvoml`)

```
responsaveis      — id, nome, telefone, aluno, turma, created_at
sessoes_escola    — telefone (PK), etapa, dados (JSONB), updated_at
cardapio          — id, semana_inicio (date), segunda/terca/quarta/quinta/sexta, created_at
agenda            — id, titulo, data (date), turma, descricao, created_at
ocorrencias_escola— id, responsavel_id (FK→responsaveis), aluno, titulo, descricao, urgencia, status, created_at
solicitacoes      — id, responsavel_id (FK→responsaveis), tipo, descricao, urgencia, status, created_at
avisos            — id, responsavel_id (FK→responsaveis), titulo, mensagem, status, created_at
autorizacoes      — id, responsavel_id (FK→responsaveis), nome_autorizador, documento, parentesco, created_at
reservas_escola   — id, responsavel_id (FK→responsaveis), local, data (date), horario, status, created_at
comunicados_escola— id, turma, titulo, mensagem, status, enviado_em, destinatarios, created_at
```

**Status de ocorrência:** `aberta` → `analise` → `andamento` → `resolvida`

**Status de solicitação:** `pendente` → `analise` → `andamento` → `resolvido`

**Status de aviso:** `pendente` → `lido` (PATCH via `markRead()`)

**Status de comunicado:** `rascunho` → `enviado`

> A tabela `reservas_escola` existe no banco mas a **página Reservas foi removida** do dashboard. Os dados podem ser gerenciados direto no Supabase enquanto não houver uma nova página.

> Após rodar `schema.sql`, executar obrigatoriamente no SQL Editor:
> ```sql
> GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
> GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
> ```
> Sem isso o role `anon` (usado pela anon key) não tem permissão de INSERT/UPDATE/DELETE em tabelas criadas via SQL direto.

---

## Workflow n8n — Arquitetura do Bot (`bot_escola.json`)

### Entrada e resposta imediata
```
Webhook (POST /escola-bot)
  ├─► Respond 200   ← responde HTTP imediatamente (padrão async)
  └─► Parsear Mensagem
```

**Parsear Mensagem** descarta:
- Mensagens enviadas pelo próprio bot (`fromMe === true`)
- Mensagens de grupos (`remoteJid` contém `@g.us`)

Extrai: `from` (telefone limpo), `texto`, `buttonId`, `instance`.

### Lookup e consolidação
```
Parsear Mensagem → GET Responsavel → GET Sessao → Consolidar → Responsavel existe? (IF)
```

### Fluxo de cadastro (responsável não encontrado)
```
Responsavel existe? [false] → Lógica Cadastro → DELETE Sessao → Cadastro OK? (IF)
  ├─► [em andamento] INSERT Sessao + Enviar mensagem
  └─► [ok=true] INSERT Responsavel + Enviar confirmação
```

**Etapas de sessão do cadastro:**
```
null → aguardando_nome → aguardando_aluno → aguardando_turma → (ok=true)
```

### Roteamento principal (responsável cadastrado)
```
Responsavel existe? [true] → Roteador → Switch Rota
  ├── cardapio     → texto="1" ou etapa.startsWith("cardapio_")
  ├── agenda       → texto="2" ou etapa.startsWith("agenda_")
  ├── ocorrencias  → texto="3" ou etapa.startsWith("ocorrencia_")
  ├── solicitacoes → texto="4" ou etapa.startsWith("solicitacao_")
  ├── avisos       → texto="5" ou etapa.startsWith("aviso_")
  ├── reservas     → texto="6" ou etapa.startsWith("reserva_")
  ├── cancelar     → texto é "CANCELAR" (maiúsculo)
  └── menu         → qualquer outra coisa
```

**Padrão de sessão multi-step (todos os fluxos):**
```
DELETE Sessao → Lógica → Fluxo OK? (IF)
  ├─► [em andamento] INSERT Sessao (próxima etapa) → Enviar resposta
  └─► [ok=true] INSERT dado final → Enviar resposta final
```
> A sessão usa DELETE+INSERT, não UPSERT. Garante registro único por telefone.

---

## Webhook de Notificação (`notificacao_webhook.json`)

Permite que o dashboard envie WhatsApp sem bloqueio de CORS.

**Endpoint:** `POST https://n8n.automacaopme.com.br/webhook/notificar-escola` com body `{ number, text }`

O `sendWhatsApp(number, text)` no dashboard chama este endpoint. Usado por AvisoApp e ComunicadoApp.

---

## Dashboard Admin (`index_2.html`)

SPA pura: nenhum framework, nenhum build. Abre direto no browser. Navegação client-side via atributos `data-page`.

### Páginas

| Página | App JS | Tabela Supabase |
|---|---|---|
| **Dashboard** | — | lê de todas as tabelas para métricas |
| **Responsáveis** | `RespApp` | `responsaveis` |
| **Cardápio** | `CardapioApp` | `cardapio` |
| **Agenda** | `AgendaApp` | `agenda` |
| **Ocorrências** | `OccApp` | `ocorrencias_escola` |
| **Solicitações** | `SolApp` | `solicitacoes` |
| **Avisos** | `AvisoApp` | `avisos` + `responsaveis` |
| **Comunicados** | `ComunicadoApp` | `comunicados_escola` + `responsaveis` |
| **Autorizações** | `AuthApp` | `autorizacoes` + `responsaveis` |

### Funcionalidades por módulo

**Responsáveis (`RespApp`):**
- Lista agrupada por turma, ordenada por nome
- Busca por nome, aluno ou turma + filtro por turma
- Modal de cadastro/edição (POST/PATCH); exclusão com confirmação (DELETE)
- Campos: nome, telefone (obrigatório), aluno, turma

**Cardápio (`CardapioApp`):**
- Lista cardápios semanais ordenados por `semana_inicio` DESC
- Form publica novo cardápio com campos por dia (segunda–sexta)
- Botão de exclusão por card

**Agenda (`AgendaApp`):**
- Cards de eventos separados por "Próximos" e "Passados"
- Filtro por turma (tabs)
- Form de novo evento: título, data, turma (opcional), descrição

**Ocorrências (`OccApp`) — Kanban:**
- 4 colunas: Aberta → Em análise → Em andamento → Resolvida
- Botão "Avançar" em cada card (`advance()` PATCH status)

**Solicitações (`SolApp`) — Kanban:**
- 4 colunas: Pendente → Análise → Andamento → Resolvido
- Mesmo padrão de `advance()` via PATCH

**Avisos (`AvisoApp`) — Kanban com swim lanes:**
- Layout: **raias horizontais** (swim lanes) × **2 colunas** (Pendente | Lido)
- Raia **"Individual"** (👤) aparece sempre primeiro; raias por turma (🏫) em ordem alfabética
- Agrupamento automático pelo campo `responsaveis.turma`; sem turma → raia Individual
- Card tem botão "✅ Marcar lido" → PATCH `status='lido'` + re-render
- `_resp(a)` normaliza join PostgREST (objeto ou array de um elemento)
- Form de novo aviso: título, mensagem, destinatário (individual, turma ou todos)
- `send()` faz POST em `avisos` + `sendWhatsApp()` para cada alvo

**Comunicados (`ComunicadoApp`):**
- Lista com badge Enviado/Rascunho
- Modal "+ Novo": título, mensagem, turma (todos se vazio)
- "Salvar rascunho" → POST com status='rascunho'
- "Enviar a todos/turma" → POST + busca responsáveis + loop `sendWhatsApp()` + PATCH status='enviado'
- Barra de progresso sequencial ("Enviando... 47/128")
- `sendDraftNow(id)` envia rascunho já salvo

**Autorizações (`AuthApp`):**
- Lista pessoas autorizadas a retirar alunos, com busca por aluno, responsável ou nome do autorizador
- `load()` faz dois GETs em paralelo: `autorizacoes` (com join PostgREST) + `responsaveis` (para `respMap`)
- `_resp(a)` tenta o join PostgREST primeiro; se nulo, cai para `respMap[a.responsavel_id]` (join client-side)
- Exclusão com confirmação (DELETE)
- **Pendente:** não tem modal de nova autorização via dashboard

### Configurações do Bot (modal)
- Ícone de engrenagem (SVG) na topbar
- Campo para alterar nome do bot via `POST /chat/updateProfileName/Bot_Escola` (Evolution API v2)

---

## Tema e Design

Identidade visual inspirada em análise real de `apple.com/br/store` (paleta/tipografia via `getComputedStyle`,
não em suposições sobre a marca Apple). Logo do Colégio Raio de Luz (`assets/logo-colegio-raio-de-luz.png`)
aplicado sobre um card branco na sidebar, para manter contraste em qualquer tema.

### Cores
```css
--brand-primary:       #0066CC   /* ações primárias/links */
--brand-primary-dark:  #004C99
--brand-secondary:     #1D1D1F   /* preenchimentos escuros */
--brand-secondary-dark:#000000
--brand-accent:        #B64400   /* único acento cromático fora da escala de cinza */
--brand-accent-dark:   #8F3600
--brand-danger:        #D70015   /* exceção funcional — ações destrutivas/urgência alta */
```

Paleta monocromática (cinzas) + os acentos acima. Dark mode em preto puro (`#000`/`#1D1D1F`).

### Light / Dark
| Token | Light | Dark |
|---|---|---|
| `--bg-page` | `#F5F5F7` | `#000000` |
| `--bg-surface` | `#FFFFFF` | `#1D1D1F` |
| `--sidebar-bg` | `#1D1D1F` | `#000000` |
| `--text-main` | `#1D1D1F` | `#F5F5F7` |

Persistido em `localStorage['escola-theme']`. Padrão: `light`.

### Fontes
Pilha nativa do sistema (`-apple-system, "SF Pro Display/Text", Helvetica Neue`) — sem SF Pro embutida (fonte
proprietária da Apple). Pesos limitados a 400/600 (sem bold pesado 700–900).

### Componentes
Cards com `border-radius:18px` + sombra `2px 4px 12px rgba(0,0,0,.08)`; botões em pílula (`border-radius:980px`),
replicando o padrão outline→preenchido-escuro no hover observado no site de origem.

### Ícones
SVG sprite inline no topo do `<body>`, estilo Feather (ícones de linha): `.icon { fill:none; stroke:currentColor;
stroke-linecap:round; stroke-linejoin:round; }` (exceto `.icon-fill`, usada só no glifo sólido do WhatsApp).
Novos ícones: adicionar `<symbol id="icon-NOME">` ao sprite. Uso: `<svg class="icon"><use href="#icon-NOME"/></svg>`.
Mensagens de WhatsApp enviadas pelo bot (templates com emoji tipo 🌟) ficam fora do escopo de identidade visual
do dashboard — são conteúdo do bot para os pais, não elementos de UI.

### Responsivo
| Breakpoint | Comportamento |
|---|---|
| `≥768px` | Sidebar lateral, grid 4 colunas, Kanban em matriz |
| `<1100px` | Métricas 2 colunas, grids reduzem |
| `<768px` | Sidebar ocultada (abre pelo hambúrguer), bottom-nav visível, Kanban em lista |
| `<480px` | Tudo em coluna única, modais sobem do rodapé |

---

## Helpers JavaScript

### supaApi
```js
supaApi(method, path, body)  // retorna Promise
// GET: retorna null em caso de erro (não lança)
// POST/PATCH/DELETE: lança Error com mensagem do servidor em caso de erro
supaApi('GET', '/responsaveis?select=*&order=nome.asc')
supaApi('POST', '/agenda', { titulo, data, turma, descricao })
supaApi('PATCH', '/ocorrencias_escola?id=eq.5', { status: 'analise' })
supaApi('DELETE', '/sessoes_escola?telefone=eq.5511999999999')
```

### sendWhatsApp
```js
sendWhatsApp(number, text)  // POST ao webhook n8n; falhas silenciosas (console.warn)
```

### showToast
```js
showToast('Mensagem de sucesso')
showToast('Algo deu errado', 'error')
showToast('Informação', 'info')
```

---

## Como editar o dashboard

`index_2.html` é auto-contido. Edite diretamente — sem build. Ao adicionar nova página:
1. Criar `<div class="page" id="page-NOME">` dentro de `<main class="main">`
2. Adicionar item no `.sidebar` com `data-page="NOME"`
3. Adicionar item no `.bottom-nav` com `data-page="NOME"`
4. Criar o App JS seguindo o padrão `{ data:[], load(), render() }`
5. Registrar no `loadPage()` e no auto-refresh (intervalo de 60s)

## Como editar o bot

1. Importe `bot_escola.json` no n8n (ou edite diretamente se já importado).
2. Ao adicionar módulo novo, siga o padrão:
   - Prefixo de sessão único (ex: `boletim_`)
   - Nova rota no nó **Roteador** + nova saída no **Switch Rota**
   - DELETE sessão → Lógica → IF ok? → INSERT sessão (continua) ou INSERT dado final (concluiu)
3. Exporte como JSON e substitua `bot_escola.json`.

---

## Persistência do dashboard

Todas as páginas recarregam dados ao serem navegadas. Auto-refresh a cada 60s.

| App JS | Tabela | Padrão de escrita |
|---|---|---|
| `RespApp` | `responsaveis` | POST/PATCH/DELETE |
| `CardapioApp` | `cardapio` | POST/DELETE |
| `AgendaApp` | `agenda` | POST/DELETE |
| `OccApp` | `ocorrencias_escola` | PATCH status via `advance()` |
| `SolApp` | `solicitacoes` | PATCH status via `advance()` |
| `AvisoApp` | `avisos` + `responsaveis` | POST + WhatsApp (send); PATCH status='lido' (markRead) |
| `ComunicadoApp` | `comunicados_escola` | POST (rascunho) + PATCH + WhatsApp em massa |
| `AuthApp` | `autorizacoes` + `responsaveis` | DELETE + join client-side via `respMap` |

---

## Pendências / TODOs

- **bot_escola.json — Supabase desatualizado** ⚠️ — todos os nós HTTP do bot ainda apontam para o projeto antigo (`rcghqqwbwxbhrxjwutqu`). Atualizar URLs e chaves para `ywsobgbpwhykkfolvoml`.
- **sessoes_escola** — tabela de sessão do bot não está em `schema.sql`. Criar:
  ```sql
  CREATE TABLE IF NOT EXISTS sessoes_escola (
    telefone text PRIMARY KEY,
    etapa    text,
    dados    jsonb,
    updated_at timestamptz DEFAULT now()
  );
  ALTER TABLE sessoes_escola ENABLE ROW LEVEL SECURITY;
  CREATE POLICY "anon all" ON sessoes_escola USING (true) WITH CHECK (true);
  GRANT ALL ON sessoes_escola TO anon;
  ```
- **Fluxos do bot** — apenas o cadastro está documentado nos nós vistos. Os fluxos de cardápio, agenda, ocorrências, solicitações, avisos e reservas precisam ser validados após a atualização do Supabase.
- **Segurança** — mover as chaves de API (Supabase anon key e Evolution API key) para variáveis de ambiente do n8n antes de entregar para o cliente em produção.
- **AuthApp sem form de nova autorização** — a página só lista e exclui. Criar modal de cadastro com busca de responsável + campos nome/documento/parentesco.

---

## Documentos de referência

| Arquivo | Conteúdo |
|---|---|
| `CLAUDE.md` | Arquitetura, schema, padrões de código — para o Claude Code |
| `handoff.md` | Estado atual, setup do zero, pendências priorizadas — para entrega ao cliente |
| `schema.sql` | DDL completo + GRANTs — rodar no Supabase SQL Editor |
