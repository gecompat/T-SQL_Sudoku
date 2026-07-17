SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32);

EXEC dbo.USP_SudokuSolve
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @ErlaubeBacktracking = 1,
    @ErlaubeForcing = 1,
    @ErlaubeForcingNets = 0,
    @ResultsetLoesungspfad = 0,
    @ResultsetStatistik = 0;

IF @Solution <> '534678912672195348198342567859761423426853791713924856961537284287419635345286179'
BEGIN
    THROW 51000, 'Smoke test failed: unexpected solution.', 1;
END;

IF @Status NOT IN ('SolvedLogically', 'SolvedByBacktracking')
BEGIN
    THROW 51001, 'Smoke test failed: unexpected status.', 1;
END;

PRINT 'Smoke test passed.';
