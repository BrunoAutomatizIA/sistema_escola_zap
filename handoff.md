# Handoff — Escola Digital (Colégio Raio de Luz)

**Produto:** Sistema de comunicação escola-família via WhatsApp  
**Cliente:** Colégio Raio de Luz  
**Responsável Automatiz.ia:** Bruno Vargas Joaquim  
**Repositório:** https://github.com/BrunoAutomatizIA/sistema_escola_zap  
**Data:** 2026-06-22

---

## O que foi entregue

### Artefatos

| Arquivo | Descrição |
|---|---|
| `index.html` | Dashboard admin — SPA completa, abre direto no browser |
| `bot_escola.json` | Workflow n8n do bot WhatsApp |
| `notificacao_webhook.json` | Workflow n8n auxiliar para envio de WhatsApp via dashboard |
| `schema.sql` | Script DDL completo do banco Supabase |

### Páginas do dashboard (`index.html`)

| Página | O que faz |
|---|---|
| Dashboard | Métricas gerais (ocorrências, avisos, autorizações, responsáveis) |
| Responsáveis | Cadastro, edição, exclusão e busca de pais/responsáveis |
| Cardápio | Publicação do cardápio semanal (segunda a sexta) |
| Agenda | Eventos e datas importantes por turma |
| Ocorrências | Kanban 4 colunas: Aberta → Análise → Andamento → Resolvida |
| Solicitações | Kanban 4 colunas: Pendente → Análise → Andamento → Resolvido |
| Avisos | Kanban com swim lanes: raia Individual + raia por turma × colunas Pendente/Lido |
| Comunicados | Envio em massa por turma ou para todos, com barra de progresso |
| Autorizações | Cadastro de pessoas autorizadas a buscar o aluno |

---

## Credenciais e infraestrutura

> Todas as credenciais estão hardcoded em `index.html` (linhas ~1296–1301). Antes de entregar o acesso ao cliente, avaliar se devem ser trocadas ou ocultadas.

| Serviço | Detalhe |
|---|---|
| **Supabase** | Projeto `AutomatizIA` · URL: `https://ywsobgbpwhykkfolvoml.supabase.co` |
| **Supabase anon key** | `eyJhbGci...kWcE8` (ver `index.html`) |
| **Evolution API** | `https://evolution.automacaopme.com.br` · Instance: `Bot_Escola` |
| **Evolution API key** | `F5E45E6A06AC-4857-807A-923D226DE8E1` |
| **n8n** | `https://n8n.automacaopme.com.br` |
| **Webhook bot** | `POST /webhook/escola-bot` |
| **Webhook notificações** | `POST /webhook/notificar-escola` |

---

## Setup do zero

### 1. Banco de dados (Supabase)

