/* New user QA script -esahin */

Declare @OLDuserID int = 1072
	   ,@NEWuserID int = 1068  -- null to see the results only for the OLD user.

drop table if exists #QAResults
Create table #QAResults (
	[Check] nvarchar(50)
	,[Results] nvarchar(50)
	,[Query] nvarchar(1000)
	)

Declare @message  nvarchar(200)
if (select count(*) from users where UserID in (@OLDuserID) and IsDeleted = 0) != 1
begin
	set @message = 'THERE IS NO SUCH USERID (COULD ALSO BE DELETED): ' + cast(@OLDuserID as nvarchar(10))
	raiserror('%s', 16,1, @message)
	return
end
if (select count(*) from users where UserID in (isnull(@NEWuserID,3)) and IsDeleted = 0) != 1
begin
	set @message = 'THERE IS NO SUCH USERID (COULD ALSO BE DELETED): ' + cast(@NEWuserID as nvarchar(10))
	raiserror('%s', 16,1, @message)
	return
end

--Role Check
drop table if exists #RoleCheck
select '[RoleCheck]' [RoleCheck]
		,RoleName
		,string_agg(UserName,',') within group (order by UserName) [UsersInRole]
		,case 
			when string_agg(cast(UserID as varchar(10)),',') not like '%' + cast(@OLDuserID as varchar(10)) + '%'  
				then 'The OLD user is missing in this role'
			when string_agg(cast(UserID as varchar(10)),',') not like '%' + cast(@NEWuserID as varchar(10)) + '%'  
				then 'The NEW user is missing in this role'
			else 'Pass'
		end [Results]
into #RoleCheck
from (
	select u.UserID
			,u.UserName
			,isnull(ur.RoleName,ur.ResourceKey) [RoleName]
	from UserRoleAssignments ura
	left join UserRoles ur on ur.RoleID = ura.RoleID
	left join Users u on u.UserID = ura.UserID
	where u.UserID = @OLDuserID
		and ur.RoleTypeID = 2
	Union all
	select u.UserID
			,u.UserName
			,isnull(ur.RoleName,ur.ResourceKey) [RoleName]
	from UserRoleAssignments ura
	left join UserRoles ur on ur.RoleID = ura.RoleID
	left join Users u on u.UserID = ura.UserID
	where u.UserID = @NEWuserID
		and ur.RoleTypeID = 2 ) RC

group by [RoleName]
order by len(string_agg(UserName,',')) desc
		,string_agg(UserName,',')
		,[RoleName]

--Email Check
drop table if exists #EmailDomains, #EmailCheck
select distinct SUBSTRING(EmailAddress, CHARINDEX('@',EmailAddress), len(EmailAddress)) [Domain]
into #EmailDomains
from users
where IsEnabled = 1
	and LicenseTypeID in (3,4)

select	'[EmailCheck]'[EmailCheck]
		,UserName
		,EmailAddress
		,case
			when SUBSTRING(EmailAddress, CHARINDEX('@',EmailAddress), len(EmailAddress)) not in (select Domain from #EmailDomains)
				then EmailAddress + ' has a new domain. Check if the email is correct and the new domain is added to SSO if the customer is a federated SSO customer.'
				else 'Pass'
		end [DomainCheck]
		,case 
			when EmailAddress not like '%_@__%.__%' or EmailAddress like '% %' or EmailAddress like '%[1-9]'
				then 'The email might not be in the correct format. Please make sure'
			else 'Pass'
		end [EmailFormatCheck]
		,cast(u.Created as date) [Created]
		,u.CreatedBy
		,cast(u.Modified as date) [Modified]
		,u.ModifiedBy
into #EmailCheck
from users u
left join LicenseType lt on lt.LicenseTypeID = u.LicenseTypeID
where UserID = @NEWuserID or (UserID = @OLDuserID and @NEWuserID is null)

--License Check
drop table if exists #LicenseHistory, #LicenseCheck
create table #LicenseCheck (
		[LicenseCheck] nvarchar(50)
		,UserID int
		,UserName nvarchar(50)
		,LicenseTypeName nvarchar(50)
		,[Date] datetime
		,[Results] nvarchar(500))
select * 
into #LicenseHistory
from Audit 
where ColumnName ='[LicenseTypeID]'
	and PrimaryKey1 = @OLDuserID
order by AuditDate

