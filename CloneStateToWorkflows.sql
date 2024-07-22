/* This query clones an existing state to the other workflows -esahin */

declare @StateID int, @UsesRoleIDs nvarchar(max), @State nvarchar(50), @push bit, @exec nvarchar(max), @X nvarchar(4), @Y nvarchar(4), @code nvarchar(100), @workflow nvarchar(100), @CloneRSCode nvarchar(100), @CloneWorkflow nvarchar(100), @RS int,@CondID int,@PrinciplesToCopy nvarchar(100), @CopyRoles bit, @users nvarchar(max), @count int, @ClonedCode nvarchar(100), @ClonedWorkflow nvarchar(100), @ExcCodes nvarchar(100), @ExcWorkflows nvarchar(100)

--Find a state to clone. They can be a like statement but the combination must return only one value because only one state can be cloned at a time. You can update the filters and run it to see the filtered results.
set @CloneRSCode = '%'
set @CloneWorkflow = '%'
set @State = '%'

--Filter the results after setting the clone state. You can include or exclude RSCodes and/or workflows. They can be a like statement.
--Excludes the workflows that already have the cloned state.
set @Code = '%'
set @workflow = '%'
set @ExcCodes = '%'			
set @ExcWorkflows = '%'

--To add users/roles, you can either provide the exact name of the state that you want to copy the users/roles from in each workflow or provide the list of user/role IDs directly.
set @PrinciplesToCopy = 'assigned' --Exact state name 'assigned' etc. or comma-separated user/role IDs like '308,320'.
set @CopyRoles = 1 --Set to 0 to exclude roles. Works only when you provide a state name above.

set @Push = 0	--First switch 0 to see the results. Update the above filters if required and then switch 1 to push the updates.


set @count = (	select count(*) 
				from ConditionWorkflowStates cws
				left join ResultSetConditions rsc on rsc.ConditionID=cws.ConditionID
				left join resultsets rs on rs.ResultSetID=rsc.ResultSetID
				left join WorkflowStates ws on ws.WorkflowStateID=cws.WorkflowStateID
				where rs.Code like @CloneRSCode 
					and isnull(rsc.ConditionName, 'Default') like @CloneWorkflow 
					and isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')) like @state
					and cws.IsDeleted = 0)
