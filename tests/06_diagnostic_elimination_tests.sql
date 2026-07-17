SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CandidateState dbo.SudokuCandidateState;
DECLARE @Result TABLE
(
    [SequenceNo] int,
    [TechniqueName] varchar(64),
    [ActionType] varchar(16),
    [Pos] tinyint,
    [Digit] tinyint NULL,
    [OldCandidateMask] smallint,
    [NewCandidateMask] smallint,
    [RemovedMask] smallint,
    [Evidence] nvarchar(2000)
);

-------------------------------------------------------------------------------
-- Pointing positive and negative cases
-------------------------------------------------------------------------------
INSERT INTO @CandidateState ([Pos], [CandidateMask])
SELECT [Pos], CONVERT(smallint, 511)
FROM dbo.SudokuPos;

UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~1)
WHERE [Pos] IN (3, 10, 11, 12, 19, 20, 21);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF NOT EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Pointing'
      AND [ActionType] = 'Eliminate'
      AND [Pos] = 4
      AND ([RemovedMask] & 1) <> 0
)
BEGIN
    THROW 51050, 'Pointing positive test failed.', 1;
END;

DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~1)
WHERE [Pos] IN (3, 11, 12, 19, 20, 21);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Pointing'
)
BEGIN
    THROW 51051, 'Pointing negative test failed.', 1;
END;

-------------------------------------------------------------------------------
-- Claiming positive and negative cases
-------------------------------------------------------------------------------
DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~2)
WHERE [Pos] IN (3, 4, 5, 6, 7, 8, 9);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF NOT EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Claiming'
      AND [ActionType] = 'Eliminate'
      AND [Pos] = 10
      AND ([RemovedMask] & 2) <> 0
)
BEGIN
    THROW 51052, 'Claiming positive test failed.', 1;
END;

DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~2)
WHERE [Pos] IN (3, 5, 6, 7, 8, 9);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Claiming'
)
BEGIN
    THROW 51053, 'Claiming negative test failed.', 1;
END;

-------------------------------------------------------------------------------
-- Naked Pair positive and negative cases
-------------------------------------------------------------------------------
DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState SET [CandidateMask] = 3 WHERE [Pos] IN (1, 2);
UPDATE @CandidateState SET [CandidateMask] = 7 WHERE [Pos] = 3;

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF NOT EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Naked Pair'
      AND [Pos] = 3
      AND [RemovedMask] = 3
      AND [NewCandidateMask] = 4
)
BEGIN
    THROW 51054, 'Naked Pair positive test failed.', 1;
END;

DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState SET [CandidateMask] = 3 WHERE [Pos] = 1;
UPDATE @CandidateState SET [CandidateMask] = 5 WHERE [Pos] = 2;
UPDATE @CandidateState SET [CandidateMask] = 7 WHERE [Pos] = 3;

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'Naked Pair'
)
BEGIN
    THROW 51055, 'Naked Pair negative test failed.', 1;
END;

-------------------------------------------------------------------------------
-- X-Wing positive and negative cases
-------------------------------------------------------------------------------
DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~1)
WHERE [Pos] BETWEEN 1 AND 18
  AND [Pos] NOT IN (1, 4, 10, 13);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF NOT EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'X-Wing'
      AND [ActionType] = 'Eliminate'
      AND [Pos] IN (19, 22)
      AND ([RemovedMask] & 1) <> 0
)
BEGIN
    THROW 51056, 'X-Wing positive test failed.', 1;
END;

DELETE FROM @Result;
UPDATE @CandidateState SET [CandidateMask] = 511;
UPDATE @CandidateState
SET [CandidateMask] = CONVERT(smallint, [CandidateMask] & ~1)
WHERE [Pos] BETWEEN 1 AND 18
  AND [Pos] NOT IN (1, 4, 10, 13, 14);

INSERT INTO @Result
EXEC dbo.USP_SudokuDiagnoseFirstDeduction
    @Puzzle = NULL,
    @CandidateState = @CandidateState,
    @UseCandidateState = 1,
    @Help = 0;

IF EXISTS
(
    SELECT 1
    FROM @Result
    WHERE [TechniqueName] = 'X-Wing'
)
BEGIN
    THROW 51057, 'X-Wing negative test failed.', 1;
END;

PRINT 'Diagnostic elimination tests passed.';
