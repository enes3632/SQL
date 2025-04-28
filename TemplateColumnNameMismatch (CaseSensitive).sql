declare @SQL nvarchar(max) = '
	 create FUNCTION dbo.fn_st_FindAllMatches
	(
		@inputString NVARCHAR(MAX),
		@pattern NVARCHAR(MAX)
	)
	RETURNS @Matches TABLE
	(
		MatchIndex INT,
		MatchValue NVARCHAR(MAX)
	)
	AS
	BEGIN
	--Receives the string value and the pattern to search in and finds all the matches and return as a table.

	DECLARE @patternLength INT = LEN(@pattern);
	DECLARE @inputLength INT = LEN(@inputString);

	WITH MatchesCTE AS (
		-- Anchor: First match
		SELECT 
			MatchIndex = PATINDEX(''%'' + @pattern + ''%'', @inputString),
			SearchOffset = CAST(0 AS INT)
		WHERE PATINDEX(''%'' + @pattern + ''%'', @inputString) > 0

		UNION ALL

		-- Recursive: continue after the previous match
		SELECT 
			MatchIndex = PATINDEX(''%'' + @pattern + ''%'', 
								  SUBSTRING(@inputString, 
											CAST(SearchOffset + MatchIndex + @patternLength AS INT), 
											@inputLength)
								 ),
			SearchOffset = CAST(SearchOffset + MatchIndex + @patternLength - 1 AS INT)
		FROM MatchesCTE
		WHERE PATINDEX(''%'' + @pattern + ''%'', 
					   SUBSTRING(@inputString, 
								 CAST(SearchOffset + MatchIndex + @patternLength AS INT), 
								 @inputLength)
					  ) > 0
	)

	insert into @Matches
	SELECT 
		MatchPosition = SearchOffset + MatchIndex,
		MatchValue = SUBSTRING(@inputString, SearchOffset + MatchIndex, @patternLength)
 
	FROM MatchesCTE
	OPTION (MAXRECURSION 0);

		RETURN;
	END;'

 begin try
	begin tran
		if object_id('dbo.fn_st_FindAllMatches','FN') is null
			begin
				exec sp_executesql @SQL
			end
	commit tran
 end try	
 begin catch
	if @@TRANCOUNT > 0
		rollback transaction

		SELECT 
				ERROR_NUMBER() AS ErrorNumber,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_STATE() AS ErrorState,
				ERROR_PROCEDURE() AS ErrorProcedure,
				ERROR_LINE() AS ErrorLine,
				ERROR_MESSAGE() AS ErrorMessage

 end catch;

SELECT
    rs.Code [ParentRS]
	,'n/a' [ChildRS]
    ,rsc.SourceColumnName
	,f.MatchValue
	,('#-ResultSet.' + CAST(rs.ResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName COLLATE Latin1_General_CS_AS) [SearchedWord]
    ,f.MatchIndex
	,CASE
        WHEN rt.TemplateTypeID = 1 THEN 'Overview'
        ELSE 'Detail'
    END AS TemplateType
    ,rt.TemplateDetails
	
FROM ResultSetColumns rsc
JOIN ResultSets rs ON rs.ResultSetID = rsc.ResultSetID
JOIN ResultSetTemplates rt ON rt.ResultSetID = rsc.ResultSetID
LEFT JOIN BusinessProcesses bp ON bp.ProcessID = rs.ProcessID
cross apply dbo.fn_st_FindAllMatches( rt.TemplateDetails, '#-ResultSet.' + CAST(rs.ResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName) f

WHERE
    rt.TemplateDetails IS NOT NULL

	and f.MatchValue != ('#-ResultSet.' + CAST(rs.ResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName COLLATE Latin1_General_CS_AS)

union all

SELECT
    rs.Code [ParentRS]
	,rs1.code [ChildRS]
    ,rsc.SourceColumnName
	,f.MatchValue
	,('#-ResultSet.' + CAST(rs.ResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName COLLATE Latin1_General_CS_AS) [SearchedWord]
    ,f.MatchIndex
	,CASE
        WHEN rt.TemplateTypeID = 1 THEN 'Overview'
        ELSE 'Detail'
    END AS TemplateType
    ,rt.TemplateDetails

FROM ResultSetColumns rsc
left join ResultSetLinks RSL on RSL.ChildResultSetID = rsc.ResultSetID
left join resultsets rs1 on rs1.ResultSetID = RSL.ChildResultSetID
left join ResultSets rs on rs.ResultSetID = rsl.ParentResultSetID
JOIN ResultSetTemplates rt ON rs.ResultSetID = rt.ResultSetID
cross apply dbo.fn_st_FindAllMatches( rt.TemplateDetails, '#-ResultSet.' + CAST(RSL.ChildResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName) f

WHERE
    rt.TemplateDetails IS NOT NULL

	and f.MatchValue != ('#-ResultSet.' + CAST(RSL.ChildResultSetID AS NVARCHAR(100)) + '.' + rsc.SourceColumnName COLLATE Latin1_General_CS_AS)

ORDER BY
    rs.Code,
	[ChildRS],
	TemplateType,
    rsc.SourceColumnName;

