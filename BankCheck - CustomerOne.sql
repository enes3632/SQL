/*** CustomerOne Bank Check Daily Report -esahin ***/

declare @CustomerOneDataLoad int
		,@DataChangedCount int
		,@DataChangedChecked int
		,@DataChangedRaised int
		,@DataChangeEx int
		,@DataProvisionDate datetime

drop table if exists #alessa
select	max(cast(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date)) as 'ExceptionRaisedOn',
		replace(replace(db_name(),'CCM_',''),'_alessa','') as 'Customer',
		'N/A' AS 'SourceSystem',
		format(max(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time'),'yyyy-MM-dd hh:mm') as 'ExceptionLoadTime',
		count(*) as 'NumberOfItems',
		rs.code as'Code'

into #alessa
from CCM_CustomerOne_ALESSA.dbo.WorkItems wi
left join CCM_CustomerOne_ALESSA.dbo.resultsets rs on rs.ResultSetID=wi.ResultSetID
left join CCM_CustomerOne_ALESSA.dbo.BusinessProcesses bp on rs.ProcessID=bp.ProcessID

where	bp.ProcessName = 'bank check'
		and cast(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date) = dateadd(day,-0,cast(getdate() as date))
		and rs.code not in ('BC0V','BC0H')

group by rs.code

select @DataChangedRaised = isnull(sum(NumberOfItems),0) from #alessa

drop table if exists #cte, #cte2
select 
	case 
		when BANKCHECK_Response_Code = 'Match'
			then 'BC001' 
		when BANKCHECK_Response_Code = 'WeakMatch'
			then 'BC002'
		when BANKCHECK_Response_Code = 'NotEnoughInfo'
			then 'BC003'
		when BANKCHECK_Response_Code = 'NotFound' 
			then 'BC004'
		when BANKCHECK_Response_Code = 'NoMatch'
			then 'BC005'
		when BANKCHECK_Details_Complete_Flag in ('Incomplete','Blank')
			then 'BC011'
		else isnull(isnull(BANKCHECK_Response_Code,BANKCHECK_Details_Complete_Flag),'Null')
	end as 'TestCode'
	,*
into #cte
FROM SchemaOne.BANKCHECK_PREP_Vendor_Bank_Account_Changes
--order by Latest_Import_Date desc
where (	
		(DATENAME(weekday, GETDATE()) != 'Monday' and cast(Latest_Import_Date as date) = dateadd(day,-1,cast(getdate() as date )))
			or
		(DATENAME(weekday, GETDATE()) = 'Monday'  and cast(Latest_Import_Date as date) >= dateadd(day,-3,cast(getdate() as date)))
		)

select TestCode, count(*) as 'DataChanged (Count)'		
into #cte2
from #cte
group by TestCode

select @DataChangedChecked = count(*)
from #cte cte
left join [SchemaOne].MAP_PREP_Vendors vnd on vnd.Vendor_ID=cte.Vendor_ID
where    -- Report is not blank.
ISNULL(cte.TestCode,'') <> ''
-- And not (BC011 or BC012 and vendor country is not Australia).
AND NOT (
ISNULL(cte.TestCode,'') IN ('BC011','BC012') AND 
ISNULL(UPPER(TRIM(vnd.Country)),'') <> '' AND
(ISNULL(UPPER(TRIM(vnd.Country)),'') NOT LIKE 'AU%' OR ISNULL(UPPER(TRIM(vnd.Country)),'') = 'AUSTRIA')
)

SELECT @DataProvisionDate = Date_Archived, 
	@CustomerOneDataLoad = cast([No_Of_Rows] as int) -1
FROM [SchemaOne].[Archived_Data_Files]
where cast(Date_Archived as date) = dateadd(day,-0,cast(getdate() as date) )
and File_Name like 'vendor_master%'

set @DataChangedCount = (select count(*) FROM SchemaOne.BANKCHECK_PREP_Vendor_Bank_Account_Changes
						 where (	
								(DATENAME(weekday, GETDATE()) != 'Monday' and cast(Latest_Import_Date as date) = dateadd(day,-1,cast(getdate() as date )))
									or
								(DATENAME(weekday, GETDATE()) = 'Monday'  and cast(Latest_Import_Date as date) >= dateadd(day,-3,cast(getdate() as date)))
								)
						)
set @DataChangeEx = @DataChangedCount - @DataChangedChecked

if @DataChangedChecked != @DataChangedRaised
begin
	select 'Missing Exceptions' as 'Message', * from #cte where Vendor_ID not in (select Vendor_ID from #alessa)
end

select	ExceptionRaisedOn,
		Customer,
		SourceSystem,
		DataProvisionDate,
		DataProvisionTime,
		case 
			when min(ExceptionLoadTime)!=max(ExceptionLoadTime) 
				then cast(format(min(ExceptionLoadTime), 'hh:mm tt') as nvarchar(10))+ ' - ' +cast(format(max(ExceptionLoadTime), 'hh:mm tt') as nvarchar(10))
			else cast(format(max(ExceptionLoadTime), 'hh:mm tt') as nvarchar(10))
		end as 'ExceptionLoadTime',
		[DataLoad (Count)],
		[DataChanged (Count)],
		[Excluded (not AU) (Count)],
		[Exceptions (Count)],
		sum(BC001) as 'BC001',
		sum(BC002) as 'BC002',
		sum(BC003) as 'BC003',
		sum(BC004) as 'BC004',
		sum(BC005) as 'BC005',
		sum(BC011) as 'BC011'
from (
	select	ExceptionRaisedOn, 
			Customer, 
			SourceSystem, 
			cast(@DataProvisionDate as date) as 'DataProvisionDate', 
			format(@DataProvisionDate, 'hh:mm tt') as 'DataProvisionTime', 
			cast(ExceptionLoadTime as datetime) as 'ExceptionLoadTime',
			@CustomerOneDataLoad as 'DataLoad (Count)',
			@DataChangedCount as 'DataChanged (Count)',
			@DataChangeEx as 'Excluded (not AU) (Count)',
			@DataChangedRaised as 'Exceptions (Count)',
			case when TestCode like 'BC001%' then NumberOfItems else 0 end as 'BC001',
			case when TestCode like 'BC002%' then NumberOfItems else 0 end as 'BC002',
			case when TestCode like 'BC003%' then NumberOfItems else 0 end as 'BC003',
			case when TestCode like 'BC004%' then NumberOfItems else 0 end as 'BC004',
			case when TestCode like 'BC005%' then NumberOfItems else 0 end as 'BC005',
			case when TestCode like 'BC011%' then NumberOfItems else 0 end as 'BC011'

	from #alessa a
	full outer join #cte2 c on a.code=c.TestCode
) a

group by	ExceptionRaisedOn,
			Customer,
			SourceSystem,
			DataProvisionDate,
			DataProvisionTime,
			[DataLoad (Count)],
			[DataChanged (Count)],
			[Excluded (not AU) (Count)],
			[Exceptions (Count)]

select * from #cte2 order by TestCode
select * from #cte order by TestCode
