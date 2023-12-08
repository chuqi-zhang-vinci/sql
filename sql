DROP SCHEMA IF EXISTS projet CASCADE;
CREATE SCHEMA projet;

CREATE TYPE projet.semestre AS ENUM ('q1', 'q2');
CREATE TYPE projet.etat_offre AS ENUM ('non validée', 'validée', 'attribuée', 'annulée');
CREATE TYPE projet.etat_candidature AS ENUM ('en attente', 'acceptée', 'refusée', 'annulée');


CREATE TABLE projet.etudiants
(
    id_etudiant        SERIAL PRIMARY KEY  NOT NULL,
    nom                VARCHAR(100)        NOT NULL,
    prenom             VARCHAR(100)        NOT NULL,
    adresse_mail       VARCHAR(100) UNIQUE NOT NULL CHECK (adresse_mail LIKE '%@student.vinci.be'),
    semestre           projet.semestre     NOT NULL,
    mot_de_passe       VARCHAR(100)        NOT NULL,
    nombre_candidature INT                 NOT NULL CHECK (nombre_candidature >= 0) DEFAULT (0)
);

CREATE TABLE projet.entreprises
(
    id_entreprise SERIAL PRIMARY KEY NOT NULL,
    nom           VARCHAR(100)       NOT NULL,
    adresse       VARCHAR(100)       NOT NULL,
    email         VARCHAR(100)       NOT NULL CHECK (email LIKE '%@%.%'),
    identifiant   VARCHAR(3) UNIQUE  NOT NULL,
    mot_de_passe  VARCHAR(100)       NOT NULL
);

