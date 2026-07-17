SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @Solution char(81),
    @Status varchar(32),
    @SolutionCount int,
    @FirstSolution char(81),
    @CaughtErrorNumber int;

-------------------------------------------------------------------------------
-- Solver rejects malformed input with the documented error number
-------------------------------------------------------------------------------
SET @CaughtErrorNumber = NULL;

BEGIN TRY
    EXEC dbo.USP_SudokuSolve
        @Puzzle = '123',
        @Solution = @Solution OUTPUT,
        @Status = @Status OUTPUT,
        @ReturnSolutionPath = 0,
        @ReturnStatistics = 0;
END TRY
BEGIN CATCH
    SET @CaughtErrorNumber = ERROR_NUMBER();
END CATCH;

IF @CaughtErrorNumber <> 50300
BEGIN
    THROW 51040, 'API behavior test failed: malformed solver input did not raise error 50300.', 1;
END;

-------------------------------------------------------------------------------
-- Validator rejects malformed input with the documented error number
-------------------------------------------------------------------------------
SET @CaughtErrorNumber = NULL;

BEGIN TRY
    EXEC dbo.USP_SudokuValidate
        @Puzzle = '123',
        @MaxSolutions = 2,
        @SolutionCount = @SolutionCount OUTPUT,
        @FirstSolution = @FirstSolution OUTPUT;
END TRY
BEGIN CATCH
    SET @CaughtErrorNumber = ERROR_NUMBER();
END CATCH;

IF @CaughtErrorNumber <> 50200
BEGIN
    THROW 51041, 'API behavior test failed: malformed validator input did not raise error 50200.', 1;
END;

-------------------------------------------------------------------------------
-- A structurally valid but contradictory puzzle returns Invalid
-------------------------------------------------------------------------------
SET @Solution = NULL;
SET @Status = NULL;

EXEC dbo.USP_SudokuSolve
    @Puzzle = '553070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @Solution = @Solution OUTPUT,
    @Status = @Status OUTPUT,
    @ValidateInitialState = 1,
    @AllowBacktracking = 0,
    @AllowForcing = 0,
    @AllowForcingNets = 0,
    @ReturnSolutionPath = 0,
    @ReturnStatistics = 0;

IF @Status <> 'Invalid'
BEGIN
    THROW 51042, 'API behavior test failed: contradictory initial puzzle did not return Invalid.', 1;
END;

IF @Solution <> '553070000600195000098000060800060003400803001700020006060000280000419005000080079'
BEGIN
    THROW 51043, 'API behavior test failed: Invalid status did not preserve the supplied board.', 1;
END;

-------------------------------------------------------------------------------
-- Help mode must return without solving or validating the puzzle
-------------------------------------------------------------------------------
SET @CaughtErrorNumber = NULL;

BEGIN TRY
    EXEC dbo.USP_SudokuSolve
        @Puzzle = NULL,
        @Solution = @Solution OUTPUT,
        @Status = @Status OUTPUT,
        @Help = 1;

    EXEC dbo.USP_SudokuValidate
        @Puzzle = NULL,
        @MaxSolutions = 2,
        @SolutionCount = @SolutionCount OUTPUT,
        @FirstSolution = @FirstSolution OUTPUT,
        @Help = 1;
END TRY
BEGIN CATCH
    SET @CaughtErrorNumber = ERROR_NUMBER();
END CATCH;

IF @CaughtErrorNumber IS NOT NULL
BEGIN
    THROW 51044, 'API behavior test failed: Help mode attempted normal puzzle validation.', 1;
END;

PRINT 'API behavior tests passed.';