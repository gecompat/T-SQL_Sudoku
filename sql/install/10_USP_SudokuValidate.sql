CREATE OR ALTER PROCEDURE dbo.USP_SudokuValidate
(
    @Puzzle        char(81),
    @MaxSolutions  tinyint = 2,
    @SolutionCount int OUTPUT,
    @FirstSolution char(81) OUTPUT,
    @Hilfe         bit = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Hilfe = 1
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

    CREATE TABLE #Stack
    (
        [StackID] bigint IDENTITY(1,1) NOT NULL,
        [Board] char(81) NOT NULL,
        CONSTRAINT [PK_Stack] PRIMARY KEY CLUSTERED ([StackID])
    );

    INSERT INTO #Stack ([Board])
    VALUES (@Puzzle);

    DECLARE
        @StackID bigint,
        @Board char(81),
        @BranchPos tinyint,
        @BranchMask smallint,
        @Digit tinyint,
        @BitMask smallint,
        @Invalid bit;

    WHILE EXISTS (SELECT 1 FROM #Stack)
      AND @SolutionCount < @MaxSolutions
    BEGIN
        SELECT TOP (1)
            @StackID = s.[StackID],
            @Board = s.[Board]
        FROM #Stack AS s
        ORDER BY s.[StackID] DESC;

        DELETE FROM #Stack
        WHERE [StackID] = @StackID;

        SET @Invalid = 0;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS p
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@Board, p.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY p.[Row], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        OR EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS p
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@Board, p.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY p.[Col], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        OR EXISTS
        (
            SELECT 1
            FROM dbo.SudokuPos AS p
            CROSS APPLY
            (
                VALUES
                    (CONVERT(tinyint, SUBSTRING(@Board, p.[Pos], 1)))
            ) AS value([Digit])
            WHERE value.[Digit] <> 0
            GROUP BY p.[Box], value.[Digit]
            HAVING COUNT_BIG(*) > 1
        )
        BEGIN
            SET @Invalid = 1;
        END;

        IF @Invalid = 1
            CONTINUE;

        IF @Board NOT LIKE '%0%'
        BEGIN
            SET @SolutionCount += 1;

            IF @FirstSolution IS NULL
                SET @FirstSolution = @Board;

            CONTINUE;
        END;

        SET @BranchPos = NULL;
        SET @BranchMask = NULL;

        ;WITH EmptyCells AS
        (
            SELECT
                p.[Pos],
                p.[Row],
                p.[Col],
                p.[Box]
            FROM dbo.SudokuPos AS p
            WHERE SUBSTRING(@Board, p.[Pos], 1) = '0'
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
                        & ~ISNULL(colMask.[UsedMask], 0)
                        & ~ISNULL(boxMask.[UsedMask], 0)
                    )
            FROM EmptyCells AS emptyCell
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(dm.[BitMask])
                FROM dbo.SudokuPos AS p2
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON dm.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@Board, p2.[Pos], 1))
                WHERE p2.[Row] = emptyCell.[Row]
            ) AS rowMask
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(dm.[BitMask])
                FROM dbo.SudokuPos AS p2
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON dm.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@Board, p2.[Pos], 1))
                WHERE p2.[Col] = emptyCell.[Col]
            ) AS colMask
            OUTER APPLY
            (
                SELECT [UsedMask] = SUM(dm.[BitMask])
                FROM dbo.SudokuPos AS p2
                INNER JOIN dbo.SudokuDigitMask AS dm
                    ON dm.[Digit] =
                       CONVERT(tinyint, SUBSTRING(@Board, p2.[Pos], 1))
                WHERE p2.[Box] = emptyCell.[Box]
            ) AS boxMask
        )
        SELECT TOP (1)
            @BranchPos = candidate.[Pos],
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
            SELECT @BitMask = dm.[BitMask]
            FROM dbo.SudokuDigitMask AS dm
            WHERE dm.[Digit] = @Digit;

            IF (@BranchMask & @BitMask) <> 0
            BEGIN
                INSERT INTO #Stack ([Board])
                VALUES
                (
                    STUFF
                    (
                        @Board,
                        @BranchPos,
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
