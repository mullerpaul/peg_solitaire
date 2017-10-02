CREATE OR REPLACE PACKAGE peg_solitaire IS

  -- Author  : PMULLER
  -- Created : 8/6/2015 10:47:56 PM
  -- Purpose : Play peg solitaire and record all possible games

  -- Public function and procedure declarations
  PROCEDURE start_game (pi_starting_board_config IN games.starting_configuration%TYPE);

END peg_solitaire;
/
