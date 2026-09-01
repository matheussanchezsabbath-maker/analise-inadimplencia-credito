-- =====================================================================
-- DELINQUENCY CASE — SQL ANALYSIS (MySQL)
-- Author: Matheus Mucci Sanchez
-- Goal: analyze the portfolio delinquency and identify risk segments
--       above the average.
-- Data: 5,000 loan contracts (fictional data).
-- Note: this file documents the analysis and the queries used. The data
--       was loaded from the case CSV using the Import Wizard.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0) SETUP — create database and table
-- ---------------------------------------------------------------------
-- Data treatment note: during the CSV import, the encoding was set to
-- latin1 to fix the accents in text columns (finalidade, regiao). The
-- columns used in the analysis have no accents, so there was no impact
-- on the results.

CREATE DATABASE IF NOT EXISTS case_fintech;
USE case_fintech;

CREATE TABLE IF NOT EXISTS emprestimos (
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

-- (The 5,000 records were loaded using the Table Data Import Wizard.)

-- Check the load
SELECT COUNT(*) AS total_records FROM emprestimos;   -- expected: 5000


-- ---------------------------------------------------------------------
-- QUESTION 1 — What is the overall delinquency rate of the portfolio?
-- ---------------------------------------------------------------------
-- Logic: since 'inadimplente_90d' is binary (0/1), the average of the
-- column equals the share of delinquent contracts (the rate).

SELECT
    COUNT(*) AS total_contracts,
    SUM(inadimplente_90d) AS total_delinquent,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS delinquency_rate_pct
FROM emprestimos;

-- Result: 5,000 contracts | 905 delinquent | 18.1% delinquency rate.


-- ---------------------------------------------------------------------
-- QUESTION 2 — Is there any segment with delinquency above the average?
-- ---------------------------------------------------------------------

-- 2.1) By ACQUISITION CHANNEL
SELECT
    canal_aquisicao AS acquisition_channel,
    COUNT(*) AS total_contracts,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS delinquency_rate_pct
FROM emprestimos
GROUP BY canal_aquisicao
ORDER BY delinquency_rate_pct DESC;
-- Finding: 'Parceiro Marketplace B' = 32.7% (1.8x the overall average of
-- 18.1%), with 569 contracts (enough volume to be reliable).


-- 2.2) Does Marketplace B bring a worse customer profile? (root-cause check)
-- Compares average score and % with credit restriction across channels.
SELECT
    canal_aquisicao AS acquisition_channel,
    COUNT(*) AS contracts,
    ROUND(AVG(score_interno), 0) AS avg_score,
    ROUND(AVG(possui_restricao) * 100, 1) AS pct_with_restriction
FROM emprestimos
GROUP BY canal_aquisicao
ORDER BY avg_score;
-- Conclusion: Marketplace B's profile (avg score ~521, restriction ~32%)
-- is almost the SAME as the other channels. So the higher risk is NOT
-- explained by the customer profile — it is a problem of the channel itself.


-- 2.3) By SCORE BAND
SELECT
    CASE
        WHEN score_interno < 400 THEN '1. Very low (0-400)'
        WHEN score_interno < 600 THEN '2. Low (400-600)'
        WHEN score_interno < 800 THEN '3. Medium (600-800)'
        ELSE '4. High (800+)'
    END AS score_band,
    COUNT(*) AS contracts,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS delinquency_rate_pct
FROM emprestimos
GROUP BY score_band
ORDER BY score_band;
-- Finding: the rate drops from 36.9% (score 0-400) to 3.7% (score 800+).
-- The internal score is a strong predictor of delinquency.


-- 2.4) By PRIOR CREDIT RESTRICTION
SELECT
    possui_restricao AS has_restriction,
    COUNT(*) AS contracts,
    ROUND(AVG(inadimplente_90d) * 100, 1) AS delinquency_rate_pct
FROM emprestimos
GROUP BY possui_restricao;
-- Finding: customers with a prior restriction default at 27.6% vs 13.9%
-- (almost double).


-- ---------------------------------------------------------------------
-- SUMMARY OF FINDINGS (Question 2)
-- ---------------------------------------------------------------------
-- Risk factors identified, all above the 18.1% average:
--   • Channel Parceiro Marketplace B ... 32.7%  (NON-OBVIOUS, actionable)
--   • Low score (0-400) ................ 36.9%  (expected; already used at approval)
--   • Prior restriction ................ 27.6%  (expected; already used at approval)
--
-- Marketplace B is the most relevant finding for action, because its high
-- risk is not explained by the customer profile.
-- =====================================================================
