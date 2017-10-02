CREATE OR REPLACE PACKAGE BODY peg_solitaire IS

  -- Private type declarations
  TYPE move_type IS RECORD (from_location   INTEGER, 
                            to_location     INTEGER, 
                            jumped_location INTEGER);

  TYPE move_table  IS TABLE OF move_type;     -- nested table collection type
  TYPE board_array IS VARRAY(33) OF BOOLEAN;  -- varray collcetion type
  
  -- global variables
  gv_board_configuration games.starting_configuration%TYPE;
  
  ---------------------------------------------------------
  FUNCTION bool_to_str(fi_bool IN BOOLEAN) RETURN VARCHAR2 IS
    lv_result VARCHAR2(5);
  
  BEGIN
    CASE
      WHEN fi_bool IS NULL THEN
        lv_result := 'NULL';
      WHEN fi_bool THEN
        lv_result := 'TRUE';
      WHEN NOT fi_bool THEN
        lv_result := 'FALSE';
    END CASE;
  
    RETURN lv_result;
  
  END bool_to_str;

  ---------------------------------------------------------
  FUNCTION move_constructor(fi_from_location   INTEGER, 
                            fi_to_location     INTEGER, 
                            fi_jumped_location INTEGER) RETURN move_type IS
    lv_result move_type;
  BEGIN
    lv_result.from_location   := fi_from_location;
    lv_result.to_location     := fi_to_location;
    lv_result.jumped_location := fi_jumped_location;
    
    RETURN lv_result;
    
  END move_constructor;    

  ---------------------------------------------------------
  FUNCTION get_between_space(fi_start IN INT,
                             fi_end   IN INT) RETURN INT IS
    lv_result INT;
    
  BEGIN
    BEGIN
      /* This is a lookup by PK, so we will get 0 or 1 row returned. */
      SELECT jumped_location
        INTO lv_result
        FROM allowable_jumps
       WHERE start_location = fi_start
         AND end_location = fi_end;
      
    EXCEPTION
      WHEN no_data_found 
        THEN lv_result := NULL;
    END;       
    
    RETURN lv_result;
    
  END get_between_space;

  ---------------------------------------------------------
  FUNCTION peg_count(fi_board IN board_array) RETURN INT IS
    lv_result INT := 0;
  
  BEGIN
    FOR i IN 1 .. 33 LOOP
      IF fi_board(i)
      THEN
        lv_result := lv_result + 1;
      END IF;
    END LOOP;
  
    RETURN lv_result;
  END peg_count;

  ---------------------------------------------------------
  PROCEDURE init_board(pi_init_config IN VARCHAR2,
                       po_board       OUT board_array) IS
    la_result board_array;
  BEGIN
    CASE
      WHEN pi_init_config = 'trivial' THEN
        /* Only 3 possible ways to play this configuration.  We can use it for testing. */
        la_result := board_array(FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE,
                   FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE,
                   FALSE, TRUE,  TRUE,  FALSE, FALSE, FALSE, FALSE,
                   FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE);

      WHEN pi_init_config = 'submarine' THEN
        la_result := board_array(FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE,
                   FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE,
                   FALSE, TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  FALSE,
                   FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE,
                                 FALSE, FALSE, FALSE);

      WHEN pi_init_config = 'cross' THEN
        la_result := board_array(FALSE, FALSE, FALSE,
                                 FALSE, TRUE,  FALSE,
                   FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE,
                   FALSE, TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  FALSE,
                   FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE, FALSE,
                                 FALSE, TRUE,  FALSE,
                                 FALSE, FALSE, FALSE);

      WHEN pi_init_config = 'small diamond' THEN
        la_result := board_array(FALSE, FALSE, FALSE,
                                 FALSE, TRUE,  FALSE,
                   FALSE, FALSE, TRUE,  TRUE,  TRUE,  FALSE, FALSE,
                   FALSE, TRUE,  TRUE,  FALSE, TRUE,  TRUE,  FALSE,
                   FALSE, FALSE, TRUE,  TRUE,  TRUE,  FALSE, FALSE,
                                 FALSE, TRUE,  FALSE,
                                 FALSE, FALSE, FALSE);

      WHEN pi_init_config = 'standard game' THEN
        /* I estimate this config. would take on the order of 1E25 recursions - so thats not going to happen on this laptop!
           We need to make some kind of duplicate detector to remove dupes due to mirror images, rotations, ordering, etc.  */
        la_result := board_array(TRUE,  TRUE,  TRUE,
                                 TRUE,  TRUE,  TRUE,
                   TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,
                   TRUE,  TRUE,  TRUE,  FALSE, TRUE,  TRUE,  TRUE,
                   TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE,
                                 TRUE,  TRUE,  TRUE,
                                 TRUE,  TRUE,  TRUE);

      ELSE
        raise_application_error(-20001,
                                'That configuration not implemented yet');
    END CASE;
    po_board := la_result;
  
  END init_board;

  ---------------------------------------------------------
  PROCEDURE print_board(pi_board_config IN board_array) IS
  
    FUNCTION pp(pi_index IN INT) RETURN VARCHAR2 IS
      lc_occupied_char CONSTANT VARCHAR2(1) := 'O';
      lc_empty_char    CONSTANT VARCHAR2(1) := '.';
      lv_result VARCHAR2(1);
    
    BEGIN
      IF pi_board_config(pi_index)
      THEN
        lv_result := lc_occupied_char;
      ELSE
        lv_result := lc_empty_char;
      END IF;
      RETURN lv_result;
    END pp;
  
  BEGIN
    dbms_output.put_line('  '             || pp(1)  || pp(2)  || pp(3)  || '  ');
    dbms_output.put_line('  '             || pp(4)  || pp(5)  || pp(6)  || '  ');
    dbms_output.put_line(pp(7)  || pp(8)  || pp(9)  || pp(10) || pp(11) || pp(12) || pp(13));
    dbms_output.put_line(pp(14) || pp(15) || pp(16) || pp(17) || pp(18) || pp(19) || pp(20));
    dbms_output.put_line(pp(21) || pp(22) || pp(23) || pp(24) || pp(25) || pp(26) || pp(27));
    dbms_output.put_line('  '             || pp(28) || pp(29) || pp(30) || '  ');
    dbms_output.put_line('  '             || pp(31) || pp(32) || pp(33) || '  ');
  
  END print_board;

  ---------------------------------------------------------
  PROCEDURE print_move_list(pi_move_list IN move_table) IS
    lv_index INTEGER;
  BEGIN
    lv_index := pi_move_list.first;
  
    IF lv_index IS NULL
    THEN
      dbms_output.put_line('Move list is empty');
    ELSE
      WHILE lv_index IS NOT NULL LOOP
        dbms_output.put_line(to_char(pi_move_list(lv_index).from_location) ||
                             ' - ' ||
                             to_char(pi_move_list(lv_index).to_location) ||
                             ' jumped ' || 
                             to_char(pi_move_list(lv_index).jumped_location));
                             
        lv_index := pi_move_list.next(lv_index);
      END LOOP;
    END IF;
  
  END print_move_list;

  ---------------------------------------------------------
  PROCEDURE log_game(pi_game_id        IN NUMBER,
                     pi_final_depth    IN NUMBER,
                     pi_pegs_remaining IN NUMBER,
                     pi_final_movelist IN move_table) IS
  
    lv_index INTEGER;
  
  BEGIN
    INSERT INTO games
      (game_id, game_time, starting_configuration, moves, pegs_remaining)
    VALUES
      (pi_game_id,
       SYSDATE,
       gv_board_configuration,
       pi_final_depth,
       pi_pegs_remaining);
  
    IF pi_pegs_remaining = 1
      /* Only record move details for games with 1 peg remaining 
         This is done to save space.  mioght have to disable this to allow for future 
         duplicate game removal. */  
      THEN
        lv_index := pi_final_movelist.first;
  
        IF lv_index IS NOT NULL
        THEN
          WHILE lv_index IS NOT NULL LOOP
            INSERT INTO moves
              (game_id, move_sequence, start_location, end_location)
            VALUES
              (pi_game_id,
               lv_index,
               pi_final_movelist(lv_index).from_location,
               pi_final_movelist(lv_index).to_location);
      
            lv_index := pi_final_movelist.next(lv_index);
          END LOOP;
        END IF;
    END IF;        
    
    COMMIT;
  
  END log_game;
                     
  ---------------------------------------------------------
  PROCEDURE make_move (pi_board         IN board_array,
                       pi_move_list     IN move_table,
                       pi_current_depth IN NUMBER) IS    --perhaps get rid of depth input and use pi_move_list.COUNT instead

    la_current_move_list  move_table := move_table();
    la_valid_move_list    move_table := move_table();
    lv_valid_move_counter INTEGER := 0;
    
    la_board         board_array;
    lv_valid_move    BOOLEAN;
    lv_jump_location INTEGER;
    
    PROCEDURE is_valid_move(pi_start         IN  INT,
                            pi_end           IN  INT,
                            po_valid_move    OUT BOOLEAN,
                            po_jump_location OUT INT) IS

      lv_result BOOLEAN;
      lv_index  INT;
    
    BEGIN
      /* Check for syntactically valid input */
      IF (pi_start > 0 AND pi_start < 34 AND pi_end > 0 AND pi_end < 34 AND
         pi_start <> pi_end AND pi_board(pi_start) AND
         NOT pi_board(pi_end))
      THEN
        /* inputs are OK, start is occupied, end is open, now check in between space. */
        lv_index := get_between_space(fi_start => pi_start,
                                      fi_end   => pi_end);
        IF lv_index IS NULL
        THEN
          /* cannot jump from start to end, return NULL. */
          lv_result := FALSE;
        ELSE
          /* can jump from start to end, return true if jumped space is occupied, false if not. */
          lv_result := pi_board(lv_index);
        END IF;
      
      ELSE
        /* Bad inputs, or start is empty, or end is occupied. */
        lv_result := FALSE;
      END IF;
    
      po_valid_move := lv_result;
      po_jump_location := lv_index;
    
    END is_valid_move;
    
  BEGIN
    /* Recursive routine.
       We have to do the following:
         1.  Make list of all valid moves.
         2.  If there are valid moves, loop over them all and call this procedure for each:
         2a.   modify the board with the move.
         2b.   append the move to the move list   
         3.  If there are none, we have finished a game and must log it. */
         
    /*  Make list of valid moves */     
    FOR from_loc IN 1 .. 33 LOOP
      IF pi_board(from_loc)  -- is the space at that index occupied?  If so, start inner loop
        THEN 
          FOR to_loc IN 1 .. 33 LOOP
            IF NOT pi_board(to_loc) THEN
              /* To space is NOT occupied so this may be a valid move. Test to find out. */
              is_valid_move(pi_start         => from_loc,
                            pi_end           => to_loc,
                            po_valid_move    => lv_valid_move,
                            po_jump_location => lv_jump_location);

              IF lv_valid_move
                THEN
                  /* Found a valid move.  Add to the list. */
                  lv_valid_move_counter := lv_valid_move_counter + 1;
                  la_valid_move_list.EXTEND;
                  la_valid_move_list(lv_valid_move_counter) := move_constructor(from_loc, to_loc, lv_jump_location);
                  
              END IF;  -- actually is a valid move.                  
            END IF;  -- test to location unoccupied  
          END LOOP; -- to location loop  
      END IF;   -- test from location occupied    
    END LOOP;  -- from location loop
    
    /* debug messages */
