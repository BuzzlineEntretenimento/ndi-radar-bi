-- Radar BI | NDI — banco compartilhado e leitura pública, escrita restrita
-- Preparado em 19/10/2026 para implantação futura em projeto Supabase aprovado.
-- Este arquivo NÃO conecta o site automaticamente ao banco nem concede acesso de edição.
-- Nunca insira service_role ou qualquer segredo privado no GitHub ou no HTML público.
BEGIN;

CREATE TABLE IF NOT EXISTS public.ndi_bi_editors (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.ndi_bi_editors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ndi_bi_editors_read_own ON public.ndi_bi_editors;
CREATE POLICY ndi_bi_editors_read_own ON public.ndi_bi_editors
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.ndi_bi_is_editor()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.ndi_bi_editors e
    WHERE e.user_id = (SELECT auth.uid())
  );
$$;
REVOKE ALL ON FUNCTION public.ndi_bi_is_editor() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ndi_bi_is_editor() TO authenticated;

CREATE TABLE IF NOT EXISTS public.ndi_bi_profiles (
  id INTEGER PRIMARY KEY,
  handle TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  monitoring_group TEXT NOT NULL,
  niche TEXT NOT NULL,
  instagram_url TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.ndi_bi_metrics (
  profile_id INTEGER PRIMARY KEY REFERENCES public.ndi_bi_profiles(id) ON DELETE CASCADE,
  followers BIGINT CHECK (followers >= 0),
  following BIGINT CHECK (following >= 0),
  total_posts BIGINT CHECK (total_posts >= 0),
  avg_likes NUMERIC,
  avg_comments NUMERIC,
  weekly_posts NUMERIC,
  avg_views NUMERIC,
  metric_date DATE,
  metric_source TEXT,
  observation TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.ndi_bi_snapshots (
  profile_id INTEGER NOT NULL REFERENCES public.ndi_bi_profiles(id) ON DELETE CASCADE,
  observed_on DATE NOT NULL,
  followers BIGINT CHECK (followers >= 0),
  total_posts BIGINT CHECK (total_posts >= 0),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(profile_id, observed_on)
);
CREATE INDEX IF NOT EXISTS ndi_bi_snapshots_profile_date ON public.ndi_bi_snapshots(profile_id, observed_on DESC);

ALTER TABLE public.ndi_bi_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ndi_bi_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ndi_bi_snapshots ENABLE ROW LEVEL SECURITY;

-- Visitantes anônimos podem consultar os dados.
DROP POLICY IF EXISTS ndi_bi_profiles_public_read ON public.ndi_bi_profiles;
CREATE POLICY ndi_bi_profiles_public_read ON public.ndi_bi_profiles FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS ndi_bi_metrics_public_read ON public.ndi_bi_metrics;
CREATE POLICY ndi_bi_metrics_public_read ON public.ndi_bi_metrics FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS ndi_bi_snapshots_public_read ON public.ndi_bi_snapshots;
CREATE POLICY ndi_bi_snapshots_public_read ON public.ndi_bi_snapshots FOR SELECT TO anon, authenticated USING (true);

-- Somente usuários autenticados que constam em ndi_bi_editors podem modificar os dados.
DROP POLICY IF EXISTS ndi_bi_profiles_editor_insert ON public.ndi_bi_profiles;
CREATE POLICY ndi_bi_profiles_editor_insert ON public.ndi_bi_profiles FOR INSERT TO authenticated WITH CHECK ((SELECT public.ndi_bi_is_editor()));
DROP POLICY IF EXISTS ndi_bi_profiles_editor_update ON public.ndi_bi_profiles;
CREATE POLICY ndi_bi_profiles_editor_update ON public.ndi_bi_profiles FOR UPDATE TO authenticated
  USING ((SELECT public.ndi_bi_is_editor())) WITH CHECK ((SELECT public.ndi_bi_is_editor()));
DROP POLICY IF EXISTS ndi_bi_metrics_editor_insert ON public.ndi_bi_metrics;
CREATE POLICY ndi_bi_metrics_editor_insert ON public.ndi_bi_metrics FOR INSERT TO authenticated WITH CHECK ((SELECT public.ndi_bi_is_editor()));
DROP POLICY IF EXISTS ndi_bi_metrics_editor_update ON public.ndi_bi_metrics;
CREATE POLICY ndi_bi_metrics_editor_update ON public.ndi_bi_metrics FOR UPDATE TO authenticated
  USING ((SELECT public.ndi_bi_is_editor())) WITH CHECK ((SELECT public.ndi_bi_is_editor()));
DROP POLICY IF EXISTS ndi_bi_snapshots_editor_insert ON public.ndi_bi_snapshots;
CREATE POLICY ndi_bi_snapshots_editor_insert ON public.ndi_bi_snapshots FOR INSERT TO authenticated WITH CHECK ((SELECT public.ndi_bi_is_editor()));
DROP POLICY IF EXISTS ndi_bi_snapshots_editor_update ON public.ndi_bi_snapshots;
CREATE POLICY ndi_bi_snapshots_editor_update ON public.ndi_bi_snapshots FOR UPDATE TO authenticated
  USING ((SELECT public.ndi_bi_is_editor())) WITH CHECK ((SELECT public.ndi_bi_is_editor()));

GRANT SELECT ON public.ndi_bi_profiles, public.ndi_bi_metrics, public.ndi_bi_snapshots TO anon, authenticated;
GRANT INSERT, UPDATE ON public.ndi_bi_profiles, public.ndi_bi_metrics, public.ndi_bi_snapshots TO authenticated;
GRANT SELECT ON public.ndi_bi_editors TO authenticated;

-- Base inicial de 90 contas; ON CONFLICT DO NOTHING impede sobrescrever dados existentes.
INSERT INTO public.ndi_bi_profiles(id,handle,name,monitoring_group,niche,instagram_url) VALUES
  (1, '@v3a.ag', 'V3A', 'Agências de eventos', 'Live marketing / experiência', 'https://www.instagram.com/v3a.ag/'),
  (2, '@casafirjan', 'Casa Firjan', 'Impacto e educação', 'Inovação / indústria criativa', 'https://www.instagram.com/casafirjan/'),
  (3, '@setur_rj', 'Secretaria de Turismo RJ', 'Turismo e órgãos públicos', 'Turismo estadual / cliente', 'https://www.instagram.com/setur_rj/'),
  (4, '@riotur.rio', 'Riotur', 'Turismo e órgãos públicos', 'Turismo municipal', 'https://www.instagram.com/riotur.rio/'),
  (5, '@smtur.rio', 'SMTUR Rio', 'Turismo e órgãos públicos', 'Política municipal de turismo', 'https://www.instagram.com/smtur.rio/'),
  (6, '@nucleodaideia', 'Núcleo da Ideia', 'NDI', 'Conta própria', 'https://www.instagram.com/nucleodaideia/'),
  (7, '@grupo.fbrc', 'Grupo Fábrica', 'Agências de eventos', 'Eventos / produção', 'https://www.instagram.com/grupo.fbrc/'),
  (8, '@apequenaafrica', 'A Pequena África', 'Impacto e educação', 'Território / cultura / patrimônio', 'https://www.instagram.com/apequenaafrica/'),
  (9, '@mostardaoficial', 'Mostarda', 'Agências de eventos', 'Eventos / brand experience', 'https://www.instagram.com/mostardaoficial/'),
  (10, '@riofilmcommission', 'Rio Film Commission', 'Cultura e audiovisual', 'Film commission / RJ', 'https://www.instagram.com/riofilmcommission/'),
  (11, '@ctavcinema', 'CTAv', 'Cultura e audiovisual', 'Formação / infraestrutura audiovisual', 'https://www.instagram.com/ctavcinema/'),
  (12, '@firjansenai', 'Firjan SENAI', 'Impacto e educação', 'Educação e inovação', 'https://www.instagram.com/firjansenai/'),
  (13, '@curtacinema', 'Festival Curta Cinema', 'Cultura e audiovisual', 'Festival audiovisual', 'https://www.instagram.com/curtacinema/'),
  (14, '@instituto.futuros', 'Instituto Futuros', 'Impacto e educação', 'Cultura / impacto / educação', 'https://www.instagram.com/instituto.futuros/'),
  (15, '@canalcurta', 'Curta!', 'Cultura e audiovisual', 'Canal cultural / audiovisual', 'https://www.instagram.com/canalcurta/'),
  (16, '@visitrio', 'Visit Rio', 'Turismo e órgãos públicos', 'Promoção de destinos', 'https://www.instagram.com/visitrio/'),
  (17, '@canalbrasil', 'Canal Brasil', 'Cultura e audiovisual', 'Canal de cinema / cultura', 'https://www.instagram.com/canalbrasil/'),
  (18, '@canalmeio', 'Canal Meio', 'Comunicação e mídia', 'Jornalismo / newsletters', 'https://www.instagram.com/canalmeio/'),
  (19, '@_riofilme', 'RioFilme', 'Cultura e audiovisual', 'Fomento audiovisual / RJ', 'https://www.instagram.com/_riofilme/'),
  (20, '@cultura_rio', 'Secretaria Municipal de Cultura RJ', 'Turismo e órgãos públicos', 'Política cultural municipal', 'https://www.instagram.com/cultura_rio/'),
  (21, '@vejario', 'Veja Rio', 'Comunicação e mídia', 'Jornalismo / cidade e cultura', 'https://www.instagram.com/vejario/'),
  (22, '@sececrj', 'Cultura e Economia Criativa RJ', 'Turismo e órgãos públicos', 'Política cultural estadual', 'https://www.instagram.com/sececrj/'),
  (23, '@festivaldorio', 'Festival do Rio', 'Cultura e audiovisual', 'Festival de cinema', 'https://www.instagram.com/festivaldorio/'),
  (24, '@cpbbrasil', 'Crispin BR', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/cpbbrasil/'),
  (25, '@dentsucreativebrasil', 'Dentsu Creative Brasil', 'Agências criativas', 'Publicidade / inovação', 'https://www.instagram.com/dentsucreativebrasil/'),
  (26, '@pnel.ag', 'PNEL', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/pnel.ag/'),
  (27, '@druidcreativegaming', 'DRUID', 'Agências criativas', 'Gaming / criatividade', 'https://www.instagram.com/druidcreativegaming/'),
  (28, '@ag.talent', 'Talent', 'Agências criativas', 'Publicidade / campanhas', 'https://www.instagram.com/ag.talent/'),
  (29, '@spfilmcommission', 'São Paulo Film Commission', 'Cultura e audiovisual', 'Film commission / SP', 'https://www.instagram.com/spfilmcommission/'),
  (30, '@acadbraseventoseturismo', 'Academia Brasileira de Eventos e Turismo', 'Entidades e prêmios', 'Setor de eventos / turismo', 'https://www.instagram.com/acadbraseventoseturismo/'),
  (31, '@artplan', 'Artplan', 'Agências de eventos', 'Publicidade / entretenimento / eventos', 'https://www.instagram.com/artplan/'),
  (32, '@iphangovbr', 'Iphan', 'Turismo e órgãos públicos', 'Patrimônio cultural', 'https://www.instagram.com/iphangovbr/'),
  (33, '@oliverlatinamerica', 'OLIVER Latin America', 'Agências criativas', 'Conteúdo / serviços in-house', 'https://www.instagram.com/oliverlatinamerica/'),
  (34, '@agenciaterrua', 'Agência Terruá', 'Agências de eventos', 'Brand experience / eventos', 'https://www.instagram.com/agenciaterrua/'),
  (35, '@netza.ag', 'Netza', 'Agências de eventos', 'Experiência / ativação', 'https://www.instagram.com/netza.ag/'),
  (36, '@publicitarioscriativos', 'Publicitários Criativos', 'Comunicação e mídia', 'Curadoria de publicidade', 'https://www.instagram.com/publicitarioscriativos/'),
  (37, '@sherpa.42', 'Sherpa42', 'Agências de eventos', 'Experiência / live marketing', 'https://www.instagram.com/sherpa.42/'),
  (38, '@b2livebrasil', 'B2LIVE', 'Agências de eventos', 'Live marketing / brand experience', 'https://www.instagram.com/b2livebrasil/'),
  (39, '@aprateleira.ag', 'A Prateleira', 'Agências de eventos', 'Criação / experiências', 'https://www.instagram.com/aprateleira.ag/'),
  (40, '@betc.havas', 'BETC Havas', 'Agências criativas', 'Publicidade / marca', 'https://www.instagram.com/betc.havas/'),
  (41, '@brmediagroup', 'BR Media', 'Marcas e infraestrutura', 'Influência / mídia', 'https://www.instagram.com/brmediagroup/'),
  (42, '@influenciadormagaluoficial', 'Influenciador Magalu', 'Marcas e infraestrutura', 'Programa de creators / varejo', 'https://www.instagram.com/influenciadormagaluoficial/'),
  (43, '@ogilvybrasil', 'Ogilvy Brasil', 'Agências criativas', 'Publicidade / marca', 'https://www.instagram.com/ogilvybrasil/'),
  (44, '@droga5sp', 'Droga5 São Paulo', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/droga5sp/'),
  (45, '@galeria.ag', 'Galeria.ag', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/galeria.ag/'),
  (46, '@govbr', 'Governo do Brasil', 'Turismo e órgãos públicos', 'Comunicação federal', 'https://www.instagram.com/govbr/'),
  (47, '@wiedenkennedysp', 'Wieden+Kennedy São Paulo', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/wiedenkennedysp/'),
  (48, '@lampada_ag', 'Lâmpada.ag', 'Agências criativas', 'Agência de comunicação', 'https://www.instagram.com/lampada_ag/'),
  (49, '@abih_nacional', 'ABIH Nacional', 'Entidades e prêmios', 'Hotelaria / entidade setorial', 'https://www.instagram.com/abih_nacional/'),
  (50, '@abramark.br', 'Abramark', 'Entidades e prêmios', 'Marketing / entidade', 'https://www.instagram.com/abramark.br/'),
  (51, '@abraccine', 'Abraccine', 'Cultura e audiovisual', 'Associação de crítica de cinema', 'https://www.instagram.com/abraccine/'),
  (52, '@agenciahaute', 'Agência Haute', 'Agências de eventos', 'Eventos / experiência', 'https://www.instagram.com/agenciahaute/'),
  (53, '@portaleventosoficial', 'Portal Eventos', 'Comunicação e mídia', 'Notícias / setor de eventos', 'https://www.instagram.com/portaleventosoficial/'),
  (54, '@effielatam', 'Effie Awards Latin America', 'Entidades e prêmios', 'Premiações / efetividade', 'https://www.instagram.com/effielatam/'),
  (55, '@guiafolha', 'Guia Folha', 'Comunicação e mídia', 'Agenda / cultura e lazer', 'https://www.instagram.com/guiafolha/'),
  (56, '@meioemensagem', 'Meio & Mensagem', 'Comunicação e mídia', 'Notícias / publicidade', 'https://www.instagram.com/meioemensagem/'),
  (57, '@revistadecinema', 'Revista de Cinema', 'Cultura e audiovisual', 'Imprensa / cinema', 'https://www.instagram.com/revistadecinema/'),
  (58, '@socialmlabs', 'mLabs', 'Comunicação e mídia', 'Social media / ferramentas', 'https://www.instagram.com/socialmlabs/'),
  (59, '@marketingdrops.news', 'MarketingDrops', 'Comunicação e mídia', 'Radar de marketing', 'https://www.instagram.com/marketingdrops.news/'),
  (60, '@valoreconomico', 'Valor Econômico', 'Comunicação e mídia', 'Economia / negócios', 'https://www.instagram.com/valoreconomico/'),
  (61, '@promoview', 'Promoview', 'Comunicação e mídia', 'Brand experience / imprensa', 'https://www.instagram.com/promoview/'),
  (62, '@infomoney', 'InfoMoney', 'Comunicação e mídia', 'Negócios / economia', 'https://www.instagram.com/infomoney/'),
  (63, '@spcine_', 'Spcine', 'Cultura e audiovisual', 'Fomento / audiovisual SP', 'https://www.instagram.com/spcine_/'),
  (64, '@olga.ri_', 'Olga Ri', 'Marcas e infraestrutura', 'Alimentação / marca', 'https://www.instagram.com/olga.ri_/'),
  (65, '@portalg1', 'g1', 'Comunicação e mídia', 'Notícias gerais', 'https://www.instagram.com/portalg1/'),
  (66, '@premiocaio', 'Prêmio Caio', 'Entidades e prêmios', 'Premiação / eventos', 'https://www.instagram.com/premiocaio/'),
  (67, '@tm1.br', 'TM1 Brand Experience', 'Agências de eventos', 'Brand experience / produção', 'https://www.instagram.com/tm1.br/'),
  (68, '@minc', 'Ministério da Cultura', 'Turismo e órgãos públicos', 'Política cultural federal', 'https://www.instagram.com/minc/'),
  (69, '@b3_oficial', 'B3', 'Marcas e infraestrutura', 'Mercado financeiro / marca', 'https://www.instagram.com/b3_oficial/'),
  (70, '@aberje', 'Aberje', 'Entidades e prêmios', 'Comunicação empresarial', 'https://www.instagram.com/aberje/'),
  (71, '@epocanegocios', 'Época Negócios', 'Comunicação e mídia', 'Negócios / inovação', 'https://www.instagram.com/epocanegocios/'),
  (72, '@mercadoeconsumo', 'Mercado & Consumo', 'Comunicação e mídia', 'Consumo / varejo', 'https://www.instagram.com/mercadoeconsumo/'),
  (73, '@canalgov', 'Canal Gov', 'Turismo e órgãos públicos', 'Comunicação governamental', 'https://www.instagram.com/canalgov/'),
  (74, '@mmulheres', 'Ministério das Mulheres', 'Turismo e órgãos públicos', 'Política pública / gênero', 'https://www.instagram.com/mmulheres/'),
  (75, '@wearedavid.sp', 'DAVID São Paulo', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/wearedavid.sp/'),
  (76, '@almapbbdo', 'AlmapBBDO', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/almapbbdo/'),
  (77, '@expocenternorte', 'Expo Center Norte', 'Marcas e infraestrutura', 'Centro de exposições / feiras', 'https://www.instagram.com/expocenternorte/'),
  (78, '@cinesescsp', 'CineSesc', 'Cultura e audiovisual', 'Exibição / programação cultural', 'https://www.instagram.com/cinesescsp/'),
  (79, '@vml_br', 'VML Brasil', 'Agências criativas', 'Publicidade / tecnologia', 'https://www.instagram.com/vml_br/'),
  (80, '@amprooficial', 'AMPRO', 'Entidades e prêmios', 'Live marketing / entidade', 'https://www.instagram.com/amprooficial/'),
  (81, '@publicisbrasil', 'Publicis Brasil', 'Agências criativas', 'Publicidade / grupo', 'https://www.instagram.com/publicisbrasil/'),
  (82, '@agenciabferraz', 'BFerraz', 'Agências de eventos', 'Brand experience / eventos', 'https://www.instagram.com/agenciabferraz/'),
  (83, '@lepub_worldwide', 'LePub', 'Agências criativas', 'Publicidade / criatividade', 'https://www.instagram.com/lepub_worldwide/'),
  (84, '@grey', 'Grey', 'Agências criativas', 'Publicidade / campanhas', 'https://www.instagram.com/grey/'),
  (85, '@dpzoficial', 'DPZ', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/dpzoficial/'),
  (86, '@livemktnews', 'Live MKT News', 'Comunicação e mídia', 'Live marketing / imprensa', 'https://www.instagram.com/livemktnews/'),
  (87, '@brazilpromotion', 'Brazil Promotion', 'Entidades e prêmios', 'Feira / marketing promocional', 'https://www.instagram.com/brazilpromotion/'),
  (88, '@laje.ac', 'LAJE', 'Agências de eventos', 'Criação / eventos', 'https://www.instagram.com/laje.ac/'),
  (89, '@clubedecriacao', 'Clube de Criação', 'Entidades e prêmios', 'Criatividade / premiação', 'https://www.instagram.com/clubedecriacao/'),
  (90, '@africaoficial', 'Africa Creative', 'Agências criativas', 'Publicidade / criação', 'https://www.instagram.com/africaoficial/')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ndi_bi_metrics(profile_id,followers,following,total_posts,metric_date) VALUES
  (1, 17400, 142, 1383, DATE '2026-10-13'),
  (2, 127000, 405, 2157, DATE '2026-10-13'),
  (3, 78800, 693, 3493, DATE '2026-10-13'),
  (4, 321000, 1381, 4567, DATE '2026-10-13'),
  (5, 58900, 579, 1193, DATE '2026-10-13'),
  (6, 3214, 166, 335, DATE '2026-10-13'),
  (7, 18500, 62, 931, DATE '2026-10-13'),
  (8, 15100, 173, 155, DATE '2026-10-13'),
  (9, 12500, 66, 1235, DATE '2026-10-13'),
  (10, 5208, 140, 269, DATE '2026-10-13'),
  (11, 34600, 0, 19, DATE '2026-10-13'),
  (12, 130000, 9, 676, DATE '2026-10-13'),
  (13, 23300, 3962, 1219, DATE '2026-10-13'),
  (14, 71000, 499, 2650, DATE '2026-10-13'),
  (15, 370000, 2580, 7056, DATE '2026-10-13'),
  (16, 251000, 2499, 4162, DATE '2026-10-13'),
  (17, 791000, 1009, 9867, DATE '2026-10-13'),
  (18, 346000, 414, 9186, DATE '2026-10-13'),
  (19, 38800, 307, 1623, DATE '2026-10-13'),
  (20, 178000, 134, 6226, DATE '2026-10-13'),
  (21, 357000, 624, 16400, DATE '2026-10-13'),
  (22, 100000, 156, 8126, DATE '2026-10-13'),
  (23, 105000, 4833, 2561, DATE '2026-10-13'),
  (24, 22700, 24, 1836, DATE '2026-10-13'),
  (25, 14300, 281, 411, DATE '2026-10-13'),
  (26, 7412, 5837, 943, DATE '2026-10-13'),
  (27, 5855, 99, 213, DATE '2026-10-13'),
  (28, 18300, 70, 287, DATE '2026-10-13'),
  (29, 8233, 302, 355, DATE '2026-10-13'),
  (30, 983, 57, 225, DATE '2026-10-13'),
  (31, 30400, 76, 734, DATE '2026-10-13'),
  (32, 199000, 148, 87, DATE '2026-10-13'),
  (33, 4894, 605, 652, DATE '2026-10-13'),
  (34, 5750, 141, 69, DATE '2026-10-13'),
  (35, 8445, 696, 1410, DATE '2026-10-13'),
  (36, 587000, 5, 5311, DATE '2026-10-13'),
  (37, 12300, 484, 121, DATE '2026-10-13'),
  (38, 2848, 498, 288, DATE '2026-10-13'),
  (39, 627, 30, 34, DATE '2026-10-13'),
  (40, 24800, 77, 1112, DATE '2026-10-13'),
  (41, 27100, 114, 660, DATE '2026-10-13'),
  (42, 185000, 185, 963, DATE '2026-10-13'),
  (43, 60200, 508, 1973, DATE '2026-10-13'),
  (44, 28900, 52, 36, DATE '2026-10-13'),
  (45, 56700, 59, 752, DATE '2026-10-14'),
  (46, 5800000, 126, 230, DATE '2026-10-13'),
  (47, 20900, 119, 830, DATE '2026-10-13'),
  (48, 27900, 3919, 960, DATE '2026-10-13'),
  (49, 9665, 7351, 1275, DATE '2026-10-13'),
  (50, 12100, 830, 5663, DATE '2026-10-13'),
  (51, 20800, 346, 179, DATE '2026-10-13'),
  (52, 106000, 165, 8778, DATE '2026-10-13'),
  (53, 15000, 1631, 2222, DATE '2026-10-13'),
  (54, 4366, 56, 13, DATE '2026-10-13'),
  (55, 177000, 210, 3927, DATE '2026-10-13'),
  (56, 385000, 218, 13300, DATE '2026-10-13'),
  (57, 9049, 22, 4407, DATE '2026-10-13'),
  (58, 254000, 830, 2792, DATE '2026-10-13'),
  (59, 25800, 4, 605, DATE '2026-10-13'),
  (60, 640000, 20, 15600, DATE '2026-10-13'),
  (61, 62900, 8, 10100, DATE '2026-10-13'),
  (62, 2800000, 11, 34200, DATE '2026-10-13'),
  (63, 73000, 2581, 3262, DATE '2026-10-13'),
  (64, 157000, 227, 666, DATE '2026-10-13'),
  (65, 12700000, 75, 61400, DATE '2026-10-13'),
  (66, 3063, 59, 203, DATE '2026-10-13'),
  (67, 33400, 331, 1223, DATE '2026-10-13'),
  (68, 577000, 139, 160, DATE '2026-10-13'),
  (69, 759000, 339, 1589, DATE '2026-10-13'),
  (70, 19900, 1265, 4063, DATE '2026-10-13'),
  (71, 562000, 150, 4989, DATE '2026-10-13'),
  (72, 49400, 372, 10900, DATE '2026-10-13'),
  (73, 1200000, 184, 293, DATE '2026-10-13'),
  (74, 240000, 136, 218, DATE '2026-10-13'),
  (75, 20600, 135, 796, DATE '2026-10-13'),
  (76, 70400, 116, 1200, DATE '2026-10-13'),
  (77, 77000, 334, 261, DATE '2026-10-13'),
  (78, 181000, 611, 4956, DATE '2026-10-13'),
  (79, 31500, 496, 2261, DATE '2026-10-13'),
  (80, 13500, 6193, 4903, DATE '2026-10-13'),
  (81, 67000, 279, 1899, DATE '2026-10-13'),
  (82, 33900, 538, 328, DATE '2026-10-13'),
  (83, 30000, 43, 173, DATE '2026-10-13'),
  (84, 105000, 156, 2078, DATE '2026-10-13'),
  (85, 44600, 730, 1338, DATE '2026-10-13'),
  (86, 12400, 2587, 2826, DATE '2026-10-13'),
  (87, 9476, 808, 674, DATE '2026-10-13'),
  (88, 97900, 651, 1631, DATE '2026-10-13'),
  (89, 67100, 2, 6708, DATE '2026-10-13'),
  (90, 133000, 190, 4511, DATE '2026-10-13')
ON CONFLICT (profile_id) DO NOTHING;

-- Primeiras capturas históricas (datas 13–14/10/2026; seguidores podem estar arredondados).
INSERT INTO public.ndi_bi_snapshots(profile_id,observed_on,followers,total_posts) VALUES
  (1, DATE '2026-10-13', 17400, 1383),
  (2, DATE '2026-10-13', 127000, 2157),
  (3, DATE '2026-10-13', 78800, 3493),
  (4, DATE '2026-10-13', 321000, 4567),
  (5, DATE '2026-10-13', 58900, 1193),
  (6, DATE '2026-10-13', 3214, 335),
  (7, DATE '2026-10-13', 18500, 931),
  (8, DATE '2026-10-13', 15100, 155),
  (9, DATE '2026-10-13', 12500, 1235),
  (10, DATE '2026-10-13', 5208, 269),
  (11, DATE '2026-10-13', 34600, 19),
  (12, DATE '2026-10-13', 130000, 676),
  (13, DATE '2026-10-13', 23300, 1219),
  (14, DATE '2026-10-13', 71000, 2650),
  (15, DATE '2026-10-13', 370000, 7056),
  (16, DATE '2026-10-13', 251000, 4162),
  (17, DATE '2026-10-13', 791000, 9867),
  (18, DATE '2026-10-13', 346000, 9186),
  (19, DATE '2026-10-13', 38800, 1623),
  (20, DATE '2026-10-13', 178000, 6226),
  (21, DATE '2026-10-13', 357000, 16400),
  (22, DATE '2026-10-13', 100000, 8126),
  (23, DATE '2026-10-13', 105000, 2561),
  (24, DATE '2026-10-13', 22700, 1836),
  (25, DATE '2026-10-13', 14300, 411),
  (26, DATE '2026-10-13', 7412, 943),
  (27, DATE '2026-10-13', 5855, 213),
  (28, DATE '2026-10-13', 18300, 287),
  (29, DATE '2026-10-13', 8233, 355),
  (30, DATE '2026-10-13', 983, 225),
  (31, DATE '2026-10-13', 30400, 734),
  (32, DATE '2026-10-13', 199000, 87),
  (33, DATE '2026-10-13', 4894, 652),
  (34, DATE '2026-10-13', 5750, 69),
  (35, DATE '2026-10-13', 8445, 1410),
  (36, DATE '2026-10-13', 587000, 5311),
  (37, DATE '2026-10-13', 12300, 121),
  (38, DATE '2026-10-13', 2848, 288),
  (39, DATE '2026-10-13', 627, 34),
  (40, DATE '2026-10-13', 24800, 1112),
  (41, DATE '2026-10-13', 27100, 660),
  (42, DATE '2026-10-13', 185000, 963),
  (43, DATE '2026-10-13', 60200, 1973),
  (44, DATE '2026-10-13', 28900, 36),
  (45, DATE '2026-10-14', 56700, 752),
  (46, DATE '2026-10-13', 5800000, 230),
  (47, DATE '2026-10-13', 20900, 830),
  (48, DATE '2026-10-13', 27900, 960),
  (49, DATE '2026-10-13', 9665, 1275),
  (50, DATE '2026-10-13', 12100, 5663),
  (51, DATE '2026-10-13', 20800, 179),
  (52, DATE '2026-10-13', 106000, 8778),
  (53, DATE '2026-10-13', 15000, 2222),
  (54, DATE '2026-10-13', 4366, 13),
  (55, DATE '2026-10-13', 177000, 3927),
  (56, DATE '2026-10-13', 385000, 13300),
  (57, DATE '2026-10-13', 9049, 4407),
  (58, DATE '2026-10-13', 254000, 2792),
  (59, DATE '2026-10-13', 25800, 605),
  (60, DATE '2026-10-13', 640000, 15600),
  (61, DATE '2026-10-13', 62900, 10100),
  (62, DATE '2026-10-13', 2800000, 34200),
  (63, DATE '2026-10-13', 73000, 3262),
  (64, DATE '2026-10-13', 157000, 666),
  (65, DATE '2026-10-13', 12700000, 61400),
  (66, DATE '2026-10-13', 3063, 203),
  (67, DATE '2026-10-13', 33400, 1223),
  (68, DATE '2026-10-13', 577000, 160),
  (69, DATE '2026-10-13', 759000, 1589),
  (70, DATE '2026-10-13', 19900, 4063),
  (71, DATE '2026-10-13', 562000, 4989),
  (72, DATE '2026-10-13', 49400, 10900),
  (73, DATE '2026-10-13', 1200000, 293),
  (74, DATE '2026-10-13', 240000, 218),
  (75, DATE '2026-10-13', 20600, 796),
  (76, DATE '2026-10-13', 70400, 1200),
  (77, DATE '2026-10-13', 77000, 261),
  (78, DATE '2026-10-13', 181000, 4956),
  (79, DATE '2026-10-13', 31500, 2261),
  (80, DATE '2026-10-13', 13500, 4903),
  (81, DATE '2026-10-13', 67000, 1899),
  (82, DATE '2026-10-13', 33900, 328),
  (83, DATE '2026-10-13', 30000, 173),
  (84, DATE '2026-10-13', 105000, 2078),
  (85, DATE '2026-10-13', 44600, 1338),
  (86, DATE '2026-10-13', 12400, 2826),
  (87, DATE '2026-10-13', 9476, 674),
  (88, DATE '2026-10-13', 97900, 1631),
  (89, DATE '2026-10-13', 67100, 6708),
  (90, DATE '2026-10-13', 133000, 4511)
ON CONFLICT (profile_id,observed_on) DO NOTHING;

COMMIT;

-- PASSO SEPARADO APÓS CRIAR UM USUÁRIO VIA SUPABASE AUTH:
-- adicionar seu user_id a public.ndi_bi_editors usando o SQL Editor com acesso administrativo.
-- Não definir usuário editor antes de confirmar a identidade/autorização.
