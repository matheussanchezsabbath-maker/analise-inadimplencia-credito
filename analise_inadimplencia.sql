-- =====================================================================
-- CASE INADIMPLÊNCIA — ANÁLISE EM SQL (MySQL)
-- Autor: Matheus Mucci Sanchez
-- Objetivo: analisar a inadimplência da carteira e identificar
--           segmentos de risco acima da média.
-- Base: 5.000 contratos de empréstimo (dados fictícios).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0) PREPARAÇÃO — criação do banco e da tabela
-- ---------------------------------------------------------------------
-- Observação de tratamento: na importação do CSV foi ajustado o encoding
-- (latin1) para corrigir a acentuação de colunas textuais (finalidade,
-- regiao). As colunas usadas nas análises não possuem acento, portanto
-- não houve impacto nos resultados.

CREATE DATABASE case_fintech;
USE case_fintech;

CREATE TABLE emprestimos (
    id_cliente VARCHAR(20),
    data_contratacao DATE,
    idade INT,
    sexo VARCHAR(1),
    regiao VARCHAR(20),
    renda_mensal INT,
    classe_social VARCHAR(1),
    score_interno INT,
    canal_aquisicao VARCHAR(50),
    num_emprestimos_anteriores INT,
    tempo_relacionamento_dias INT,
    possui_restricao TINYINT,
    valor_solicitado INT,
    prazo_meses INT,
    taxa_juros_am DECIMAL(6,4),
    valor_parcela DECIMAL(10,2),
    comprometimento_renda DECIMAL(5,3),
    finalidade VARCHAR(30),
    dias_atraso_max INT,
    inadimplente_90d TINYINT
);

-- (Os 5.000 registros foram carregados via Table Data Import Wizard.)

-- Conferência da carga
SELECT COUNT(*) AS total_registros FROM emprestimos;   -- esperado: 5000


-- ---------------------------------------------------------------------
-- PERGUNTA 1 — Qual a taxa geral de inadimplência da carteira?
-- ---------------------------------------------------------------------
-- Lógica: como 'inadimplente_90d' é binária (0/1), a média da coluna
-- equivale à proporção de inadimplentes (a taxa).

SELECT
    COUNT(*) AS total_contratos,
    SUM(inadimplente_90d) AS total_inadimplentes,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS taxa_inadimplencia_pct
FROM emprestimos;

-- Resultado: 5.000 contratos | 905 inadimplentes | 18,1% de inadimplência.


-- ---------------------------------------------------------------------
-- PERGUNTA 2 — Existe algum segmento com inadimplência acima da média?
-- ---------------------------------------------------------------------

-- 2.1) Por CANAL DE AQUISIÇÃO
SELECT
    canal_aquisicao,
    COUNT(*) AS total_contratos,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS taxa_inadimplencia_pct
FROM emprestimos
GROUP BY canal_aquisicao
ORDER BY taxa_inadimplencia_pct DESC;
-- Achado: 'Parceiro Marketplace B' = 32,7% (1,8x a média geral de 18,1%),
-- com 569 contratos (volume suficiente para ser confiável).


-- 2.2) O Marketplace B tem perfil de cliente pior? (checagem de causa)
-- Compara score médio e % de restrição entre os canais.
SELECT
    canal_aquisicao,
    COUNT(*) AS contratos,
    ROUND(AVG(score_interno), 0) AS score_medio,
    ROUND(AVG(possui_restricao) * 100, 1) AS pct_com_restricao
FROM emprestimos
GROUP BY canal_aquisicao
ORDER BY score_medio;
-- Conclusão: o perfil do Marketplace B (score ~521, restrição ~32%) é
-- praticamente IGUAL ao dos demais canais. Ou seja, o risco elevado NÃO
-- se explica pelo perfil do cliente — é um problema do próprio canal.


-- 2.3) Por FAIXA DE SCORE
SELECT
    CASE
        WHEN score_interno < 400 THEN '1. Muito baixo (0-400)'
        WHEN score_interno < 600 THEN '2. Baixo (400-600)'
        WHEN score_interno < 800 THEN '3. Medio (600-800)'
        ELSE '4. Alto (800+)'
    END AS faixa_score,
    COUNT(*) AS contratos,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS taxa_pct
FROM emprestimos
GROUP BY faixa_score
ORDER BY faixa_score;
-- Achado: taxa cai de 36,9% (score 0-400) para 3,7% (score 800+).
-- O score interno é um forte previsor de inadimplência.


-- 2.4) Por RESTRIÇÃO PRÉVIA
SELECT
    possui_restricao,
    COUNT(*) AS contratos,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS taxa_pct
FROM emprestimos
GROUP BY possui_restricao;
-- Achado: clientes com restrição inadimplem 27,6% vs 13,9% (quase o dobro).


-- ---------------------------------------------------------------------
-- RESUMO DOS ACHADOS (Pergunta 2)
-- ---------------------------------------------------------------------
-- Fatores de risco identificados, todos acima da média de 18,1%:
--   • Canal Parceiro Marketplace B ... 32,7%  (achado NÃO-ÓBVIO e acionável)
--   • Score baixo (0-400) ............ 36,9%  (fator esperado; já usado na concessão)
--   • Restrição prévia ............... 27,6%  (fator esperado; já usado na concessão)
--
-- O canal Marketplace B é o achado mais relevante para ação, pois seu
-- risco elevado não é explicado pelo perfil do cliente.
-- =====================================================================
