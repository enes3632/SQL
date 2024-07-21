/*** This query adds the same action to multiple workflows -esahin ***/

declare @ActionID int, @Action nvarchar(20), @UserIDs nvarchar(max), @push bit, @exec nvarchar(max), @code nvarchar(100), @workflow nvarchar(100), @StartState nvarchar(50), @EndState nvarchar(50), @RequiredFields nvarchar(4)

--The users in the start state will be enabled in the action.
--Does not create an action if the start state has no user.
--Does not tick the indicators. Use the incdicator update query.
--Does not duplicate the existing actions.

set @Action = '%'	 --This can be a like statement. Safe to execute as long as @Push = 0

--Filter the results after setting the state. They can be a like statement.
set @code = '%' 
set @Workflow = '%'
set @StartState = '%'
set @EndState = '%'
set @RequiredFields =	null	-- 1-Comment, 2-Indicator, 3-PredefinedComment, 4-Attachment

set @Push = 0	--First switch 0 to see the results. Update the above filters if required and then switch 1 to push the updates.

if (select count(*) from WorkflowActions where isnull(workflowActionName,replace(ResourceKey,'WorkflowActions_','')) like @Action) = 1 and @Push = 0
	begin
		drop table if exists #commands
		set @ActionID = (Select WorkflowActionID from WorkflowActions where isnull(workflowActionName,replace(ResourceKey,'WorkflowActions_','')) like @Action)
		
		set @Action = (select isnull(WorkflowActionName,replace(ResourceKey,'WorkflowActions_','')) from WorkflowActions where WorkflowActionID=@ActionID)

		drop table if exists #Excludes --Gets the list of existing actions to prevent duplications 
		select concat(rsc.ConditionID, ws1.WorkflowStateID, ws2.WorkflowStateID) as 'EX'
		into #Excludes
		from resultsets rs 
			left join ResultSetConditions rsc on rsc.ResultSetID=rs.ResultSetID
			left join ConditionWorkflowActions cwa on cwa.ConditionID=rsc.ConditionID
			left join ConditionWorkflowStates cws1 on cws1.ConditionStateID=cwa.StartConditionStateID
			left join WorkflowStates ws1 on ws1.WorkflowStateID = cws1.WorkflowStateID
			left join ConditionWorkflowStates cws2 on cws2.ConditionStateID=cwa.EndConditionStateID
			left join WorkflowStates ws2 on ws2.WorkflowStateID = cws2.WorkflowStateID
		where cwa.WorkflowActionID = @ActionID and cwa.isdeleted = 0 

		select	Query + string_agg(ActionPrinciples,',') +''','''',1' as 'Query' ,Code ,Workflow ,StartState ,EndState ,ActionToAdd ,string_agg(PrincipleNames,' | ') within group (order by PrincipleNames) as 'UsersToAdd' 
		into #commands
		from (
				select 'exec [dbo].[st_rw_AddConditionWorkflowAction] ' + cast(rsc.conditionid as nvarchar(max)) + ',' + cast(@ActionID  as nvarchar(max)) + ',2,'+ cast(cwss.ConditionStateID as nvarchar(max)) +','+  cast(cwse.ConditionStateID as nvarchar(max)) +',3,0,0,0,null,''' as 'Query'
					,rs.code as 'Code'
					,isnull(rsc.ConditionName,'Default') as 'Workflow'
					,isnull(wss.WorkflowStateName,replace(wss.ResourceKey, 'WorkflowStates_', '')) as 'StartState'
					,isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', '')) as 'EndState'
					,@Action as 'ActionToAdd'
					,u.userid as 'ActionPrinciples'
					,u.username as 'PrincipleNames'
				from  ResultSetConditions rsc 
					left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
					left join ConditionWorkflowStates cwss on  cwss.ConditionID=rsc.conditionid
					left join WorkflowStates wss on cwss.WorkflowStateID = wss.WorkflowStateID
					left join ConditionWorkflowStates cwse on cwss.ConditionID=cwse.conditionid
					left join WorkflowStates wse on cwse.WorkflowStateID = wse.WorkflowStateID
					left join ConditionWorkflowStatePrincipals cwsp on cwss.ConditionStateID=cwsp.ConditionStateID
					left join users u on u.userid=cwsp.principalid
				where u.UserID is not null
					and rs.IsDeleted = 0 
					and rs.IsOnline = 1
					and rs.TypeID = 1
					and cwse.IsDeleted = 0
					and cwss.IsDeleted = 0
					and concat(rsc.ConditionID,wss.WorkflowStateID,wse.WorkflowStateID) not in (select ex from #Excludes)
			) a
		group by Query, Code, Workflow, StartState, EndState, ActionToAdd
		having StartState != 'Start' and EndState != 'Start' and StartState != EndState
			and code like @code 
			and Workflow like @Workflow
			and StartState like @StartState
			and EndState like @EndState
		
	if (select top(1) Query from #commands) is not null
		begin
			select * from #commands order by code, workflow, StartState, EndState
		end
	else
		begin
			Select 'No results to show. Update your filters.' as '********ErrorMessage********'
		end
	end

else if @Push = 1 and object_id('tempdb..#commands') is null
	begin
		select 'There is nothing to push. Please update the filters.' as '********ErrorMessage********'
	end

else if @Push = 1 and object_id('tempdb..#commands') is not null
	begin
		begin transaction
			while (select top(1) Query from #commands) is not null
				begin
					set @exec =  (select top(1) Query  from #commands)
					exec sp_executesql @exec
					delete top(1) from #commands
				end
		if @@error <> 0
			begin
				rollback transaction
				print 'The transaction rolled back due to an error: ' + convert(varchar(max),error_message())
			end
		else
			begin
				commit transaction
				print 'Updates pushed successfully!'
			end
	end
else
	begin
		drop table if exists #commands
		select 'Error - Please use a valid action name-->' as '********ErrorMessage********', replace(isnull(workflowActionName,resourcekey),'WorkflowActions_','') as 'ValidActions' from WorkflowActions
	end
