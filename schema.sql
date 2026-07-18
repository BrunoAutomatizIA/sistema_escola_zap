-- ============================================================
--  Escola Digital — Colégio Raio de Luz
--  Schema Supabase
--  Rodar no SQL Editor do novo projeto Supabase
-- ============================================================

-- 1. RESPONSÁVEIS (pais / responsáveis)
CREATE TABLE IF NOT EXISTS responsaveis (
  id          bigint generated always as identity primary key,
  nome        text NOT NULL,
  telefone    text NOT NULL,
  aluno       text,
  turma       text,
  user_id     uuid REFERENCES auth.users(id), -- liga a conta de login do portal (app_escola_zap_2) a esta linha
  created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS responsaveis_user_id_idx ON responsaveis(user_id);
ALTER TABLE responsaveis ENABLE ROW LEVEL SECURITY;

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
CREATE POLICY "anon all" ON cardapio USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON agenda USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON ocorrencias_escola USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON solicitacoes USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON avisos USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON autorizacoes USING (true) WITH CHECK (true);

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
CREATE POLICY "anon all" ON comunicados_escola USING (true) WITH CHECK (true);

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

-- IMPORTANTE: permissões para o role anon (necessário para tabelas criadas via SQL)
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
