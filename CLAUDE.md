# Escola Digital — Bot WhatsApp para Colégio Raio de Luz

Produto da **Automatiz.ia** que automatiza a comunicação escola-família via WhatsApp. Composto por três artefatos:

| Arquivo | O que é |
|---|---|
| `bot_escola.json` | Workflow n8n principal (bot WhatsApp) |
| `notificacao_webhook.json` | Workflow n8n auxiliar — webhook de notificações |
| `index.html` | Dashboard admin SPA (HTML/CSS/JS puro, sem build) |
| `schema.sql` | Script DDL completo para o Supabase |

---

## Infraestrutura

| Serviço | Uso | Credencial no projeto |
|---|---|---|
| **n8n** | Plataforma de automação que roda os workflows | host: `n8n.automacaopme.com.br` |
| **Evolution API** | Gateway WhatsApp | `apikey: F5E45E6A06AC-4857-807A-923D226DE8E1` (host: `evolution.automacaopme.com.br`, instance: `Bot_Escola`) |
| **Supabase** | Banco PostgreSQL via REST | projeto `AutomatizIA` — `ywsobgbpwhykkfolvoml` (anon key hardcoded em `index.html`) |

> As credenciais estão hardcoded nos arquivos. Em produção com múltiplos clientes, extraí-las para variáveis de ambiente do n8n.

> **ATENÇÃO:** `bot_escola.json` ainda aponta para o projeto Supabase antigo (`rcghqqwbwxbhrxjwutqu`). Todos os nós HTTP do bot precisam ter a URL e chave atualizadas para `ywsobgbpwhykkfolvoml`. O dashboard (`index.html`) já usa o projeto correto.

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

**Status de aviso:** `pendente` → `lido`

**Status de reserva:** `pendente` → `confirmada` | `cancelada`

**Status de comunicado:** `rascunho` → `enviado`

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

O `sendWhatsApp(number, text)` no dashboard chama este endpoint. Usado por AvisoApp, ComunicadoApp e ReservaApp ao confirmar/cancelar.

---

## Dashboard Admin (`index.html`)

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
| **Reservas** | `ReservaApp` | `reservas_escola` + `responsaveis` |

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
- Lista pessoas autorizadas a retirar alunos
- Form: busca responsável + nome do autorizador, documento, parentesco

**Reservas (`ReservaApp`):**
- Lista de reservas de espaços (salão, quadra, etc.)
- Botões Confirmar/Cancelar em cards pendentes
- Ao confirmar/cancelar: PATCH status + `sendWhatsApp()` ao responsável
- Form de nova reserva: busca responsável + local + data + horário

### Configurações do Bot (modal)
- Ícone ⚙️ na topbar
- Campo para alterar nome do bot via `POST /chat/updateProfileName/Bot_Escola` (Evolution API v2)

---

## Tema e Design

### Cores (Colégio Raio de Luz)
```css
--brand-primary:       #1E72BE   /* azul principal */
--brand-primary-dark:  #155A97
--brand-secondary:     #7DC242   /* verde */
--brand-secondary-dark:#5F9930
--brand-accent:        #FBB040   /* âmbar */
--brand-accent-dark:   #D9960A
```

### Light / Dark
| Token | Light | Dark |
|---|---|---|
| `--bg-page` | `#F0F6FF` | `#091828` |
| `--bg-surface` | `#FFFFFF` | `#0F2235` |
| `--sidebar-bg` | `#0D2140` | `#060E1A` |
| `--text-main` | `#0D2140` | `#E0EEFF` |

Persistido em `localStorage['escola-theme']`. Padrão: `light`.

### Fontes
- **Outfit** (400/500/600/700/800) — UI principal
- **Space Mono** (400/700) — métricas e labels monospace

### Ícones
SVG sprite inline no topo do `<body>`. Novos ícones: adicionar `<symbol id="icon-NOME">` ao sprite. Uso: `<svg class="icon"><use href="#icon-NOME"/></svg>`.

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

`index.html` é auto-contido. Edite diretamente — sem build. Ao adicionar nova página:
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
| `AvisoApp` | `avisos` | POST + WhatsApp |
| `ComunicadoApp` | `comunicados_escola` | POST (rascunho) + PATCH + WhatsApp em massa |
| `AuthApp` | `autorizacoes` | POST/DELETE |
| `ReservaApp` | `reservas_escola` | POST/PATCH + WhatsApp ao confirmar/cancelar |

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
