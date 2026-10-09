CREATE TABLE clients (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(50) NOT NULL,
    prenom VARCHAR(50) NOT NULL,
    date_naissance DATE,
    pseudonyme VARCHAR(50)
);

CREATE TABLE adresses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    numero VARCHAR(10),
    rue VARCHAR(100),
    code_postal VARCHAR(5),
    commune VARCHAR(50)
);

CREATE TABLE clients_adresses (
    client_id INT,
    adresse_id INT,
    PRIMARY KEY (client_id, adresse_id),
    FOREIGN KEY (client_id) REFERENCES clients(id),
    FOREIGN KEY (adresse_id) REFERENCES adresses(id)
);

CREATE TABLE chiens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(50) NOT NULL,
    date_naissance DATE,
    race VARCHAR(50),
    sterilise BOOLEAN
);

CREATE TABLE chats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(50) NOT NULL,
    date_naissance DATE,
    race VARCHAR(50),
    sterilise BOOLEAN
);

INSERT INTO clients (nom, prenom, date_naissance, pseudonyme) VALUES
    ('Dupont', 'Marie', '1990-04-12', 'mariedup'),
    ('Martin', 'Lucas', '1985-11-03', 'lulu85'),
    ('Bernard', 'Emma', '1998-07-25', 'emmab');

INSERT INTO adresses (numero, rue, code_postal, commune) VALUES
    ('12', 'rue des Lilas', '44000', 'Nantes'),
    ('5', 'avenue de la Gare', '75010', 'Paris'),
    ('27', 'rue Victor Hugo', '69003', 'Lyon');

INSERT INTO clients_adresses (client_id, adresse_id) VALUES
    (1, 1),
    (2, 2),
    (3, 3),
    (3, 1);

INSERT INTO chiens (nom, date_naissance, race, sterilise) VALUES
    ('Rex', '2019-03-15', 'Berger allemand', TRUE),
    ('Nala', '2021-08-02', 'Labrador', FALSE),
    ('Oscar', '2017-12-20', 'Beagle', TRUE);

INSERT INTO chats (nom, date_naissance, race, sterilise) VALUES
    ('Minou', '2020-05-10', 'Siamois', TRUE),
    ('Luna', '2022-01-18', 'Maine Coon', FALSE),
    ('Felix', '2018-09-07', 'Européen', TRUE);
