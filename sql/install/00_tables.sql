SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.SudokuPos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SudokuPos
    (
        [Pos] tinyint NOT NULL,
        [Row] tinyint NOT NULL,
        [Col] tinyint NOT NULL,
        [Box] tinyint NOT NULL,
        CONSTRAINT [PK_SudokuPos] PRIMARY KEY CLUSTERED ([Pos]),
        CONSTRAINT [UQ_SudokuPos_RowCol] UNIQUE ([Row], [Col]),
        CONSTRAINT [CK_SudokuPos_Pos] CHECK ([Pos] BETWEEN 1 AND 81),
        CONSTRAINT [CK_SudokuPos_Row] CHECK ([Row] BETWEEN 1 AND 9),
        CONSTRAINT [CK_SudokuPos_Col] CHECK ([Col] BETWEEN 1 AND 9),
        CONSTRAINT [CK_SudokuPos_Box] CHECK ([Box] BETWEEN 1 AND 9)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SudokuPos)
BEGIN
    ;WITH n AS
    (
        SELECT TOP (81)
            [Pos] = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT INTO dbo.SudokuPos
    (
        [Pos],
        [Row],
        [Col],
        [Box]
    )
    SELECT
        CONVERT(tinyint, n.[Pos]),
        CONVERT(tinyint, ((n.[Pos] - 1) / 9) + 1),
        CONVERT(tinyint, ((n.[Pos] - 1) % 9) + 1),
        CONVERT
        (
            tinyint,
            ((((n.[Pos] - 1) / 9) / 3) * 3)
            + (((n.[Pos] - 1) % 9) / 3)
            + 1
        )
    FROM n
    ORDER BY n.[Pos];
END;
GO

IF OBJECT_ID(N'dbo.SudokuDigitMask', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SudokuDigitMask
    (
        [Digit] tinyint NOT NULL,
        [BitMask] smallint NOT NULL,
        CONSTRAINT [PK_SudokuDigitMask] PRIMARY KEY CLUSTERED ([Digit]),
        CONSTRAINT [UQ_SudokuDigitMask_BitMask] UNIQUE ([BitMask]),
        CONSTRAINT [CK_SudokuDigitMask_Digit] CHECK ([Digit] BETWEEN 1 AND 9)
    );
END;
GO

MERGE dbo.SudokuDigitMask AS target
USING
(
    VALUES
        (CONVERT(tinyint, 1), CONVERT(smallint,   1)),
        (CONVERT(tinyint, 2), CONVERT(smallint,   2)),
        (CONVERT(tinyint, 3), CONVERT(smallint,   4)),
        (CONVERT(tinyint, 4), CONVERT(smallint,   8)),
        (CONVERT(tinyint, 5), CONVERT(smallint,  16)),
        (CONVERT(tinyint, 6), CONVERT(smallint,  32)),
        (CONVERT(tinyint, 7), CONVERT(smallint,  64)),
        (CONVERT(tinyint, 8), CONVERT(smallint, 128)),
        (CONVERT(tinyint, 9), CONVERT(smallint, 256))
) AS source([Digit], [BitMask])
ON target.[Digit] = source.[Digit]
WHEN MATCHED THEN
    UPDATE SET target.[BitMask] = source.[BitMask]
WHEN NOT MATCHED THEN
    INSERT ([Digit], [BitMask])
    VALUES (source.[Digit], source.[BitMask]);
GO

IF OBJECT_ID(N'dbo.BitCount511', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BitCount511
    (
        [Mask] smallint NOT NULL,
        [BitCount] tinyint NOT NULL,
        CONSTRAINT [PK_BitCount511] PRIMARY KEY CLUSTERED ([Mask]),
        CONSTRAINT [CK_BitCount511_Mask] CHECK ([Mask] BETWEEN 0 AND 511),
        CONSTRAINT [CK_BitCount511_BitCount] CHECK ([BitCount] BETWEEN 0 AND 9)
    );
END;
GO

IF (SELECT COUNT_BIG(*) FROM dbo.BitCount511) <> 512
BEGIN
    DELETE FROM dbo.BitCount511;

    ;WITH n AS
    (
        SELECT TOP (512)
            [Mask] = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    )
    INSERT INTO dbo.BitCount511
    (
        [Mask],
        [BitCount]
    )
    SELECT
        CONVERT(smallint, n.[Mask]),
        CONVERT
        (
            tinyint,
              CASE WHEN (n.[Mask] &   1) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &   2) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &   4) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &   8) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &  16) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &  32) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] &  64) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] & 128) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (n.[Mask] & 256) <> 0 THEN 1 ELSE 0 END
        )
    FROM n
    ORDER BY n.[Mask];
