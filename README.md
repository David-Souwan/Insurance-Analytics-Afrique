<div align="center">

<img src="https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python&logoColor=white"/>
<img src="https://img.shields.io/badge/SQL-8-336791?style=flat-square&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/pandas-2.0-150458?style=flat-square&logo=pandas&logoColor=white"/>
<img src="https://img.shields.io/badge/Plotly-Interactive-3F4F75?style=flat-square&logo=plotly&logoColor=white"/>
<img src="https://img.shields.io/badge/Secteur-Assurance_Afrique-C0392B?style=flat-square"/>
<img src="https://img.shields.io/badge/Niveau-Cabinet_de_Conseil-1A1A2E?style=flat-square"/>

<br/><br/>

# **INSSURANCE**

# Analyse Stratégique · Compagnie d'Assurance Africaine

### *5 marchés · 4 produits · 300 agents · 1 200 contrats · 2020–2025*

<br/>

> **"Pour 100 encaissés en primes, 189 sont payés en sinistres.**
> **Cette analyse identifie les causes exactes et les 5 décisions à prendre."**

<br/>

</div>

---

## Table des matières

- [Contexte business](#-contexte-business)
- [Signal d'alarme immédiat](#-signal-dalarme-immédiat)
- [Structure du projet](#-structure-du-projet)
- [Installation](#-installation--utilisation)
- [Méthodologie](#-méthodologie-complète)
- [Résultats clés](#-résultats-clés-par-dimension)
- [Requêtes SQL](#-requêtes-sql--kpis-clés)
- [Recommandations](#-5-recommandations-stratégiques)
- [Stack technique](#-stack-technique)

---

## 🌍 Contexte business

Une compagnie d'assurance panafricaine opère sur **5 marchés** (Kenya, Nigeria, Maroc, Sénégal, Côte d'Ivoire) avec **4 lignes de produits** (Auto, Santé, Habitation, Vie). La direction constate une croissance du portefeuille couplée à une rentabilité instable. La mission : transformer les données en décisions.

| Dimension | Périmètre analysé |
|---|---|
| Période | Janvier 2020 – Décembre 2025 |
| Contrats | 1 200 polices actives |
| Clients | 765 clients uniques |
| Agents | 295 agents actifs / 300 |
| Pays | 5 marchés africains |
| Produits | Auto · Santé · Habitation · Vie |

---

## 🚨 Signal d'alarme immédiat

```
┌──────────────────────────────────────────────────────────────┐
│  LOSS RATIO GLOBAL : 189,3%                                  │
│                                                              │
│  Norme sectorielle saine : < 80%                            │
│  Seuil d'équilibre       : 100%                             │
│  Réalité du portefeuille : 189,3%                           │
│                                                              │
│  → Pour 100 encaissés, 189 payés en sinistres               │
│  → Perte nette cumulée : -1 113 035                         │
│  → Aucune année rentable sur 6 ans                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Structure du projet

```
insurance-analytics/
│
├── 📓 Insurance_Analysis.ipynb          ← Notebook principal (10 sections)
│
├── 📂 data/
│   ├── agents.csv                       ← 300 agents (id, région, expérience)
│   ├── claims.csv                       ← 1 200 sinistres (montant, date, statut)
│   ├── clients.csv                      ← 1 200 clients (âge, pays, signup)
│   ├── policies.csv                     ← 1 200 contrats (produit, dates, agent)
│   └── premiums.csv                     ← 1 200 primes (montant, date paiement)
│
├── 📂 outputs/
│   ├── dashboard1_executive.png         ← KPIs + Produits + Pays + Temporel
│   ├── dashboard2_agents_clients.png    ← Agents + CLV + Heatmap risque
│   ├── viz1_gauge_loss_ratio.html       ← Gauge interactif (Plotly)
│   ├── viz2_produit_performance.html    ← Waterfall P&L par produit
│   ├── viz3_loss_ratio_pays.html        ← Ranking géographique
│   ├── viz4_evolution_temporelle.html   ← Série temporelle 2020–2025
│   ├── viz5_agents_scatter.html         ← Profit vs Expérience
│   ├── viz6_top_bottom_agents.html      ← Top 10 / Bottom 10
│   ├── viz7_distribution_lr.html        ← Distribution Loss Ratio
│   └── viz8_treemap_portefeuille.html   ← Carte du risque pays × produit
│
├── 📂 sql/
│   └── kpis_queries.sql                 ← 8 requêtes SQL commentées
│
├── 📄 README.md
└── 📄 requirements.txt
```

---

## ⚙️ Installation & utilisation

```bash
# 1. Cloner le dépôt
git clone https://github.com/votre-username/insurance-analytics.git
cd insurance-analytics

# 2. Installer les dépendances
pip install -r requirements.txt

# 3. Placer les fichiers de données
cp *.csv data/

# 4. Lancer le notebook
jupyter notebook Insurance_Analysis.ipynb
```

### requirements.txt

```
pandas>=2.0.0
numpy>=1.24.0
matplotlib>=3.7.0
seaborn>=0.12.0
plotly>=5.18.0
jupyter>=1.0.0
```

---

## 🔬 Méthodologie complète

### Modèle de données

```
clients ──(client_id)──► policies ──(policy_id)──► premiums  [revenus]
                                  └──(policy_id)──► claims    [pertes]
agents  ──(agent_id) ──► policies                             [performance]
```

### Phase 1 — Audit

```
5 fichiers CSV · 0 valeur manquante · 0 doublon
Anomalie détectée : 403 contrats avec start_date > end_date (durées négatives)
Correction : df['duree'] = (end_date - start_date).dt.days.abs()

Statut sinistres : 'Accepted' (971) | 'Rejected' (229)
⚠ ATTENTION : filtrer avec status == 'Accepted' (majuscule stricte)
```

### Phase 2 — Construction df_master

```python
# Pipeline de jointure
df_master = policies
  .merge(clients,       on='client_id',  how='left')  # profil client
  .merge(agents,        on='agent_id',   how='left')  # données agent
  .merge(premiums_agg,  on='policy_id',  how='left')  # primes agrégées
  .merge(claims_all,    on='policy_id',  how='left')  # tous sinistres
  .merge(claims_acc,    on='policy_id',  how='left')  # sinistres acceptés
```

### Phase 3 — KPIs calculés

| Variable | Formule | Usage |
|---|---|---|
| `total_premium` | `sum(amount)` par policy | Revenu par contrat |
| `total_claim_accepted` | `sum(claim_amount)` où `status='Accepted'` | Coût réel |
| `loss_ratio` | `total_claim_accepted / total_premium × 100` | Rentabilité |
| `profit` | `total_premium - total_claim_accepted` | Marge nette |
| `CLV` | `sum(profit)` par client | Valeur vie client |
| `claim_frequency` | `nb_claims / nb_policies` | Fréquence sinistralité |

---

## 📊 Résultats clés par dimension

### Performance globale

```
┌─────────────────────────────────────────────────────────┐
│  COMPAGNIE D'ASSURANCE · 2020–2025                      │
├─────────────────────────────────────────────────────────┤
│  Total primes encaissées  :      1 246 154              │
│  Total sinistres acceptés :      2 359 188              │
│  Perte nette cumulée      :     -1 113 035  🔴          │
│  Loss Ratio global        :         189,3%  🔴          │
│  Contrats rentables       :   452 / 1 200  (37,7%)     │
│  Clients rentables        :   274 /   765  (35,8%)     │
│  Taux d'acceptation       :          80,9%  ⚠️          │
└─────────────────────────────────────────────────────────┘
```

### Par produit

| Produit | Primes | Sinistres | Perte | LR | Fréquence |
|---|---|---|---|---|---|
| **Habitation** | 345 006 | 722 472 | -377 466 | **209%** | 0,898 |
| **Vie** | 267 027 | 553 622 | -286 595 | **207%** | 0,866 |
| **Auto** | 287 564 | 510 543 | -222 978 | **178%** | 0,726 |
| **Santé** | 346 557 | 572 552 | -225 996 | **165%** ✓ | 0,748 |

### Par pays

| Pays | Loss Ratio | Perte | Priorité |
|---|---|---|---|
| Maroc | **207%** | -229 260 | 🔴 Gel souscriptions |
| Sénégal | **199%** | -258 586 | 🔴 Révision urgente |
| Côte d'Ivoire | **195%** | -260 106 | 🔴 Révision urgente |
| Nigeria | **194%** | -225 195 | 🟠 Optimiser |
| **Kenya** | **154%** ✓ | -139 887 | 🟢 Développer |

### Évolution temporelle

```
2020  │ LR: 187%  Perte: -196 595
2021  │ LR: 161%  Perte: -138 287  ← Meilleure année
2022  │ LR: 209%  Perte: -225 730  ← Rupture
2023  │ LR: 181%  Perte: -180 638
2024  │ LR: 222%  Perte: -201 883  ← Pire ratio
2025  │ LR: 187%  Perte: -169 902  (en cours)
```

### Agents — Anomalies critiques

```
Agent 127 (Nigeria) : sinistres 31 176 — primes 0 → FRAUDE POTENTIELLE
Agent 202 (Nigeria) : Loss Ratio 686%
Agent 18  (Nigeria) : Loss Ratio 956%
```

### Clients — Asymétrie CLV

```
Top 10% (77 clients)    : +256 807 de profit
Bottom 10% (77 clients) : -680 543 de perte
→ Les pires clients détruisent 2,65× la valeur créée par les meilleurs
```

---

## 🗄️ Requêtes SQL — KPIs clés

Le projet inclut 8 requêtes SQL commentées couvrant :

| # | Requête | KPI produit |
|---|---|---|
| SQL 1 | P&L par année | Loss Ratio annuel, profit technique |
| SQL 2 | Rentabilité par produit | Loss Ratio, marge par ligne |
| SQL 3 | Performance par pays | CA, sinistres, profit géographique |
| SQL 4 | Top 10 agents | Profit net par agent |
| SQL 5 | Top 20 clients CLV | Customer Lifetime Value technique |
| SQL 6 | Sinistralité par produit | Fréquence, coût moyen, risk cost |
| SQL 7 | Cohortes de rétention | Taux de rétention par année signup |
| SQL 8 | Agents sous-performants | Agents avec LR > 200%, seuil ≥ 3 polices |

> ⚠️ **Note critique** : Filtrer sur `status = 'Accepted'` (majuscule stricte). Le filtre `IN ('PAID', 'ACCEPTED')` retourne 0 résultat sur ce dataset.

---

## 🎯 5 Recommandations stratégiques

### P1 — Auditer l'agent 127 ⚡ *0–30 jours · Critique*
Sinistres sans primes = impossibilité technique → fraude ou erreur système.
**KPI :** Clôture audit · Exposition de 31 176 à clarifier.

### P2 — Geler Habitation/Vie au Maroc ⚡ *0–60 jours · Urgent*
LR 207%+ sur ces segments = perte garantie à chaque souscription.
**KPI :** Zéro nouvelle souscription sous 60 jours.

### P3 — Révision tarifaire globale 📋 *1–3 mois*
Prime actuelle couvre 53% du coût sinistre. Objectif : LR < 120% sur nouvelles souscriptions.
**KPI :** LR nouvelles souscriptions < 120% à M+6.

### P4 — Renforcer les critères d'acceptation 🔧 *1–4 mois*
Taux acceptation 80,9% vs norme 60–65%. Réduction de 15 points = -15% de sinistres.
**KPI :** Taux acceptation < 68% à M+3.

### P5 — Expansion Kenya × Santé 📈 *3–6 mois*
Kenya (LR 154%) × Santé (LR 165%) = combinaison la moins risquée du portefeuille.
**KPI :** +200 contrats Kenya·Santé · LR global < 175% à M+12.

---

## 🛠️ Stack technique

```python
# Analyse données
pandas      >= 2.0    # Manipulation, agrégations, jointures
numpy       >= 1.24   # Calculs numériques, gestion des NaN

# Visualisations
matplotlib  >= 3.7    # Dashboards statiques (2 dashboards produits)
seaborn     >= 0.12   # Heatmaps, distributions
plotly      >= 5.18   # 8 graphiques interactifs (gauge, waterfall, treemap...)

# SQL
PostgreSQL / SQLite    # 8 requêtes KPI métier

# Environnement
Python 3.10+ · Jupyter · VS Code
```

---

## 📈 Ce projet en chiffres

```
1 200   contrats analysés
    5   fichiers CSV joints en 1 dataset maître
    8   dimensions d'analyse (produit, pays, agents, clients, temps, risque, CLV, rétention)
    8   requêtes SQL KPI métier
    8   visualisations interactives Plotly
    2   dashboards statiques matplotlib
    5   recommandations chiffrées et actionnables
```

---

## 👤 Auteur

**DAVID SOUWAN** · Data Analyst · Spécialisation Assurance & Finance Africaine
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=flat-square&logo=github)](https://github.com/David-Souwan)

---

<div align="center">

*Analyse stratégique · Compagnie d'Assurance Africaine · 2020–2025*
*Python · SQL · pandas · matplotlib · seaborn · plotly*

**⭐ Si ce projet vous a été utile, une étoile GitHub est appréciée.**

</div>
