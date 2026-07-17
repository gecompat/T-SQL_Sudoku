CREATE OR ALTER PROCEDURE dbo.USP_SudokuValidate
(
    @Puzzle        char(81),
    @MaxSolutions  tinyint = 2,
    @SolutionCount int OUTPUT,
    @FirstSolution char(81) OUTPUT,
    @Help          bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Help = 1
    BEGIN
        PRINT 'dbo.USP_SudokuValidate';
        PRINT 'Counts solutions using independent backtracking.';
        PRINT '@Puzzle: exactly 81 digits; 0 represents an empty cell.';
        PRINT '@MaxSolutions: stop after this many solutions.';
        RETURN;
    END;

    IF @Puzzle IS NULL
       OR LEN(@Puzzle) <> 81
       OR @Puzzle LIKE '%[^0-9]%'
    BEGIN
        THROW 50200,
              'Puzzle must contain exactly 81 digits from 0 through 9.',
              1;
    END;

    IF @MaxSolutions IS NULL OR @MaxSolutions < 1
        SET @MaxSolutions = 1;

    SET @SolutionCount = 0;
    SET @FirstSolution = NULL;

    CREATE TABLE #SearchStack
    (
        [StackID] bigint IDENTITY(1,1) NOT NULL,
        [Board] char(81) NOT NULL,
        CONSTRAINT [PK_SearchStack] PRIMARY KEY CLUSTERED ([StackID])
    );

    INSERT INTO #SearchStack ([Board])
    VALUES (@Puzzle);

    DECLARE
        @StackID bigint,
        @CurrentBoard char(81),
        @BranchPosition tinyint,
        @BranchMask smallint,
        @Digit tinyint,
        @DigitMask smallint,
        @IsInvalid bit;

    WHILE EXISTS (SELECT 1 FROM #SearchStack)
      AND @SolutionCount < @MaxSolutions
    BEGIN
        SELECT TOP (1)
            @StackID = stackItem.[StackID],
            @CurrentBoard = stackItem.[Board]
        FROM #SearchStack AS stackItem
        ORDER BY stackItem.[StackID] DESC;

        DELETE FROM #SearchStack
        WHERE [StackID] = @StackID;

        SET @IsInvalid = 0;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS position
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@CurrentBoard, position.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY position.[Row], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        OR EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS position
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@CurrentBoard, position.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY position.[Col], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        OR EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS position
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@CurrentBoard, position.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY position.[Box], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        BEGIN
            SET @IsInvalid = 1;
        END;

        IF @IsInvalid = 1
            CONTINUE;

        IF @CurrentBoard NOT LIKE '%0%'
        BEGIN
            SET @SolutionCount += 1;

            IF @FirstSolution IS NULL
                SET @FirstSolution = @CurrentBoard;

            CONTINUE;
        END;

        SET @BranchPosition = NULL;
        SET @BranchMask = NULL;

        ;WITH EmptyCells AS
        (
            SELECT
                position.[Pos],
                position.[Row],
                position.[Col],
                position.[Box]
            FROM dbo.SudokuPos AS position
            WHERE SUBSTRING(@CurrentBoard, position.[Pos], 1) = '0'
        ),
        CandidateMasks AS
        (
            SELECT
                emptyCell.[Pos],
                [CandidateMask] =
                    CONVERT
                    (
                        smallint,
                        511
                        & ~ISNULL(rowMask.[UsedMask], 0)
                        & ~ISNULL(columnMask.[UsedMask], 0)
                        & ~ISNULL(boxMask.[UsedMask], 0)
                    )
            FROM EmptyCells AS emptyCell
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(digitMask.[BitMask])
                FROM dbo.SudokuPos AS peer
                INNER JOIN dbo.SudokuDigitMask AS digitMask
                    ON digitMask.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@CurrentBoard, peer.[Pos], 1))
                WHERE peer.[Row] = emptyCell.[Row]
            ) AS rowMask
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(digitMask.[BitMask])
                FROM dbo.SudokuPos AS peer
                INNER JOIN dbo.SudokuDigitMask AS digitMask
                    ON digitMask.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@CurrentBoard, peer.[Pos], 1))
                WHERE peer.[Col] = emptyCell.[Col]
            ) AS columnMask
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(digitMask.[BitMask])
                FROM dbo.SudokuPos AS peer
                INNER JOIN dbo.SudokuDigitMask AS digitMask
                    ON digitMask.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@CurrentBoard, peer.[Pos], 1))
                WHERE peer.[Box] = emptyCell.[Box]
            ) AS boxMask
        )
        SELECT TOP (1)
            @BranchPosition = candidate.[Pos],
            @BranchMask = candidate.[CandidateMask]
        FROM CandidateMasks AS candidate
        INNER JOIN dbo.BitCount511 AS bitCount
            ON bitCount.[Mask] = candidate.[CandidateMask]
        ORDER BY
            bitCount.[BitCount],
            candidate.[Pos];

        IF @BranchMask IS NULL OR @BranchMask = 0
            CONTINUE;

        SET @Digit = 1;

        WHILE @Digit <= 9
        BEGIN
            SELECT @DigitMask = mask.[BitMask]
            FROM dbo.SudokuDigitMask AS mask
            WHERE mask.[Digit] = @Digit;

            IF (@BranchMask & @DigitMask) <> 0
            BEGIN
                INSERT INTO #SearchStack ([Board])
                VALUES
                (
                    STUFF
                    (
                        @CurrentBoard,
                        @BranchPosition,
                        1,
                        CONVERT(char(1), @Digit)
                    )
                );
            END;

            SET @Digit += 1;
        END;
    END;
END;
GO
