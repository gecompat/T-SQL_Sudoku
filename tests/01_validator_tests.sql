SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @SolutionCount int,
    @FirstSolution char(81);

EXEC dbo.USP_SudokuValidate
    @Puzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @MaxSolutions = 2,
    @SolutionCount = @SolutionCount OUTPUT,
    @FirstSolution = @FirstSolution OUTPUT;

IF @SolutionCount <> 1
BEGIN
    THROW 51010, 'Validator test failed: expected one solution.', 1;
END;

IF @FirstSolution <> '534678912672195348198342567859761423426853791713924856961537284287419635345286179'
BEGIN
    THROW 51011, 'Validator test failed: unexpected first solution.', 1;
END;

EXEC dbo.USP_SudokuValidate
    @Puzzle = '553070000600195000098000060800060003400803001700020006060000280000419005000080079',
    @MaxSolutions = 2,
    @SolutionCount = @SolutionCount OUTPUT,
    @FirstSolution = @FirstSolution OUTPUT;

IF @SolutionCount <> 0
BEGIN
    THROW 51012, 'Validator test failed: invalid puzzle was accepted.', 1;
END;

/*
    This puzzle is derived from a valid completed board by removing every 1 and 2.
    At least two completions therefore exist by globally swapping digits 1 and 2.
*/
EXEC dbo.USP_SudokuValidate
    @Puzzle = '534678900670095348098340567859760403406853790703904856960537084087409635345086079',
    @MaxSolutions = 2,
    @SolutionCount = @SolutionCount OUTPUT,
    @FirstSolution = @FirstSolution OUTPUT;

IF @SolutionCount <> 2
BEGIN
    THROW 51013, 'Validator test failed: expected at least two solutions.', 1;
END;

IF @FirstSolution IS NULL OR @FirstSolution LIKE '%0%'
BEGIN
    THROW 51014, 'Validator test failed: first completion was not returned.', 1;
END;

PRINT 'Validator tests passed.';