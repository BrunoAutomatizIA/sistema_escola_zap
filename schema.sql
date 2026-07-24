-- ============================================================
--  Escola Digital — Colégio Raio de Luz
--  Schema Supabase
--  Rodar no SQL Editor do novo projeto Supabase
-- ============================================================

-- 1. RESPONSÁVEIS (pais / responsáveis)
CREATE TABLE IF NOT EXISTS responsaveis (
  id             bigint generated always as identity primary key,
  nome           text NOT NULL,
  telefone       text NOT NULL,
  aluno          text,
  turma          text,
  user_id        uuid REFERENCES auth.users(id), -- liga a conta de login do portal (app_escola_zap_2) a esta linha
  data_nascimento date, -- do aluno — app_escola_zap_2/specs/perfil-aluno.md § 8 (2026-07-19)
  parentesco     text, -- deste responsável com o aluno (ex.: "Mãe", "Pai", "Avó")
  created_at     timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS responsaveis_user_id_idx ON responsaveis(user_id);
ALTER TABLE responsaveis ENABLE ROW LEVEL SECURITY;

-- Migração pra bancos que já têm a tabela sem essas 2 colunas (CREATE TABLE IF NOT EXISTS
-- acima não altera tabela existente) — seguro rodar de novo, ADD COLUMN IF NOT EXISTS.
ALTER TABLE responsaveis ADD COLUMN IF NOT EXISTS data_nascimento date;
ALTER TABLE responsaveis ADD COLUMN IF NOT EXISTS parentesco text;

-- RLS real (app_escola_zap_2, ver specs/mural-de-fotos.md § 8): substitui a antiga policy única
-- "anon all" USING (true) — que, sem `TO anon`, liberava geral pra qualquer sessão, não só o bot.
-- anon mantém acesso total (o bot do WhatsApp cria/lê responsaveis sem sessão nenhuma, não pode quebrar).
CREATE POLICY "anon acesso completo" ON responsaveis FOR ALL TO anon USING (true) WITH CHECK (true);
-- admin (staff autenticado no /admin) mantém acesso total.
CREATE POLICY "admin acesso completo" ON responsaveis FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
-- responsavel (portal autenticado) só lê a própria linha.
CREATE POLICY "responsavel le proprio registro" ON responsaveis FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- 2. CARDÁPIO SEMANAL
CREATE TABLE IF NOT EXISTS cardapio (
  id            bigint generated always as identity primary key,
  semana_inicio date NOT NULL,/*  */
  segunda       text,
  terca         text,
  quarta        text,
  quinta        text,
  sexta         text,
  created_at    timestamptz DEFAULT now()
);
ALTER TABLE cardapio ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado que o bot só faz GET
-- /cardapio, nunca escreve): substitui a antiga "anon all" USING(true). Sem coluna de turma —
-- é dado da escola inteira, sem PII, então responsavel lê tudo sem filtro extra.
DROP POLICY IF EXISTS "anon all" ON cardapio;
CREATE POLICY "anon le cardapio" ON cardapio FOR SELECT TO anon USING (true);
CREATE POLICY "admin acesso completo" ON cardapio FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le cardapio" ON cardapio FOR SELECT TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel');

-- 3. AGENDA DE EVENTOS
CREATE TABLE IF NOT EXISTS agenda (
  id         bigint generated always as identity primary key,
  titulo     text NOT NULL,
  data       date NOT NULL,
  turma      text,
  descricao  text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE agenda ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado em bot_escola.json que o bot só faz
-- GET /agenda, nunca escreve): substitui a antiga "anon all" USING(true) por acesso só de leitura.
DROP POLICY IF EXISTS "anon all" ON agenda;
CREATE POLICY "anon le agenda" ON agenda FOR SELECT TO anon USING (true);
-- admin (staff autenticado no /admin) mantém acesso total.
CREATE POLICY "admin acesso completo" ON agenda FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
-- responsavel (portal autenticado) lê eventos gerais da escola (turma nula) ou da própria turma.
CREATE POLICY "responsavel le agenda da turma ou geral" ON agenda FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND (turma IS NULL OR turma = (SELECT turma FROM responsaveis WHERE user_id = auth.uid()))
  );

