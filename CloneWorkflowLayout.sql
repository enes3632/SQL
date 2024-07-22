/* Clones the workflow layout to the other workflows with the same states and actions -esahin */

declare @FromRS nvarchar(100),
		@FromWF nvarchar(100),
		@ToRS nvarchar(100),
		@ToWF nvarchar(100),
		@X int,
		@Y int,
		@Coordinates nvarchar(100)

set @FromRS = '%'
set @FromWF = '%'

set @ToRS = '%'
set @ToWF = '%'

drop table if exists #FromRSStates, #FromRSActions, #Statess, #Actionss

select	cws.WorkflowStateID,
		XCoordinate,
		YCoordinate
into #FromRSStates
from ConditionWorkflowStates cws
LEFT JOIN ResultSetConditions rsc on rsc.ConditionID = cws.ConditionID
LEFT JOIN ResultSets rs on rs.ResultSetID = rsc.ResultSetID
LEFT JOIN BusinessProcesses bp on bp.ProcessID = rs.ProcessID
LEFT JOIN WorkflowStates ws on ws.[WorkflowStateID] = cws.[WorkflowStateID]
where rs.IsOnline = 1 and rs.IsDeleted = 0 and rsc.IsActive = 1 and cws.IsDeleted = 0 
	 and rs.Code like @FromRS and isnull(rsc.ConditionName, 'Default') like @FromWF

select	wa.WorkflowActionID,
		wss.WorkflowStateID as 'StartStateID',
		wse.WorkflowStateID as 'EndStateID',
		Coordinates
into #FromRSActions
from ConditionWorkflowActions cwa
left join ResultSetConditions rsc on cwa.ConditionID = rsc.ConditionID
left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
left join BusinessProcesses bp on rs.ProcessID = bp.ProcessID
left join WorkflowActions wa on cwa.WorkflowActionID = wa.WorkflowActionID
left join ConditionWorkflowStates cwss on cwa.StartConditionStateID = cwss.ConditionStateID
left join WorkflowStates wss on cwss.WorkflowStateID = wss.WorkflowStateID
left join ConditionWorkflowStates cwse on cwa.EndConditionStateID = cwse.ConditionStateID
left join WorkflowStates wse on cwse.WorkflowStateID = wse.WorkflowStateID
where rs.IsOnline = 1 and rs.IsDeleted = 0 and rsc.IsActive = 1 and cwa.IsDeleted = 0
	and rs.Code like @FromRS and isnull(rsc.ConditionName, 'Default') like @FromWF
	
select 'Update ConditionWorkflowStates
		set XCoordinate = ' + cast(f.XCoordinate as nvarchar(100)) + '
			,YCoordinate = ' + cast(f.YCoordinate as nvarchar(100)) + '
		where ConditionID = ' + cast(rsc.ConditionID as nvarchar(100)) + '
			and ConditionStateID = ' + cast(cws.ConditionStateID as nvarchar(100))  as Query,
		bp.ProcessName,
		rs.Code,
		isnull(rsc.ConditionName, 'Default') as 'Workflow',
		isnull(ws.WorkflowStateName ,replace(ws.ResourceKey, 'WorkflowStates_', '')) as 'State'
into #Statess
from ConditionWorkflowStates cws
LEFT JOIN ResultSetConditions rsc on rsc.ConditionID = cws.ConditionID
LEFT JOIN ResultSets rs on rs.ResultSetID = rsc.ResultSetID
LEFT JOIN BusinessProcesses bp on bp.ProcessID = rs.ProcessID
LEFT JOIN WorkflowStates ws on ws.[WorkflowStateID] = cws.[WorkflowStateID]
left join #FromRSStates f on f.WorkflowStateID = cws.[WorkflowStateID]
where rs.Code like @ToRS and isnull(rsc.ConditionName, 'Default') like @ToWF

select	'Update ConditionWorkflowActions
		set Coordinates = ''' + cast(f.Coordinates as nvarchar(100)) + '''
		where ConditionID = ' + cast(rsc.ConditionID as nvarchar(100)) + '
			and ConditionActionID = ' + cast(cwa.ConditionActionID as nvarchar(100)) as Query,
		bp.ProcessName,
		rs.Code,
		isnull(rsc.ConditionName, 'Default') as 'Workflow',
		isnull(wa.WorkflowActionName, replace(wa.ResourceKey, 'WorkflowActions_', '')) as 'WorkflowAction',
		isnull(wss.WorkflowStateName ,replace(wss.ResourceKey, 'WorkflowStates_', '')) as 'StartState',
		isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', '')) as 'EndState'

into #Actionss
from ConditionWorkflowActions cwa
left join ResultSetConditions rsc on cwa.ConditionID = rsc.ConditionID
left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
left join BusinessProcesses bp on rs.ProcessID = bp.ProcessID
left join WorkflowActions wa on cwa.WorkflowActionID = wa.WorkflowActionID
left join ConditionWorkflowStates cwss on cwa.StartConditionStateID = cwss.ConditionStateID
left join WorkflowStates wss on cwss.WorkflowStateID = wss.WorkflowStateID
left join ConditionWorkflowStates cwse on cwa.EndConditionStateID = cwse.ConditionStateID
left join WorkflowStates wse on cwse.WorkflowStateID = wse.WorkflowStateID
left join #FromRSActions f on f.WorkflowActionID = cwa.WorkflowActionID 
							and f.StartStateID = wss.WorkflowStateID
							and f.EndStateID = wse.WorkflowStateID

where rs.Code like @ToRS and isnull(rsc.ConditionName, 'Default') like @ToWF
		and f.Coordinates is not null


select * from #Statess order by Code, Workflow, State 
select * from #Actionss order by Code, Workflow, StartState, EndState ,WorkflowAction

