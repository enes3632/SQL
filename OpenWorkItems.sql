declare @RPT nvarchar(100)
		,@RSID nvarchar(50)
		,@SQL nvarchar(max)

if OBJECT_ID('tempdb..#temp') is not null drop table #temp

select  bp.ProcessName, 
		rs.Code, 
		rs.ResultSetID as RSID, 
		rs.ResultSetName+'_Archive' as RPT, 
		wi.*
into #temp
from workitems wi
left join resultsets rs on rs.ResultSetID=wi.ResultSetID
left join BusinessProcesses bp on rs.ProcessID=bp.ProcessID
where	bp.ProcessName like '%' 
		and wi.DateClosed is null
		and rs.IsOnline = 1
		and rs.IsDeleted = 0
		--and rs.TypeID = 1

if OBJECT_ID('tempdb..#temp2') is not null drop table #temp2
select distinct RPT into #temp2 from #temp

while exists(select * from #temp2)
begin
	select top(1) @RPT = RPT from #temp2

	if OBJECT_ID('tempdb..#temp3') is not null drop table #temp3

	select * into #temp3 from #temp where RPT = @RPT

		select top(1) @RSID = RSID from #temp3

		set @SQL = '
					select  bp.ProcessName,
							rs.Code,
							case when rs.TypeID = 1 then ''Exceptional'' else ''Informational'' end as ''TestType'',
							rs.Description,
							rs.RiskScore,
							rpt.*
					
					from workitems wi
					left join '+@RPT+' rpt on rpt.[_Monitor_RecordID] = wi.RecordID and wi.ResultsetID = '+@RSID+'
					left join resultsets rs on rs.ResultSetID=wi.ResultSetID
					left join BusinessProcesses bp on rs.ProcessID=bp.ProcessID

					where	wi.DateClosed is null
							and wi.ResultSetID = '+@RSID+'
							and (rs.TypeID = 1
								or (rs.TypeID = 2 and cast(wi.DateFirstDetected as date) between ''2023-06-01'' and cast(getdate() as date)))
					'

		exec sp_executesql @SQL

	delete top(1) from #temp2
end