-- 4. OCORRÊNCIAS ESCOLARES
CREATE TABLE IF NOT EXISTS ocorrencias_escola (
  id             bigint generated always as identity primary key,
  responsavel_id bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  aluno          text,
  titulo         text,
  descricao      text,
  urgencia       text DEFAULT 'media',
  status         text DEFAULT 'aberta',
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE ocorrencias_escola ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado que o bot só faz POST
-- /ocorrencias_escola, nunca lê): substitui a antiga "anon all" USING(true) por INSERT só.
DROP POLICY IF EXISTS "anon all" ON ocorrencias_escola;
CREATE POLICY "anon cria ocorrencia" ON ocorrencias_escola FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "admin acesso completo" ON ocorrencias_escola FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le propria ocorrencia" ON ocorrencias_escola FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 5. SOLICITAÇÕES DE SERVIÇO
CREATE TABLE IF NOT EXISTS solicitacoes (
  id             bigint generated always as identity primary key,
  responsavel_id bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  tipo           text,
  descricao      text,
  urgencia       text DEFAULT 'media',
  status         text DEFAULT 'pendente',
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE solicitacoes ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado que o bot só faz POST
-- /solicitacoes, nunca lê): substitui a antiga "anon all" USING(true) por INSERT só.
DROP POLICY IF EXISTS "anon all" ON solicitacoes;
CREATE POLICY "anon cria solicitacao" ON solicitacoes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "admin acesso completo" ON solicitacoes FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le propria solicitacao" ON solicitacoes FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 6. AVISOS INDIVIDUAIS / POR TURMA
CREATE TABLE IF NOT EXISTS avisos (
  id             bigint generated always as identity primary key,
  responsavel_id bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  titulo         text NOT NULL,
  mensagem       text,
  status         text DEFAULT 'pendente',
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE avisos ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado em bot_escola.json que o bot só faz
-- GET /avisos, nunca escreve): substitui a antiga "anon all" USING(true) por acesso só de leitura.
DROP POLICY IF EXISTS "anon all" ON avisos;
CREATE POLICY "anon le avisos" ON avisos FOR SELECT TO anon USING (true);
-- admin (staff autenticado no /admin) mantém acesso total.
CREATE POLICY "admin acesso completo" ON avisos FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
-- responsavel (portal autenticado) só lê os próprios avisos.
CREATE POLICY "responsavel le proprio aviso" ON avisos FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );
-- responsavel marca o próprio aviso como lido (único update permitido no portal).
CREATE POLICY "responsavel marca proprio aviso como lido" ON avisos FOR UPDATE TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  )
  WITH CHECK (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 7. AUTORIZAÇÕES DE SAÍDA
CREATE TABLE IF NOT EXISTS autorizacoes (
  id               bigint generated always as identity primary key,
  responsavel_id   bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  nome_autorizador text,
  documento        text,
  parentesco       text,
  created_at       timestamptz DEFAULT now()
);
ALTER TABLE autorizacoes ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado que o bot só faz POST
-- /autorizacoes, nunca lê): substitui a antiga "anon all" USING(true) por INSERT só. Tem PII
-- (documento, nome_autorizador), então responsavel só lê a própria.
DROP POLICY IF EXISTS "anon all" ON autorizacoes;
CREATE POLICY "anon cria autorizacao" ON autorizacoes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "admin acesso completo" ON autorizacoes FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le propria autorizacao" ON autorizacoes FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 8. RESERVAS DE ESPAÇOS
CREATE TABLE IF NOT EXISTS reservas_escola (
  id             bigint generated always as identity primary key,
  responsavel_id bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  local          text NOT NULL,
  data           date NOT NULL,
  horario        text,
  status         text DEFAULT 'pendente',
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE reservas_escola ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon all" ON reservas_escola USING (true) WITH CHECK (true);

-- 9. COMUNICADOS GERAIS
CREATE TABLE IF NOT EXISTS comunicados_escola (
  id           bigint generated always as identity primary key,
  turma        text,
  titulo       text NOT NULL,
  mensagem     text NOT NULL,
  status       text DEFAULT 'rascunho',
  enviado_em   timestamptz,
  destinatarios int DEFAULT 0,
  created_at   timestamptz DEFAULT now()
);
ALTER TABLE comunicados_escola ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, levantamento de 2026-07-19 — confirmado em bot_escola.json que o bot nunca
-- lê nem escreve esta tabela): sem policy pra anon, igual ao padrão de registros_atividades.
DROP POLICY IF EXISTS "anon all" ON comunicados_escola;
-- admin (staff autenticado no /admin) mantém acesso total.
CREATE POLICY "admin acesso completo" ON comunicados_escola FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
-- responsavel (portal autenticado) só lê comunicados já enviados (nunca rascunho), da turma ou geral.
CREATE POLICY "responsavel le comunicado enviado da turma ou geral" ON comunicados_escola FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND status = 'enviado'
    AND (turma IS NULL OR turma = (SELECT turma FROM responsaveis WHERE user_id = auth.uid()))
  );