/*    dbms_output.put_line('current depth: ' || to_char(pi_current_depth));
    dbms_output.put_line('current move list: ');
    print_move_list(la_current_move_list);
    dbms_output.put_line('valid moves list: ');
    print_move_list(la_valid_move_list);
    dbms_output.put_line('-------------------------------------------------');  */
                         
    /* Were any valid moves found? */
    IF lv_valid_move_counter > 0 
      THEN
        /* Valid move(s) found.  Call this procedure recursivly for each valid move. */
        FOR i IN la_valid_move_list.FIRST .. la_valid_move_list.LAST LOOP
          
          /* modify board */
          la_board := pi_board;
          la_board(la_valid_move_list(i).from_location) := FALSE;
          la_board(la_valid_move_list(i).to_location) := TRUE;
          la_board(la_valid_move_list(i).jumped_location) := FALSE;
          
          /*  add move to list */
          la_current_move_list := pi_move_list;
          la_current_move_list.extend;
          la_current_move_list(pi_current_depth + 1) := la_valid_move_list(i);
          
          /*  recurse! */
          make_move(pi_board         => la_board,
                    pi_move_list     => la_current_move_list,
                    pi_current_depth => pi_current_depth + 1);
        END LOOP;  
      ELSE
        /* No valid moves found.  Log game and end. */
        log_game(pi_game_id        => game_seq.nextval,
                 pi_final_depth    => pi_current_depth,
                 pi_pegs_remaining => peg_count(pi_board),
                 pi_final_movelist => pi_move_list);

    END IF;    
          
  END make_move;
                         
  ---------------------------------------------------------
  PROCEDURE start_game (pi_starting_board_config IN games.starting_configuration%TYPE) IS

    lv_board    board_array;
    lv_movelist move_table := move_table();

  BEGIN
    gv_board_configuration := pi_starting_board_config;
    init_board(pi_init_config => gv_board_configuration,
               po_board       => lv_board);
               
    dbms_output.put_line('starting position');
    print_board(pi_board_config => lv_board);
    
    /* Initial call of recursive routine. */
    make_move(pi_board         => lv_board,     -- newly created board
              pi_move_list     => lv_movelist,  -- newly initialized moved list (atomicall NULL)
              pi_current_depth => 0);           -- start at depth zero
    
  END start_game;

END peg_solitaire;
/
