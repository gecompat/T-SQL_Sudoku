SET NOCOUNT ON;
SET XACT_ABORT ON;

IF TYPE_ID(N'dbo.SudokuCandidateState') IS NULL
BEGIN
    THROW 51060, 'Diagnostic contract test failed: dbo.SudokuCandidateState is missing.', 1;
END;

IF OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P') IS NULL
BEGIN
    THROW 51061, 'Diagnostic contract test failed: dbo.USP_SudokuDiagnoseFirstDeduction is missing.', 1;
END;

DECLARE @ExpectedParameter TABLE
(
    [ParameterName] sysname NOT NULL PRIMARY KEY,
    [ParameterID] int NOT NULL
);

INSERT INTO @ExpectedParameter
(
    [ParameterName],
    [ParameterID]
)
VALUES
    (N'@Puzzle', 1),
    (N'@CandidateState', 2),
    (N'@UseCandidateState', 3),
    (N'@Help', 4);

IF EXISTS
(
    SELECT [ParameterName], [ParameterID]
    FROM @ExpectedParameter
    EXCEPT
    SELECT [name], [parameter_id]
    FROM sys.parameters
    WHERE [object_id] = OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P')
)
OR EXISTS
(
    SELECT [name], [parameter_id]
    FROM sys.parameters
    WHERE [object_id] = OBJECT_ID(N'dbo.USP_SudokuDiagnoseFirstDeduction', N'P')
    EXCEPT
    SELECT [ParameterName], [ParameterID]
    FROM @ExpectedParameter
)
BEGIN
    THROW 51062, 'Diagnostic contract test failed: parameter names or order differ.', 1;
END;

DECLARE @EmptyState dbo.SudokuCandidateState;

BEGIN TRY
    EXEC dbo.USP_SudokuDiagnoseFirstDeduction
        @Puzzle = NULL,
        @CandidateState = @EmptyState,
        @UseCandidateState = 1,
        @Help = 0;

    THROW 51063, 'Diagnostic contract test failed: incomplete candidate state was accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50501
        THROW;
END CATCH;

BEGIN TRY
    EXEC dbo.USP_SudokuDiagnoseFirstDeduction
        @Puzzle = '123',
        @CandidateState = @EmptyState,
        @UseCandidateState = 0,
        @Help = 0;

    THROW 51064, 'Diagnostic contract test failed: malformed puzzle was accepted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50500
        THROW;
END CATCH;

EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @EmptyState,
    @UseCandidateState = 0,
    @Help = 1;

PRINT 'Diagnostic contract tests passed.';
