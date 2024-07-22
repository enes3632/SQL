/* Creates multiple auto-escalations from the same principle to multiple assignees based on a conditions -esahin */

declare @TransitionTo nvarchar(max) = '1,2,3' -- Set the user/role IDs
	,@TimeUnit int = 1 -- 1-Min / 2-Hour / 3-Day
	,@AfterElapsedTime int = 1 -- Set the time for the escalation
	,@isActive bit = 1 -- Set if you want it to be enabled at first.
	,@resultSetCodeFilter nvarchar(100) = '%ap00[2348]%'  -- Set a Result Set Code Filter
	,@UseAdvancedFilter bit = 0 --If 1 adjust the below 
	,@TransitionQuery nvarchar(max) = '[ColumnName]=''''11''''' 
	,@Part int = 1 --1 for creating the escalations. 2 for adding the principles
--------------------------------------------------------------------------------------------------
	,@AssignTo int
	,@userName nvarchar(50) = current_user
	,@userID nvarchar(10)

set @userName = replace(@userName, 'SATORICLD\', '')

if @userName in (select UserName from Users)
	select @userID = convert(nvarchar, UserID)
	from Users
	where UserName = @userName
else
	set @userID = '3' -- Default administrator

drop table if exists #tmp,#exec
select value as 'AssignTo' into #tmp from string_split(@TransitionTo, ',')

create table #exec (TransitionQuery nvarchar(max)
					,DisplayName nvarchar(max)
					,Workflow nvarchar(max)
					,TransitionTo nvarchar(max)
					,ActionName nvarchar(max)
					,StartState nvarchar(max)
					,EndState nvarchar(max))

while exists(select * from #tmp) and @Part = 1

begin 

select top(1) @AssignTo = AssignTo from #tmp

insert into #exec
select 'INSERT INTO [dbo].[ConditionWorkflowActionAutoTransitions]
		   ([ConditionActionID],[TransitionToPrincipalID],[IsAutoClose],[IsActive],[TransitionQuery],[DateEventTriggerID],[TriggerDateTypeID],[AfterElapsedTime],[TimeIntervalID],[AfterElapsedTimeInMinutes]
		   ,[Created],[CreatedBy],[Modified],[ModifiedBy],[UseAdvancedFilter])
		Values (
			' + convert(nvarchar(max), cwa.ConditionActionID) + ',
			' + convert(nvarchar(max), @AssignTo) + ',
			0,
			' + convert(nvarchar(max), @isActive) + ',
			'+ case when @UseAdvancedFilter = 0 then 'null' 
				else '''(([' + rs.ResultSetName + '_Archive].'+ @TransitionQuery +'))''' end +',
			1,
			1,
			' + convert(nvarchar(max), @AfterElapsedTime) + ',
			' + convert(nvarchar(max), @TimeUnit) +',
			'+case 
				when @TimeUnit = 1 then convert(nvarchar(max), @AfterElapsedTime)
				when @TimeUnit = 2 then convert(nvarchar(max), @AfterElapsedTime * 60 )
				when @TimeUnit = 3 then convert(nvarchar(max), @AfterElapsedTime * 60 * 24)
			end + ',
			GETUTCDATE(),
			''' + convert(nvarchar(max), @userName) + ''',
			GETUTCDATE(),
			''' + convert(nvarchar(max), @userName) + ''',
			' + convert(nvarchar(max), @UseAdvancedFilter) 
		+ ')' as 'TransitionQuery'
		,rs.DisplayName
		,isnull(rsc.ConditionName, 'Default') as 'Workflow'
		,isnull(u.UserName,ur.RoleName) as 'TransitionTo'
		,isnull(wa.WorkflowActionName, wa.ResourceKey) as ActionName
		,isnull(wss.WorkflowStateName, wss.ResourceKey) as StartState
		,isnull(wse.WorkflowStateName, wse.ResourceKey) as EndState
FROM [ConditionWorkflowActions] cwa
LEFT JOIN ResultSetConditions rsc ON rsc.ConditionID = cwa.ConditionID
LEFT JOIN ResultSets rs ON rs.ResultSetID = rsc.ResultSetID
LEFT JOIN BusinessProcesses bp ON bp.ProcessID = rs.ProcessID
LEFT JOIN WorkflowActions wa ON wa.[WorkflowActionID] = cwa.[WorkflowActionID]
LEFT JOIN [ConditionWorkflowStates] cwss ON cwss.ConditionStateID = cwa.StartConditionStateID
LEFT JOIN WorkflowStates wss ON wss.[WorkflowStateID] = cwss.[WorkflowStateID]
LEFT JOIN [ConditionWorkflowStates] cwse ON cwse.ConditionStateID = cwa.EndConditionStateID
LEFT JOIN WorkflowStates wse ON wse.[WorkflowStateID] = cwse.[WorkflowStateID]
left join users u on u.userid = @AssignTo
left join userroles ur on ur.RoleID = @AssignTo
--left join principals p on cwa.StartConditionStateID = p.ConditionStateID
--left join principals p2 on cwa.EndConditionStateID = p2.ConditionStateID
where  --@TransitionTo in (select value from string_split(p2.principals, ','))	and 
	rs.Code like @resultSetCodeFilter
	and isnull(wa.WorkflowActionName, wa.ResourceKey) like '%assign'
	and isnull(wss.WorkflowStateName, wss.ResourceKey) like '%assigned'

delete top(1) from #tmp

end

drop table if exists #tmp1, #exec1
create table #exec1 (Query nvarchar(max)
					)

;with cte as (select TransitionID
				from ConditionWorkflowActionAutoTransitions
				group by TransitionID)

select TransitionID
into #tmp1
from cte
where TransitionID not in (select TransitionID from ConditionTransitionPrincipals)

while exists(select * from #tmp1) and @Part=2
begin

select top(1) @AssignTo = TransitionID from #tmp1

insert into #exec1
select 'INSERT INTO [dbo].[ConditionTransitionPrincipals]
		Values (
		'+ convert(nvarchar(max),@AssignTo) +',
		'+ convert(nvarchar(max),isnull(uf.UserID, urf.RoleID)) +',
		GETUTCDATE(),
		''' + convert(nvarchar(max), @userName) + ''',
		GETUTCDATE(),
		''' + convert(nvarchar(max), @userName) + '''
		)' as Query
FROM [ConditionWorkflowActions] cwa
LEFT JOIN ResultSetConditions rsc ON rsc.ConditionID = cwa.ConditionID
LEFT JOIN ResultSets rs ON rs.ResultSetID = rsc.ResultSetID
LEFT JOIN BusinessProcesses bp ON bp.ProcessID = rs.ProcessID
LEFT JOIN WorkflowActions wa ON wa.[WorkflowActionID] = cwa.[WorkflowActionID]
LEFT JOIN [ConditionWorkflowStates] cws ON cws.ConditionStateID = cwa.StartConditionStateID
LEFT JOIN WorkflowStates ws ON ws.[WorkflowStateID] = cws.[WorkflowStateID]
left join ConditionWorkflowActionAutoTransitions cwaat on cwaat.ConditionActionID = cwa.ConditionActionID
left join [ConditionWorkflowStatePrincipals] cwsp on cws.[ConditionStateID] = cwsp.[ConditionStateID]
left join Users uf on cwsp.PrincipalID = uf.UserID
left join UserRoles urf on cwsp.PrincipalID = urf.RoleID

where cwaat.TransitionID = @AssignTo

delete top(1) from #tmp1

end

if exists(select * from #exec)
begin select * from #exec order by DisplayName end

if exists(select * from #exec1)
begin select * from #exec1 end


