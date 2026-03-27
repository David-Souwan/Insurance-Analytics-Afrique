-- ===========================================================================
-- COMPAGNIE D'ASSURANCE AFRICAINE — REQUÊTES SQL KPIs STRATÉGIQUES
-- Période : 2020–2025 | 5 pays | 4 produits | 300 agents | 1 200 contrats
-- ===========================================================================
-- SCHÉMA DES TABLES :
--   agents   (agent_id, region, experience_years)
--   claims   (claim_id, policy_id, claim_amount, claim_date, status)
--   clients  (client_id, age, country, signup_date)
--   policies (policy_id, client_id, product_type, start_date, end_date, agent_id)
--   premiums (premium_id, policy_id, amount, payment_date)
--
-- ⚠️  NOTES CRITIQUES :
--   1. Filtrer toujours sur status = 'Accepted' (majuscule stricte)
--      Le filtre 'accepted' (minuscule) retourne 0 résultat sur ce dataset
--   2. Utiliser EXTRACT(YEAR FROM date) selon votre SGBD
--      PostgreSQL : EXTRACT(YEAR FROM date)
--      MySQL      : YEAR(date)
--      SQLite     : strftime('%Y', date)
--   3. Seuil agents : >= 3 polices minimum pour fiabilité statistique
-- ===========================================================================


-- ===========================================================================
-- SQL 1 — P&L TECHNIQUE PAR ANNÉE
-- Objectif : comprendre l'évolution de la rentabilité sur 6 ans
-- ===========================================================================
-- Le P&L technique annuel est le premier indicateur de santé d'un assureur.
-- Un Loss Ratio > 100% signifie que les sinistres dépassent les primes.
-- À 189%, l'assureur paie 1,89 pour chaque 1,00 encaissé.

WITH yearly_premiums AS (
    -- Agrège les primes encaissées par année de paiement
    SELECT
        EXTRACT(YEAR FROM p.payment_date) AS annee,
        SUM(p.amount) AS total_primes
    FROM premiums p
    WHERE p.payment_date IS NOT NULL        -- Exclut les primes sans date enregistrée
    GROUP BY EXTRACT(YEAR FROM p.payment_date)
),
yearly_claims AS (
    -- Agrège les sinistres ACCEPTÉS par année de survenance
    -- ⚠️ status = 'Accepted' avec majuscule stricte
    SELECT
        EXTRACT(YEAR FROM c.claim_date)  AS annee,
        SUM(c.claim_amount) AS total_sinistres
    FROM claims c
    WHERE c.status = 'Accepted'
    GROUP BY EXTRACT(YEAR FROM c.claim_date)
)
SELECT
    COALESCE(yp.annee, yc.annee)                        AS annee,
    COALESCE(yp.total_primes, 0)                        AS total_primes,
    COALESCE(yc.total_sinistres, 0)                     AS total_sinistres,
    COALESCE(yp.total_primes, 0)
        - COALESCE(yc.total_sinistres, 0)               AS profit_technique,
    CASE
        WHEN COALESCE(yp.total_primes, 0) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(yc.total_sinistres, 0) / yp.total_primes) * 100, 2
        )
    END                                                  AS loss_ratio_pct,
    CASE
        WHEN COALESCE(yp.total_primes, 0) = 0 THEN 'Anomalie'
        WHEN (yc.total_sinistres / yp.total_primes * 100) > 200 THEN 'CRITIQUE'
        WHEN (yc.total_sinistres / yp.total_primes * 100) > 100 THEN 'DÉFICITAIRE'
        ELSE 'RENTABLE'
    END                                                  AS signal
FROM yearly_premiums yp
FULL OUTER JOIN yearly_claims yc ON yp.annee = yc.annee
ORDER BY annee;

-- Résultats attendus :
-- 2020 : LR ~187% · 2021 : LR ~161% (meilleure année) · 2022 : LR ~209% (rupture)
-- 2024 : LR ~222% (pire ratio) · Aucune année rentable sur 6 ans


-- ===========================================================================
-- SQL 2 — RENTABILITÉ PAR PRODUIT
-- Objectif : identifier les lignes à réviser ou arrêter
-- ===========================================================================
-- Distinguer fréquence (nb sinistres / nb polices) et coût moyen (severity)
-- est fondamental pour la tarification actuarielle.
-- Prime pure nécessaire = fréquence × coût moyen

