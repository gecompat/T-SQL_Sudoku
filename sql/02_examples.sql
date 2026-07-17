SET NOCOUNT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32);

EXEC dbo.USP_SudokuSolve
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @NurEinSchritt = 0,
    @ErlaubeBacktracking = 1,
    @ErlaubeForcing = 1,
    @ErlaubeForcingNets = 0,
    @ValidiereStartzustand = 1,
    @ValidiereEndergebnis = 1,
    @MaxIterationen = 10000,
    @MaxLaufzeitMs = 30000,
    @MaxForcingPruefungen = 64,
    @ResultsetLoesungspfad = 1,
    @ResultsetStatistik = 1,
    @PrintMeldungen = 0,
    @Hilfe = 0;

SELECT
    @Solution AS [Solution],
    @Status AS [Status];