1. Abrir o projeto `AutomatizIA` em [supabase.com](https://supabase.com)
2. SQL Editor → rodar `schema.sql` completo
3. Em seguida, rodar obrigatoriamente:
   ```sql
   GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
   GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
   ```
   Sem isso, INSERT/UPDATE/DELETE retornam 403 para o role `anon`.

4. Também criar a tabela de sessões do bot (não está no `schema.sql`):
   ```sql
   CREATE TABLE IF NOT EXISTS sessoes_escola (
     telefone   text PRIMARY KEY,
     etapa      text,
     dados      jsonb,
     updated_at timestamptz DEFAULT now()
   );
   ALTER TABLE sessoes_escola ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "anon all" ON sessoes_escola USING (true) WITH CHECK (true);
   GRANT ALL ON sessoes_escola TO anon;
   ```

### 2. Bot WhatsApp (n8n)

1. Acessar n8n em `https://n8n.automacaopme.com.br`
2. Importar `bot_escola.json`
3. **IMPORTANTE:** atualizar todos os nós HTTP Request do workflow — eles ainda apontam para o projeto Supabase antigo (`rcghqqwbwxbhrxjwutqu`). Substituir por `ywsobgbpwhykkfolvoml` na URL e nos headers `apikey`/`Authorization`.
4. Importar `notificacao_webhook.json` (webhook auxiliar de notificações)
5. Ativar ambos os workflows

### 3. Dashboard

Abrir `index.html` diretamente no browser — não requer servidor, build ou dependências.

---

## O que está funcionando

- [x] Cadastro, edição e exclusão de responsáveis
- [x] Publicação do cardápio semanal
- [x] Agenda de eventos com filtro por turma
- [x] Kanban de Ocorrências (4 status)
- [x] Kanban de Solicitações (4 status)
- [x] Kanban de Avisos com swim lanes por turma
- [x] Comunicados em massa com barra de progresso
- [x] Autorizações de busca (cadastro + lista + busca)
- [x] Tema claro/escuro, persistido no localStorage
- [x] Layout responsivo (desktop, tablet, mobile)
- [x] Feedback de erro real via toast (supaApi lança Error em mutações)

---

## Pendências e problemas conhecidos

### Alta prioridade

1. **bot_escola.json aponta para Supabase antigo** — Os nós HTTP do bot usam `rcghqqwbwxbhrxjwutqu`. O dashboard já usa `ywsobgbpwhykkfolvoml`. Atualizar manualmente no n8n ou reeditar e exportar o JSON.

2. **GRANT obrigatório após rodar schema.sql** — Tabelas criadas via SQL no Supabase não herdam permissões para o role `anon` automaticamente. Sem o GRANT, saves falham com 403.

3. **Autorizações — FK PostgREST** — Join via `responsaveis(nome,aluno,turma)` pode falhar se o Supabase não reconhecer a FK criada via SQL. O código já faz fallback via `respMap` (join client-side), mas se a tabela `autorizacoes` não existir ainda, a página fica vazia.

### Média prioridade

4. **Formulário de nova autorização ausente** — A página de Autorizações tem busca e exclusão, mas não tem botão/modal para adicionar nova autorização via dashboard. Por enquanto só é possível via Supabase diretamente ou via bot (se implementado).

5. **Sem validação de conflito de reserva** — A página de Reservas foi removida do dashboard. Se o bot aceitar reservas, o admin não tem interface para gerenciá-las. Reativar ou criar página dedicada se necessário.

### Baixa prioridade

6. **Bot não tem fluxos de cardápio/agenda** — O `bot_escola.json` tem o roteador com rotas para cardápio, agenda etc., mas os fluxos internos não foram implementados (apenas cadastro está pronto). Implementar ao longo do projeto.

7. **Segurança** — As chaves de API estão hardcoded no `index.html`. Para produção com múltiplos clientes, extrair para variáveis de ambiente do n8n e não distribuir o `index.html` publicamente.

---

## Padrões do código (para manutenção)

### supaApi
```js
supaApi(method, path, body)
// GET  → retorna null em erro (não lança)
// POST/PATCH/DELETE → lança Error com mensagem do servidor
```

### Todos os saves/deletes têm try/catch
```js
try {
  await supaApi('POST', '/tabela', body);
  showToast('Salvo!');
  closeModal('...');
  this.load();
} catch(e) { showToast('Erro: ' + e.message, 'error'); }
```

### Join PostgREST com fallback client-side
```js
// _resp(a) normaliza objeto ou array; fallback via respMap por id
_resp(a) {
  const joined = Array.isArray(a.responsaveis) ? a.responsaveis[0] : a.responsaveis;
  return joined || this.respMap[a.responsavel_id] || null;
}
```

### Adicionar nova página
1. `<div class="page" id="page-NOME">` em `<main>`
2. Item na `.sidebar` com `data-page="NOME"`
3. Item no `.bottom-nav` com `data-page="NOME"`
4. App JS: `{ data:[], load(), render() }`
5. Registrar em `loadPage()` e no auto-refresh