if	@count = 1
	and @Push = 0 
	and @PrinciplesToCopy != ''
	begin

	select	@rs = rs.resultsetid, 
			@CondID = rsc.ConditionID, 
			@StateID = ws.WorkflowStateID,
			@ClonedCode = rs.code,
			@ClonedWorkflow = isnull(rsc.ConditionName, 'Default'),
			@State = isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')),
			@X = cws.XCoordinate,
			@Y = cws.YCoordinate
	from ConditionWorkflowStates cws
	left join ResultSetConditions rsc on rsc.ConditionID=cws.ConditionID
	left join resultsets rs on rs.ResultSetID=rsc.ResultSetID
	left join WorkflowStates ws on ws.WorkflowStateID=cws.WorkflowStateID
	where rs.Code like @CloneRSCode 
		and isnull(rsc.ConditionName, 'Default') like @CloneWorkflow 
		and isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')) like @state

	if PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) = 0 --means user/role IDs are provided directly.
		begin
			set @users = (	select string_agg(username,',') 
							from (	select userid,username 
									from users 
										union 
									select roleid, rolename 
									from userroles	) a 
							where UserID in (select value from string_split(@PrinciplesToCopy,','))	)
		end

	drop table if exists #commands;
	with cte as (
		select	concat(Query1,Query2) as 'Query',
				Code,
				Workflow,
				Clonning,
				[Users/RolesToAdd],
				StateID, 
				string_agg(UsersComingFrom,', ') as 'UsersComingFrom' 
		from (
			select 'exec [dbo].[st_rw_AddConditionWorkflowState] ' + cast(rsc.conditionid as nvarchar(max)) + ',' + cast(@stateid  as nvarchar(max)) + ',1,' + @X + ',' + @Y + ',130,60,0,0,3,0,0,2,' as 'Query1',
					case 
						when string_agg(cast(isnull(u.UserID,ur.RoleID) as nvarchar(max)),',') is null and PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) != 0
							then 'null,3,0,0,1,null,null,null,null,null,null,1' 
						when PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) = 0 
							then '''' + @PrinciplesToCopy + ''',3,0,0,1,null,null,null,null,null,null,1'
						else '''' + string_agg(cast(isnull(u.UserID,ur.RoleID) as nvarchar(max)),',') + ''',3,0,0,1,null,null,null,null,null,null,1'
					end as 'Query2', 
					rs.code as 'Code',
					isnull(rsc.ConditionName,'Default') as 'Workflow',
					@ClonedCode + ' - ' + @ClonedWorkflow + ' - ' + @State as 'Clonning', 
					case 
						when PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) != 0 
							then isnull(string_agg(cast(isnull(u.UserName,ur.RoleName) as nvarchar(max)),','),'Null')
						else  @users
					end as 'Users/RolesToAdd',
					@stateid as 'StateID',
					case 
						when PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) != 0 
							then isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_',''))
						else 'Null' 
					end as 'UsersComingFrom'
			from ConditionWorkflowStates cws
				left join ResultSetConditions rsc on rsc.ConditionID=cws.ConditionID
				left join resultsets rs on rs.ResultSetID=rsc.ResultSetID
				left join WorkflowStates ws on ws.WorkflowStateID=cws.WorkflowStateID 
				left join ConditionWorkflowStatePrincipals cwsp on cwsp.ConditionStateID=cws.ConditionStateID
				left join users u on u.UserID = cwsp.PrincipalID
				left join userroles ur on ur.RoleID = cwsp.PrincipalID
			where cws.IsDeleted = 0
				and rs.IsDeleted = 0 
				and rs.IsOnline = 1
				and rs.TypeID = 1
				and rsc.ConditionID != @CondID
				and (@ExcCodes = '%' or (@ExcCodes != '%' and rs.code not like @ExcCodes))
				and (@ExcWorkflows = '%' or (@ExcWorkflows != '%' and isnull(rsc.ConditionName,'Default') not like @ExcWorkflows))
				and (
						(	PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) != 0 
							and (ISNULL(ws.WorkflowStateName, REPLACE(ws.ResourceKey, 'WorkflowStates_', '')) = @PrinciplesToCopy)
							and (@CopyRoles = 1 or (@CopyRoles = 0 and ur.RoleID is null))	)
						or
						(	PATINDEX('%[a-zA-Z]%', @PrinciplesToCopy) = 0
							and (@CopyRoles = 1 or (@CopyRoles = 0 and ur.RoleID is null))	)
					)
				 
			group by rsc.conditionid, rs.code, isnull(rsc.ConditionName, 'Default'), cws.WorkflowStateID ,isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_',''))
				) a 
		group by concat(Query1,Query2),Code,Workflow,Clonning,[Users/RolesToAdd],StateID
		having Code like @code and Workflow like @workflow
		)
	,cte2 as (
		select 	rs.code, 
				isnull(rsc.ConditionName,'Default') as 'Workflow', 
				string_agg(isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_','')),',') within group (order by isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_',''))) as 'ExistingStates'
		from resultsets rs
		left join ResultSetConditions rsc on rsc.ResultSetID=rs.ResultSetID
		left join ConditionWorkflowStates cws on cws.ConditionID=rsc.ConditionID
		left join WorkflowStates ws on ws.WorkflowStateID=cws.WorkflowStateID
		where isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_','')) not like 'start%'
			and cws.IsDeleted = 0
		group by rs.code, isnull(rsc.ConditionName,'Default')
		having string_agg(isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_','')),', ') like '%closed%'
		)

	select Query, Clonning, cte.Code, cte.Workflow, [Users/RolesToAdd], UsersComingFrom, cte2.ExistingStates
	into #commands 
	from cte
	left join cte2 on cte2.code = cte.code and cte2.Workflow=cte.Workflow
	where not exists (select 1 from string_split(ExistingStates,',') es where es.value = @state)
		and cte2.ExistingStates is not null

	if (select top(1) Query from #commands) is not null
		begin
			select * from #commands order by Code, Workflow
		end
	else
		begin
			Select 'No results to show. Update your filters or principles.' as '********ErrorMessage********'
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
else if @PrinciplesToCopy = '' 
		and @count = 1
	begin
		select 'Need to update @PrinciplesToCopy.' as '********ErrorMessage********'
	end
else
	begin
		drop table if exists #commands
		select 'More than one clone state found!.' as '********ErrorMessage********'
		select 	rs.code as 'RSCode', 
				isnull(rsc.ConditionName, 'Default') as 'Workflow', 
				isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')) as 'State' 
		from ConditionWorkflowStates cws
		left join ResultSetConditions rsc on rsc.ConditionID=cws.ConditionID
		left join resultsets rs on rs.ResultSetID=rsc.ResultSetID
		left join WorkflowStates ws on ws.WorkflowStateID=cws.WorkflowStateID
		where rs.Code like @CloneRSCode 
			and isnull(rsc.ConditionName, 'Default') like @CloneWorkflow 
			and isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')) like @state
			and isnull(workflowStateName,replace(ResourceKey,'WorkflowStates_','')) != 'start'
			and cws.IsDeleted = 0
		order by rs.code, rsc.ConditionID, ws.WorkflowStateID
	end
