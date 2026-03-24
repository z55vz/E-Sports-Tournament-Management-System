-- ============================================
-- E-Sports Tournament Management System
-- Database Script
-- Author: Abdulrahman Ageeli
-- Description: Full database setup including tables,
-- constraints, triggers, views, and sample data
-- ============================================
-- DATABASE SETUP
DROP DATABASE IF EXISTS esports_tournament;
CREATE DATABASE esports_tournament;
USE esports_tournament;

-- TEAMS TABLE
CREATE TABLE Teams (
    Team_ID INT AUTO_INCREMENT PRIMARY KEY,
    Team_Name VARCHAR(100) NOT NULL UNIQUE,
    Creation_Date DATE CHECK (Creation_Date <= CURDATE())
) ENGINE=InnoDB;

-- GAMES TABLE
CREATE TABLE Games (
    Game_ID INT AUTO_INCREMENT PRIMARY KEY,
    Game_Name VARCHAR(100) NOT NULL UNIQUE,
    Game_Type VARCHAR(50),
    Number_of_Rounds INT NOT NULL CHECK (Number_of_Rounds IN (1,3,5,7))
) ENGINE=InnoDB;

-- TOURNAMENTS TABLE
CREATE TABLE Tournaments (
    Tournament_ID INT AUTO_INCREMENT PRIMARY KEY,
    Tournament_Name VARCHAR(150) NOT NULL,
    Start_Date DATE NOT NULL,
    Award_Pool DECIMAL(12,2) DEFAULT 0 CHECK (Award_Pool >= 0),
    Game_ID INT NOT NULL,
    
    FOREIGN KEY (Game_ID)
        REFERENCES Games(Game_ID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- PLAYERS TABLE
CREATE TABLE Players (
    Player_ID INT AUTO_INCREMENT PRIMARY KEY,
    Player_Name VARCHAR(100) NOT NULL,
    Nickname VARCHAR(60) NOT NULL UNIQUE,
    Region VARCHAR(50),
    Date_of_Birth DATE CHECK (Date_of_Birth < CURDATE()),
    Team_ID INT NOT NULL,

    FOREIGN KEY (Team_ID)
        REFERENCES Teams(Team_ID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_players_team ON Players(Team_ID);

-- MATCHES TABLE
CREATE TABLE Matches (
    Match_ID INT AUTO_INCREMENT PRIMARY KEY,
    Match_Date DATE NOT NULL,
    Score_A INT NOT NULL CHECK (Score_A >= 0),
    Score_B INT NOT NULL CHECK (Score_B >= 0),

    Tournament_ID INT NOT NULL,
    Team_A_ID INT NOT NULL,
    Team_B_ID INT NOT NULL,
    Winner_ID INT NOT NULL,

    FOREIGN KEY (Tournament_ID)
        REFERENCES Tournaments(Tournament_ID)
        ON DELETE CASCADE,

    FOREIGN KEY (Team_A_ID)
        REFERENCES Teams(Team_ID),

    FOREIGN KEY (Team_B_ID)
        REFERENCES Teams(Team_ID),

    FOREIGN KEY (Winner_ID)
        REFERENCES Teams(Team_ID),

    CHECK (Team_A_ID <> Team_B_ID),
    UNIQUE (Tournament_ID, Team_A_ID, Team_B_ID, Match_Date)
) ENGINE=InnoDB;

CREATE INDEX idx_matches_tournament ON Matches(Tournament_ID);

-- AWARDS TABLE
CREATE TABLE Awards (
    Award_ID INT AUTO_INCREMENT PRIMARY KEY,
    Award_Rank INT NOT NULL CHECK (Award_Rank >= 1),
    Amount DECIMAL(12,2) NOT NULL CHECK (Amount >= 0),

    Tournament_ID INT NOT NULL,
    Team_ID INT NOT NULL,

    FOREIGN KEY (Tournament_ID)
        REFERENCES Tournaments(Tournament_ID)
        ON DELETE CASCADE,

    FOREIGN KEY (Team_ID)
        REFERENCES Teams(Team_ID),

    UNIQUE (Tournament_ID, Award_Rank),
    UNIQUE (Tournament_ID, Team_ID)
) ENGINE=InnoDB;

-- VIEW
CREATE VIEW Match_Details AS
SELECT
    M.Match_ID,
    T.Tournament_Name,
    G.Game_Name,
    TA.Team_Name AS Team_A,
    TB.Team_Name AS Team_B,
    CONCAT(M.Score_A, '-', M.Score_B) AS Score,
    TW.Team_Name AS Winner,
    M.Match_Date
FROM Matches M
JOIN Tournaments T ON M.Tournament_ID = T.Tournament_ID
JOIN Games G ON T.Game_ID = G.Game_ID
JOIN Teams TA ON M.Team_A_ID = TA.Team_ID
JOIN Teams TB ON M.Team_B_ID = TB.Team_ID
JOIN Teams TW ON M.Winner_ID = TW.Team_ID;

-- STORED PROCEDURE
DELIMITER $$

CREATE PROCEDURE Get_Tournament_Winner(IN t_id INT)
BEGIN
    SELECT TE.Team_Name, COUNT(*) AS Wins
    FROM Matches M
    JOIN Teams TE ON M.Winner_ID = TE.Team_ID
    WHERE M.Tournament_ID = t_id
    GROUP BY TE.Team_Name
    ORDER BY Wins DESC
    LIMIT 1;
END$$

DELIMITER ;

-- TRIGGER
DELIMITER $$

CREATE TRIGGER trg_validate_match
BEFORE INSERT ON Matches
FOR EACH ROW
BEGIN
    DECLARE v_num_rounds INT;
    DECLARE v_wins_required INT;

    IF NOT (NEW.Winner_ID = NEW.Team_A_ID OR NEW.Winner_ID = NEW.Team_B_ID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid Winner';
    END IF;

    IF NEW.Score_A = NEW.Score_B THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No Draw Allowed';
    END IF;

    SELECT g.Number_of_Rounds INTO v_num_rounds
    FROM Games g
    JOIN Tournaments t ON t.Game_ID = g.Game_ID
    WHERE t.Tournament_ID = NEW.Tournament_ID;

    SET v_wins_required = FLOOR(v_num_rounds / 2) + 1;

    IF NOT (
        (NEW.Score_A = v_wins_required AND NEW.Score_B < v_wins_required) OR
        (NEW.Score_B = v_wins_required AND NEW.Score_A < v_wins_required)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid Score (Best-of-N)';
    END IF;
END$$

DELIMITER ;
