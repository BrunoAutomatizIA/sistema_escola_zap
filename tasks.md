# Tasks — EscolaZap

Rastreamento de pendências do projeto. Cada task referencia a spec correspondente em `specs/`.

---

## 🔴 Alta Prioridade

- [ ] **[BANCO]** Adicionar tabela `sessoes_escola` ao `schema.sql`
  - Incluir RLS policy e GRANT para `anon`
  - DDL exato em `handoff.md` → seção "Setup do zero → 1. Banco de dados"

---

## 🟢 Baixa Prioridade

- [ ] **[SEGURANÇA]** Mover chaves de API para variáveis de ambiente do n8n
  - Evolution API key e Supabase anon key hardcoded em `index.html` (bloco `CONFIG`)
  - Supabase anon key também em `bot_escola.json` (todos os nós HTTP)

---

## ✅ Concluído

- [x] Corrigir bug de regex em "Fazer Reserva" (quebrava o fluxo silenciosamente)
- [x] Comandos globais `CANCELAR` e `MENU`/`0` — funcionam em qualquer etapa, inclusive no cadastro
- [x] Atualizar `bot_escola.json` para Supabase novo (`ywsobgbpwhykkfolvoml`)
- [x] Criar modal de nova autorização em `AuthApp` — `specs/dashboard-autorizacoes.md`
- [x] Cadastro de responsáveis via bot (multi-step 2 passos) — `specs/bot-cadastro.md`
- [x] Fluxo de Autorização de Busca via bot — `specs/bot-autorizacao.md`
- [x] Fluxo de Ocorrência via bot (protocolo OC-) — `specs/bot-ocorrencia.md`
- [x] Fluxo de Solicitação via bot (protocolo SL-) — `specs/bot-solicitacao.md`
- [x] Fluxo de Avisos via bot — `specs/bot-avisos.md`
- [x] Fluxo de Cardápio via bot — `specs/bot-cardapio.md`
- [x] Fluxo de Agenda via bot — `specs/bot-agenda.md`
- [x] Dashboard — Responsáveis (CRUD completo + busca) — `specs/dashboard-responsaveis.md`
- [x] Dashboard — Cardápio (publicar + histórico) — `specs/dashboard-cardapio.md`
- [x] Dashboard — Agenda (filtro por turma + CRUD) — `specs/dashboard-agenda.md`
- [x] Dashboard — Ocorrências (Kanban 4 colunas) — `specs/dashboard-ocorrencias.md`
- [x] Dashboard — Solicitações (Kanban 4 colunas) — `specs/dashboard-solicitacoes.md`
- [x] Dashboard — Avisos (swim lanes + envio WhatsApp) — `specs/dashboard-avisos.md`
- [x] Dashboard — Comunicados (massa + barra de progresso) — `specs/dashboard-comunicados.md`
- [x] Dashboard — Autorizações (lista + busca + exclusão) — `specs/dashboard-autorizacoes.md`
- [x] Tema claro/escuro (localStorage)
- [x] Layout responsivo (desktop / tablet / mobile)
- [x] Webhook de notificação (CORS bypass)