END;
GO

IF OBJECT_ID(N'dbo.SudokuTechnique', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SudokuTechnique
    (
        [SortOrder] smallint NOT NULL,
        [TechniqueName] varchar(64) NOT NULL,
        [TechniqueFamily] varchar(32) NOT NULL,
        [ImplementationMode] varchar(16) NOT NULL,
        [IsDefaultEnabled] bit NOT NULL,
        [Description] nvarchar(500) NOT NULL,
        CONSTRAINT [PK_SudokuTechnique] PRIMARY KEY CLUSTERED ([SortOrder]),
        CONSTRAINT [UQ_SudokuTechnique_Name] UNIQUE ([TechniqueName]),
        CONSTRAINT [CK_SudokuTechnique_Mode]
            CHECK ([ImplementationMode] IN ('Explicit', 'Generalized'))
    );
END;
GO

MERGE dbo.SudokuTechnique AS target
USING
(
    VALUES
        ( 10, 'Naked Single',            'Singles',          'Explicit',    1, N'Only one candidate remains in a cell.'),
        ( 20, 'Hidden Single',           'Singles',          'Explicit',    1, N'Only one position remains for a digit in a house.'),
        ( 30, 'Naked Pair',              'Subsets',          'Explicit',    1, N'Two cells contain the same two candidates.'),
        ( 40, 'Hidden Pair',             'Subsets',          'Explicit',    1, N'Two digits occur only in the same two cells.'),
        ( 50, 'Pointing',                'Locked Candidates','Explicit',    1, N'Box candidates are restricted to one row or column.'),
        ( 60, 'Claiming',                'Locked Candidates','Explicit',    1, N'Row or column candidates are restricted to one box.'),
        ( 70, 'Naked Triple',            'Subsets',          'Explicit',    1, N'Three cells contain exactly three combined candidates.'),
        ( 80, 'Hidden Triple',           'Subsets',          'Explicit',    1, N'Three digits occur only in the same three cells.'),
        ( 90, 'Naked Quad',              'Subsets',          'Explicit',    1, N'Four cells contain exactly four combined candidates.'),
        (100, 'Hidden Quad',             'Subsets',          'Explicit',    1, N'Four digits occur only in the same four cells.'),
        (110, 'X-Wing',                  'Fish',             'Explicit',    1, N'Basic fish of size two.'),
        (120, 'Finned X-Wing',           'Fish',             'Generalized', 1, N'Covered by fish premises and inference search.'),
        (130, 'Sashimi X-Wing',          'Fish',             'Generalized', 1, N'Covered by fish premises and inference search.'),
        (140, 'Skyscraper',              'Single Digit',     'Generalized', 1, N'Covered by the single-digit inference engine.'),
        (150, 'Two-String Kite',         'Single Digit',     'Generalized', 1, N'Covered by the single-digit inference engine.'),
        (160, 'Empty Rectangle',         'Single Digit',     'Generalized', 1, N'Covered by grouped single-digit inference.'),
        (170, 'Swordfish',               'Fish',             'Explicit',    1, N'Basic fish of size three.'),
        (180, 'Finned Swordfish',        'Fish',             'Generalized', 1, N'Covered by fish premises and inference search.'),
        (190, 'Sashimi Swordfish',       'Fish',             'Generalized', 1, N'Covered by fish premises and inference search.'),
        (200, 'Jellyfish',               'Fish',             'Explicit',    1, N'Basic fish of size four.'),
        (210, 'Finned Jellyfish',        'Fish',             'Generalized', 0, N'Covered by bounded fish premises and inference search.'),
        (220, 'Sashimi Jellyfish',       'Fish',             'Generalized', 0, N'Covered by bounded fish premises and inference search.'),
        (230, 'XY-Wing',                 'Wings',            'Explicit',    1, N'Three-cell bivalue wing.'),
        (240, 'XYZ-Wing',                'Wings',            'Explicit',    1, N'Trivalue pivot with two bivalue wings.'),
        (250, 'W-Wing',                  'Wings',            'Generalized', 1, N'Covered by bivalue inference.'),
        (260, 'Simple Coloring',         'Coloring',         'Generalized', 1, N'Covered by strong-link component inference.'),
        (270, 'Multi-Coloring',          'Coloring',         'Generalized', 1, N'Covered by multi-component inference.'),
        (280, 'Remote Pairs',            'Chains',           'Generalized', 1, N'Covered by bivalue chain inference.'),
        (290, 'X-Chain',                 'Chains',           'Generalized', 1, N'Covered by single-digit AIC search.'),
        (300, 'XY-Chain',                'Chains',           'Generalized', 1, N'Covered by bivalue AIC search.'),
        (310, 'AIC',                     'Chains',           'Generalized', 1, N'Alternating inference over candidate nodes.'),
        (320, 'Continuous Nice Loop',    'Loops',            'Generalized', 1, N'Closed alternating inference loop.'),
        (330, 'Discontinuous Nice Loop', 'Loops',            'Generalized', 1, N'Loop contradiction forces a candidate state.'),
        (340, 'Grouped AIC',             'Grouped Chains',   'Generalized', 1, N'Inference includes grouped house intersections.'),
        (350, 'ALS-XZ',                  'ALS',              'Explicit',    1, N'Two non-overlapping ALS connected by an RCC.'),
        (360, 'ALS-AIC',                 'ALS',              'Generalized', 1, N'ALS transitions participate in inference search.'),
        (370, 'Kraken Fish',             'Last Resort',      'Generalized', 0, N'Fish premises are evaluated by bounded forcing branches.'),
        (380, 'Forcing Chain',           'Last Resort',      'Generalized', 1, N'Contradiction and common-consequence proof.'),
        (390, 'Forcing Net',             'Last Resort',      'Generalized', 0, N'Bounded branching proof search.'),
        (400, 'Backtracking',            'Search',           'Explicit',    1, N'Independent complete fallback and validator.')
) AS source
(
    [SortOrder],
    [TechniqueName],
    [TechniqueFamily],
    [ImplementationMode],
    [IsDefaultEnabled],
    [Description]
)
ON target.[TechniqueName] = source.[TechniqueName]
WHEN MATCHED THEN
    UPDATE SET
        target.[SortOrder] = source.[SortOrder],
        target.[TechniqueFamily] = source.[TechniqueFamily],
        target.[ImplementationMode] = source.[ImplementationMode],
        target.[IsDefaultEnabled] = source.[IsDefaultEnabled],
        target.[Description] = source.[Description]
WHEN NOT MATCHED THEN
    INSERT
    (
        [SortOrder],
        [TechniqueName],
        [TechniqueFamily],
        [ImplementationMode],
        [IsDefaultEnabled],
        [Description]
    )
    VALUES
    (
        source.[SortOrder],
        source.[TechniqueName],
        source.[TechniqueFamily],
        source.[ImplementationMode],
        source.[IsDefaultEnabled],
        source.[Description]
    );
GO
