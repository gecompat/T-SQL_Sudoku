SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32),
    @InitialZeroCount int,
    @FinalZeroCount int;

-------------------------------------------------------------------------------
-- Single-step execution must apply exactly one logical action and stop.
-------------------------------------------------------------------------------
DECLARE @SingleStepPuzzle char(81) =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

SET @InitialZeroCount =
    LEN(@SingleStepPuzzle) - LEN(REPLACE(@SingleStepPuzzle, '0', ''));

EXEC dbo.USP_SudokuSolve
    @Puzzle = @SingleStepPuzzle,
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

IF @Status <> 'SingleStepCompleted'
BEGIN
    THROW 51030, 'Single-step test failed: unexpected status.', 1;
END;

IF @FinalZeroCount >= @InitialZeroCount
BEGIN
    THROW 51031, 'Single-step test failed: no logical progress was applied.', 1;
END;

-------------------------------------------------------------------------------
-- A one-iteration limit must be distinguishable from a natural logic stall.
-------------------------------------------------------------------------------
EXEC dbo.USP_SudokuSolve
    @Puzzle = '000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 0,
    @AllowBacktracking = 0,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ValidateInitialState = 0,
    @ValidateFinalResult = 0,
    @MaxIterations = 1,
    @MaxRuntimeMs = 30000,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0,
    @PrintMessages = 0,
    @Help = 0;

IF @Status <> 'IterationLimit'
BEGIN
    THROW 51032, 'Iteration-limit test failed: unexpected status.', 1;
END;

EXEC dbo.USP_SudokuSolve
    @Puzzle = '000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 0,
    @AllowBacktracking = 0,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ValidateInitialState = 0,
    @ValidateFinalResult = 0,
    @MaxIterations = 10,
    @MaxRuntimeMs = 30000,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0,
    @PrintMessages = 0,
    @Help = 0;

IF @Status <> 'LogicStalled'
BEGIN
    THROW 51033, 'Logic-stalled test failed: unexpected status.', 1;
END;

-------------------------------------------------------------------------------
-- Removing every 1 and 2 from a valid completed board guarantees at least two
-- completions because globally swapping digits 1 and 2 yields another solution.
-------------------------------------------------------------------------------
DECLARE @MultipleSolutionPuzzle char(81) =
    '534678900670095348098340567859760403406853790703904856960537084087409635345086079';

EXEC dbo.USP_SudokuSolve
    @Puzzle = @MultipleSolutionPuzzle,
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 0,
    @AllowBacktracking = 1,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ValidateInitialState = 1,
    @ValidateFinalResult = 1,
    @MaxIterations = 100,
    @MaxRuntimeMs = 30000,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0,
    @PrintMessages = 0,
    @Help = 0;

IF @Status <> 'MultipleSolutions'
BEGIN
    THROW 51034, 'Multiple-solution test failed: unexpected status.', 1;
END;

EXEC dbo.USP_SudokuSolve
    @Puzzle = @MultipleSolutionPuzzle,
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @SingleStep = 0,
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

IF @Status <> 'LogicStalled'
BEGIN
    THROW 51035, 'Backtracking-disabled test failed: unexpected status.', 1;
END;

PRINT 'Solver status boundary tests passed.';