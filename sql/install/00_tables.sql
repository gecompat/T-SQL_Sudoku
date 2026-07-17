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

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPos) <> 81
BEGIN
    DELETE FROM dbo.SudokuPos;

    ;WITH NumberSource AS
    (
        SELECT TOP (81)
            [Pos] = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
        FROM sys.all_objects AS ObjectA
        CROSS JOIN sys.all_objects AS ObjectB
    )
    INSERT INTO dbo.SudokuPos
    (
        [Pos],
        [Row],
        [Col],
        [Box]
    )
    SELECT
        CONVERT(tinyint, NumberSource.[Pos]),
        CONVERT(tinyint, ((NumberSource.[Pos] - 1) / 9) + 1),
        CONVERT(tinyint, ((NumberSource.[Pos] - 1) % 9) + 1),
        CONVERT
        (
            tinyint,
            ((((NumberSource.[Pos] - 1) / 9) / 3) * 3)
            + (((NumberSource.[Pos] - 1) % 9) / 3)
            + 1
        )
    FROM NumberSource
    ORDER BY NumberSource.[Pos];
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

DECLARE @ExpectedDigitMask TABLE
(
    [Digit] tinyint NOT NULL PRIMARY KEY,
    [BitMask] smallint NOT NULL UNIQUE
);

INSERT INTO @ExpectedDigitMask
(
    [Digit],
    [BitMask]
)
VALUES
    (1,   1),
    (2,   2),
    (3,   4),
    (4,   8),
    (5,  16),
    (6,  32),
    (7,  64),
    (8, 128),
    (9, 256);

UPDATE Target
SET Target.[BitMask] = Source.[BitMask]
FROM dbo.SudokuDigitMask AS Target
INNER JOIN @ExpectedDigitMask AS Source
    ON Source.[Digit] = Target.[Digit]
WHERE Target.[BitMask] <> Source.[BitMask];

INSERT INTO dbo.SudokuDigitMask
(
    [Digit],
    [BitMask]
)
SELECT
    Source.[Digit],
    Source.[BitMask]
FROM @ExpectedDigitMask AS Source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SudokuDigitMask AS Target
    WHERE Target.[Digit] = Source.[Digit]
);

DELETE Target
FROM dbo.SudokuDigitMask AS Target
WHERE NOT EXISTS
(
    SELECT 1
    FROM @ExpectedDigitMask AS Source
    WHERE Source.[Digit] = Target.[Digit]
);
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

    ;WITH NumberSource AS
    (
        SELECT TOP (512)
            [Mask] = ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1
        FROM sys.all_objects AS ObjectA
        CROSS JOIN sys.all_objects AS ObjectB
    )
    INSERT INTO dbo.BitCount511
    (
        [Mask],
        [BitCount]
    )
    SELECT
        CONVERT(smallint, NumberSource.[Mask]),
        CONVERT
        (
            tinyint,
              CASE WHEN (NumberSource.[Mask] &   1) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &   2) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &   4) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &   8) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &  16) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &  32) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] &  64) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] & 128) <> 0 THEN 1 ELSE 0 END
            + CASE WHEN (NumberSource.[Mask] & 256) <> 0 THEN 1 ELSE 0 END
        )
    FROM NumberSource
    ORDER BY NumberSource.[Mask];
END;
GO

IF OBJECT_ID(N'dbo.SudokuPeer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SudokuPeer
    (
        [Pos] tinyint NOT NULL,
        [PeerPos] tinyint NOT NULL,
        CONSTRAINT [PK_SudokuPeer] PRIMARY KEY CLUSTERED ([Pos], [PeerPos]),
        CONSTRAINT [CK_SudokuPeer_DifferentPositions] CHECK ([Pos] <> [PeerPos])
    );
END;
GO

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPeer) <> 1620
BEGIN
    DELETE FROM dbo.SudokuPeer;

    INSERT INTO dbo.SudokuPeer
    (
        [Pos],
        [PeerPos]
    )
    SELECT
        SourcePos.[Pos],
        PeerPos.[Pos]
    FROM dbo.SudokuPos AS SourcePos
    INNER JOIN dbo.SudokuPos AS PeerPos
        ON PeerPos.[Pos] <> SourcePos.[Pos]
       AND
       (
           PeerPos.[Row] = SourcePos.[Row]
           OR PeerPos.[Col] = SourcePos.[Col]
           OR PeerPos.[Box] = SourcePos.[Box]
       );
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

DECLARE @ExpectedTechnique TABLE
(
    [SortOrder] smallint NOT NULL PRIMARY KEY,
    [TechniqueName] varchar(64) NOT NULL UNIQUE,
    [TechniqueFamily] varchar(32) NOT NULL,
    [ImplementationMode] varchar(16) NOT NULL,
    [IsDefaultEnabled] bit NOT NULL,
    [Description] nvarchar(500) NOT NULL
);

