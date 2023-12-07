DROP SCHEMA IF EXISTS projet CASCADE;
CREATE SCHEMA projet;

CREATE TYPE projet.semestre AS ENUM ('q1', 'q2');
CREATE TYPE projet.etat_offre AS ENUM ('non validée', 'validée', 'attribuée', 'annulée');
CREATE TYPE projet.etat_candidature AS ENUM ('en attente', 'acceptée', 'refusée', 'annulée');


CREATE TABLE projet.etudiants (
    id_etudiant SERIAL PRIMARY KEY NOT NULL,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    adresse_mail VARCHAR(100) NOT NULL CHECK (adresse_mail LIKE '%@student.vinci.be'),
    semestre projet.semestre NOT NULL,
    mot_de_passe VARCHAR(100) NOT NULL,
    nombre_candidature INT NOT NULL CHECK (nombre_candidature >= 0) DEFAULT (0)
);

CREATE TABLE projet.entreprises (
    id_entreprise SERIAL PRIMARY KEY NOT NULL,
    nom VARCHAR(100) NOT NULL,
    adresse VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL CHECK (email LIKE '%@%.%'),
    identifiant VARCHAR(3) UNIQUE NOT NULL,
    mot_de_passe VARCHAR(100) NOT NULL
);

CREATE TABLE projet.mot_cles (
    id_mot_cle SERIAL PRIMARY KEY NOT NULL,
    intitule VARCHAR(100) NOT NULL
);

CREATE TABLE projet.offre_stages (
    id_offre SERIAL PRIMARY KEY NOT NULL,
    etat projet.etat_offre NOT NULL DEFAULT ('non validée'),
    entreprise INT NOT NULL,
    FOREIGN KEY (entreprise) REFERENCES projet.entreprises(id_entreprise),
    code VARCHAR(30) UNIQUE NOT NULL,
    semestre projet.semestre NOT NULL,
    description VARCHAR(200) NULL,
    is_visible BOOLEAN NOT NULL DEFAULT (FALSE)
);

CREATE TABLE projet.mot_cle_offres (
    id_mot_cle_offre SERIAL PRIMARY KEY NOT NULL,
    mot_cle INT NOT NULL,
    FOREIGN KEY (mot_cle) REFERENCES projet.mot_cles(id_mot_cle),
    offre INT NOT NULL,
    FOREIGN KEY (offre) REFERENCES projet.offre_stages(id_offre)
);

CREATE TABLE projet.candidatures (
    id_candidature SERIAL PRIMARY KEY NOT NULL,
    etat projet.etat_candidature NOT NULL DEFAULT ('en attente'),
    etudiant INT NOT NULL,
    FOREIGN KEY (etudiant) REFERENCES projet.Etudiants(id_etudiant),
    offre INT NOT NULL,
    FOREIGN KEY (offre) REFERENCES projet.offre_stages(id_offre),
    motivation VARCHAR(200) NOT NULL
);

CREATE OR REPLACE FUNCTION check_uppercase_three_letters()
RETURNS TRIGGER AS $$
BEGIN
    IF LENGTH(NEW.identifiant) = 3 AND NEW.identifiant ~ '^[A-Z]{3}$' THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'La valeur de your_column doit être composée de 3 lettres majuscules';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger
BEFORE INSERT ON projet.entreprises
FOR EACH ROW
EXECUTE FUNCTION check_uppercase_three_letters();



INSERT INTO projet.entreprises (nom, adresse, email, identifiant, mot_de_passe)
VALUES ('kookle', 'avenue de microsoft 11333333', 'blabla@kookle.be', 'KOO', 'kookle123');

INSERT INTO projet.entreprises(nom, adresse, email, identifiant, mot_de_passe)
VALUES ('micrasaft', 'avenue de google 4567876', 'hehehe@micrasaft.be', 'MIC', 'micrasaft123');

