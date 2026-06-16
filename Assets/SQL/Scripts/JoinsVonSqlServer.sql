WITH TablesWithReference
AS (
SELECT  obj.name AS FK_NAME,
    sch.name AS [schema_name],
    tab1.name AS [table],
    col1.name AS [column],
    tab2.name AS [referenced_table], 
    col2.name AS [referenced_column]
FROM sys.foreign_key_columns fkc
INNER JOIN sys.objects obj
    ON obj.object_id = fkc.constraint_object_id
INNER JOIN sys.tables tab1
    ON tab1.object_id = fkc.parent_object_id
INNER JOIN sys.schemas sch
    ON tab1.schema_id = sch.schema_id
INNER JOIN sys.columns col1
    ON col1.column_id = parent_column_id AND col1.object_id = tab1.object_id
INNER JOIN sys.tables tab2
    ON tab2.object_id = fkc.referenced_object_id
INNER JOIN sys.columns col2
    ON col2.column_id = referenced_column_id AND col2.object_id = tab2.object_id
)
SELECT 

--SUBSTRING(FK_NAME, 5, LEN(FK_NAME)),
--SUBSTRING(FK_NAME, 5, 3),
--   [schema_name],
--    STRING_AGG([column],', ') as ColOrig,
--    STRING_AGG([referenced_column],', ') as Colref,
concat(SUBSTRING([table],1,3), '_', SUBSTRING([referenced_table],1,3) ),
STRING_AGG(SUBSTRING([column], 5, LEN([column])) ,'; ') as Parent,
STRING_AGG(SUBSTRING([referenced_column], 5, LEN([referenced_column])) ,'; ') as Child
FROM TablesWithReference
	
GROUP BY FK_NAME,[schema_name],[table],[referenced_table]