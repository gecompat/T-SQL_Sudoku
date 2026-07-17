SET NOCOUNT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32);

EXEC dbo.USP_SudokuSolve
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 0,
    @AllowBacktracking = 1,
    @AllowForcing = 1,
    @AllowForcingNets = 0,
    @ValidateInitialState = 1,
    @ValidateFinalResult = 1,
    @MaxIterations = 10000,
    @MaxRuntimeMs = 30000,
    @MaxForcingChecks = 64,
    @ReturnSolutionPath = 1,
    @ReturnStatistics = 1,
    @PrintMessages = 0,
    @Help = 0;

SELECT
    @Solution AS [Solution],
    @Status AS [Status];
