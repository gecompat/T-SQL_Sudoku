SET NOCOUNT ON;
SET XACT_ABORT ON;

-------------------------------------------------------------------------------
-- Required objects
-------------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.USP_SudokuSolve', N'P') IS NULL
    THROW 51020, 'Contract test failed: dbo.USP_SudokuSolve is missing.', 1;

IF OBJECT_ID(N'dbo.USP_SudokuValidate', N'P') IS NULL
    THROW 51021, 'Contract test failed: dbo.USP_SudokuValidate is missing.', 1;

IF OBJECT_ID(N'dbo.SudokuPos', N'U') IS NULL
    THROW 51022, 'Contract test failed: dbo.SudokuPos is missing.', 1;

IF OBJECT_ID(N'dbo.SudokuDigitMask', N'U') IS NULL
    THROW 51023, 'Contract test failed: dbo.SudokuDigitMask is missing.', 1;

IF OBJECT_ID(N'dbo.BitCount511', N'U') IS NULL
    THROW 51024, 'Contract test failed: dbo.BitCount511 is missing.', 1;

IF OBJECT_ID(N'dbo.SudokuPeer', N'U') IS NULL
    THROW 51025, 'Contract test failed: dbo.SudokuPeer is missing.', 1;

-------------------------------------------------------------------------------
-- Helper data integrity
-------------------------------------------------------------------------------
IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPos) <> 81
    THROW 51026, 'Contract test failed: dbo.SudokuPos must contain 81 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuDigitMask) <> 9
    THROW 51027, 'Contract test failed: dbo.SudokuDigitMask must contain 9 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.BitCount511) <> 512
    THROW 51028, 'Contract test failed: dbo.BitCount511 must contain 512 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM dbo.SudokuPeer) <> 1620
    THROW 51029, 'Contract test failed: dbo.SudokuPeer must contain 1620 directed rows.', 1;

IF EXISTS
(
    SELECT PositionSource.[Pos]
    FROM dbo.SudokuPos AS PositionSource
    LEFT JOIN dbo.SudokuPeer AS Peer
        ON Peer.[Pos] = PositionSource.[Pos]
    GROUP BY PositionSource.[Pos]
    HAVING COUNT(Peer.[PeerPos]) <> 20
)
BEGIN
    THROW 51030, 'Contract test failed: every Sudoku position must have exactly 20 peers.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.SudokuPeer AS Peer
    WHERE Peer.[Pos] = Peer.[PeerPos]
)
BEGIN
    THROW 51031, 'Contract test failed: a position cannot be its own peer.', 1;
END;

-------------------------------------------------------------------------------
-- English public API
-------------------------------------------------------------------------------
DECLARE @ExpectedSolverParameter TABLE
(
    [ParameterName] sysname NOT NULL PRIMARY KEY,
    [ParameterID] int NOT NULL
);

INSERT INTO @ExpectedSolverParameter
(
    [ParameterName],
    [ParameterID]
)
VALUES
    (N'@Puzzle', 1),
    (N'@Solution', 2),
    (N'@Status', 3),
    (N'@SingleStep', 4),
    (N'@AllowBacktracking', 5),
    (N'@AllowForcing', 6),
    (N'@AllowForcingNets', 7),
    (N'@ValidateInitialState', 8),
    (N'@ValidateFinalResult', 9),
    (N'@MaxIterations', 10),
    (N'@MaxRuntimeMs', 11),
    (N'@MaxForcingChecks', 12),
    (N'@ReturnSolutionPath', 13),
    (N'@ReturnStatistics', 14),
    (N'@PrintMessages', 15),
    (N'@Help', 16);

