UPDATE dbo.SudokuTechnique
SET
    [ImplementationMode] = 'Generalized',
    [Description] = N'Covered by the generalized contradiction and inference stage.'
WHERE [TechniqueName] IN
(
    'Hidden Pair',
    'Hidden Triple',
    'Hidden Quad',
    'XYZ-Wing',
    'ALS-XZ'
);
GO
