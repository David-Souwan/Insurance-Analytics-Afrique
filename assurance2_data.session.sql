
--- Création de la table agents

CREATE TABLE agents (
    agent_id INT, 
    region VARCHAR,
    experience_years INT
);

--- Création de la table claims

CREATE TABLE claims(
    claim_id INT, policy_id INT, 
    claim_amount NUMERIC(10, 2), 
    claim_date DATE,
    status VARCHAR
);

--- Création de la table clients

CREATE TABLE clients(
    client_id INT, 
    age INT, 
    country VARCHAR, 
    signup_date DATE
);

--- Création de la table policies

CREATE TABLE policies(
    policy_id INT, 
    client_id INT, 
    product_type VARCHAR,
    start_date DATE,
    end_date DATE, 
    agent_id INT
);

--- Création de la table premiums

CREATE TABLE premiums(
    premium_id INT, 
    policy_id INT, amount NUMERIC(10, 2), 
    payment_date DATE
);

SELECT * FROM agents


-- Etape 1 : Compter les lignes

--- Compter le nombre de agents : 300 Agents

SELECT COUNT(*) AS Total_agents
FROM agents

--- Compter le nombre de sinistre : 1200 Sinistres

SELECT COUNT(*) AS Total_sinistre
FROM claims

--- Compter le nombre de clients : 1200 clients

SELECT COUNT(*) AS Total_clients
FROM clients

--- Compter le nombre de policies : 1200 polices

SELECT COUNT(*) AS Total_polices
FROM policies


--- Compter le nombre de premiums : 1200 premiums

SELECT COUNT(*) AS Total_premiums
FROM premiums