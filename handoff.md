# Handoff — Escola Digital (Colégio Raio de Luz)

**Produto:** Sistema de comunicação escola-família via WhatsApp  
**Cliente:** Colégio Raio de Luz  
**Responsável Automatiz.ia:** Bruno Vargas Joaquim  
**Repositório:** https://github.com/BrunoAutomatizIA/sistema_escola_zap  
**Data:** 2026-06-22 (última atualização: 2026-07-04)  
**URL publicada:** https://brunoautomatizia.github.io/sistema_escola_zap/ (GitHub Pages, branch `main`)

---

## O que foi entregue

### Artefatos

| Arquivo | Descrição |
|---|---|
| `index.html` | Dashboard admin — SPA completa, abre direto no browser (identidade visual estilo Apple Store) |
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

### Identidade visual

O cliente avaliou duas opções de identidade visual (a original, com emojis, e uma alternativa mais
sóbria/profissional inspirada em `apple.com/br/store`) e **escolheu a segunda** como dashboard oficial —
paleta neutra (branco/cinza/preto) com azul e laranja como únicos acentos, tipografia do sistema, ícones
SVG no lugar de emojis, botões em formato pílula. O arquivo da variante (`index_2.html`) foi renomeado para
`index.html` e a versão anterior foi removida do repositório.

---

## Credenciais e infraestrutura

> Todas as credenciais estão hardcoded em `index.html` (bloco `CONFIG`, próximo à tag `<script>`). Antes de entregar o acesso ao cliente, avaliar se devem ser trocadas ou ocultadas.

| Serviço | Detalhe |
|---|---|
| **Supabase** | Projeto `AutomatizIA` · URL: `https://ywsobgbpwhykkfolvoml.supabase.co` |
| **Supabase anon key** | `eyJhbGci...kWcE8` (ver `index.html`) |
| **Evolution API** | `https://evolution.automacaopme.com.br` · Instance: `bot-bruno` |
| **Evolution API key** | `187303942A46-4052-8D89-5A4CA2523ABD` |
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
2. Importar `bot_escola.json` (já aponta para o projeto Supabase correto, `ywsobgbpwhykkfolvoml`)
3. Importar `notificacao_webhook.json` (webhook auxiliar de notificações)
4. Ativar ambos os workflows

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
- [x] Autorizações de busca (cadastro via modal + lista + busca)
- [x] Bot com todos os fluxos implementados (cadastro, cardápio, agenda, ocorrências, solicitações, avisos, reservas)
- [x] Tema claro/escuro, persistido no localStorage
- [x] Layout responsivo (desktop, tablet, mobile)
- [x] Feedback de erro real via toast (supaApi lança Error em mutações)

---

## Pendências e problemas conhecidos

### Alta prioridade

1. **Tabela `sessoes_escola` fora do `schema.sql`** — a sessão multi-step do bot depende dela, mas o DDL não está no script principal (ver seção "Setup do zero" acima para o SQL exato). Incluir no `schema.sql` para evitar esquecimento em um novo ambiente.

2. **GRANT obrigatório após rodar schema.sql** — Tabelas criadas via SQL no Supabase não herdam permissões para o role `anon` automaticamente. Sem o GRANT, saves falham com 403.

3. **Autorizações — FK PostgREST** — Join via `responsaveis(nome,aluno,turma)` pode falhar se o Supabase não reconhecer a FK criada via SQL. O código já faz fallback via `respMap` (join client-side).

### Média prioridade

4. **Sem validação de conflito de reserva** — A página de Reservas foi removida do dashboard, mas o bot já insere registros em `reservas_escola` via WhatsApp. O admin não tem interface para gerenciá-las nem para checar conflito de horário. Reativar ou criar página dedicada se necessário.

### Baixa prioridade

5. **Segurança** — As chaves de API estão hardcoded no `index.html` e em `bot_escola.json`. Para produção com múltiplos clientes, extrair para variáveis de ambiente do n8n e não distribuir o `index.html` publicamente.

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