-- 10. REGISTROS DE ATIVIDADES (Mural de Fotos — app_escola_zap_2/specs/mural-de-fotos.md)
CREATE TABLE IF NOT EXISTS registros_atividades (
  id             bigint generated always as identity primary key,
  turma          text NOT NULL,
  responsavel_id bigint REFERENCES responsaveis(id) ON DELETE SET NULL,
  tipo           text NOT NULL DEFAULT 'atividade',
  titulo         text NOT NULL,
  descricao      text,
  foto_url       text,
  professor      text NOT NULL,
  data           date NOT NULL DEFAULT current_date,
  created_at     timestamptz DEFAULT now()
);
ALTER TABLE registros_atividades ENABLE ROW LEVEL SECURITY;

-- RLS real (app_escola_zap_2, ver specs/mural-de-fotos.md § 8) — sem policy pra anon: o bot nunca
-- escreve nem lê esta tabela, então uma requisição anônima corretamente não vê nada.
CREATE POLICY "admin acesso completo" ON registros_atividades FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le registro da turma ou do filho" ON registros_atividades FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND (
      responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
      OR (responsavel_id IS NULL AND turma = (SELECT turma FROM responsaveis WHERE user_id = auth.uid()))
    )
  );

-- 11. DESENVOLVIMENTO (BNCC — app_escola_zap_2/specs/perfil-aluno.md § 1 e § 8)
-- 1 registro por (aluno, campo, mês) — ciclo mensal, decidido em conversa de 2026-07-19.
-- Preenchido por qualquer staff autenticado em /admin (sem conceito de "professora da turma X").
CREATE TABLE IF NOT EXISTS desenvolvimento_registros (
  id             bigint generated always as identity primary key,
  responsavel_id bigint NOT NULL REFERENCES responsaveis(id) ON DELETE CASCADE,
  campo          text NOT NULL,
  nivel          text NOT NULL,
  observacao     text,
  mes_referencia date NOT NULL, -- sempre dia 1 do mês (YYYY-MM-01)
  created_at     timestamptz DEFAULT now(),
  UNIQUE (responsavel_id, campo, mes_referencia)
);
CREATE INDEX IF NOT EXISTS desenvolvimento_registros_responsavel_idx ON desenvolvimento_registros(responsavel_id);
ALTER TABLE desenvolvimento_registros ENABLE ROW LEVEL SECURITY;

-- RLS real — sem policy pra anon: o bot nunca escreve nem lê esta tabela (mesmo padrão de
-- registros_atividades), então uma requisição anônima corretamente não vê nada.
CREATE POLICY "admin acesso completo" ON desenvolvimento_registros FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le proprio desenvolvimento" ON desenvolvimento_registros FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 12. ALIMENTAÇÃO (indicador mensal do Resumo — app_escola_zap_2/specs/perfil-aluno.md § 8)
-- 1 registro por (aluno, mês) — mesmo ciclo/enum de desenvolvimento_registros, mas sem
-- sub-campos (é 1 indicador só, não 5). Decidido em conversa de 2026-07-19.
CREATE TABLE IF NOT EXISTS alimentacao_registros (
  id             bigint generated always as identity primary key,
  responsavel_id bigint NOT NULL REFERENCES responsaveis(id) ON DELETE CASCADE,
  nivel          text NOT NULL,
  observacao     text,
  mes_referencia date NOT NULL,
  created_at     timestamptz DEFAULT now(),
  UNIQUE (responsavel_id, mes_referencia)
);
CREATE INDEX IF NOT EXISTS alimentacao_registros_responsavel_idx ON alimentacao_registros(responsavel_id);
ALTER TABLE alimentacao_registros ENABLE ROW LEVEL SECURITY;

