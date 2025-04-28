--select * from ResultSetTemplates rst left join resultsets rs on rs.ResultSetID=rst.ResultSetID where code like 'ap003h'

declare @Script nvarchar(max),
		@ResultSetFilter nvarchar(25),
		@RSID nvarchar(25),
		@html nvarchar(max),
		@html2 nvarchar(max) = '',
		@headings nvarchar(max),
		@DisplayName nvarchar(50),
		@ColumnName1 nvarchar(50),
		@ColumnName2 nvarchar(50),
		@DataType nvarchar(50), 
		@Width nvarchar(1), 
		@Icon nvarchar(30),
		@code varchar(50),
		@Execute bit

set @ResultSetFilter = '%er00[1234]%' --Can be a like statement
set @Execute = 0 --Set 1 to execute changes for all

drop table if exists #Overview, #RSIDs, #Script
select resultsetid, code 
into #RSIDs from resultsets rs
where rs.IsOnline=1 and IsDeleted=0 and TypeID=1 and rs.Code not like 'his%'
	and code like @ResultSetFilter

create table #Script (Script nvarchar(max), Code varchar(50), Overview char(20))
create table #Overview (DisplayName nvarchar(50), ColumnName1 nvarchar(50), ColumnName2 nvarchar(50), DataType nvarchar(50), Width int, Icon nvarchar(30))

--ColumnName1 can be null if it is the same as the DisplayName. Replaces spaces with underscores.
--Use ColumnName2 if needs to add another column next to it like InvoiceAmount + Currency
--Specify the DataType if needed ::NUMFORMAT(N2)', '::SHORTDATETIMEFORMAT(UTC, dd MMM yyyy)', '::NUMFORMAT("c",en-AU)' etc.
--Specify the Width. Usually between 1 and 4.
--Specify the icon. Visit https://nitw.ac.in/tlc/elements/font-icons.htm for all the available icons.

insert into #Overview
values --DisplayName,		ColumnName1,		ColumnName2,	DataType,				Width,	Icon

		('Vendor Status',	null,				null,			null,					1,		'fa-tag'),
		('Vendor Number',	null,				null,			null,					2,		'fa-tag'),
		('Vendor Name',		null,				null,			null,					3,		'fa-building'),
		('Invoice Number',	null,				null,			null,					2,		'fa-bell'),
		('Invoice Amount',	null,				null,			'::NUMFORMAT("c",en-AU)',		2,		'fa-money'),
		('Invoice Date',	null,				null,			'::SHORTDATETIMEFORMAT(UTC, dd MMM yyyy)',	1,		'fa-calendar')

while (select count(*) from #RSIDs) != 0
begin
	select top(1) 
		@RSID = cast(resultsetid as nvarchar(25)),
		@code = code
	from #RSIDs

	drop table if exists #temp
	select * into #temp from #Overview

	while (select count(*) from #temp) != 0
	begin
	
		select top(1)
			@DisplayName = DisplayName,
			@ColumnName1 = isnull(ColumnName1,replace(@DisplayName,' ','_')),
			@ColumnName2 = ColumnName2,
			@DataType	 = isnull(DataType,''),
			@Width		 = cast(Width as nvarchar(1)),
			@Icon		 = Icon
		from #temp

	set @html2 = @html2 + 
		'
			<div id="cards" class="col-md-'+@Width+'">
				<div class="panel panel-primary">
					<div class="panel-heading" role="tab"> <i id=''icon'' class="fa '+@icon+'"></i><strong style = "color:#fff;"> 
						'+@DisplayName+'
					</div>
					<div class="panel-body figure">
						#-ResultSet.'+@RSID+'.'+@ColumnName1+@DataType+'-# '+
						case
							when @ColumnName2 is not null then '#-ResultSet.'+@RSID+'.'+@ColumnName2+'-#'
							else ''
						end
						+'
					</div>
				</div>
			</div>
		'
		delete top(1) from #temp
	end

	set @html = '
		<link href="/Content/Styles/App/Bootstrap.min.css" type="text/css" rel="stylesheet">
		<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.4.0/css/font-awesome.min.css">
		<style>  
		.panel-heading #icon {display: inline-block; font: normal normal normal 14px/1 FontAwesome !important; font-size: 90%; text-rendering: auto; -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale; color:#fff}
		#cards .panel {background-color: #fff; border-color: #17375E; margin-bottom:0px;}
		#cards .panel-heading {border-color: #17375E; background-color: #17375E; padding: 2px 0px; text-align: center; font-size: 90%;}
		#cards .panel-body {padding: 3px;}
		#cards .figure {font-size:110%; text-align:center; color: black;}
		</style>
		<div class="container-fluid">
			<div class="row">'
			+ @html2 + '
				<div id="cards" class="col-md-1">
					<div class="panel panel-primary">
						<div class="panel-heading" role="tab">
							<i id=''icon'' class="fa fa-envelope"></i><strong style = "color:#fff;"> Contact Us                
						</div>
						<div class="panel-body figure"> 
							<a href="mailto:satorisupport@satoriassured.com"> SATORI </a>     
						</div>
					</div>
				</div> 
			</div>
		</div>'
	
	insert into #script
	select 'Update ResultSetTemplates Set TemplateDetails=''' + replace(@html,'''icon''','''''icon''''') + ''' where ResultSetID='+@RSID+' and TemplateTypeID=1' as 'Script',
		@code as 'Code',
		'Overview' as 'Overview'
	

	set @html2 = ''
	delete top(1) from #RSIDs
end

if @Execute = 0 
	select * from #script order by code
else
	while (select count(*) from #script) != 0
	begin
		select top(1) @Script=script from #script
		exec sp_executesql @Script
		delete top(1) from #script
	end