CREATE TABLE projet.mot_cles
(
    id_mot_cle SERIAL PRIMARY KEY  NOT NULL,
    intitule   VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE projet.offre_stages
(
    id_offre    SERIAL PRIMARY KEY NOT NULL,
    etat        projet.etat_offre  NOT NULL DEFAULT ('non validée'),
    entreprise  INT                NOT NULL,
    FOREIGN KEY (entreprise) REFERENCES projet.entreprises (id_entreprise),
    code        VARCHAR(30) UNIQUE NOT NULL,
    semestre    projet.semestre    NOT NULL,
    description VARCHAR(200)       NULL,
    is_visible  BOOLEAN            NOT NULL DEFAULT (FALSE)
);

CREATE TABLE projet.mot_cle_offres
(
    id_mot_cle_offre SERIAL PRIMARY KEY NOT NULL,
    mot_cle          INT                NOT NULL,
    FOREIGN KEY (mot_cle) REFERENCES projet.mot_cles (id_mot_cle),
    offre            INT                NOT NULL,
    FOREIGN KEY (offre) REFERENCES projet.offre_stages (id_offre)
);

CREATE TABLE projet.candidatures
(
    id_candidature SERIAL PRIMARY KEY      NOT NULL,
    etat           projet.etat_candidature NOT NULL DEFAULT ('en attente'),
    etudiant       INT                     NOT NULL,
    FOREIGN KEY (etudiant) REFERENCES projet.Etudiants (id_etudiant),
    offre          INT                     NOT NULL,
    FOREIGN KEY (offre) REFERENCES projet.offre_stages (id_offre),
    motivation     VARCHAR(200)            NOT NULL
);

CREATE OR REPLACE FUNCTION check_uppercase_three_letters()
    RETURNS TRIGGER AS
$$
BEGIN
    IF LENGTH(NEW.identifiant) = 3 AND NEW.identifiant ~ '^[A-Z]{3}$' THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'La valeur de your_column doit être composée de 3 lettres majuscules';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger
    BEFORE INSERT
    ON projet.entreprises
    FOR EACH ROW
    EXECUTE PROCEDURE check_uppercase_three_letters();

CREATE OR REPLACE FUNCTION check_poser_candidatures()
    RETURNS TRIGGER AS
$$
BEGIN
    /* Il ne peut poser de candidature s’il a déjà une
    candidature acceptée, s’il a déjà posé sa candidature pour cette offre, si l’offre n’est
    pas dans l’état validée ou si l’offre ne correspond pas au bon semestre. */

    IF (SELECT ca.offre FROM projet.candidatures ca WHERE NEW.etudiant = ca.etudiant) IN (NEW.offre) THEN
        RAISE EXCEPTION 'Il y a déjà une candidature pour cette offre';
    END IF;

    IF (SELECT os.etat FROM projet.offre_stages os WHERE NEW.offre = os.id_offre) NOT IN ('validée') THEN
        RAISE EXCEPTION 'On ne peut pas poser de candidature pour une offre non validée';
    END IF;

    IF (SELECT et.semestre FROM projet.etudiants et WHERE NEW.etudiant = et.id_etudiant) NOT IN
       (SELECT os.semestre FROM projet.offre_stages os WHERE NEW.offre = os.id_offre) THEN
        RAISE EXCEPTION 'Semestre étudiant ne correspond pas au semestre de l offre';
    END IF;

    IF (SELECT ca.etat FROM projet.candidatures ca WHERE NEW.etudiant = ca.etudiant) IN ('acceptée') THEN
        RAISE EXCEPTION 'Il y a déjà une candidature acceptée';
    END IF;

    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_poser_candidatures
    BEFORE INSERT
    ON projet.candidatures
    FOR EACH ROW
EXECUTE PROCEDURE check_poser_candidatures();

/**2. offre stage attribuée -> offre passe à l'état "attribuée", autres offres devient "annulée"
pour cette entreprise et ce semestre et candidatures étudiant passe à "accepté",
candidatures d'autres étudiants passent à "refusée" pour cet entreprise et ce semestre,
autres candidatures de l'étudiant sélectionné passe à "annulée"*/
CREATE OR REPLACE FUNCTION check_candidatures()
    RETURNS TRIGGER AS
$$
BEGIN
    /* Il ne peut poser de candidature s’il a déjà une
    candidature acceptée, s’il a déjà posé sa candidature pour cette offre, si l’offre n’est
    pas dans l’état validée ou si l’offre ne correspond pas au bon semestre. */


    IF (NEW.etat == 'annulée') THEN
        -- Vérifier si l'offre est dans un état qui permet l'annulation
        IF (SELECT os.etat
            FROM projet.candidatures ca,
                 projet.offre_stages os
            WHERE os.id_offre = NEW.offre) NOT IN ('attribuée') THEN
            RAISE EXCEPTION 'offre pas attribuée';
        END IF;
        IF (SELECT ca.etat FROM projet.candidatures ca WHERE ca.id_candidature = NEW.id_candidature) NOT IN
           ('acceptée') THEN
            RAISE EXCEPTION 'candidature pas acceptée';
        END IF;
    END IF;

    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_candidatures
    BEFORE UPDATE
    ON projet.candidatures
    FOR EACH ROW
EXECUTE PROCEDURE check_candidatures();

--10.annuler une offre : échoue si pas à l'entreprise, si pas attribuée ou si déjà annulée. si l'annulation réussi : toute les candidaures en attentes de cette offre sont annulées
CREATE OR REPLACE FUNCTION check_offres_stage()
    RETURNS TRIGGER AS
$$
BEGIN
    IF (NEW.etat IN ('validée')) THEN
        IF (OLD.etat IN ('validée', 'attribuée', 'annulée')) THEN
            RAISE EXCEPTION 'tentative de valider une offre autre que validée';
        END IF;
    END IF;

    -- Vérifier si l'offre est dans un état qui ne permet pas l'annulation
    IF (SELECT os.etat FROM projet.offre_stages os WHERE os.id_offre = NEW.id_offre) NOT IN ('attribuée') THEN
        RAISE EXCEPTION 'UPDATE invalide';
    END IF;

    -- changer l'état des candidatures
    UPDATE projet.candidatures
    SET etat = 'annulée'
    WHERE offre = NEW.id_offre;

    RETURN NEW;

END
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_offres_stage
    BEFORE UPDATE
    ON projet.offre_stages
    FOR EACH ROW
EXECUTE PROCEDURE check_offres_stage();

/* 6.une offre de stage peut avoir max 3 mots-cles qui sont dans la liste des mots-cles */
/* 7.pas possible d'ajouter un mot-cle si l'offre est attribuée ou annulée */
/* 7,5. ou si elle appartient à une autre entreprise ?????????*/
CREATE OR REPLACE FUNCTION check_mots_cles_offres()
    RETURNS TRIGGER AS
$$
BEGIN
    -- Vérifier le nombre maximum de mots-clés par offre
    IF (SELECT COUNT(mco.mot_cle) FROM projet.mot_cle_offres mco WHERE mco.offre = NEW.offre) = 3 THEN
        RAISE EXCEPTION 'Une offre ne peut avoir que trois mots-clés.';
    END IF;

    -- Vérifier l'état de l'offre
    IF (SELECT os.etat FROM projet.offre_stages os WHERE os.id_offre = NEW.offre) IN ('attribuée', 'annulée') THEN
        RAISE EXCEPTION 'Une offre ne peut pas être attribuée ou annulée.';
    END IF;

    -- Vérifier si la ligne existe déjà
    IF EXISTS(
            SELECT 1
            FROM projet.mot_cle_offres mco
            WHERE mco.offre = NEW.offre
              AND mco.mot_cle = NEW.mot_cle
        ) THEN
        RAISE EXCEPTION 'Ligne déjà existante';
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_mots_cles
    BEFORE INSERT
    ON projet.mot_cle_offres
    FOR EACH ROW
EXECUTE PROCEDURE check_mots_cles_offres();



INSERT INTO projet.entreprises (nom, adresse, email, identifiant, mot_de_passe)
VALUES ('kookle', 'avenue de microsoft 11333333', 'blabla@kookle.be', 'KOO', 'kookle123');

INSERT INTO projet.entreprises(nom, adresse, email, identifiant, mot_de_passe)
VALUES ('micrasaft', 'avenue de google 4567876', 'hehehe@micrasaft.be', 'MIC', 'micrasaft123');

INSERT INTO projet.entreprises(nom, adresse, email, identifiant, mot_de_passe)
VALUES ('pineapple', 'avenue de appel 98663432', 'pipapipo@pineapple.be', 'PIN', 'pineapple123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('crokaert', 'gabriel', 'gabriel.crokaert@student.vinci.be', 'q1', 'gc123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('nait mazi', 'mona', 'mona.naitmazi@student.vinci.be', 'q2', 'nm123');

INSERT INTO projet.etudiants(nom, prenom, adresse_mail, semestre, mot_de_passe)
VALUES ('zhang', 'chuqi', 'chuqi.zhang@student.vinci.be', 'q2', 'zc123');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Java');

INSERT INTO projet.mot_cles(intitule)
VALUES ('SQL');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Web');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Web2');

INSERT INTO projet.mot_cles(intitule)
VALUES ('Web3');


CREATE OR REPLACE FUNCTION code_offre()
    RETURNS TRIGGER AS
$$
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
    BEFORE INSERT
    ON projet.offre_stages
    FOR EACH ROW
EXECUTE PROCEDURE code_offre();

INSERT INTO projet.offre_stages(etat, entreprise, semestre, description)
VALUES ('validée', 2, 'q1', 'on cherche qqun');

INSERT INTO projet.offre_stages(etat, entreprise, semestre, description)
VALUES ('validée', 2, 'q2', 'on recrute qqun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (1, 'q1', 'on cherche qqun');

INSERT INTO projet.offre_stages(entreprise, semestre, description)
VALUES (3, 'q2', 'on cherche qqun');

INSERT INTO projet.offre_stages(etat, entreprise, semestre, description)
VALUES ('annulée', 3, 'q1', 'on cherche qqun');

INSERT INTO projet.offre_stages(etat, entreprise, semestre, description)
VALUES ('attribuée', 2, 'q2', 'on cherche qqun');

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (1, 1);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (2, 2);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (3, 3);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (3, 2);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (3, 1);

INSERT INTO projet.mot_cle_offres(mot_cle, offre)
VALUES (4, 1);

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (1, 1, 'je veux des sous');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (2, 2, 'je veux des sous');

INSERT INTO projet.candidatures(etudiant, offre, motivation)
VALUES (3, 2, 'je veux des sous');

--10.annuler une offre : échoue si pas à l'entreprise, si pas attribuée ou si déjà annulée. si l'annulation réussi : toute les candidaures en attentes de cette offre sont annulées
CREATE OR REPLACE FUNCTION entreprise_annule_offre(param_entreprise int, param_code TEXT)
    RETURNS BOOLEAN AS
$$
DECLARE
    offre_a_annuler INT;
BEGIN
    -- Récupérer l'ID de l'offre
    SELECT os.id_offre
    INTO offre_a_annuler
    FROM projet.offre_stages os
    WHERE os.code = param_code;

    IF (SELECT os.etat
        FROM projet.offre_stages os
        WHERE os.code = param_code) == 'non validée' && (SELECT os.entreprise
                                                         FROM projet.offre_stages os
                                                         WHERE os.code = param_code) == param_entreprise THEN
        UPDATE projet.offre_stages
        SET etat       = 'annulée',
            is_visible = FALSE
        WHERE projet.offre_stages.code = param_code;

        UPDATE projet.candidatures
        SET etat = 'annulée'
        WHERE projet.candidatures.offre = offre_a_annuler;
    END IF;
    RETURN TRUE;
END
$$ LANGUAGE plpgsql;

--1. professeur valide -> offre passe à l'état "validé", offre devient "visible" aux étudiants
--1. professeur valide -> offre passe à l'état "validé", offre devient "visible" aux étudiants
/*CREATE OR REPLACE FUNCTION prof_valide_offre(param_code TEXT)
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

CREATE OR REPLACE FUNCTION prof_valide_offre()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.etat != 'validée' OR NEW.is_visible != TRUE THEN
        RAISE EXCEPTION 'le prof nas pas reussi a valide loffre';
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER prof_valide_offre_trigger
BEFORE UPDATE ON projet.offre_stages
FOR EACH ROW EXECUTE FUNCTION prof_valide_offre();

-- test check_offres_stage()

UPDATE projet.offre_stages SET etat = 'attribuée' where id_offre = 1;

UPDATE projet.offre_stages SET etat = 'annulée' where id_offre = 1;

/**2. offre stage attribuée -> offre passe à l'état "attribuée", autres offres devient "annulée"
pour cette entreprise et ce semestre et candidatures étudiant passe à "accepté",
candidatures d'autres étudiants passent à "refusée" pour cet entreprise et ce semestre,
autres candidatures de l'étudiant sélectionné passe à "annulée"*/*/

CREATE OR REPLACE FUNCTION entreprise_attribue_offre(param_etudiant_mail TEXT, param_code TEXT, param_entreprise INT)
    RETURNS BOOLEAN AS
$$
DECLARE
    offre_a_attribuer INT;
    etudiant_concerne INT;
    semestre_concerne TEXT;
BEGIN
    -- Récupérer l'ID de l'offre
    SELECT os.id_offre
    INTO offre_a_attribuer
    FROM projet.offre_stages os
    WHERE os.code = param_code;

    -- Récupérer l'ID de l'étudiant
    SELECT et.id_etudiant
    INTO etudiant_concerne
    FROM projet.etudiants et
    WHERE et.adresse_mail = param_etudiant_mail;

    --Récupérer le semestre
    SELECT os.semestre
    INTO semestre_concerne
    FROM projet.offre_stages os
    WHERE os.code = param_code;

    IF (SELECT os.etat
        FROM projet.offre_stages os
        WHERE os.code = param_code) NOT IN ('validée') ||
       (SELECT c.etat FROM projet.candidatures c WHERE c.etudiant = etudiant_concerne) NOT IN ('en attente') ||
       (SELECT os.entreprise
        FROM projet.offre_stages os
        WHERE os.code = param_code) == param_entreprise
    THEN
        RAISE EXCEPTION 'Pas possible de faire cette attribution';
    END IF;

    UPDATE projet.offre_stages
    SET etat = 'attribuée'
    WHERE projet.candidatures.offre = offre_a_attribuer;

    UPDATE projet.candidatures
    SET etat = 'acceptée'
    WHERE projet.candidatures.etudiant = etudiant_concerne
      AND projet.offre_stages.id_offre = offre_a_attribuer;

    UPDATE projet.candidatures
    SET etat = 'refusée'
    WHERE projet.candidatures.etudiant = etudiant_concerne
      AND projet.offre_stages.id_offre != offre_a_attribuer;

    UPDATE projet.offre_stages
    SET etat = 'annulée'
    WHERE projet.offre_stages.entreprise = param_entreprise
      AND projet.offre_stages.id_offre != offre_a_attribuer
      AND projet.offre_stages.semestre = semestre_concerne;

    UPDATE projet.candidatures
    SET etat = 'refusée'
    WHERE projet.candidatures.offre IN (SELECT os.id_offre
                                        FROM projet.offre_stages os
                                        WHERE os.entreprise = param_entreprise
                                          AND os.id_offre != offre_a_attribuer
                                          AND os.semestre = semestre_concerne);

    RETURN TRUE;
END
$$ LANGUAGE plpgsql;

--application professeur

/* 1. Encoder un étudiant : le professeur devra encoder son nom, son prénom, son adresse
mail (se terminant par @student.vinci.be) et le semestre pendant lequel il fera son
stage (Q1 ou Q2). Il choisira également un mot de passe pour l’étudiant. Ce mot de
passe sera communiqué à l’étudiant par mail. */

CREATE OR REPLACE FUNCTION projet.encoder_etudiant(param_nom TEXT, param_prenom TEXT, param_mail TEXT,
                                                   param_semestre CHAR(2), param_mdp TEXT)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO projet.etudiants (nom, prenom, adresse_mail, semestre, mot_de_passe)
    VALUES (param_nom, param_prenom, param_mail, param_semestre::projet.semestre, param_mdp);
END
$$ LANGUAGE plpgsql;


/* 2. Encoder une entreprise : le professeur devra encoder le nom de l’entreprise, son
adresse (une seule chaîne de caractère) et son adresse mail. Il choisira pour l’entreprise
un identifiant composé de 3 lettres majuscules (par exemple « VIN » pour l’entreprise
Vinci). Il choisira également un mot de passe pour l’entreprise. Ce mot de passe sera
communiqué à l’entreprise par mail. */

CREATE OR REPLACE FUNCTION encoder_entreprises(param_nom TEXT, param_adressse TEXT, param_mail TEXT,
                                               param_identifiant TEXT, param_mdp TEXT)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO projet.entreprises (nom, adresse, email, identifiant, mot_de_passe)
    VALUES (param_nom, param_adressse, param_mail, param_identifiant, param_mdp);
END
$$ LANGUAGE plpgsql;

/* 3. Encoder un mot-clé que les entreprises pourront utiliser pour décrire leur stage. Par
exemple « Java », « SQL » ou « Web ». L’encodage échouera si le mot clé est déjà
présent. */

CREATE OR REPLACE FUNCTION encoder_mot_cle(param_mot TEXT)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO projet.mot_cles (intitule) VALUES (param_mot);
END
$$ LANGUAGE plpgsql;

/* 4. Voir les offres de stage dans l’état « non validée ». Pour chaque offre, on affichera son
code, son semestre, le nom de l’entreprise et sa description. */

CREATE VIEW offres_non_validees AS
SELECT os.code, os.semestre, en.nom, os.description
FROM projet.offre_stages os,
     projet.entreprises en
WHERE os.entreprise = en.id_entreprise
  AND os.etat = 'non validée';

/* 5. Valider une offre de stage en donnant son code. On ne pourra valider que des offres
de stages « non validée ». */

CREATE OR REPLACE FUNCTION valider_offre(param_code TEXT)
    RETURNS VOID AS
$$
BEGIN
    UPDATE projet.offre_stages SET etat = 'validée', is_visible = true WHERE code = param_code;
END
$$ LANGUAGE plpgsql;

/* 6. Voir les offres de stage dans l’état « validée ». Même affichage qu’au point 4.*/

CREATE VIEW offres_validees AS
SELECT os.code, os.semestre, en.nom, os.description
FROM projet.offre_stages os,
     projet.entreprises en
WHERE os.entreprise = en.id_entreprise
  AND os.etat = 'validée';

/* 7. Voir les étudiants qui n’ont pas de stage (pas de candidature à l’état « acceptée »).
Pour chaque étudiant, on affichera son nom, son prénom, son email, le semestre où il
fera son stage et le nombre de ses candidatures en attente. */

CREATE VIEW etudiants_sans_stage AS
SELECT DISTINCT et.nom, et.prenom, et.adresse_mail, et.semestre, et.nombre_candidature
FROM projet.etudiants et,
     projet.candidatures ca
WHERE et.id_etudiant = ca.etudiant
  AND ca.etat != 'acceptée';

/* 8. Voir les offres de stage dans l’état « attribuée ». Pour chaque offre, on affichera son
code, le nom de l’entreprise ainsi que le nom et le prénom de l’étudiant qui le fera. */

CREATE VIEW offres_attribuees AS
SELECT os.code, en.nom AS nom_entreprise, et.nom AS nom_etudiant, et.prenom
FROM projet.offre_stages os,
     projet.entreprises en,
     projet.candidatures ca,
     projet.etudiants et
WHERE os.entreprise = en.id_entreprise
  AND os.id_offre = ca.offre
  AND ca.etudiant = et.id_etudiant
  AND os.etat = 'attribuée';

-- application étudiante

/* 1. Voir toutes les offres de stage dans l’état « validée » correspondant au semestre où
l’étudiant fera son stage. Pour une offre de stage, on affichera son code, le nom de
l’entreprise, son adresse, sa description et les mots-clés (séparés par des virgules sur
une même ligne). */

CREATE VIEW projet.offres_validees_etudiant AS
SELECT DISTINCT os.code, en.nom, en.adresse, mc.intitule, os.semestre :: VARCHAR(2)
FROM projet.offre_stages os,
     projet.entreprises en,
     projet.candidatures ca,
     projet.mot_cle_offres mco,
     projet.mot_cles mc
WHERE os.id_offre = mco.offre
  AND mco.mot_cle = mc.id_mot_cle
  AND os.entreprise = en.id_entreprise
  AND os.id_offre = ca.offre
  AND os.etat = 'validée';

/* 2. Recherche d’une offre de stage par mot clé. Cette recherche n’affichera que les offres
de stages validées et correspondant au semestre où l’étudiant fera son stage. Les
offres de stage seront affichées comme au point précédent. */

CREATE OR REPLACE VIEW projet.offres_par_mot_cles AS
SELECT DISTINCT os.code, en.nom, en.adresse, mc.intitule, os.semestre::VARCHAR(2)
FROM projet.offre_stages os,
     projet.entreprises en,
     projet.candidatures ca,
     projet.mot_cle_offres mco,
     projet.mot_cles mc
WHERE os.id_offre = mco.offre
  AND mco.mot_cle = mc.id_mot_cle
  AND os.entreprise = en.id_entreprise
  AND os.id_offre = ca.offre
  AND os.etat = 'validée';

/* 3. Poser sa candidature. Pour cela, il doit donner le code de l’offre de stage et donner ses
motivations sous format textuel. Il ne peut poser de candidature s’il a déjà une
candidature acceptée, s’il a déjà posé sa candidature pour cette offre, si l’offre n’est
pas dans l’état validée ou si l’offre ne correspond pas au bon semestre. */

CREATE OR REPLACE FUNCTION poser_candidature(param_code TEXT, param_motivation TEXT, param_etudiant INT)
    RETURNS VOID AS
$$
DECLARE
    offre_id INT;
BEGIN
    -- Récupérer l'ID de l'offre
    SELECT os.id_offre
    INTO offre_id
    FROM projet.offre_stages os
    WHERE os.code = param_code;

    INSERT INTO projet.candidatures(etudiant, offre, motivation) VALUES (param_etudiant, offre_id, param_motivation);
END
$$ LANGUAGE plpgsql;

/* 4. Voir les offres de stage pour lesquels l’étudiant a posé sa candidature. Pour chaque
offre, on verra le code de l’offre, le nom de l’entreprise ainsi que l’état de sa
candidature. */

CREATE OR REPLACE VIEW projet.offres_avec_candidature AS
SELECT os.code, en.nom, en.adresse, ca.etat, ca.etudiant
FROM projet.offre_stages os,
     projet.entreprises en,
     projet.candidatures ca
WHERE os.entreprise = en.id_entreprise
  AND os.id_offre = ca.offre;

/* 5. Annuler une candidature en précisant le code de l’offre de stage. Les candidatures ne
peuvent être annulées que si elles sont « en attente ». */

CREATE OR REPLACE FUNCTION annuler_candidature(param_code TEXT, param_etudiant INT)
    RETURNS VOID AS
$$
DECLARE
    offre_id INT;
BEGIN
    -- Récupérer l'ID de l'offre
    SELECT os.id_offre
    INTO offre_id
    FROM projet.offre_stages os
    WHERE os.code = param_code;

    UPDATE projet.candidatures SET etat = 'annulée' where offre_id = offre AND param_etudiant = etudiant;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION authentifier_etudiant(_identifiant TEXT, _mot_de_passe TEXT)
    RETURNS INT AS
$$
DECLARE
    _id_etudiant INT;
BEGIN
    IF (SELECT e.mot_de_passe
        FROM projet.etudiants e
        WHERE e.adresse_mail = _identifiant) = _mot_de_passe THEN
        _id_etudiant = (SELECT e2.id_etudiant
                        FROM projet.etudiants e2
                        WHERE e2.adresse_mail = _identifiant);
        RETURN _id_etudiant;
    ELSE
        RETURN -1;
    END IF;
END;
$$ language plpgsql;

--application entreprise

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
            WHERE os3.id_offre = __code) != _id_entreprise
            THEN
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
                                                                                                                WHERE ca.etudiant = _id_etudiant AND ca.offre = _id_offre) != 'en attente' OR _code NOT LIKE '????%'

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

        UPDATE projet.offre_stages os5
        SET etat = 'annulée'
        WHERE os5.id_offre = _id_offre;
    END IF;
END;
$$ language plpgsql;

--GRANT pour la DB et le schéma
GRANT CONNECT ON DATABASE postgres TO gabrielcrokaert, monanaitmazi;
GRANT USAGE ON SCHEMA projet TO gabrielcrokaert, monanaitmazi;

--GRANT pour gabrielcrokaert (entreprise)
GRANT SELECT ON projet.offre_stages, projet.mot_cles, projet.mot_cle_offres, projet.candidatures, projet.etudiants, projet.entreprises, projet.mots_cle_disponible, projet.vue_offres_stages TO gabrielcrokaert;
GRANT UPDATE ON projet.offre_stages, projet.candidatures TO gabrielcrokaert;
GRANT INSERT ON projet.offre_stages, projet.mot_cle_offres TO gabrielcrokaert;

--GRANT pour monanaitmazi (étudiant)
GRANT SELECT ON  projet.etudiants, projet.entreprises, projet.offre_stages, projet.mot_cle_offres, projet.mot_cles, projet.candidatures, projet.offres_validees_etudiant, projet.offres_par_mot_cles, projet.offres_avec_candidature TO monanaitmazi;
GRANT UPDATE ON projet.candidatures TO monanaitmazi;
GRANT INSERT ON projet.candidatures TO monanaitmazi;
