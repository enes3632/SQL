/* Reassigns work items to another user. -esahin */

--Make sure the new assignee is in the same states as the old one.

Declare @From int = 19
		,@To int = 85
		,@ApprovedBy nvarchar(50) = ''
		,@Execute bit = 0 

		,@ItemsToReassign nvarchar(max)
		,@HistoryLog nvarchar(max)
		,@Today DATETIME = GetDate()
		,@Date DATETIME = GetUTCDate()

drop table if exists #temp1, #temp2
begin transaction
		select wi.WorkItemID as 'WorkItemID',
		rs.DisplayName as 'ResultSet',
		wi.AssignToPrincipalName as 'AssignedTo',
		COALESCE(WS.WorkflowStateName, WS.ResourceKey) AS [CurrentState]
		into #temp1
		from workitems wi
		left join resultsets rs on rs.ResultSetID=wi.ResultSetID
		left join ResultSetConditions rsc on rsc.ConditionID=wi.ConditionID
		LEFT JOIN WorkflowStates WS ON WI.WorkflowStateID = WS.WorkflowStateID

		where wi.AssignTo = @From 
			and COALESCE(WS.WorkflowStateName, WS.ResourceKey) not like '%close%'
	
	select cast(string_agg(cast(WorkItemID as nvarchar(max)),',') as nvarchar(max)) [WorkItems]
	into #temp2
	from #temp1

	select @ItemsToReassign = [WorkItems]
	from #temp2

	if not exists(select * from #temp1)
	begin
		THROW 50001, 'The user has no open work items.', 1;
	end

	else 
	begin 
		select * from #temp1 
	end
		
	set @HistoryLog = 'This work item has been reassigned to ' + (select username from users where userid=@To) + ' by the System after '+@ApprovedBy+'''s approval on '+cast(convert(date,@Today,23) as nvarchar(max))+'.'

	exec st_wi_ReassignWorkItems @To, @ItemsToReassign, 2, 'en',0,0,1,@Date

	exec st_wi_AddComments @HistoryLog, @ItemsToReassign,null,null,@Date,0,null,2,0,1
 
	;with cte as (
	select 
		wi.WorkItemID as 'WorkItemID'
		,rs.DisplayName as 'ResultSet'
		,wi.AssignToPrincipalName as 'AssignedTo'
		,COALESCE(WS.WorkflowStateName, WS.ResourceKey) AS [CurrentState]
		,wic.CommentDetails
		,ROW_NUMBER() over(partition by wi.WorkItemID order by wic.created desc) [Row]  

	from workitems wi
	left join resultsets rs on rs.ResultSetID=wi.ResultSetID
	left join ResultSetConditions rsc on rsc.ConditionID=wi.ConditionID
	LEFT JOIN WorkflowStates WS ON WI.WorkflowStateID = WS.WorkflowStateID
	left join workitemcomments wic on wic.workitemid = wi.workitemid

	where  COALESCE(WS.WorkflowStateName, WS.ResourceKey) not like '%close%'
		and wi.WorkItemID in ( select value from string_split((select [WorkItems] from #temp2),','))
	)
	select WorkItemID, ResultSet, AssignedTo, CurrentState, CommentDetails 
	from cte 
	where Row = 1
	order by WorkItemID

 if @Execute = 0 
begin rollback end

else 
begin commit end
