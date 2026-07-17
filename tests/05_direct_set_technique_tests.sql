SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32),
    @InitialZeroCount int,
    @FinalZeroCount int;

-------------------------------------------------------------------------------
-- Naked Single: the final cell has only digit 9 available.
-------------------------------------------------------------------------------
DECLARE @NakedSinglePuzzle char(81) =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286170';

EXEC dbo.USP_SudokuSolve
    @Puzzle = @NakedSinglePuzzle,
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 1,
    @AllowBacktracking = 0,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ValidateInitialState = 1,
    @ValidateFinalResult = 1,
    @MaxIterations = 10,
    @MaxRuntimeMs = 30000,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0,
    @PrintMessages = 0,
    @Help = 0;

IF @Solution <> '534678912672195348198342567859761423426853791713924856961537284287419635345286179'
BEGIN
    THROW 51040, 'Naked Single test failed: unexpected board.', 1;
END;

IF @Status <> 'SolvedLogically'
BEGIN
    THROW 51041, 'Naked Single test failed: unexpected status.', 1;
END;

-------------------------------------------------------------------------------
-- Hidden Single: no cell starts with one candidate. In row 4, digit 6 has only
-- position 32 available, whose initial candidate set contains 3, 4, 6, and 8.
-------------------------------------------------------------------------------
DECLARE @HiddenSinglePuzzle char(81) =
    '030600000600000308100002000059700020400050700010000006900007200000010005040006170';

SET @InitialZeroCount =
    LEN(@HiddenSinglePuzzle) - LEN(REPLACE(@HiddenSinglePuzzle, '0', ''));

EXEC dbo.USP_SudokuSolve
    @Puzzle = @HiddenSinglePuzzle,
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 1,
    @AllowBacktracking = 0,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ValidateInitialState = 1,
    @ValidateFinalResult = 0,
    @MaxIterations = 100,
    @MaxRuntimeMs = 30000,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0,
    @PrintMessages = 0,
    @Help = 0;

SET @FinalZeroCount =
    LEN(@Solution) - LEN(REPLACE(@Solution, '0', ''));

IF SUBSTRING(@Solution, 32, 1) <> '6'
BEGIN
    THROW 51042, 'Hidden Single test failed: expected digit 6 at position 32.', 1;
END;

IF @FinalZeroCount <> @InitialZeroCount - 1
BEGIN
    THROW 51043, 'Hidden Single test failed: single-step changed an unexpected number of cells.', 1;
END;

IF @Status <> 'SingleStepCompleted'
BEGIN
    THROW 51044, 'Hidden Single test failed: unexpected status.', 1;
END;

PRINT 'Direct set-technique tests passed.';