/* Clone result set templates and gridview settings to the historical ones -esahin */

declare @Overview nvarchar(max) 
		,@Detail nvarchar(max)
		,@RSCopyFrom nvarchar(max)
		,@RSSummaryFrom nvarchar(max)
		,@RSDetailFrom nvarchar(max)
		,@RSCopyTo nvarchar(max)
		,@RSSummaryTo nvarchar(max)
		,@RSDetailTo nvarchar(max)
		,@RSReversalFrom nvarchar(max)
		,@RSReversalTo nvarchar(max)

drop table if exists #temptable
create table #temptable (Script nvarchar(max)
						,CopyFrom nvarchar(50)
						,CopyTo nvarchar(50)
						,Summary nvarchar(50)
						,Detail nvarchar(50)
						,Reversal nvarchar(50)
						,TemplateType nvarchar(25))

drop table if exists #RSIDs
select ResultSetID 
into #RSIDs from resultsets 
where IsOnline= 1 and IsDeleted=0 and TypeID=1
and CODE LIKE 'his_ap0%' --update which historicals to clone to

while (select count(*) from #RSIDs)!=0
begin

set @RSCopyTo = (select top(1) ResultSetID  from #RSIDs)
set @RSCopyFrom = (select resultsetid from resultsets where code = (select replace(code,'his_','') from resultsets where ResultSetID=@RSCopyTo))

set @RSSummaryFrom = isnull((select resultsetid from resultsets where code = (select code from resultsets where ResultSetID=@RSCopyFrom)+'S'),'1')
set @RSDetailFrom = isnull((select resultsetid from resultsets where code = (select code from resultsets where ResultSetID=@RSCopyFrom)+'D'),'1')
set @RSReversalFrom = isnull((select resultsetid from resultsets where code = (select replace(replace(replace(code,'L',''),'M',''),'H','') from resultsets where ResultSetID=@RSCopyFrom)+'X'),'1')

set @RSSummaryTo = isnull((select resultsetid from resultsets where code = (select code from resultsets where ResultSetID=@RSCopyTo)+'S'),'1')
set @RSDetailTo = isnull((select resultsetid from resultsets where code = (select code from resultsets where ResultSetID=@RSCopyTo)+'D'),'1')
set @RSReversalTo = isnull((select resultsetid from resultsets where code = (select 'HIS'+replace(replace(replace(replace(code,'L',''),'M',''),'HIS',''),'H','') from resultsets where ResultSetID=@RSCopyTo)+'X'),'1')

set @Overview = replace(
					replace(
						replace(
							replace(
								replace((select templatedetails 
										from ResultSetTemplates
										where ResultSetID = @RSCopyFrom and TemplateTypeID = 1)
								,@RSCopyFrom,@RSCopyTo)
							,'''icon''','''''icon''''')
						,@RSSummaryFrom,@RSSummaryTo)
					,@RSDetailFrom,@RSDetailTo)
				,@RSReversalFrom,@RSReversalTo)
				
set @detail =	replace(
					replace(
						replace(
							replace(
								replace((select templatedetails 
										from ResultSetTemplates
										where ResultSetID = @RSCopyFrom and TemplateTypeID = 2)
								,@RSCopyFrom,@RSCopyTo)
							,'''icon''','''''icon''''')
						,@RSSummaryFrom,@RSSummaryTo)
					,@RSDetailFrom,@RSDetailTo)
				,@RSReversalFrom,@RSReversalTo)
				
insert into #temptable (script,CopyFrom,CopyTo,Summary,Detail,Reversal,TemplateType)
values( 'Update ResultSetTemplates Set TemplateDetails='''+@Overview+''' where ResultSetID='+@RSCopyTo+' and TemplateTypeID=1' 
		,(select code from resultsets where ResultSetID=@RSCopyFrom)
		,(select code from resultsets where ResultSetID=@RSCopyTo)
		,(select code from resultsets where ResultSetID=@RSSummaryTo)
		,(select code from resultsets where ResultSetID=@RSDetailTo)
		,(select code from resultsets where ResultSetID=@RSReversalTo)
		,'Overview')

insert into #temptable (script,CopyFrom,CopyTo,Summary,Detail,Reversal,TemplateType)
values( 'Update ResultSetTemplates Set TemplateDetails='''+@Detail+''' where ResultSetID='+@RSCopyTo+' and TemplateTypeID=2'
		,(select code from resultsets where ResultSetID=@RSCopyFrom)
		,(select code from resultsets where ResultSetID=@RSCopyTo)
		,(select code from resultsets where ResultSetID=@RSSummaryTo)
		,(select code from resultsets where ResultSetID=@RSDetailTo)
		,(select code from resultsets where ResultSetID=@RSReversalTo)
		,'Detail')

insert into #temptable (script,CopyFrom,CopyTo,Summary,Detail,Reversal,TemplateType)
values( 'Update GlobalResultSetColumnJsonSettings Set ColumnJsonSettings = (select ColumnJsonSettings from GlobalResultSetColumnJsonSettings where ResultSetID='+@RSCopyFrom+') where ResultSetID='+@RSCopyTo
		,(select code from resultsets where ResultSetID=@RSCopyFrom)
		,(select code from resultsets where ResultSetID=@RSCopyTo)
		,'N/A','N/A','N/A'
		,'GridViewJsonSettings')

delete top(1) from #RSIDs
end

select isnull(script,'--No Template Configured--') as 'Script',
		CopyFrom,
		CopyTo,
		isnull(Summary,'N/A') as 'Summary',
		isnull(Detail,'N/A') as 'Detail',
		isnull(Reversal,'N/A') as 'Reversal',
		TemplateType
from #temptable order by TemplateType,CopyTo