SELECT
    p.product_type,
    COUNT(DISTINCT p.policy_id)                          AS nb_polices,
    ROUND(SUM(pr.amount), 2)                             AS total_primes,
    ROUND(COALESCE(SUM(c.claim_amount), 0), 2)           AS total_sinistres,
    ROUND(SUM(pr.amount)
        - COALESCE(SUM(c.claim_amount), 0), 2)           AS profit_technique,
    CASE
        WHEN SUM(pr.amount) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(SUM(c.claim_amount), 0) / SUM(pr.amount)) * 100, 2
        )
    END                                                  AS loss_ratio_pct,
    -- Fréquence de sinistralité = nb sinistres / nb polices
    ROUND(
        COUNT(c.claim_id) * 1.0
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 3
    )                                                    AS frequence_sinistralite,
    -- Coût moyen par sinistre (severity)
    ROUND(AVG(c.claim_amount), 2)                        AS cout_moyen_sinistre,
    -- Coût du risque par police = prime pure nécessaire
    ROUND(
        COALESCE(SUM(c.claim_amount), 0)
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 2
    )                                                    AS risk_cost_par_police
FROM policies p
INNER JOIN premiums pr ON p.policy_id = pr.policy_id
LEFT JOIN claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'               -- ⚠️ Majuscule stricte
GROUP BY p.product_type
ORDER BY loss_ratio_pct DESC;

-- Résultats attendus :
-- Habitation : LR 209%, fréquence 0.898 → quasi un sinistre par contrat
-- Vie        : LR 207%, fréquence 0.866
-- Auto       : LR 178%, fréquence 0.726
-- Santé      : LR 165%, fréquence 0.748 → produit le moins déficitaire


-- ===========================================================================
-- SQL 3 — PERFORMANCE GÉOGRAPHIQUE
-- Objectif : prioriser l'expansion et identifier les marchés à risque
-- ===========================================================================
-- L'analyse géographique permet d'adapter la tarification, les conditions
-- de souscription et l'allocation des ressources commerciales par pays.

SELECT
    cl.country,
    COUNT(DISTINCT p.policy_id)                          AS nb_polices,
    ROUND(SUM(pr.amount), 2)                             AS total_primes,
    ROUND(COALESCE(SUM(c.claim_amount), 0), 2)           AS total_sinistres,
    ROUND(SUM(pr.amount)
        - COALESCE(SUM(c.claim_amount), 0), 2)           AS profit_technique,
    CASE
        WHEN SUM(pr.amount) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(SUM(c.claim_amount), 0) / SUM(pr.amount)) * 100, 2
        )
    END                                                  AS loss_ratio_pct,
    -- Perte moyenne par contrat (normalise pour comparer des marchés de tailles différentes)
    ROUND(
        (SUM(pr.amount) - COALESCE(SUM(c.claim_amount), 0))
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 2
    )                                                    AS profit_par_police,
    -- Part du CA total par pays
    ROUND(
        SUM(pr.amount) * 100.0
        / SUM(SUM(pr.amount)) OVER (), 1
    )                                                    AS part_ca_pct
FROM clients cl
INNER JOIN policies p  ON cl.client_id = p.client_id
INNER JOIN premiums pr ON p.policy_id  = pr.policy_id
LEFT JOIN  claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'
GROUP BY cl.country
ORDER BY loss_ratio_pct DESC;

-- Résultats attendus :
-- Maroc   : LR ~207% → gel des souscriptions Habitation/Vie recommandé
-- Kenya   : LR ~154% → seul marché sous 160% → à développer en priorité


-- ===========================================================================
-- SQL 4 — TOP 10 AGENTS PAR PROFIT NET
-- Objectif : identifier les meilleurs agents pour les valoriser
-- ===========================================================================
-- Un agent performant génère du volume ET sélectionne de bons risques.
-- Le profit net est plus révélateur que le simple volume de primes.

