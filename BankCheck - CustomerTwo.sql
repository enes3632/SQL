/* CustomerTwo Daily Bank Check Report -esahin */

declare @CustomerwoCMSDataLoad int
		,@CustomerTwoJDEDataLoad int
		,@DataChangedCountJDE int
		,@DataChangedCountCMS int
		,@DataChangedCheckedJDE int
		,@DataChangedCheckedCMS int
		,@DataChangedRaisedJDE int
		,@DataChangedRaisedCMS int
		,@DataChangeExJDE int
		,@DataChangeExCMS int
		,@DataProvisionDateJDE datetime
		,@DataProvisionDateCMS datetime
		,@BC0V int
		,@BC0H int

drop table if exists #alessa
select	max(cast(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date)) as 'ExceptionRaisedOn',
		replace(replace(db_name(),'CCM_',''),'_alessa','') as 'Customer',
		case
			when rs.code like '%jde' then 'JDE'
			when rs.code like '%cms' then 'CMS'
			else 'N/A'
		end as 'SourceSystem',
		format(max(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time'),'yyyy-MM-dd HH:mm') as 'ExceptionLoadTime',
		count(*) as 'NumberOfItems',
		rs.code as'Code'

into #alessa	
from CCM_CustomerTwo_ALESSA.SchemaThree.WorkItems wi
left join CCM_CustomerTwo_ALESSA.SchemaThree.resultsets rs on rs.ResultSetID=wi.ResultSetID
left join CCM_CustomerTwo_ALESSA.SchemaThree.BusinessProcesses bp on rs.ProcessID=bp.ProcessID

where	bp.ProcessName = 'bank check'
		and cast(wi.DateFirstDetected AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date) = dateadd(day,-0,cast(getdate() as date))
		--and rs.code not in ('BC0V','BC0H')

group by	case
				when rs.code like '%jde%' then 'JDE'
				when rs.code like '%cms%' then 'CMS'
				else 'N/A'
			end,
			rs.code

select @DataChangedRaisedJDE = isnull(sum(NumberOfItems),0) from #alessa where Code like '%JDE' and code not in ('BC0V','BC0H')
select @DataChangedRaisedCMS = isnull(sum(NumberOfItems),0) from #alessa where Code like '%CMS' and code not in ('BC0V','BC0H')

drop table if exists #cte, #cte2
select 
	case 
		when BANKCHECK_Response_Code = 'Match'
			then 'BC001'+Source_System
		when BANKCHECK_Response_Code = 'WeakMatch'
			then 'BC002'+Source_System
		when BANKCHECK_Response_Code = 'NotEnoughInfo'
			then 'BC003'+Source_System
		when BANKCHECK_Response_Code = 'NotFound' 
			then 'BC004'+Source_System
		when BANKCHECK_Response_Code = 'NoMatch'
			then 'BC005'+Source_System
		when BANKCHECK_Details_Complete_Flag in ('Incomplete','Blank','Invalid')
			then 'BC011'+Source_System
		else isnull(isnull(BANKCHECK_Response_Code,BANKCHECK_Details_Complete_Flag),'Null')+'-'+Source_System
	end as 'TestCode'
	,*

into #cte
FROM  CCM_CustomerTwo.[SchemaOne].[BANKCHECK_PREP_CHANGES_Vendor_Bank_Account]
where cast(Latest_Import_Date as date) = dateadd(day,-0,cast(getdate() as date))

select TestCode, count(*) as 'DataChanged (Count)' 
into #cte2 
from #cte 
group by TestCode

drop table if exists #IncludedExceptions
select TestCode
into #IncludedExceptions
from #cte cte
left join [SchemaTwo].[MAP_PREPARATION_Vendors] vnd on vnd.Vendor_ID=cte.Vendor_ID
where  cast(cte.Latest_Import_Date as date) = dateadd(day,-0,cast(getdate() as date))
		and cte.Latest_Import_Date > '2024-01-25 17:49:15.660' 
		AND ISNULL(cte.BSB,'') <> 'No Change' 
		AND	ISNULL(cte.Bank_Account_Number,'') <> 'No Change' 
		AND	ISNULL(cte.Bank_Account_Name,'') <> 'No Change'
		and NOT (	ISNULL(TestCode,'') IN ('BC011JDE','BC011CMS') AND 
					ISNULL(UPPER(TRIM(vnd.Country)),'') <> '' AND
					(ISNULL(UPPER(TRIM(vnd.Country)),'') NOT LIKE 'AU%' OR ISNULL(UPPER(TRIM(vnd.Country)),'') = 'AUSTRIA')		)

select @DataChangedCheckedJDE = count(*) from #IncludedExceptions where TestCode like '%JDE'
select @DataChangedCheckedCMS = count(*) from #IncludedExceptions where TestCode like '%CMS'
	
select @DataProvisionDateJDE = Date_Archived
FROM [SchemaTwo].[Archived_Data_Files]
where cast(Date_Archived as date) = dateadd(day,-0,cast(getdate() as date) )
and File_Name like 'JDE_Vendor_BankAccounts_%'

select @DataProvisionDateCMS = Date_Archived
FROM [SchemaTwo].[Archived_Data_Files]
where cast(Date_Archived as date) = dateadd(day,-0,cast(getdate() as date) )
and File_Name like 'CMS_Vendor_BankAccounts_%'

set @CustomerTwoJDEDataLoad = (select count(*) from [CCM_CustomerTwo].[SchemaTwo].[CUMULATIVE_JDE_Vendor_BankAccounts])
set @CustomerTwoCMSDataLoad = (select count(*) from [CCM_CustomerTwo].[SchemaTwo].[CUMULATIVE_CMS_Vendor_BankAccounts])

set @DataChangedCountJDE = (select count(*) from [SchemaOne].[BANKCHECK_PREP_CHANGES_Vendor_Bank_Account]
							where cast(Latest_Import_Date as date) = dateadd(day,-0,cast(getdate() as date)) and Source_System = 'JDE')
set @DataChangedCountCMS = (select count(*) from [SchemaOne].[BANKCHECK_PREP_CHANGES_Vendor_Bank_Account] 
							where cast(Latest_Import_Date as date) = dateadd(day,-0,cast(getdate() as date)) and Source_System = 'CMS'  )

set @DataChangeExJDE = @DataChangedCountJDE - @DataChangedCheckedJDE
set @DataChangeExCMS = @DataChangedCountCMS - @DataChangedCheckedCMS


select	ExceptionRaisedOn,
		Customer, 
		SourceSystem,
		DataProvisionDate, 
		DataProvisionTime,
		case 
			when min(ExceptionLoadTime) != max(ExceptionLoadTime) 
				then cast(format(min(ExceptionLoadTime), 'hh:mm tt') as varchar(10)) + ' - ' + cast(format(max(ExceptionLoadTime), 'hh:mm tt') as varchar(10))
			else cast(format(max(ExceptionLoadTime),'hh:mm tt') as varchar(10))
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
			cast(ExceptionLoadTime as datetime) as 'ExceptionLoadTime',
			case
				when SourceSystem = 'JDE' then cast(@DataProvisionDateJDE as date) 
				when SourceSystem = 'CMS' then cast(@DataProvisionDateCMS as date) 
			end as 'DataProvisionDate',
			case
				when SourceSystem = 'JDE' then format(@DataProvisionDateJDE, 'hh:mm tt')
				when SourceSystem = 'CMS' then format(@DataProvisionDateCMS, 'hh:mm tt')
			end as 'DataProvisionTime',
			case
				when SourceSystem = 'JDE' then @CustomerTwoJDEDataLoad
				when SourceSystem = 'CMS' then @CustomerTwoCMSDataLoad
			end as 'DataLoad (Count)',
			case
				when SourceSystem = 'JDE' then @DataChangedCountJDE
				when SourceSystem = 'CMS' then @DataChangedCountCMS
			end as 'DataChanged (Count)',
			case 
				when SourceSystem = 'JDE' then @DataChangeExJDE 
				when SourceSystem = 'CMS' then @DataChangeExCMS
			end as 'Excluded (not AU) (Count)',
			case 
				when SourceSystem = 'JDE' then @DataChangedRaisedJDE 
				when SourceSystem = 'CMS' then @DataChangedRaisedCMS
			end as 'Exceptions (Count)',
			case when TestCode like 'BC001%' then NumberOfItems else 0 end as 'BC001',
			case when TestCode like 'BC002%' then NumberOfItems else 0 end as 'BC002',
			case when TestCode like 'BC003%' then NumberOfItems else 0 end as 'BC003',
			case when TestCode like 'BC004%' then NumberOfItems else 0 end as 'BC004',
			case when TestCode like 'BC005%' then NumberOfItems else 0 end as 'BC005',
			case when TestCode like 'BC011%' then NumberOfItems else 0 end as 'BC011'

	from #alessa a
	full outer join #cte2 c on a.code=c.TestCode
	where a.code not in ('BC0V','BC0H')
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

-- if @DataChangedCheckedCMS != @DataChangedRaisedCMS or @DataChangedCheckedJDE != @DataChangedRaisedJDE
-- begin
-- 	select 'Missing Exceptions' as 'Message', * from #cte where TestCode not in (select code from #alessa)
-- end

;drop table if exists #ClientReport
;with cte3 as (
	select	rs.Code,
			DisplayName,
			Case
				when TypeID = 1 then 'Exceptional'
				else 'Informational'
			end as 'ReportType'
	from CCM_CustomerTwo_ALESSA.SchemaThree.resultsets rs
	left join CCM_CustomerTwo_ALESSA.SchemaThree.BusinessProcesses bp on rs.ProcessID=bp.ProcessID
	where bp.ProcessName = 'bank check' and rs.IsOnline=1

)
--, BC0V as (
--	select 'BC0V' as 'Code',
--			count(*) as 'BC0V_Count', 
--			Source_System
--	from CCM_CustomerTwo_ALESSA.SchemaThree.8351_Archive
--	where cast(_Monitor_RunDate AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date) = dateadd(day,-0,cast(getdate() as date))
--	group by Source_System
--), BC0H as (
--	select 'BC0H' as 'Code',
--			count(*) as 'BC0H_Count', 
--			Source_System
--	from CCM_CustomerTwo_ALESSA.SchemaThree.8347_Archive
--	where cast(_Monitor_RunDate AT TIME ZONE 'UTC' AT TIME ZONE 'AUS Eastern Standard Time' as date) = dateadd(day,-0,cast(getdate() as date))
--	group by Source_System
--)

select	cte3.DisplayName,
		case
			when i.TestCode is not null and cte3.DisplayName like '%JDE.%' then i.NumberOfItems
			--when cte4.NumberOfExceptions is null and cte3.Code = 'BC0V' then vcms.BC0V_Count
			--when cte4.NumberOfExceptions is null and cte3.Code = 'BC0H' then hcms.BC0H_Count
			else '0'
		end as 'JDENumberOfWorkItems',
		case
			when i.TestCode is not null and cte3.DisplayName like '%CMS.%' then i.NumberOfItems
			--when cte4.NumberOfExceptions is null and cte3.Code = 'BC0V' then vcms.BC0V_Count
			--when cte4.NumberOfExceptions is null and cte3.Code = 'BC0H' then hcms.BC0H_Count
			else '0'
		end as 'CMSNumberOfWorkItems',
		cte3.ReportType

into #ClientReport
from (select TestCode, count(*) as 'NumberOfItems' from #IncludedExceptions group by TestCode) i
Full join cte3 on cte3.Code=i.TestCode
--left join BC0V vjde on vjde.Code=cte3.code and vjde.Source_System = 'JDE'
--left join BC0V vcms on vcms.Code=cte3.code and vcms.Source_System = 'CMS'
--left join BC0H hjde on hjde.Code=cte3.code and hjde.Source_System = 'JDE'
--left join BC0H hcms on hcms.Code=cte3.code and hcms.Source_System = 'CMS'

select DisplayName, JDENumberOfWorkItems, ReportType
from #ClientReport
where DisplayName like '%JDE.%' --or DisplayName like 'BC0[VH]%'
order by DisplayName

select DisplayName, CMSNumberOfWorkItems, ReportType
from #ClientReport
where DisplayName like '%CMS.%' --or DisplayName like 'BC0[VH]%'
order by DisplayName

select * from #cte order by TestCode