IF EXISTS
(
    SELECT Expected.[ParameterName], Expected.[ParameterID]
    FROM @ExpectedSolverParameter AS Expected
    EXCEPT
    SELECT ParameterDefinition.[name], ParameterDefinition.[parameter_id]
    FROM sys.parameters AS ParameterDefinition
    WHERE ParameterDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
)
OR EXISTS
(
    SELECT ParameterDefinition.[name], ParameterDefinition.[parameter_id]
    FROM sys.parameters AS ParameterDefinition
    WHERE ParameterDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
    EXCEPT
    SELECT Expected.[ParameterName], Expected.[ParameterID]
    FROM @ExpectedSolverParameter AS Expected
)
BEGIN
    THROW 51032, 'Contract test failed: solver parameter names or order differ from the documented API.', 1;
END;

DECLARE @ExpectedValidatorParameter TABLE
(
    [ParameterName] sysname NOT NULL PRIMARY KEY,
    [ParameterID] int NOT NULL
);

INSERT INTO @ExpectedValidatorParameter
(
    [ParameterName],
    [ParameterID]
)
VALUES
    (N'@Puzzle', 1),
    (N'@MaxSolutions', 2),
    (N'@SolutionCount', 3),
    (N'@FirstSolution', 4),
    (N'@Help', 5);

IF EXISTS
(
    SELECT Expected.[ParameterName], Expected.[ParameterID]
    FROM @ExpectedValidatorParameter AS Expected
    EXCEPT
    SELECT ParameterDefinition.[name], ParameterDefinition.[parameter_id]
    FROM sys.parameters AS ParameterDefinition
    WHERE ParameterDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuValidate', N'P')
)
OR EXISTS
(
    SELECT ParameterDefinition.[name], ParameterDefinition.[parameter_id]
    FROM sys.parameters AS ParameterDefinition
    WHERE ParameterDefinition.[object_id] = OBJECT_ID(N'dbo.USP_SudokuValidate', N'P')
    EXCEPT
    SELECT Expected.[ParameterName], Expected.[ParameterID]
    FROM @ExpectedValidatorParameter AS Expected
)
BEGIN
    THROW 51033, 'Contract test failed: validator parameter names or order differ from the documented API.', 1;
END;

-------------------------------------------------------------------------------
-- Installed procedure definitions must not name local-temp constraints
-------------------------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM sys.sql_modules AS ModuleDefinition
    WHERE ModuleDefinition.[object_id] IN
          (
              OBJECT_ID(N'dbo.USP_SudokuValidate', N'P'),
              OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
          )
      AND
      (
          ModuleDefinition.[definition] LIKE N'%CONSTRAINT [PK_Stack]%'
          OR ModuleDefinition.[definition] LIKE N'%CONSTRAINT [PK_BoardCells]%'
          OR ModuleDefinition.[definition] LIKE N'%CONSTRAINT [PK_TechniqueLog]%'
          OR ModuleDefinition.[definition] LIKE N'%CONSTRAINT [PK_Removal]%'
      )
)
BEGIN
    THROW 51034, 'Contract test failed: named constraints remain on local temporary tables.', 1;
END;

-------------------------------------------------------------------------------
-- Deprecated German public parameter names must not exist
-------------------------------------------------------------------------------
IF EXISTS
(
    SELECT 1
    FROM sys.parameters AS ParameterDefinition
    WHERE ParameterDefinition.[object_id] IN
          (
              OBJECT_ID(N'dbo.USP_SudokuValidate', N'P'),
              OBJECT_ID(N'dbo.USP_SudokuSolve', N'P')
          )
      AND ParameterDefinition.[name] IN
          (
              N'@Hilfe',
              N'@NurEinSchritt',
              N'@ErlaubeBacktracking',
              N'@ErlaubeForcing',
              N'@ErlaubeForcingNets',
              N'@ValidiereStartzustand',
              N'@ValidiereEndergebnis',
              N'@MaxIterationen',
              N'@MaxLaufzeitMs',
              N'@MaxForcingPruefungen',
              N'@ResultsetLoesungspfad',
              N'@ResultsetStatistik',
              N'@PrintMeldungen'
          )
)
BEGIN
    THROW 51035, 'Contract test failed: deprecated German parameter names remain.', 1;
END;

PRINT 'Installation contract tests passed.';