SELECT
    a.agent_id,
    a.region,
    a.experience_years,
    COUNT(DISTINCT p.policy_id)                          AS nb_polices_vendues,
    ROUND(SUM(pr.amount), 2)                             AS total_primes,
    ROUND(COALESCE(SUM(c.claim_amount), 0), 2)           AS total_sinistres,
    ROUND(SUM(pr.amount)
        - COALESCE(SUM(c.claim_amount), 0), 2)           AS profit_net,
    CASE
        WHEN SUM(pr.amount) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(SUM(c.claim_amount), 0) / SUM(pr.amount)) * 100, 2
        )
    END                                                  AS loss_ratio_pct
FROM agents a
INNER JOIN policies p  ON a.agent_id   = p.agent_id
INNER JOIN premiums pr ON p.policy_id  = pr.policy_id
LEFT JOIN  claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'
GROUP BY a.agent_id, a.region, a.experience_years
ORDER BY profit_net DESC
LIMIT 10;

-- Insight : Agent 234 (Nigeria, 3 ans) → LR 52% — meilleure sélection du risque
-- L'expérience ne corrèle pas avec la performance dans ce dataset


-- ===========================================================================
-- SQL 5 — TOP 20 CLIENTS PAR CLV TECHNIQUE
-- Objectif : identifier les clients à fort potentiel pour la rétention
-- ===========================================================================
-- La CLV technique = primes totales - sinistres totaux sur l'historique client.
-- Elle exclut les frais d'acquisition et d'administration (non disponibles).
-- Ces clients sont prioritaires pour les programmes de fidélisation.

SELECT
    cl.client_id,
    cl.age,
    cl.country,
    MIN(p.start_date) AS premiere_police,
    COUNT(DISTINCT p.policy_id) AS nb_polices,
    ROUND(SUM(pr.amount), 2) AS total_primes_payees,
    ROUND(COALESCE(SUM(c.claim_amount), 0), 2) AS total_sinistres_recus,
    ROUND(SUM(pr.amount)
        - COALESCE(SUM(c.claim_amount), 0), 2) AS clv_technique,
    CASE
        WHEN SUM(pr.amount) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(SUM(c.claim_amount), 0) / SUM(pr.amount)) * 100, 2
        )
    END  AS loss_ratio_pct,
    -- Ancienneté client en années
    ROUND(
        EXTRACT(YEAR FROM CURRENT_DATE)
        - EXTRACT(YEAR FROM MIN(p.start_date)), 0
    )  AS anciennete_annees
FROM clients cl
INNER JOIN policies p  ON cl.client_id = p.client_id
INNER JOIN premiums pr ON p.policy_id  = pr.policy_id
LEFT JOIN  claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'
GROUP BY cl.client_id, cl.age, cl.country
ORDER BY clv_technique DESC
LIMIT 20;

-- Le top 10% des clients génère +256 807 de profit
-- Le bottom 10% détruit -680 543 → ratio destruction/création = 2.65x


-- ===========================================================================
-- SQL 6 — FRÉQUENCE ET COÛT MOYEN DES SINISTRES PAR PRODUIT
-- Objectif : paramètres actuariels clés pour la révision tarifaire
-- ===========================================================================
-- Fréquence = nb sinistres acceptés / nb polices
-- Sévérité = coût moyen par sinistre
-- Prime pure minimum = fréquence × sévérité

SELECT
    p.product_type,
    COUNT(DISTINCT p.policy_id)                          AS nb_polices,
    COUNT(c.claim_id)                                    AS nb_sinistres_acceptes,
    -- Fréquence de sinistralité
    ROUND(
        COUNT(c.claim_id) * 1.0
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 3
    )                                                    AS frequence,
    -- Sévérité (coût moyen par sinistre)
    ROUND(AVG(c.claim_amount), 2)                        AS cout_moyen_sinistre,
    ROUND(SUM(c.claim_amount), 2)                        AS cout_total_sinistres,
    -- Risk cost = coût du risque par police = prime pure nécessaire
    ROUND(
        SUM(c.claim_amount) * 1.0
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 2
    )                                                    AS risk_cost_par_police,
    -- Prime actuelle moyenne (pour comparaison avec le risk cost)
    ROUND(
        SUM(pr.amount) * 1.0
        / NULLIF(COUNT(DISTINCT p.policy_id), 0), 2
    )                                                    AS prime_moyenne_actuelle,
    -- Ratio prime actuelle / risk cost (doit être > 1.0 pour être rentable)
    ROUND(
        SUM(pr.amount) * 1.0
        / NULLIF(SUM(c.claim_amount), 0), 3
    )                                                    AS ratio_couverture
