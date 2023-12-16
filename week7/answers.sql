-- Create your tables, views, functions and procedures here!
CREATE SCHEMA destruction;
USE destruction;

CREATE TABLE players
(
  player_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(30),
  last_name VARCHAR(30),
  email VARCHAR(30)
);

CREATE TABLE characters 
(
    character_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    player_id INT,
    name VARCHAR(255),
    level INT,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);

CREATE TABLE winners 
(
    character_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE character_stats 
(
    character_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    health INT,
    armor INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE teams 
(
    team_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(255)
);

CREATE TABLE team_members 
(
    team_member_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    team_id INT,
    character_id INT,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (character_id) REFERENCES characters(character_id)
);

CREATE TABLE items 
(
    item_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    name VARCHAR(255),
    armor INT,
    damage INT
);

CREATE TABLE inventory 
(
    inventory_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

CREATE TABLE equipped 
(
    equipped_id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
    character_id INT,
    item_id INT,
    FOREIGN KEY (character_id) REFERENCES characters(character_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

-- I'm trying to be as verbose as I can with JOINs
-- Additionally, I like to indent like this so that only statements
-- that are related to each other go in the same line
CREATE VIEW character_items AS
SELECT 
    c.character_id,
    c.name AS character_name, -- you told me to alias these a few weeks ago
    i.name AS item_name,
    i.armor,
    i.damage
FROM 
    characters AS c
INNER JOIN 
    inventory AS inv ON c.character_id = inv.character_id -- not sure if this is correct
INNER JOIN                                                -- UPDATE: It wasn't XD
    items AS i ON inv.item_id = i.item_id
UNION
SELECT 
    c.character_id,
    c.name AS character_name,
    i.name AS item_name,
    i.armor,
    i.damage
FROM 
    characters AS c
INNER JOIN 
    equipped AS e ON c.character_id = e.character_id
INNER JOIN 
    items AS i ON e.item_id = i.item_id -- this is where it should allow the view
ORDER BY item_name;


-- basically rinse repeat but for all of them in a team
CREATE VIEW team_items AS
SELECT 
    t.team_id,
    t.name AS team_name,
    i.name AS item_name,
    i.armor,
    i.damage
FROM 
    teams t
INNER JOIN 
    team_members tm ON t.team_id = tm.team_id -- didn't know what else to call tm
INNER JOIN 
    characters c ON tm.character_id = c.character_id
INNER JOIN 
    inventory inv ON c.character_id = inv.character_id
INNER JOIN 
    items i ON inv.item_id = i.item_id
UNION
SELECT 
    t.team_id,
    t.name AS team_name,
    i.name AS item_name,
    i.armor,
    i.damage
FROM 
    teams t
INNER JOIN 
    team_members tm ON t.team_id = tm.team_id
INNER JOIN 
    characters c ON tm.character_id = c.character_id
INNER JOIN 
    equipped e ON c.character_id = e.character_id
INNER JOIN 
    items i ON e.item_id = i.item_id;

DELIMITER ;; -- I didn't know these delimeters could be set to be anything :-)
CREATE FUNCTION armor_total(character_id INT) RETURNS INT
DETERMINISTIC -- UPDATE - Github complained about this missing 
BEGIN
    DECLARE total_armor INT; -- I still struggle with when is it that vars need an @ symbol 
			     -- before the declaration... I think they dont when they're local

    SELECT SUM(i.armor) INTO total_armor
    FROM equipped e
    INNER JOIN items i ON e.item_id = i.item_id
    WHERE e.character_id = character_id;

    RETURN total_armor;
END ;;
DELIMITER ;

DELIMITER ;; 
CREATE PROCEDURE attack(IN id_of_character_being_attacked INT, IN id_of_equipped_item_used_for_attack INT)
BEGIN
    DECLARE armor INT;
    DECLARE damage INT;
    DECLARE health INT;

    -- armor of character being attacked
    SET armor = armor_total(id_of_character_being_attacked);

    -- damage of item used to attack
    SELECT damage INTO damage FROM items WHERE item_id = id_of_equipped_item_used_for_attack;

    -- calc the damage
    SET damage = damage - armor; -- substracting armor from damage
    IF damage < 0 THEN
        SET damage = 0; -- this is assuming we don't care about the durability of the armor
    END IF;				      -- or it regenerates on it's onw like in Call of Duty	

    -- set the health
    SELECT health INTO health FROM character_stats WHERE character_id = id_of_character_being_attacked;

    -- Sub the damage
    SET health = health - damage; -- I'm comparing health with the damage from before

	-- now we update the health or delete the poor victim of database violence 
    IF health > 0 THEN
        UPDATE character_stats SET health = health WHERE character_id = id_of_character_being_attacked;
    ELSE
        DELETE FROM character_stats WHERE character_id = id_of_character_being_attacked;
        DELETE FROM characters WHERE character_id = id_of_character_being_attacked; -- He's dead! T_T
        DELETE FROM inventory WHERE character_id = id_of_character_being_attacked;
        DELETE FROM equipped WHERE character_id = id_of_character_being_attacked;
        DELETE FROM team_members WHERE character_id = id_of_character_being_attacked;
    END IF;
END ;;
DELIMITER ;

DELIMITER ;;
CREATE PROCEDURE equip(IN inventory_id INT)
BEGIN
    DECLARE character_id INT;
    DECLARE item_id INT;

    -- getting id's from the inventory... Final Fantasy didn't work like I thought it did
SELECT character_id, item_id INTO character_id, item_id 
    FROM inventory AS inv 
    WHERE inv.inventory_id = inventory_id; -- I aliased this because it was confusing me too much
										                       -- and the hamster complained
    -- del from inventory
    DELETE FROM inventory AS inv 
    WHERE inv.inventory_id = inventory_id;

    -- Insert the item into the equipped table
    INSERT INTO equipped (character_id, item_id) VALUES (character_id, item_id);
END ;;
DELIMITER ;

DELIMITER ;;
CREATE PROCEDURE unequip(IN equipped_id INT)
BEGIN
    DECLARE character_id INT;
    DECLARE item_id INT;

    -- find id's from equipped table
    SELECT character_id, item_id INTO character_id, item_id 
    FROM equipped AS eqp 
    WHERE eqp.equipped_id = equipped_id;

    -- Delete item
    DELETE FROM equipped AS eqp 
    WHERE eqp.equipped_id = equipped_id;

    -- Insert to inventory
    INSERT INTO inventory (character_id, item_id) 
    VALUES (character_id, item_id);
END ;;
DELIMITER ;

DELIMITER ;; -- I think this is what you meant in canvas(Update the winners 
			 -- table so that only the characters in the passed team on in the winners table.)
CREATE PROCEDURE set_winners(IN team_id INT)
BEGIN
    -- Delete the whole stuff in here
    DELETE FROM winners;

    -- Insert from the team passed as argument to winners... This is what I understood you wanted
    INSERT INTO winners (character_id, name)
    SELECT c.character_id, c.name
    FROM characters AS c
    INNER JOIN team_members AS tm ON c.character_id = tm.character_id
    WHERE tm.team_id = team_id;
END ;;
DELIMITER ;