if not exists(select 1 from #LicenseHistory)
begin
	with cte as (
	select 
		u.UserID
		,u.UserName
		,lt.LicenseTypeName
		,cast(getdate() as datetime) [Date]
		,case
			when u.LicenseTypeID not in (3,4)
				then lt.LicenseTypeName + ' - Wrong license!'
			else lt.LicenseTypeName + ' - Check if this is the right license'
		end [Results]
	from users u
	left join LicenseType lt on lt.LicenseTypeID = u.LicenseTypeID
	where UserID = @NEWuserID

	union all

	select	
		u.UserID
		,u.UserName
		,lt.LicenseTypeName
		,cast(u.Created as datetime) [Date]
		,'Old user license history' [Results]
	from users u
	left join LicenseType lt on lt.LicenseTypeID = u.LicenseTypeID
	where u.UserID = @OLDuserID )

	insert into #LicenseCheck 
	select '[LicenseCheck]' [LicenseCheck]
			,* 
	from cte 
end

else
begin
	with cte as (
	select 
		u.UserID
		,u.UserName
		,lt.LicenseTypeName
		,cast(getdate() as datetime) [Date]
		,case
			when u.LicenseTypeID not in (3,4)
				then lt.LicenseTypeName + ' - Wrong license!'
			else lt.LicenseTypeName + ' - Check if this is the right license'
		end [Results]
	from users u
	left join LicenseType lt on lt.LicenseTypeID = u.LicenseTypeID
	where UserID = @NEWuserID

	union all

	select top (1)
		(select UserID from Users where UserID = @OLDuserID) [UserID]	
		,(select UserName from Users where UserID = @OLDuserID) [UserName]
		,lt.LicenseTypeName
		,(select cast(Created as datetime) from Users where UserID = @OLDuserID) [Date]
		,'OLD user license history' [Results]
	from #LicenseHistory lh
	left join LicenseType lt on lt.LicenseTypeID = lh.OldValue 
	where AuditDate = (select min(AuditDate) from #LicenseHistory)

	Union ALL

	select
		(select UserID from Users where UserID = @OLDuserID) [UserID]
		,(select UserName from Users where UserID = @OLDuserID) [UserName]
		,lt.LicenseTypeName
		,cast(AuditDate as datetime) [Date]
		,'OLD user license history' [LicenseCheck]
	from #LicenseHistory lh
	left join LicenseType lt on lt.LicenseTypeID = lh.NewValue
	)
	insert into #LicenseCheck 
	select '[LicenseCheck]' [LicenseCheck]
			,* 
	from cte
end

--Permissions Check
declare @User int,
		@languageId INT

drop table if exists #perms, #PermissionsCheck
create table #perms ([PermissionCheck] nvarchar(50),
					[Module] nvarchar(100),
					[Code] nvarchar(100),
					[IsExceptional] int,
					[DisplayName] nvarchar(150),
					[View] nvarchar(100),
					[Delete] nvarchar(100),
					[Modify] nvarchar(100),
					[Create] nvarchar(100),
					Username nvarchar(100),
					Userid nvarchar(100))

drop table if exists #efusers
select userid
into #efusers
from users
where UserID in (@OLDuserID,@NEWuserID)

while (select count(*) from #efusers) > 0
begin
	set @User = (select top(1) userid from #efusers)

	SELECT @languageId = LanguageID FROM  dbo.UserSettings WHERE  UserID = @User;

	WITH RECORDS AS (SELECT u.UserID, FirstName,  LastName, EmailAddress, MobileNumber, LicenseTypeID, UserName
					 FROM [dbo].[Users] u 
					 WHERE  u.userId = @User) 			
						
    insert into #perms
	SELECT	'[PermissionCheck]' [PermissionCheck],
			bp.ProcessName as 'Module',
			rs.code as 'Code', 
			case when rs.TypeID = 1 then 1 else 0 end [IsExceptional],
			rs.DisplayName as 'DisplayName',
			[dbo].[fn_HasPermission](t.ObjectID,u.UserID,3) as 'View',
			[dbo].[fn_HasPermission](t.ObjectID,u.UserID,1) as 'Delete',
			[dbo].[fn_HasPermission](t.ObjectID,u.UserID,2) as 'Modify',
			[dbo].[fn_HasPermission](t.ObjectID,u.UserID,4) as 'Create',
			u.UserName,
			u.UserID 
	
	FROM   dbo.[fn_rp_GetObjectPermissionBase](@languageId) t
	CROSS JOIN RECORDS u 
	left join resultsets rs on rs.DisplayName=t.DisplayName
	left join BusinessProcesses bp on rs.ProcessID=bp.ProcessID

	where t.ObjectDisplayName = 'Result sets'
	and [dbo].[fn_HasPermission](t.ObjectID,u.UserID,3) in (1)	--update this to (0,1) to see the ones that the user does not have permission to see

	ORDER BY  t.TypeId,  t.displayname

	delete top(1) from #efusers
end

select  [PermissionCheck]
		,[Module]
		,[Code]
		,[IsExceptional]
		,[DisplayName]
		,[View]
		,[Delete]
		,[Modify]
		,[Create]
		,string_agg(Username,',') within group (order by username) [Users]
		,case
			when @NEWuserID is null
				then 'Check'
			when string_agg(Username,',') not like (select '%' + username + '%' from users where Userid = @OLDuserID)
				or string_agg(Username,',') not like (select '%' + username + '%' from users where Userid = @NEWuserID)
				then 'The new user has different set of permissions. Please check.'
			else 'Pass'
		end [Results]
into #PermissionsCheck
from #perms rs
group by [PermissionCheck]
		,[Module]
		,[Code]
		,[IsExceptional]
		,[DisplayName]
		,[View]
		,[Delete]
		,[Modify]
		,[Create]

having case
			when @NEWuserID is null
				then 'Check'
			when string_agg(Username,',') not like (select '%' + username + '%' from users where Userid = @OLDuserID)
				or string_agg(Username,',') not like (select '%' + username + '%' from users where Userid = @NEWuserID)
				then 'The new user has different set of permissions. Please check.'
			else 'Pass'
		end != 'Pass'

order by [Module]
		,[Code]

--Notification Check
drop table if exists #NotificationCheck
;with Recipients as (

    select nr.NotificationId
        ,string_agg(isnull(u.UserName, ur.RoleName), ', ') as 'NotifyUserRole'
		,string_agg(isnull(u.EmailAddress, ur.RoleName), ', ')  as 'NotificationEmails'
    from NotificationRecipients nr
    left join Users u on nr.PrincipalID = u.UserID
    left join UserRoles ur on nr.PrincipalID = ur.RoleID
	where userid = @OLDuserID
    group by nr.NotificationId

), 
NotificationActions as (

	select ns.NotificationId
		,bp.ProcessName
		,rs.Code
		,case	
			when rs.Code is null then null
			else isnull(rsc.ConditionName, 'Default')
		end as 'Workflow'
		,string_agg('[' + isnull(wa.WorkflowActionName,replace(wa.ResourceKey,'WorkflowActions_','')) + ' (' + isnull(ws1.WorkflowStateName,replace(ws1.ResourceKey,'WorkflowStates_','')) + ' -> ' + isnull(ws2.WorkflowStateName,replace(ws2.ResourceKey,'WorkflowStates_','')) + ')]',' , ') within group (order by isnull(wa.WorkflowActionName,replace(wa.ResourceKey,'WorkflowActions_',''))) [Actions (with from & to states)]
	from NotificationSubscriptions ns
		cross apply string_split(ns.EventObjectIds, ',')
	left join ConditionWorkflowActions cwa on value = cwa.ConditionActionID
	left join ResultSetConditions rsc on rsc.ConditionID = cwa.ConditionID
	left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
	left join BusinessProcesses bp on rs.ProcessID = bp.ProcessID
	left join WorkflowActions wa on wa.WorkflowActionID = cwa.WorkflowActionID
	left join ConditionWorkflowStates cws1 on cws1.ConditionStateID = cwa.StartConditionStateID
	left join WorkflowStates ws1 on ws1.WorkflowStateID = cws1.WorkflowStateID
	left join ConditionWorkflowStates cws2 on cws2.ConditionStateID = cwa.EndConditionStateID
	left join WorkflowStates ws2 on ws2.WorkflowStateID = cws2.WorkflowStateID

	where ns.IsSystem = 0
		and cwa.ConditionActionID is not null

	group by ns.NotificationId
		,bp.ProcessName
		,rs.Code 
		,case	
			when rs.Code is null then null
			else isnull(rsc.ConditionName, 'Default')
		end
)

select	'[NotificationCheck]' [NotificationCheck]
		,ns.NotificationName
		,na.ProcessName
		,na.Code
		,na.Workflow
		,na.[Actions (with from & to states)]
		,ns.NotifyAssignee
		,r.NotifyUserRole
		,IsEnabled
		,case
			when @NEWuserID is null
				then 'Pass'
			when r.NotifyUserRole not like (select '%' + username + '%' from users where Userid = @NEWuserID)
				then 'The NEW user is missing in this notification' 
			when r.NotifyUserRole not like (select '%' + username + '%' from users where Userid = @OLDuserID)
				then 'The OLD user is missing in this notification' 
			else 'Pass'
		end [Results]
into #NotificationCheck
from NotificationSubscriptions ns
left join Recipients r on ns.NotificationId = r.NotificationId
right join NotificationActions na on na.NotificationId = ns.NotificationId

where  NotificationName not like 'watch list%'
		and r.NotificationId is not null
	
order by ns.NotificationName;

--Module BPA Check
drop table if exists #ModuleBPACheck
select	'[BPACheck]' [BPACheck]
		,ProcessName
		,u.UserName [BPA]
		,case
			when Administrator = @OLDuserID
				then 'The OLD user is still the BPA of this module'
			when Administrator = @NEWuserID
				then 'The NEW user is the BPA of this module'
		end [Results]
into #ModuleBPACheck
from BusinessProcesses bp
left join users u on bp.Administrator = u.UserID
where Administrator in (@OLDuserID,@NEWuserID)
	and bp.IsDeleted = 0

--State Check
drop table if exists #StateCheck, #StateCount
;with OldUserStates as (
	select	cwsp.ConditionStateID
			,cwsp.PrincipalID

	from ConditionWorkflowStatePrincipals cwsp
	left join ConditionWorkflowStates cws on cws.ConditionStateID = cwsp.ConditionStateID

	where cwsp.PrincipalID = @OLDuserID
		and cws.IsDeleted = 0

), NewUserStates as (
	select	cwsp.ConditionStateID
			,cwsp.PrincipalID

	from ConditionWorkflowStatePrincipals cwsp
	left join ConditionWorkflowStates cws on cws.ConditionStateID = cwsp.ConditionStateID

	where cwsp.PrincipalID = @NEWuserID
		and cws.IsDeleted = 0
)

select '[StateCheck]' [StateCheck]
		,o.PrincipalID [OldUserID]
		,n.PrincipalID [NewUserID]
		,bp.ProcessName
		,rs.Code
		,isnull(rsc.ConditionName,'Default') [Workflow]
		,isnull(ws.WorkflowStateName,replace(ws.ResourceKey,'WorkflowStates_','')) [State]
		,u.UserName
		,case
			when @NEWuserID is null
				then 'Check'
			when o.PrincipalID is null
				then 'The OLD user is missing in this state'
			when n.PrincipalID is null
				then 'The NEW user is missing in this state'
		end [Results]

into #StateCount
from OldUserStates o
full outer join NewUserStates n on n.ConditionStateID = o.ConditionStateID

left join users u on u.UserID = o.PrincipalID or u.UserID = n.PrincipalID
left join ConditionWorkflowStates cws on cws.ConditionStateID = o.ConditionStateID or cws.ConditionStateID = n.ConditionStateID
left join WorkflowStates ws on ws.WorkflowStateID = cws.WorkflowStateID
left join ResultSetConditions rsc on rsc.ConditionID = cws.ConditionID
left join ResultSets rs on rs.ResultSetID = rsc.ResultSetID
left join BusinessProcesses bp on bp.ProcessID = rs.ProcessID

where cws.IsDeleted = 0
	  and rs.IsDeleted = 0
	  and bp.IsDeleted = 0

select *
into #StateCheck
from #StateCount
where (
		([OldUserID] is null or [NewUserID] is null) 
			and @NEWuserID is not null
			)

		or @NEWuserID is null

--Action Check
drop table if exists #ActionCheck, #ActionCount
;with OldUserActions as (
	select	cwsa.ConditionActionID
			,cwsa.PrincipalID

	from ConditionWorkflowActionPrincipals cwsa
	left join ConditionWorkflowActions cwa on cwa.ConditionActionID = cwsa.ConditionActionID

	where cwsa.PrincipalID = @OLDuserID
		and cwa.IsDeleted = 0

), NewUserActions as (
	select	cwsa.ConditionActionID
			,cwsa.PrincipalID

	from ConditionWorkflowActionPrincipals cwsa
	left join ConditionWorkflowActions cwa on cwa.ConditionActionID = cwsa.ConditionActionID

	where cwsa.PrincipalID = @NEWuserID
		and cwa.IsDeleted = 0
)

select '[ActionCheck]' [ActionCheck]
		,o.PrincipalID [OldUserID]
		,n.PrincipalID [NewUserID]
		,bp.ProcessName
		,rs.Code
		,isnull(rsc.ConditionName,'Default') [Workflow]
		,isnull(wa.WorkflowActionName,replace(wa.ResourceKey,'WorkflowActions_','')) [Action]
		,isnull(wss.WorkflowStateName,replace(wss.ResourceKey,'WorkflowStates_','')) [StartState]
		,isnull(wse.WorkflowStateName,replace(wse.ResourceKey,'WorkflowStates_','')) [EndState]
		,u.UserName
		,case
			when @NEWuserID is null
				then 'Check'
			when o.PrincipalID is null
				then 'The OLD user is missing in this action'
			when n.PrincipalID is null
				then 'The NEW user is missing in this action'
		end [Results]

into #ActionCount 
from OldUserActions o
full outer join NewUserActions n on n.ConditionActionID = o.ConditionActionID
left join users u on u.UserID = o.PrincipalID or u.UserID = n.PrincipalID
left join ConditionWorkflowActions cwa on cwa.ConditionActionID = o.ConditionActionID or cwa.ConditionActionID = n.ConditionActionID
left join WorkflowActions wa on wa.WorkflowActionID = cwa.WorkflowActionID
left join ConditionWorkflowStates cwss on cwss.ConditionStateID = cwa.StartConditionStateID
left join WorkflowStates wss on wss.WorkflowStateID = cwss.WorkflowStateID
left join ConditionWorkflowStates cwse on cwse.ConditionStateID = cwa.EndConditionStateID
left join WorkflowStates wse on wse.WorkflowStateID = cwse.WorkflowStateID
left join ResultSetConditions rsc on rsc.ConditionID = cwa.ConditionID
left join ResultSets rs on rs.ResultSetID = rsc.ResultSetID
left join BusinessProcesses bp on bp.ProcessID = rs.ProcessID

where cwa.IsDeleted = 0
	and cwss.IsDeleted = 0
	and wss.IsDeleted = 0
	and cwse.IsDeleted = 0
	and wse.IsDeleted = 0
	and rs.IsDeleted = 0
	and bp.IsDeleted = 0

select *
into #ActionCheck
from #ActionCount
where (
		([OldUserID] is null or [NewUserID] is null) 
			and @NEWuserID is not null
			)

		or @NEWuserID is null

--Auto-Action Check
drop table if exists #AutoActionCheck, #AutoActionCount
;with OldUserAutoActions as (
	select	ctp.TransitionID
			,ctp.PrincipalID

	from ConditionTransitionPrincipals ctp
	left join ConditionWorkflowActions cwa on cwa.ConditionActionID = ctp.TransitionID

	where ctp.PrincipalID = @OLDuserID
		and cwa.IsDeleted = 0

), NewUserAutoActions as (
	select	ctp.TransitionID
			,ctp.PrincipalID

	from ConditionTransitionPrincipals ctp
	left join ConditionWorkflowActions cwa on cwa.ConditionActionID = ctp.TransitionID

	where ctp.PrincipalID = @NEWuserID
		and cwa.IsDeleted = 0
)

select '[AutoActionCheck]' [AutoActionCheck]
		,o.PrincipalID [OldUserID]
		,n.PrincipalID [NewUserID]
		,u.UserName
		,bp.ProcessName
		,rs.Code as Code
		,isnull(rsc.ConditionName, 'Default') as 'Workflow'
		,isnull(wa.WorkflowActionName, replace(wa.ResourceKey, 'WorkflowActions_', '')) as 'WorkflowAction'
		,isnull(wss.WorkflowStateName ,replace(wss.ResourceKey, 'WorkflowStates_', '')) as 'StartState'
		,isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', '')) as 'EndState'
		,isnull(ut.UserName, urt.RoleName) as 'TransitionTo'
		,isnull(rscc.ColumnName, replace(cdet.ResourceKey, 'ConditionDateEventTriggers_', '')) as 'EventTrigger'
		,cwaat.AfterElapsedTime
		,replace(ti.ResourceKey, 'TimeIntervals_', '') as 'TimeUnits'
		,cwaat.IsActive
		,cwaat.TransitionQuery
		,case
			when @NEWuserID is null
				then 'Check'
			when o.PrincipalID is null
				then 'The OLD user is missing in this auto-action'
			when n.PrincipalID is null
				then 'The NEW user is missing in this auto-action'
		end [Results]
into #AutoActionCount
from OldUserAutoActions o
full outer join NewUserAutoActions n on n.TransitionID = o.TransitionID
left join ConditionWorkflowActionAutoTransitions cwaat on cwaat.TransitionID = o.TransitionID or cwaat.TransitionID = n.TransitionID
left join ConditionWorkflowActions cwa on cwaat.ConditionActionID = cwa.ConditionActionID
left join ResultSetConditions rsc on cwa.ConditionID = rsc.ConditionID
left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
left join BusinessProcesses bp on rs.ProcessID = bp.ProcessID
left join WorkflowActions wa on cwa.WorkflowActionID = wa.WorkflowActionID
left join ConditionWorkflowStates cwss on cwa.StartConditionStateID = cwss.ConditionStateID
left join WorkflowStates wss on cwss.WorkflowStateID = wss.WorkflowStateID
left join ConditionWorkflowStates cwse on cwa.EndConditionStateID = cwse.ConditionStateID
left join WorkflowStates wse on cwse.WorkflowStateID = wse.WorkflowStateID
left join Users ut on cwaat.TransitionToPrincipalID = ut.UserID
left join UserRoles urt on cwaat.TransitionToPrincipalID = urt.RoleID
left join ConditionDateEventTriggers cdet on cwaat.DateEventTriggerID = cdet.DateEventTriggerID
left join TimeIntervals ti on cwaat.TimeIntervalID = ti.TimeIntervalID
left join ResultSetColumns rscc on rscc.ColumnID=cwaat.TriggerDateColumnID
left join users u on u.UserID = o.PrincipalID or u.UserID = n.PrincipalID

where cwa.IsDeleted = 0
	and bp.IsDeleted = 0
	and RS.IsDeleted = 0
	and cwa.IsDeleted = 0
	and wa.IsDeleted = 0
	and cwss.IsStartState = 0
	and cwss.IsDeleted = 0
	and wss.IsDeleted = 0
	and cwse.IsStartState = 0
	and cwse.IsDeleted = 0
	and wse.IsDeleted = 0

select *
into #AutoActionCheck
from #AutoActionCount
where (
		([OldUserID] is null or [NewUserID] is null) 
			and @NEWuserID is not null
			)

		or @NEWuserID is null

--Dashboard Check
drop table if exists #Dashboard, #DashboardCheck
;with UserRoleAssigned as (

	select ura.UserID
	from UserRoleAssignments ura
	join UserRoles ur on ura.RoleID = ur.RoleID
	
)

select lt.LicenseTypeName
	,lt.LicenseTypeID
	,pl.PanelID
	,pps.RowIndex
	,pps.ColumnIndex
	,ROW_NUMBER() over (partition by pl.PanelID order by pl.PanelID) [Count]
	,u.UserName
	,pl.PanelName
into #Dashboard
from PagePanelSettings pps
join Pages pg on pps.PageID = pg.PageID
	and pg.SystemObjectNameID = 9
join Panels pl on pps.PanelID = pl.PanelID
join Users u on pg.[Owner] = u.UserID
join LicenseType lt on u.LicenseTypeID = lt.LicenseTypeID
where u.UserID = @NEWuserID
	
select	'[DashboardCheck]' [DashboardCheck]
		,UserName
		,LicenseTypeName
		,PanelID
		,PanelName
		,RowIndex
		,ColumnIndex
		,case
			when RowIndex > 2 or ColumnIndex > 2
				then 'There is an extra panel spot'
			else 'Pass'
		end [PanelIndexCheck]
		,case
			when LicenseTypeID = 3 and PanelID not in (13,33,3,10)
				then 'Wrong panel. Expected panels are 13,33,3,10'
			when LicenseTypeID = 4 and PanelID not in (13,33,3,23)
				then 'Wrong panel. Expected panels are 13,33,3,23'
			else 'Pass'
		end [PanelCheck]
		,case
			when [Count] > 1
				then 'Configured multiple times'
			when (select count(*) from #Dashboard) != 4
				then 'Missing or extra panels'
			else 'Pass'
		end [PanelCountCheck]
into #DashboardCheck
from #Dashboard
where	case
			when RowIndex > 2 or ColumnIndex > 2
				then 'There is an extra panel spot'
			else 'Pass'
		end != 'Pass'
	and 
		case
			when LicenseTypeID = 3 and PanelID not in (13,33,3,10)
				then 'Wrong panel is configured'
			when LicenseTypeID = 4 and PanelID not in (13,33,3,23)
				then 'Wrong panel is configured'
			else 'Pass'
		end != 'Pass'
	and 
		case
			when [Count] > 1
				then 'Configured multiple times'
			when (select count(*) from #Dashboard) != 4
				then 'Missing or extra panels'
			else 'Pass'
		end != 'Pass'
	and @NEWuserID is not null

--Initial Assignee Check
drop table if exists #InitialAssigneeCheck
SELECT	'[InitialAssigneeCheck]' [InitialAssigneeCheck]
		,bp.ProcessName
		,rs.Code	[ResultSets]
		,isnull(ConditionName,'Default') [Workflow]
		,QueryString [Conditions]
		,IsActive
		,isnull(u.UserName,ur.RoleName) [InitialAssignee]
into #InitialAssigneeCheck
FROM ResultSetConditions rsc 
LEFT OUTER JOIN ResultSets rs ON rsc.ResultSetID = rs.ResultSetID  
left join BusinessProcesses bp on bp.ProcessID = rs.ProcessID
LEFT OUTER JOIN WorkflowTemplates wft ON rsc.TemplateID = wft.TemplateID 
LEFT OUTER JOIN Users u ON rsc.AssignTo = u.UserID 
LEFT OUTER JOIN UserRoles ur ON rsc.AssignTo = ur.RoleID 

WHERE rs.IsDeleted = 0
	and userid in (@OLDuserID,@NEWuserID)


ORDER BY rs.DisplayName, OrdinalPosition;

--Escalated User Check
drop table if exists #EscalatedUserCheck
;with autoTransitions as (
	select '[EscalatedUserCheck]'														 [EscalatedUserCheck]
		,rs.Code 																		as 'ResultSetCode'
		,isnull(rsc.ConditionName, 'Default') 											as 'Workflow'
		,isnull(wa.WorkflowActionName, replace(wa.ResourceKey, 'WorkflowActions_', '')) as 'WorkflowAction'
		,isnull(wss.WorkflowStateName ,replace(wss.ResourceKey, 'WorkflowStates_', '')) as 'AssignFromState'
		,isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', '')) as 'AssignToState'
		,string_agg(convert(nvarchar(max), isnull(uf.UserName, urf.RoleName)), ', ') 	as 'AssignFrom'
		,isnull(ut.UserName, urt.RoleName) 												as 'AssignTo'
		,case
			when ut.UserID = @OLDuserID
				then 'The OLD user is still the escalated user'	
			when ut.UserID = @NEWuserID
				then 'The NEW user has been configured as the escalated user'
			else null
		end																				as 'Results'
		,isnull(ut.UserID, urt.RoleID)													as 'UserOrRoleID'
		,replace(cdet.ResourceKey, 'ConditionDateEventTriggers_', '') 					as 'EventTrigger'
		,cwaat.AfterElapsedTime															as 'AfterElapsedTime'
		,replace(ti.ResourceKey, 'TimeIntervals_', '') 									as 'TimeUnits'
		,cwaat.IsActive																	as 'IsActive'
	from ConditionTransitionPrincipals ctp
	left join ConditionWorkflowActionAutoTransitions cwaat on ctp.TransitionID = cwaat.TransitionID
	left join ConditionWorkflowActions cwa on cwaat.ConditionActionID = cwa.ConditionActionID
	left join ResultSetConditions rsc on cwa.ConditionID = rsc.ConditionID
	left join ResultSets rs on rsc.ResultSetID = rs.ResultSetID
	left join BusinessProcesses bp on rs.ProcessID = bp.ProcessID
	left join WorkflowActions wa on cwa.WorkflowActionID = wa.WorkflowActionID
	left join ConditionWorkflowStates cwss on cwa.StartConditionStateID = cwss.ConditionStateID
	left join WorkflowStates wss on cwss.WorkflowStateID = wss.WorkflowStateID
	left join ConditionWorkflowStates cwse on cwa.EndConditionStateID = cwse.ConditionStateID
	left join WorkflowStates wse on cwse.WorkflowStateID = wse.WorkflowStateID
	left join Users ut on cwaat.TransitionToPrincipalID = ut.UserID
	left join UserRoles urt on cwaat.TransitionToPrincipalID = urt.RoleID
	left join Users uf on ctp.PrincipalID = uf.UserID
	left join UserRoles urf on ctp.PrincipalID = urf.RoleID
	left join ConditionDateEventTriggers cdet on cwaat.DateEventTriggerID = cdet.DateEventTriggerID
	left join TimeIntervals ti on cwaat.TimeIntervalID = ti.TimeIntervalID
	where cwa.IsDeleted = 0
		and rs.IsDeleted = 0
		
	group by rs.Code
		,isnull(rsc.ConditionName, 'Default')
		,isnull(wa.WorkflowActionName, replace(wa.ResourceKey, 'WorkflowActions_', ''))
		,isnull(wss.WorkflowStateName ,replace(wss.ResourceKey, 'WorkflowStates_', ''))
		,isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', ''))
		,isnull(ut.UserName, urt.RoleName)
		,case when cast(ut.IsEnabled as varchar(10)) = 1 then 'ActiveUser'
			when cast(ut.IsEnabled as varchar(10)) = 0 then 'DisabledUser'
			else 'Role' end	
		,replace(cdet.ResourceKey, 'ConditionDateEventTriggers_', '')
		,cwaat.AfterElapsedTime
		,replace(ti.ResourceKey, 'TimeIntervals_', '')
		,cwaat.IsActive
		,isnull(ut.UserID, urt.RoleID)
		,case
			when ut.UserID = @OLDuserID
				then 'The OLD user is still the escalated user'	
			when ut.UserID = @NEWuserID
				then 'The NEW user has been configured as the escalated user'
			else null
		end
)
select *
into #EscalatedUserCheck
from autoTransitions
where (Results is not null and @NEWuserID is not null)
		or (@NEWuserID is null and UserOrRoleID = @OLDuserID) 
order by 
	AssignTo
	,WorkflowAction
	,AssignFromState
	,ResultSetCode
	,Workflow

--Open Assigned Work Items Check
drop table if exists #OpenAssignedWorkItemsCheck
SELECT '[OpenWorkItemsCheck]' [OpenWorkItemsCheck],
	bp.ProcessName, 
	RS.Code as 'ResultSet',
	isnull(RSC.ConditionName,'Default') as 'Workflow',
	COALESCE(U.UserName, UR.RoleName)              AS [AssignedTo],
	replace(COALESCE(WS.WorkflowStateName, WS.ResourceKey),'workflowstates_','') AS [CurrentState],
	COUNT(*)                                       AS [NumberOfItems]
into #OpenAssignedWorkItemsCheck
FROM WorkItems WI
LEFT JOIN ResultSets RS ON WI.ResultSetID = RS.ResultSetID
left join BusinessProcesses bp on bp.ProcessID = rs.ProcessID
LEFT JOIN Users U ON WI.AssignTo = U.UserID
LEFT JOIN UserRoles UR ON WI.AssignTo = UR.RoleID
LEFT JOIN ResultSetConditions RSC ON WI.ConditionID = RSC.ConditionID
LEFT JOIN WorkflowStates WS ON WI.WorkflowStateID = WS.WorkflowStateID

WHERE WI.AssignTo = @OLDuserID
	and COALESCE(WS.WorkflowStateName, WS.ResourceKey) not like '%close%' 
	and rs.IsDeleted = 0
	and bp.IsDeleted = 0

GROUP BY bp.ProcessName,
	RS.code,
  RSC.ConditionName,
  COALESCE(U.UserName, UR.RoleName),
  COALESCE(WS.WorkflowStateName, WS.ResourceKey)

order by COUNT(*) desc

--Informational Users Check
drop table if exists #InformationalUsersCheck
;with viewers as (
	SELECT 
		BP.ProcessName,
		rs.Code,
		RS.DisplayName,
		COALESCE(RSC.ConditionName, 'Default') AS [Workflow],
		string_agg(U.UserName,',') within group (order by u.UserName) [InformationalUsers]

	FROM ConditionViewOnlyPrincipals CVOP
	LEFT JOIN ResultSetConditions RSC ON CVOP.ConditionID = RSC.ConditionID
	LEFT JOIN ResultSets RS ON RSC.ResultSetID = RS.ResultSetID
	LEFT JOIN BusinessProcesses BP ON RS.ProcessID = BP.ProcessID
	left JOIN Users U ON CVOP.PrincipalID = U.UserID  

	where bp.IsDeleted = 0 
		and rs.IsDeleted = 0 
		and u.UserID in (@OLDuserID,@NEWuserID)

	group by BP.ProcessName,
			rs.Code,
			RS.DisplayName,
			COALESCE(RSC.ConditionName, 'Default')
	)

select '[InformationalUsersCheck]' [InformationalUsersCheck]
		,*
		,case
			when @NEWuserID is null
				then 'Check'
			when [InformationalUsers] not like (select '%' + UserName + '%' from users where Userid = @NEWuserID)
				then 'The new user is not an informational user of this. Please check.'
			else 'Pass'
		end [Results]
into #InformationalUsersCheck
from viewers
where case
			when [InformationalUsers] not like (select '%' + UserName + '%' from users where Userid = @NEWuserID)
				then 'The new user is not an informational user of this. Please check.'
			else 'Pass'
		end != 'Pass'

order by ProcessName,
		DisplayName,
		Workflow
 

--User Access Check
drop table if exists #UserAccessCheck
select '[UserAccessCheck]' [OldUserAccessCheck]
	,UserID
	,UserName
	,IsEnabled
	,case
		when IsEnabled = 1 and UserID = @OLDuserID
			then 'OLD user is ENABLED???'
		when IsEnabled = 0 and UserID = @OLDuserID
			then 'OLD user is disabled'
		when IsEnabled = 1 and UserID = @NEWuserID
			then 'NEW user is enabled'
		when IsEnabled = 0 and UserID = @NEWuserID
			then 'NEW user is DISABLED???'
	end [Results]
into #UserAccessCheck
from Users
where UserID in (@OLDuserID,@NEWuserID)

--Unticked Indicator Check
drop table if exists #IndicatorCheck
SELECT '[IndicatorCheck]' [IndicatorCheck]
	,RS.DisplayName
	,isnull(rsc.ConditionName, 'Default') as 'Workflow'
	,I.IndicatorName
	,CWAI.IsRequired
	,isnull(wa.WorkflowActionName, replace(wa.ResourceKey, 'WorkflowActions_', '')) as 'WorkflowAction'
	,isnull(wss.WorkflowStateName ,replace(wss.ResourceKey, 'WorkflowStates_', '')) as 'StartState'
	,isnull(wse.WorkflowStateName ,replace(wse.ResourceKey, 'WorkflowStates_', '')) as 'EndState'
	,CWAI.CalculatedValueExpression
	,CWAI.IsValueEditable
into #IndicatorCheck
FROM ConditionWorkflowActionIndicators CWAI
LEFT JOIN Indicators I ON CWAI.IndicatorID = I.IndicatorID
LEFT JOIN ConditionWorkflowActions CWA ON CWAI.ConditionActionID = CWA.ConditionActionID
LEFT JOIN ResultSetConditions RSC ON CWA.ConditionID = RSC.ConditionID
LEFT JOIN ResultSets RS ON RSC.ResultSetID = RS.ResultSetID
LEFT JOIN WorkflowActions WA ON CWA.WorkflowActionID = WA.WorkflowActionID
LEFT JOIN ConditionWorkflowStates Cwss ON CWA.StartConditionStateID = Cwss.ConditionStateID
LEFT JOIN WorkflowStates wss ON Cwss.WorkflowStateID = wss.WorkflowStateID
LEFT JOIN ConditionWorkflowStates Cwse ON CWA.EndConditionStateID = Cwse.ConditionStateID
LEFT JOIN WorkflowStates wse ON Cwse.WorkflowStateID = wse.WorkflowStateID
LEFT JOIN BusinessProcesses bp on rs.ProcessID = bp.ProcessID
WHERE CWAI.IsRequired = 0
	AND RS.IsOnline = 1
	AND RSC.IsActive = 1
	AND CWAI.ConditionActionID IN	(
									SELECT ConditionActionID
									FROM ConditionWorkflowActionRequiredFields
									WHERE FieldID = 2
									)
	AND CWA.IsDeleted = 0
	AND RS.IsDeleted = 0

--Futuro Emails Check
drop table if exists #FuturoEmailsCheck, #FuturoEmails
create table #FuturoEmails (
		Alessa_Resultset_Code nvarchar(500)
		,Result_Object nvarchar(500)
		,Recipient_Email_Address nvarchar(max)
		,Is_Active int
	)

declare @DB nvarchar(100) = (select [name] from sys.databases where [name] = replace(db_name(),'_alessa',''))
		,@SQL nvarchar(max)
		,@OldUserEmail nvarchar(1000) = (select EmailAddress from users where UserID = @OLDuserID)
		,@NewUserEmail nvarchar(1000) = (select EmailAddress from users where UserID = @NEWuserID)

set @SQL = '
	use ' + @DB + '
	insert into #FuturoEmails
	select Alessa_Resultset_Code
		,Result_Object
		,Recipient_Email_Address
		,Is_Active
	from CCMAnalytics.Config_Email
	'
exec sp_executesql @SQL

select	'[FuturoEmailCheck]' [FuturoEmailCheck]
		,bp.ProcessName
		,f.Alessa_Resultset_Code
		,rs.Code
		,f.Recipient_Email_Address
		,case
			when Recipient_Email_Address like '%'+@OldUserEmail+'%'
				and Recipient_Email_Address not like '%'+@NewUserEmail+'%'
				then 'Old & New users'
			when Recipient_Email_Address like '%'+@OldUserEmail+'%'
				then 'Old user only'
			when Recipient_Email_Address not like '%'+@NewUserEmail+'%'
				then 'New user only'
			else 'None'
		end [IsOldNewUsersIn]
		,(select count(*) from string_split(Recipient_Email_Address,';')) [NumberOfRecipients]
		,f.Is_Active
		,case
			when Recipient_Email_Address like '%'+@OldUserEmail+'%'
				and Recipient_Email_Address not like '%'+@NewUserEmail+'%'
				then 'The new user is missing in this Futuro email'
			else 'Pass'
		end [Results]
into #FuturoEmailsCheck
from #FuturoEmails f 
left join ResultSets rs on rs.Code = f.Alessa_Resultset_Code
left join BusinessProcesses bp on bp.ProcessID = rs.ProcessID
where rs.IsDeleted = 0 
		and rs.IsOnline = 1
		and bp.IsDeleted = 0
		and bp.IsOnline = 1

--Prepare results
declare @Check nvarchar(100)
	,@Check2 nvarchar(100)
	,@Check3 nvarchar(100)
	,@Checks nvarchar(1000) = '#RoleCheck,#EmailCheck,#LicenseCheck,#PermissionsCheck,#NotificationCheck,#ModuleBPACheck,#StateCheck,#ActionCheck,#AutoActionCheck,#DashboardCheck,#InitialAssigneeCheck,#EscalatedUserCheck,#OpenAssignedWorkItemsCheck,#InformationalUsersCheck,#UserAccessCheck,#IndicatorCheck,#FuturoEmailsCheck'
	,@Query nvarchar(1000)

while (select top (1) value from string_split(@Checks,',')) != '' 
begin 
	select top (1) @Check = value from string_split(@Checks,',')

	set @Check2 = 'select @Check3 = count(*) from ' + @Check
	exec sp_executesql @Check2, N'@Check3 int output', @Check3 = @Check3 output

	if @Check3 != 0 or @NEWuserID is null
		insert into #QAResults values (replace(replace(@Check,'#',''),'Check',' Check'),'Check the results below','Select * from ' + @Check)
	else 
		insert into #QAResults values (replace(replace(@Check,'#',''),'Check',' Check'),'Pass',null)

	set @Checks = replace(replace(@Checks,@Check+',',''),@Check,'')

end

if not exists(select 1 from #InitialAssigneeCheck where InitialAssignee = (select username from users where UserID = @OLDuserID))
begin 
	update #QAResults set Results = 'Pass' where [Check] = 'InitialAssignee Check' 
end

if exists(select * from #FuturoEmails where Recipient_Email_Address like '%'+@OldUserEmail+'%' or Recipient_Email_Address like '%'+@NewUserEmail+'%' ) and @NEWuserID is not null
begin 
	update #QAResults set Query = 'Select * from #FuturoEmailsCheck where Recipient_Email_Address like ''%'+@OldUserEmail+'%'' or Recipient_Email_Address like ''%'+@NewUserEmail+'%'' ' where [Check] = 'FuturoEmails Check' 
end

if (select count(*) from #UserAccessCheck 
	where	(IsEnabled = 1 and UserName = (select username from users where UserID = @OLDuserID))
				or
			(IsEnabled = 0 and UserName = (select username from users where UserID = @NEWuserID))
		) = 0
begin
	update #QAResults set Results = 'Pass' where [Check] = 'UserAccess Check' 
end

if (select count(*) from #RoleCheck) = 0
begin
	update #QAResults set Results = 'Check the results below', Query = 'Select ''[Role Check]'' [Role Check], ''Both OLD & NEW users have NO roles'' [Results] ' where [Check] = 'Role Check'
end

select [Check], Results from #QAResults

drop table if exists #Query
select 
	case 
		when [Query] like '%#LicenseCheck%'
			then [Query] + ' order by UserID desc, [Date] desc'
		when [Query] like '%#RoleCheck%'
			then [Query] + ' order by len([UsersInRole]), [UsersInRole], [RoleName]'
		when [Query] like '%#StateCheck%'
			then [Query] + ' order by ProcessName,Code,Workflow,State'
		when [Query] like '%#ActionCheck%'
			then [Query] + ' order by ProcessName,Code,Workflow,Action,StartState,EndState'
		when [Query] like '%#AutoActionCheck%'
			then [Query] + ' order by ProcessName,Code,Workflow,WorkflowAction,StartState,EndState'
		when [Query] like '%#FuturoEmails%'
			then [Query] + ' order by ProcessName,Code'
		else [Query]
	end [Query]
into #Query 
from #QAResults 
where [Query] is not null

while exists(select 1 from #Query)
begin
	select top(1) @Query = [Query] from #Query 
	exec sp_executesql @Query
	delete top(1) from #Query
end

select '[WorkflowCheck]' [WorkflowCheck]
		,UserName
		,sum([NumberOfStates]) [NumberOfStates]
		,sum([NumberOfActions]) [NumberOfActions]
		,sum([NumberOfAutoActions]) [NumberOfAutoActions]
from (
	select UserName
			,isnull([NumberOfStates],0) [NumberOfStates]
			,isnull([NumberOfActions],0) [NumberOfActions]
			,isnull([NumberOfAutoActions],0) [NumberOfAutoActions]
	from (
		select (select UserName from Users where UserID = @OLDuserID) [UserName]
				,0 [NumberOfStates]
				,0 [NumberOfActions]
				,0 [NumberOfAutoActions]

		union all

		select (select UserName from Users where UserID = @NEWuserID) [UserName]
				,0 [NumberOfStates]
				,0 [NumberOfActions]
				,0 [NumberOfAutoActions]

		union all

		select * from (
			select UserName
				,count(*) [NumberOfStates]
				,0 [NumberOfActions]
				,0 [NumberOfAutoActions]
			from #StateCount
			group by UserName
			) States

		union all

		select * from (
			select UserName
				,0 [NumberOfStates]
				,count(*) [NumberOfActions]
				,0 [NumberOfAutoActions]
			from #ActionCount
			group by UserName
			) Actions

		union all

		select * from (
			select UserName
				,0 [NumberOfStates]
				,0 [NumberOfActions]
				,count(*) [NumberOfAutoActions]
			from #AutoActionCount
			group by UserName
			) AutoActions
	) Counts
) TotalCounts

group by UserName

having UserName is not null