FROM policies p
INNER JOIN premiums pr ON p.policy_id = pr.policy_id
LEFT JOIN  claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'
GROUP BY p.product_type
ORDER BY frequence DESC;

-- Résultats attendus :
-- Habitation : fréquence 0.898, risk_cost 2 237, prime_moyenne 1 068 → ratio 0.48
-- Cela signifie que la prime couvre seulement 48% du coût réel des sinistres


-- ===========================================================================
-- SQL 7 — ANALYSE DE RÉTENTION PAR COHORTE
-- Objectif : mesurer la fidélisation client et identifier le churn
-- ===========================================================================
-- Chaque client est assigné à sa cohorte d'année de première souscription.
-- La rétention mesure la proportion de clients actifs chaque année suivante.

WITH premiere_police AS (
    -- Identifie l'année de première souscription pour chaque client (cohorte)
    SELECT
        client_id,
        MIN(EXTRACT(YEAR FROM start_date))               AS annee_cohorte
    FROM policies
    GROUP BY client_id
),
activite_annuelle AS (
    -- Pour chaque cohorte, compte les clients actifs chaque année
    SELECT
        pp.annee_cohorte,
        EXTRACT(YEAR FROM p.start_date)                  AS annee_activite,
        COUNT(DISTINCT p.client_id)                      AS clients_actifs
    FROM premiere_police pp
    INNER JOIN policies p ON pp.client_id = p.client_id
    WHERE EXTRACT(YEAR FROM p.start_date) >= pp.annee_cohorte
    GROUP BY pp.annee_cohorte, EXTRACT(YEAR FROM p.start_date)
)
SELECT
    annee_cohorte,
    annee_activite,
    clients_actifs,
    -- Clients de l'année précédente (pour calculer la rétention)
    LAG(clients_actifs) OVER (
        PARTITION BY annee_cohorte
        ORDER BY annee_activite
    )                                                    AS clients_annee_precedente,
    -- Taux de rétention = clients actifs N / clients actifs N-1
    ROUND(
        clients_actifs * 100.0 / NULLIF(
            LAG(clients_actifs) OVER (
                PARTITION BY annee_cohorte
                ORDER BY annee_activite
            ), 0
        ), 2
    )                                                    AS taux_retention_pct,
    -- Nombre d'années depuis la création de la cohorte
    annee_activite - annee_cohorte                       AS annee_depuis_souscription
FROM activite_annuelle
ORDER BY annee_cohorte, annee_activite;

-- Usage : identifier les cohortes avec fort churn en année 1
-- Action : programme de fidélisation déclenché à 3 mois après souscription


-- ===========================================================================
-- SQL 8 — AGENTS SOUS-PERFORMANTS (LOSS RATIO > 200%)
-- Objectif : identifier les agents à auditer ou accompagner
-- ===========================================================================
-- Un LR > 200% signifie que les sinistres dépassent le double des primes générées.
-- Ces agents nécessitent un audit : mauvaise sélection des risques, zone géographique
-- à risque non tarifée, ou manipulation des données.
-- Seuil minimal : 3 polices pour éviter les agents avec faible volumétrie.

WITH agent_performance AS (
    SELECT
        a.agent_id,
        a.region,
        a.experience_years,
        COUNT(DISTINCT p.policy_id)                      AS nb_polices_vendues,
        ROUND(SUM(pr.amount), 2)                         AS total_primes,
        ROUND(COALESCE(SUM(c.claim_amount), 0), 2)       AS total_sinistres,
        ROUND(SUM(pr.amount)
            - COALESCE(SUM(c.claim_amount), 0), 2)       AS profit_net,
        CASE
            WHEN SUM(pr.amount) = 0 THEN NULL            -- NULL si aucune prime → anomalie critique
            ELSE (COALESCE(SUM(c.claim_amount), 0)
                  / SUM(pr.amount)) * 100
        END                                              AS loss_ratio_pct
    FROM agents a
    INNER JOIN policies p  ON a.agent_id   = p.agent_id
    INNER JOIN premiums pr ON p.policy_id  = pr.policy_id
    LEFT JOIN  claims c
        ON p.policy_id = c.policy_id
        AND c.status = 'Accepted'
    GROUP BY a.agent_id, a.region, a.experience_years
    HAVING COUNT(DISTINCT p.policy_id) >= 3             -- Seuil minimal de fiabilité statistique
)
SELECT
    agent_id,
    region,
    experience_years,
    nb_polices_vendues,
    total_primes,
    total_sinistres,
    profit_net,
    ROUND(loss_ratio_pct, 2)                             AS loss_ratio_pct,
    CASE
        WHEN loss_ratio_pct IS NULL   THEN '🔴 ANOMALIE — Sinistres sans primes'
        WHEN loss_ratio_pct > 500     THEN '🔴 CRITIQUE — Audit immédiat'
        WHEN loss_ratio_pct > 300     THEN '🔴 GRAVE — Investigation requise'
        ELSE                               '🟠 ÉLEVÉ — Suivi renforcé'
    END                                                  AS niveau_alerte