-- RLS real — sem policy pra anon: o bot nunca escreve nem lê esta tabela.
CREATE POLICY "admin acesso completo" ON alimentacao_registros FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le propria alimentacao" ON alimentacao_registros FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 13. DOCUMENTOS DO ALUNO (checklist do Perfil → Informações — app_escola_zap_2/specs/perfil-aluno.md § 8)
-- Só um checkbox anexado/pendente preenchido pelo admin — sem upload de arquivo real
-- (decisão de 2026-07-19, escopo reduzido em relação a um Storage completo).
CREATE TABLE IF NOT EXISTS documentos_aluno (
  id             bigint generated always as identity primary key,
  responsavel_id bigint NOT NULL REFERENCES responsaveis(id) ON DELETE CASCADE,
  tipo           text NOT NULL,
  anexado        boolean NOT NULL DEFAULT false,
  created_at     timestamptz DEFAULT now(),
  UNIQUE (responsavel_id, tipo)
);
CREATE INDEX IF NOT EXISTS documentos_aluno_responsavel_idx ON documentos_aluno(responsavel_id);
ALTER TABLE documentos_aluno ENABLE ROW LEVEL SECURITY;

-- RLS real — sem policy pra anon: o bot nunca escreve nem lê esta tabela.
CREATE POLICY "admin acesso completo" ON documentos_aluno FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le proprio documento" ON documentos_aluno FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- 14. MENSAGENS (Comunicação → Mensagens, bot de IA — app_escola_zap_2/specs/comunicacao-mensagens.md)
-- Chat responsável ↔ IA (Qwen via Ollama, orquestrado pelo n8n em bot_ia_mensagens.json). O n8n só
-- INSERE (nunca lê) via anon — diferente de agenda/cardapio/avisos, o texto da mensagem é entregue ao
-- webhook direto no payload (o app já manda o texto), então não precisa reler a tabela pra responder.
-- Isso evita dar SELECT geral pra chave anon pública sobre conversa de família (mais sensível que
-- agenda/cardápio, que são informação não-pessoal).
CREATE TABLE IF NOT EXISTS mensagens (
  id                     bigint generated always as identity primary key,
  responsavel_id         bigint NOT NULL REFERENCES responsaveis(id) ON DELETE CASCADE,
  remetente              text NOT NULL CHECK (remetente IN ('responsavel', 'ia', 'humano')),
  texto                  text NOT NULL,
  precisa_atencao_humana boolean NOT NULL DEFAULT false,
  created_at             timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mensagens_responsavel_idx ON mensagens(responsavel_id);
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon insere resposta ia" ON mensagens FOR INSERT TO anon
  WITH CHECK (remetente IN ('ia', 'humano'));
CREATE POLICY "admin acesso completo" ON mensagens FOR ALL TO authenticated
  USING ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');
CREATE POLICY "responsavel le propria mensagem" ON mensagens FOR SELECT TO authenticated
  USING (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );
CREATE POLICY "responsavel insere propria mensagem" ON mensagens FOR INSERT TO authenticated
  WITH CHECK (
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'responsavel'
    AND remetente = 'responsavel'
    AND responsavel_id = (SELECT id FROM responsaveis WHERE user_id = auth.uid())
  );

-- Habilitar Realtime pra essa tabela (Supabase Studio → Database → Replication → supabase_realtime
-- → marcar "mensagens", ou rodar o comando abaixo direto no SQL Editor):
-- ALTER PUBLICATION supabase_realtime ADD TABLE mensagens;

-- IMPORTANTE: permissões para o role anon (necessário para tabelas criadas via SQL)
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
