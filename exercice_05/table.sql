CREATE TABLE etudiants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(50),
    ville VARCHAR(50)
);

INSERT INTO etudiants (nom, ville) VALUES
    ('Bryan', 'Nantes'),
    ('Lucas', 'Paris'),
    ('Emma', 'Lyon');