FROM agent_performance
WHERE loss_ratio_pct > 200
   OR loss_ratio_pct IS NULL                             -- Inclut les cas sans prime (fraude potentielle)
ORDER BY loss_ratio_pct DESC;

-- Résultats attendus :
-- Agent 18  (Nigeria, 3 ans)  : LR ~956% → audit immédiat
-- Agent 202 (Nigeria, 4 ans)  : LR ~686% → audit immédiat
-- Agent 59  (Sénégal, 4 ans)  : LR ~559%
-- Agent 127 (Nigeria, 9 ans)  : NULL (sinistres sans primes) → fraude potentielle


-- ===========================================================================
-- SQL BONUS — HEATMAP LOSS RATIO PAR PAYS × PRODUIT
-- Objectif : carte du risque croisée pour les décisions de souscription
-- ===========================================================================

SELECT
    cl.country,
    p.product_type,
    COUNT(DISTINCT p.policy_id)                          AS nb_polices,
    ROUND(SUM(pr.amount), 2)                             AS total_primes,
    ROUND(COALESCE(SUM(c.claim_amount), 0), 2)           AS total_sinistres,
    CASE
        WHEN SUM(pr.amount) = 0 THEN NULL
        ELSE ROUND(
            (COALESCE(SUM(c.claim_amount), 0) / SUM(pr.amount)) * 100, 2
        )
    END                                                  AS loss_ratio_pct
FROM clients cl
INNER JOIN policies p  ON cl.client_id = p.client_id
INNER JOIN premiums pr ON p.policy_id  = pr.policy_id
LEFT JOIN  claims c
    ON p.policy_id = c.policy_id
    AND c.status = 'Accepted'
GROUP BY cl.country, p.product_type
ORDER BY cl.country, loss_ratio_pct DESC;

-- Usage : identifier les combinaisons pays × produit les plus destructrices
-- Ex : Maroc × Habitation = zone à geler en priorité


-- ===========================================================================
-- SQL BONUS — COMBINED RATIO ESTIMÉ (si frais disponibles)
-- Objectif : mesure de viabilité technique complète
-- ===========================================================================
-- Combined Ratio = Loss Ratio + Expense Ratio
-- < 100% = rentabilité technique · > 100% = perte souscrite
-- Note : les frais d'exploitation ne sont pas dans ce dataset.
-- Approximation : si frais = 25% des primes (hypothèse standard)

SELECT
    ROUND(
        SUM(c.claim_amount) / SUM(pr.amount) * 100, 2
    )                                                    AS loss_ratio_pct,
    25.0                                                 AS expense_ratio_estime_pct,
    ROUND(
        SUM(c.claim_amount) / SUM(pr.amount) * 100 + 25.0, 2
    )                                                    AS combined_ratio_estime_pct,
    CASE
        WHEN SUM(c.claim_amount) / SUM(pr.amount) * 100 + 25.0 > 100
        THEN 'Perte technique — action urgente'
        ELSE 'Rentable techniquement'
    END                                                  AS verdict
FROM premiums pr
LEFT JOIN claims c
    ON pr.policy_id = c.policy_id
    AND c.status = 'Accepted';

-- Résultat attendu : Combined Ratio ~214% → perte technique sévère

-- ===========================================================================
-- FIN DU FICHIER SQL
-- Compagnie d'Assurance Africaine · 2020–2025
-- Python · pandas · matplotlib · seaborn · plotly
-- ===========================================================================
