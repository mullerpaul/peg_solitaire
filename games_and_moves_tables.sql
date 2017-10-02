--DROP TABLE moves PURGE;
--DROP TABLE games PURGE;

CREATE TABLE games
  (game_id                NUMBER       NOT NULL,
   game_time              DATE         NOT NULL,
   starting_configuration VARCHAR2(20) NOT NULL,
   moves                  NUMBER       NOT NULL,
   pegs_remaining         NUMBER       NOT NULL);

ALTER TABLE games
ADD CONSTRAINT games_pk
PRIMARY KEY (game_id);

CREATE TABLE moves
  (game_id        NUMBER  NOT NULL,
   move_sequence  NUMBER  NOT NULL,
   start_location INTEGER NOT NULL,
   end_location   INTEGER NOT NULL);

ALTER TABLE moves
ADD CONSTRAINT moves_pk
PRIMARY KEY (game_id, move_sequence);

ALTER TABLE moves
ADD CONSTRAINT moves_fk01
FOREIGN KEY (game_id)
REFERENCES games;

CREATE SEQUENCE game_seq;
   
  
   