INSERT INTO @ExpectedTechnique
(
    [SortOrder],
    [TechniqueName],
    [TechniqueFamily],
    [ImplementationMode],
    [IsDefaultEnabled],
    [Description]
)
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
    (120, 'Finned X-Wing',           'Fish',             'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (130, 'Sashimi X-Wing',          'Fish',             'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (140, 'Skyscraper',              'Single Digit',     'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (150, 'Two-String Kite',         'Single Digit',     'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (160, 'Empty Rectangle',         'Single Digit',     'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (170, 'Swordfish',               'Fish',             'Explicit',    1, N'Basic fish of size three.'),
    (180, 'Finned Swordfish',        'Fish',             'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (190, 'Sashimi Swordfish',       'Fish',             'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (200, 'Jellyfish',               'Fish',             'Explicit',    1, N'Basic fish of size four.'),
    (210, 'Finned Jellyfish',        'Fish',             'Generalized', 0, N'Covered by bounded candidate contradiction proofs.'),
    (220, 'Sashimi Jellyfish',       'Fish',             'Generalized', 0, N'Covered by bounded candidate contradiction proofs.'),
    (230, 'XY-Wing',                 'Wings',            'Explicit',    1, N'Three-cell bivalue wing.'),
    (240, 'XYZ-Wing',                'Wings',            'Explicit',    1, N'Trivalue pivot with two bivalue wings.'),
    (250, 'W-Wing',                  'Wings',            'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (260, 'Simple Coloring',         'Coloring',         'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (270, 'Multi-Coloring',          'Coloring',         'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (280, 'Remote Pairs',            'Chains',           'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (290, 'X-Chain',                 'Chains',           'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (300, 'XY-Chain',                'Chains',           'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (310, 'AIC',                     'Chains',           'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (320, 'Continuous Nice Loop',    'Loops',            'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (330, 'Discontinuous Nice Loop', 'Loops',            'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (340, 'Grouped AIC',             'Grouped Chains',   'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (350, 'ALS-XZ',                  'ALS',              'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (360, 'ALS-AIC',                 'ALS',              'Generalized', 1, N'Covered by bounded candidate contradiction proofs.'),
    (370, 'Kraken Fish',             'Last Resort',      'Generalized', 0, N'Covered by bounded candidate contradiction proofs.'),
    (380, 'Forcing Chain',           'Last Resort',      'Generalized', 1, N'Candidate contradiction and common-consequence proof.'),
    (390, 'Forcing Net',             'Last Resort',      'Generalized', 0, N'Bounded premise search.'),
    (400, 'Backtracking',            'Search',           'Explicit',    1, N'Independent complete fallback and validator.');

UPDATE Target
SET
    Target.[SortOrder] = Source.[SortOrder],
    Target.[TechniqueFamily] = Source.[TechniqueFamily],
    Target.[ImplementationMode] = Source.[ImplementationMode],
    Target.[IsDefaultEnabled] = Source.[IsDefaultEnabled],
    Target.[Description] = Source.[Description]
FROM dbo.SudokuTechnique AS Target
INNER JOIN @ExpectedTechnique AS Source
    ON Source.[TechniqueName] = Target.[TechniqueName]
WHERE Target.[SortOrder] <> Source.[SortOrder]
   OR Target.[TechniqueFamily] <> Source.[TechniqueFamily]
   OR Target.[ImplementationMode] <> Source.[ImplementationMode]
   OR Target.[IsDefaultEnabled] <> Source.[IsDefaultEnabled]
   OR Target.[Description] <> Source.[Description];

INSERT INTO dbo.SudokuTechnique
(
    [SortOrder],
    [TechniqueName],
    [TechniqueFamily],
    [ImplementationMode],
    [IsDefaultEnabled],
    [Description]
)
SELECT
    Source.[SortOrder],
    Source.[TechniqueName],
    Source.[TechniqueFamily],
    Source.[ImplementationMode],
    Source.[IsDefaultEnabled],
    Source.[Description]
FROM @ExpectedTechnique AS Source
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.SudokuTechnique AS Target
    WHERE Target.[TechniqueName] = Source.[TechniqueName]
);

DELETE Target
FROM dbo.SudokuTechnique AS Target
WHERE NOT EXISTS
(
    SELECT 1
    FROM @ExpectedTechnique AS Source
    WHERE Source.[TechniqueName] = Target.[TechniqueName]
);
GO

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPos) <> 81
    THROW 50400, 'dbo.SudokuPos must contain exactly 81 rows.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.SudokuPos
    GROUP BY [Row], [Col]
    HAVING COUNT_BIG(*) <> 1
)
    THROW 50401, 'dbo.SudokuPos contains an invalid row and column mapping.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuDigitMask) <> 9
    THROW 50402, 'dbo.SudokuDigitMask must contain exactly 9 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.BitCount511) <> 512
    THROW 50403, 'dbo.BitCount511 must contain exactly 512 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPeer) <> 1620
    THROW 50404, 'dbo.SudokuPeer must contain exactly 1,620 directed peer rows.', 1;

IF EXISTS
(
    SELECT [Pos]
    FROM dbo.SudokuPeer
    GROUP BY [Pos]
    HAVING COUNT_BIG(*) <> 20
)
    THROW 50405, 'Each Sudoku position must have exactly 20 peers.', 1;
GO