INSERT INTO projet.entreprises(nom, adresse, email, identifiant, mot_de_passe)
VALUES ('pineapple', 'avenue de appel 98663432', 'pipapipo@pineapple.be', 'PIN', 'pineapple123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('crokaert', 'gabriel', 'gabriel.crokaert@student.vinci.be', 'q1', 'gc123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('nait mazi', 'mona', 'mona.naitmazi@student.vinci.be', 'q1', 'nm123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('zhang', 'chuqi', 'chuqi.zhang@student.vinci.be', 'q2', 'zc123');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Java');

INSERT INTO projet.mot_cles(intitule)
VALUES ('SQL');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Web');



CREATE OR REPLACE FUNCTION code_offre_normal(_id_entreprise INT)
RETURNS TEXT AS $$
DECLARE
    code TEXT;
BEGIN
    code =
    (SELECT e.identifiant || 1 + (SELECT COUNT(*)
                               FROM projet.offre_stages o
                               WHERE o.entreprise = _id_entreprise)
    FROM projet.entreprises e
    WHERE e.id_entreprise = _id_entreprise);
    RETURN code;
END;
$$ language plpgsql;







CREATE OR REPLACE FUNCTION code_offre()
RETURNS TRIGGER AS $$
BEGIN
  NEW.code := (SELECT e.identifiant
               FROM projet.entreprises e
               WHERE e.id_entreprise = NEW.entreprise) || 1 + (SELECT COUNT(*)
                                                               FROM projet.offre_stages o
                                                               WHERE o.entreprise = NEW.entreprise);
  RETURN NEW;
END
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger
BEFORE INSERT ON projet.offre_stages
FOR EACH ROW
EXECUTE FUNCTION code_offre();




INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (2, 'q1', 'on cherche qqun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (2, 'q2', 'on recrute qqun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (1, 'q1', 'on cherche qqun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (2, 'q1', 'on recherche quelquun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (3, 'q2', 'on cherche qqun');

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (1, 1);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (2, 2);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (3, 3);

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (1, 1, 'je veux des sous');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (2, 2, 'je veux des sous');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (3, 3, 'je veux des sous');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (2, 1, 'je veux être riche');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (1, 3, 'je suis pauvre');




--1. professeur valide -> offre passe à l'état "validé", offre devient "visible" aux étudiants
CREATE OR REPLACE FUNCTION prof_valide_offre(param_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT os.etat
         FROM projet.offre_stages os
         WHERE os.code = param_code)!='validée' THEN
            UPDATE projet.offre_stages
            SET etat = 'validée', is_visible = TRUE
            WHERE projet.offre_stages.code = param_code;
    END IF;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION crypted_entreprise_pw(pw TEXT, _id_entreprise INT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO projet.entreprises(mot_de_passe)
    VALUES (pw);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION maximum_mots_cles()
RETURNS TRIGGER AS $$
BEGIN
    -- Vérifier le nombre maximum de mots-clés par offre
    IF (SELECT COUNT(mco.mot_cle) FROM projet.mot_cle_offres mco WHERE mco.offre = NEW.offre) = 3 THEN
        RAISE EXCEPTION 'Une offre ne peut avoir que trois mots-clés.';
    END IF;

    -- Vérifier l'état de l'offre
    IF (SELECT os.etat FROM projet.offre_stages os WHERE os.id_offre = NEW.offre) IN ('attribuée', 'annulée') THEN
        RAISE EXCEPTION 'Une offre ne peut pas être attribuée ou annulée.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_maximum_mots_cles
BEFORE INSERT ON projet.mot_cle_offres
FOR EACH ROW EXECUTE FUNCTION maximum_mots_cles();





CREATE VIEW offres_validees AS
SELECT os.code, en.nom, en.adresse, mc.intitule
FROM projet.offre_stages os, projet.entreprises en, projet.candidatures ca, projet.etudiants et, projet.mot_cle_offres mco, projet.mot_cles mc
WHERE os.id_offre = mco.offre
AND mco.mot_cle = mc.id_mot_cle
AND os.entreprise = en.id_entreprise
AND os.id_offre = ca.offre
AND ca.etudiant = et.id_etudiant
AND os.semestre = et.semestre
AND os.etat = 'validée';


SELECT * FROM offres_validees;








CREATE OR REPLACE FUNCTION authentifier_entreprise(_identifiant TEXT, _mot_de_passe TEXT)
RETURNS INT AS $$
DECLARE
    _id_entreprise INT;
BEGIN
    IF(SELECT e.mot_de_passe
        FROM projet.entreprises e
        WHERE e.identifiant = _identifiant) = _mot_de_passe THEN
            _id_entreprise = (
                SELECT e2.id_entreprise
                FROM projet.entreprises e2
                WHERE e2.identifiant = _identifiant
            );
        RETURN _id_entreprise;
    ELSE
        RETURN -1;
    END IF;
END;
$$ language plpgsql;

--appliucation entreprise
/**1.Encoder une offre de stage. Pour cela, l’entreprise devra encoder une description et le
semestre. Chaque offre de stage recevra automatiquement un code qui sera la
concaténation de l’identifiant de l’entreprise et d’un numéro. Par exemple, le premier
stage de l’entreprise Vinci ara le code « VIN1 », le deuxième « VIN2 », le dixième «
VIN10 », … Cette fonctionnalité échouera si l’entreprise a déjà une offre de stage
attribuée durant ce semestre.*/
CREATE OR REPLACE FUNCTION encoder_une_offre_stage(_id_entreprise INT, _description TEXT, _semestre CHAR(2))
RETURNS BOOLEAN AS $$
    BEGIN
        INSERT INTO projet.offre_stages(entreprise, code, semestre, description)
        VALUES (_id_entreprise, code_offre_normal(_id_entreprise), _semestre::projet.semestre, _description);
        RETURN TRUE;
    END;
$$ language plpgsql;



--2.Voir les mots-clés disponibles pour décrire une offre de stage
CREATE VIEW projet.mots_cle_disponible AS
    SELECT mc.intitule
    FROM projet.mot_cles mc;

/**3.
    Ajouter un mot-clé à une de ses offres de stage (en utilisant son code). Une offre de
    stage peut avoir au maximum 3 mots-clés. Ces mots-clés doivent faire partie de la liste
    des mots-clés proposés par les professeurs. Il ne sera pas possible d'ajouter un mot-
    clé si l'offre de stage est dans l'état "attribuée" ou "annulée" ou si l’offre n’est pas une
    offre de l’entreprise.
 */
CREATE OR REPLACE FUNCTION ajouter_mot_cle_pour_une_offre(_id_entreprise INT, _code TEXT, _mot_cle TEXT)
RETURNS VOID AS $$
    DECLARE
    __code INT;
    __mot_cle INT;
    BEGIN
        __code = (SELECT os.id_offre
                    FROM projet.offre_stages os
                    WHERE os.code = _code);
        __mot_cle = (SELECT mc.id_mot_cle
                    FROM projet.mot_cles mc
                    WHERE mc.intitule = _mot_cle);
        IF (SELECT os3.entreprise
            FROM projet.offre_stages os3
            WHERE os3.id_offre = __code) != _id_entreprise THEN
            RAISE EXCEPTION 'L''entreprise ne correspond pas à l''offre %', _code;
        ELSE
            INSERT INTO projet.mot_cle_offres(mot_cle, offre)
            VALUES (__mot_cle, __code);
        END IF;
    END;
$$ language plpgsql;



/**
  4. Voir ses offres de stages : Pour chaque offre de stage, on affichera son code, sa
description, son semestre, son état, le nombre de candidatures en attente et le nom
de l’étudiant qui fera le stage (si l’offre a déjà été attribuée). Si l'offre de stage n'a pas
encore été attribuée, il sera indiqué "pas attribuée" à la place du nom de l'étudiant.
 */
CREATE OR REPLACE VIEW projet.vue_offres_stages AS
SELECT
    os.code AS code_offre,
    os.description AS description_offre,
    os.semestre AS semestre_offre,
    os.etat AS etat_offre,
    os.entreprise AS entreprise_offre,
    COALESCE(c.nombre_candidatures, 0) AS nombre_candidatures_en_attente,
    COALESCE(e.nom, 'Pas attribuée') AS nom_etudiant_attribue
FROM
    projet.offre_stages os
LEFT JOIN
    (
        SELECT
            offre,
            COUNT(*) AS nombre_candidatures
        FROM
            projet.candidatures
        WHERE
            etat = 'en attente'
        GROUP BY
            offre
    ) c ON os.id_offre = c.offre
LEFT JOIN
    projet.candidatures ca ON os.id_offre = ca.offre AND ca.etat = 'acceptée'
LEFT JOIN
    projet.etudiants e ON ca.etudiant = e.id_etudiant;




/**
  5. Voir les candidatures pour une de ses offres de stages en donnant son code. Pour
    chaque candidature, on affichera son état, le nom, prénom, adresse mail et les
    motivations de l’étudiant. Si le code ne correspond pas à une offre de l’entreprise ou
    qu’il n’y a pas de candidature pour cette offre, le message suivant sera affiché “Il n'y a
    pas de candidatures pour cette offre ou vous n'avez pas d'offre ayant ce code”.
 */
CREATE OR REPLACE FUNCTION voir_candidatures(_id_entreprise INT, _code TEXT)
RETURNS TABLE(etat projet.etat_candidature, nom VARCHAR, prenom VARCHAR, adresse_mail VARCHAR, motivations VARCHAR) as $$
DECLARE
    _id_offre INT;
BEGIN
    _id_offre =
    (SELECT os2.id_offre
    FROM projet.offre_stages os2
    WHERE os2.code = _code);

    IF(SELECT os.entreprise
        FROM projet.offre_stages os
        WHERE os.code = _code) != _id_entreprise OR (SELECT COUNT(*)
                                                        FROM projet.candidatures ca
                                                        WHERE ca.offre = _id_offre) = 0 THEN
        RAISE EXCEPTION 'Il n''y a pas de candidatures pour cette offre ou vous n''avez pas d''offre ayant ce code';
    ELSE
                RETURN QUERY
                (SELECT ca.etat, et.nom, et.prenom, et.adresse_mail, ca.motivation
                FROM projet.candidatures ca, projet.etudiants et
                WHERE ca.etudiant = et.id_etudiant and ca.offre = _id_offre);
    END IF;
END;
$$ language plpgsql;







--fonction pour fonction selectionner_un_etudiant_pour_une_offre()
CREATE OR REPLACE FUNCTION attribue_offre_Stage(code_offre TEXT, email_etudiant TEXT, _id_entreprise INT)
RETURNS VOID AS $$
DECLARE
    _id_offre INT;
    _id_etudiant INT;
    _semestre projet.semestre;
BEGIN
    _id_offre = (SELECT DISTINCT os.id_offre
        FROM projet.offre_stages os
        WHERE os.code = code_offre);

    _id_etudiant = (SELECT e.id_etudiant
                    FROM projet.etudiants e
                    WHERE e.adresse_mail = email_etudiant);

    _semestre = (SELECT e.semestre
                 FROM projet.etudiants e
                 WHERE e.id_etudiant = _id_etudiant);

    IF (SELECT os.etat
        FROM projet.offre_stages os
        WHERE os.code = code_offre) = 'validée' AND (SELECT e.semestre
                                                             FROM projet.etudiants e
                                                             WHERE e.id_etudiant = _id_etudiant) = _semestre  THEN
         -- Mettre à jour l'état de l'offre sélectionnée
            UPDATE projet.offre_stages os
            SET etat = 'attribuée'
            WHERE os.code = code_offre;

        -- Mettre à jour l'état des autres offres pour cette entreprise et ce semestre
        UPDATE projet.offre_stages os
        SET etat = 'annulée'
        WHERE os.entreprise = _id_entreprise AND os.semestre = _semestre AND os.code != code_offre;

        -- Mettre à jour l'état des candidatures de l'étudiant
        UPDATE projet.candidatures ca
        SET etat = 'acceptée'
        WHERE ca.etudiant = _id_etudiant AND ca.offre = _id_offre;

        -- Mettre à jour l'état des candidatures des autres étudiants pour cette entreprise et ce semestre
        UPDATE projet.candidatures ca
        SET etat = 'refusée'
        WHERE ca.offre IN (SELECT os.id_offre FROM projet.offre_stages os WHERE os.entreprise = _id_entreprise AND os.semestre = _semestre) AND ca.etudiant != _id_etudiant;

        -- Mettre à jour l'état des autres candidatures de l'étudiant sélectionné
        UPDATE projet.candidatures ca
        SET etat = 'annulée'
        WHERE ca.etudiant = _id_etudiant AND ca.offre != _id_offre;
    END IF;
END
$$ LANGUAGE plpgsql;
/**
  6. Sélectionner un étudiant pour une de ses offres de stage. Pour cela, l’entreprise devra
    donner le code de l’offre et l’adresse mail de l’étudiant. L’opération échouera si l’offre
    de stage n’est pas une offre de l’entreprise, si l’offre n’est pas dans l’état « validée »
    ou que la candidature n’est pas dans l’état « en attente ». L’état de l’offre passera à
    « attribuée ». La candidature de l’étudiant passera à l’état « acceptée ». Les autres
    candidatures en attente de cet étudiant passeront à l’état « annulée ». Les autres
    candidatures en attente d’étudiants pour cette offre passeront à « refusée ». Si
    l’entreprise avait d’autres offres de stage non annulées durant ce semestre, l’état de
    celles-ci doit passer à « annulée » et toutes les candidatures en attente de ces offres
    passeront à « refusée »
 */
CREATE OR REPLACE FUNCTION selectionner_un_etudiant_pour_une_offre(_id_entreprise INT, _code TEXT, email_etudiant TEXT)
RETURNS VOID AS $$
    DECLARE
        _id_etudiant INT;
        _id_offre INT;
BEGIN
    _id_offre = (SELECT os.id_offre
                    FROM projet.offre_stages os
                    WHERE os.code = _code);

    _id_etudiant = (SELECT et.id_etudiant
                    FROM projet.etudiants et
                    where et.adresse_mail = email_etudiant);

    IF(SELECT os2.entreprise
        FROM projet.offre_stages os2
        WHERE os2.id_offre = _id_offre) != _id_entreprise OR (SELECT os3.etat
                                                                FROM projet.offre_stages os3
                                                                WHERE os3.id_offre = _id_offre) != 'validée' OR (SELECT ca.etat
                                                                                                                FROM projet.candidatures ca
                                                                                                                WHERE ca.etudiant = _id_etudiant AND ca.offre = _id_offre) != 'en attente'

    THEN
        RAISE EXCEPTION 'erreur';
    ELSE
        PERFORM attribue_offre_Stage(_code , email_etudiant , _id_entreprise);
    END IF;
END;
$$ language plpgsql;




/**
    7.Annuler une offre de stage en donnant son code. Cette opération ne pourra être
    réalisée que si l’offre appartient bien à l’entreprise et si elle n’est pas encore attribuée,
    ni annulée. Toutes les candidatures en attente de cette offre passeront à « refusée ».
 */
CREATE OR REPLACE FUNCTION annuler_une_offre(_id_entreprise INT, _code TEXT)
RETURNS VOID AS $$
DECLARE
    _id_offre INT;
BEGIN
    _id_offre =
    (SELECT os4.id_offre
    FROM projet.offre_stages os4
    WHERE os4.code = _code);

    IF(SELECT os.entreprise
       FROM projet.offre_stages os
       WHERE os.code = _code) != _id_entreprise OR (SELECT os2.etat
                                                    FROM projet.offre_stages os2
                                                    WHERE os2.code = _code) = 'attribuée' OR (SELECT os3.etat
                                                                                              FROM projet.offre_stages os3
                                                                                              WHERE os3.code = _code) = 'annulée' THEN
        RAISE EXCEPTION 'erreur ! ';
    ELSE
        UPDATE projet.candidatures ca
        SET etat = 'refusée'
        WHERE ca.offre = _id_offre;
    END IF;
END;
$$ language plpgsql;













--SELECT prof_valide_offre('MIC1');

/**UPDATE projet.offre_stages
SET etat = 'validée'
where code = 'MIC1';*/













--1. professeur valide -> offre passe à l'état "validé", offre devient "visible" aux étudiants
/**CREATE OR REPLACE FUNCTION prof_valide_offre(param_code TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT os.etat
         FROM projet.offre_stages os
         WHERE os.code = param_code)!='validée' THEN
            UPDATE projet.offre_stages
            SET etat = 'validée', is_visible = TRUE
            WHERE projet.offre_stages.code = param_code;
    END IF;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;

SELECT prof_valide_offre('MIC1') FROM projet.offre_stages;*/


/**2. offre stage attribuée -> offre passe à l'état "attribuée", autres offres devient "annulée"
pour cette entreprise et ce semestre et candidatures étudiant passe à "accepté",
candidatures d'autres étudiants passent à "refusée" pour cet entreprise et ce semestre,
autres candidatures de l'étudiant sélectionné passe à "annulée"
CREATE OR REPLACE FUNCTION update_last_semestre() RETURNS TRIGGER AS $$
BEGIN
    NEW.semestre = OLD.semestre;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_last_semestre_trigger
BEFORE UPDATE OF semestre ON projet.etudiants
FOR EACH ROW EXECUTE FUNCTION update_last_semestre();





CREATE OR REPLACE FUNCTION update_offre_stages() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.code = code_offre THEN
        NEW.etat = 'attribuée';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_offre_stages_trigger
BEFORE UPDATE ON projet.offre_stages
FOR EACH ROW EXECUTE FUNCTION update_offre_stages();

CREATE OR REPLACE FUNCTION cancel_other_offres() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.entreprise = _id_entreprise AND NEW.semestre = _semestre AND NEW.code != code_offre THEN
        NEW.etat = 'annulée';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cancel_other_offres_trigger
BEFORE UPDATE ON projet.offre_stages
FOR EACH ROW EXECUTE FUNCTION cancel_other_offres();











SELECT attribue_offre_Stage('MIC1', 'gabriel.crokaert@student.vinci.be', 2);

/**CREATE OR REPLACE FUNCTION entrpise_annule_offre(_code_offre TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF (SELECT e.
        FROM projet.entreprises e
        WHERE
END;
$$
end;*/
