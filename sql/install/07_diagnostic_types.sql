SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF TYPE_ID(N'dbo.SudokuCandidateState') IS NULL
BEGIN
    EXEC sys.sp_executesql N'
        CREATE TYPE dbo.SudokuCandidateState AS TABLE
        (
            [Pos] tinyint NOT NULL PRIMARY KEY,
            [CandidateMask] smallint NOT NULL
        );';
END;
GO
