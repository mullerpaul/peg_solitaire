SELECT * FROM user_objects;

-- hows the data look?
SELECT * FROM ALLOWABLE_JUMPS;

SELECT start_location, COUNT(*) AS possible_jumps 
  FROM allowable_jumps 
 GROUP BY start_location;
 
SELECT possible_jumps, COUNT(*) AS positions
  FROM (SELECT start_location, COUNT(*) AS possible_jumps 
          FROM allowable_jumps 
         GROUP BY start_location)
 GROUP BY possible_jumps
 ORDER BY 1; 


--- does the MOVES column always match the count of the MOVES table?
-- yes!
SELECT g.game_id, g.moves, g.pegs_remaining, COUNT(*) AS move_count
  FROM games g, 
       moves m
 WHERE g.game_id = m.game_id
 GROUP BY g.game_id, g.moves, g.pegs_remaining
HAVING COUNT(*) <> g.moves;

---
TRUNCATE TABLE moves;
DELETE FROM games;
---
SELECT * FROM user_errors;
---

BEGIN
  peg_solitaire.start_game(pi_starting_board_config => 'small diamond');
END;
/

---  
SELECT * FROM games;
SELECT * FROM moves;

----
SELECT starting_configuration, COUNT(*) FROM games GROUP BY starting_configuration;
SELECT starting_configuration, Min(game_time) AS earliest, max(game_time) AS latest, COUNT(*) FROM games GROUP BY starting_configuration;
SELECT starting_configuration, pegs_Remaining, COUNT(*) FROM games GROUP BY starting_configuration, pegs_Remaining ORDER BY 1,2;

SELECT g.starting_configuration, g.moves, g.pegs_remaining, m.move_sequence, m.start_location, m.end_location
  FROM games g, moves m
 WHERE g.game_id = m.game_id
   AND g.starting_configuration = 'submarine'
   AND g.pegs_remaining IN (1,4) 
 ORDER BY g.game_id, move_sequence; 



