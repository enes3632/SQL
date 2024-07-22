USE [CCM_CustomerOne_ALESSA]
GO

/****** Object:  StoredProcedure [dbo].[sp_Custom_CustomerOne_User_Deletion]    Script Date: 25/07/2023 3:13:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

alter PROCEDURE   [dbo].[sp_Custom_CustomerOne_User_Deletion] 
	
	AS
	SET NOCOUNT ON
BEGIN

--Creates a table called 'UsersRemoved' if not exists to store the fully removed users. Fully means from all the workflows.
if (select count(*) from sys.tables where name='UsersRemoved') = 0
  begin
    create table dbo.UsersRemoved (userid int not null primary key, username NVARCHAR(max) not null) 
    CREATE INDEX UsersRemoved_userid ON UsersRemoved(userid)
  end

--Creates a role for 'Disabled Users' if not exists
declare @DisabledUsersRoleID int
if (select count(*) from userroles where RoleName='Disabled Users') = 0
  begin
    exec st_ug_AddRole @roleName='Disabled Users', @description='This role is for the removed users', @modifiedBy='sp_Custom_CustomerOne_User_Deletion', @roleID=@DisabledUsersRoleID
  end
ELSE
  begin
    set @DisabledUsersRoleID  = (select RoleID from userroles where RoleName='Disabled Users')
  end

--Pick up the users previously fully removed and then readded to EMF. Those users get removed from the UsersRemoved table. So, they are not missed if deleted again.
drop table if exists #reactivated;

with emf2 AS (
  select * from 1305_Archive
  where _Monitor_RunDate in (select max(_Monitor_RunDate) from 1305_Archive))

select * 
into #reactivated 
from UsersRemoved
where userid in (
  select ur.userid 
  from UsersRemoved ur
  inner join emf2 emf2 on ur.UserName=emf2.Emp_UserName)

if (select count(*) from #reactivated) > 0
  begin 
    delete from UsersRemoved where userid in (select userid from #reactivated)
  end

--Get the list of users to disable
drop table if exists #tobedisabled;

with emf AS (
  select * from 1305_Archive
  where _Monitor_RunDate in (select max(_Monitor_RunDate) from 1305_Archive))

select * into #tobedisabled
from users u
left join emf emf
on u.UserName=emf.Emp_UserName
where emf.Emp_UserName is null
  and u.UserName not in ('System','UserCopyFrom')
  and u.LicenseTypeID in (1,3,4) --gets only nolicense, expert and BPA licenses
  and u.userid not in (select userid from UsersRemoved) --filters the fully removed users out

declare @user_count int = (select count(*) from #tobedisabled)
declare @mainUserID int

if @user_count > 0
BEGIN
  while @user_count > 0
  BEGIN
    set @mainUserID = (select top(1) userid from #tobedisabled)

    --Checks if the user has any workitems assigned in any state but close
    drop table if exists #workflowlist
    SELECT WI.ConditionID
    into #workflowlist
    FROM WorkItems WI
    LEFT JOIN ResultSets RS ON WI.ResultSetID = RS.ResultSetID
    LEFT JOIN Users U ON WI.AssignTo = U.UserID
    LEFT JOIN UserRoles UR ON WI.AssignTo = UR.RoleID
    LEFT JOIN ResultSetConditions RSC ON WI.ConditionID = RSC.ConditionID
    LEFT JOIN WorkflowStates WS ON WI.WorkflowStateID = WS.WorkflowStateID
    WHERE WI.AssignTo = @mainuserid
    and COALESCE(WS.WorkflowStateName, WS.ResourceKey) not like '%close%'
    GROUP BY WI.ConditionID

  --the user will be fully removed if has no open work items assigned. This part adds the user to the table that stores fully removed users
    if (select count(*) from #workflowlist) = 0 
      BEGIN
        insert into UsersRemoved (userid, username) values (@mainUserID, (select username from users where userid=@mainUserID))
      end
  
    declare @count int
    declare @exect nvarchar(max)

    --Removes from auto-escalations if any
    drop table if exists #autoess
    SELECT 'DELETE FROM ConditionTransitionPrincipals WHERE TransitionID = ' + CAST(cwaat.TransitionID AS VARCHAR(10)) + ' AND PrincipalID = ' + CAST(ctp.PrincipalID AS VARCHAR(10)) as Command
    into #autoess
    FROM [ConditionWorkflowActionAutoTransitions] cwaat
    LEFT JOIN ConditionTransitionPrincipals ctp
      ON cwaat.TransitionID = ctp.TransitionID
    LEFT JOIN [ConditionWorkflowActions] cwa
      ON cwaat.ConditionActionID = cwa.ConditionActionID
    LEFT JOIN ResultSetConditions rsc
      ON rsc.ConditionID = cwa.ConditionID
    LEFT JOIN ResultSets rs
      ON rs.ResultSetID = rsc.ResultSetID
    LEFT JOIN BusinessProcesses bp
      ON bp.ProcessID = rs.ProcessID
    LEFT JOIN WorkflowActions wa
      ON wa.[WorkflowActionID] = cwa.[WorkflowActionID]
    LEFT JOIN [ConditionWorkflowStates] cwss
      ON cwss.ConditionStateID = cwa.StartConditionStateID
    LEFT JOIN WorkflowStates wss
      ON wss.[WorkflowStateID] = cwss.[WorkflowStateID]
    LEFT JOIN [ConditionWorkflowStates] cwse
      ON cwse.ConditionStateID = cwa.EndConditionStateID
    LEFT JOIN WorkflowStates wse
      ON wse.[WorkflowStateID] = cwse.[WorkflowStateID]
    WHERE ctp.PrincipalID = @mainUserID
    and (not exists (select 1 from #workflowlist)
        OR not exists(select 1 from #workflowlist wfl where wfl.ConditionID=cwa.ConditionID)) 
    ORDER BY rs.DisplayName,
      rsc.ConditionName;

    set @count = (select count(*) from #autoess)
    if @count > 0
      BEGIN
        while @count > 0
          BEGIN
            set @exect = (select top(1) command from #autoess)
            if @exect is not null exec sp_executesql @exect

            delete top(1) from #autoess 
            set @count = @count - 1 
          END
      END

    --Removes from actions if any
    drop table if exists #actss
    SELECT 'DELETE FROM ConditionWorkflowActionPrincipals WHERE ConditionActionID = ' + CAST(cwa.ConditionActionID AS VARCHAR(10)) + ' AND PrincipalID = ' + CAST(cwap.PrincipalID AS VARCHAR(10))as Command    into #actss
    FROM [ConditionWorkflowActionPrincipals] cwap
    LEFT JOIN [ConditionWorkflowActions] cwa
      ON cwa.[ConditionActionID] = cwap.[ConditionActionID]
    LEFT JOIN ResultSetConditions rsc
      ON rsc.ConditionID = cwa.ConditionID
    LEFT JOIN ResultSets rs
      ON rs.ResultSetID = rsc.ResultSetID
    LEFT JOIN BusinessProcesses bp
      ON bp.ProcessID = rs.ProcessID
    LEFT JOIN WorkflowActions wa
      ON wa.[WorkflowActionID] = cwa.[WorkflowActionID]
    LEFT JOIN [ConditionWorkflowStates] cwss
      ON cwss.ConditionStateID = cwa.StartConditionStateID
    LEFT JOIN WorkflowStates wss
      ON wss.[WorkflowStateID] = cwss.[WorkflowStateID]
    LEFT JOIN [ConditionWorkflowStates] cwse
      ON cwse.ConditionStateID = cwa.EndConditionStateID
    LEFT JOIN WorkflowStates wse
      ON wse.[WorkflowStateID] = cwse.[WorkflowStateID]
    WHERE cwap.PrincipalID = @mainUserID
    and (not exists (select 1 from #workflowlist)
        OR not exists(select 1 from #workflowlist wfl where wfl.ConditionID=cwa.ConditionID)) 
    ORDER BY rs.DisplayName,
      rsc.ConditionName;

    set @count = (select count(*) from #actss)
    if @count > 0
      BEGIN
        while @count > 0
          BEGIN
            set @exect = (select top(1) command from #actss)
            if @exect is not null exec sp_executesql @exect

            delete top(1) from #actss 
            set @count = @count - 1 
          END
      END

    --Removes from states if any
    drop table if exists #statess
    SELECT 'DELETE FROM ConditionWorkflowStatePrincipals WHERE ConditionStateID = ' + CAST(cws.ConditionStateID AS VARCHAR(10)) + ' AND PrincipalID = ' + CAST(cwsp.PrincipalID AS VARCHAR(10))as Command
    into #statess
    FROM [ConditionWorkflowStatePrincipals] cwsp
    LEFT JOIN [ConditionWorkflowStates] cws
      ON cws.[ConditionStateID] = cwsp.[ConditionStateID]
    LEFT JOIN ResultSetConditions rsc
      ON rsc.ConditionID = cws.ConditionID
    LEFT JOIN ResultSets rs
      ON rs.ResultSetID = rsc.ResultSetID
    LEFT JOIN BusinessProcesses bp
      ON bp.ProcessID = rs.ProcessID
    LEFT JOIN WorkflowStates ws
      ON ws.[WorkflowStateID] = cws.[WorkflowStateID]
    WHERE RS.IsDeleted = 0
      AND PrincipalID = @mainUserID 
    and (not exists (select 1 from #workflowlist)
        OR not exists(select 1 from #workflowlist wfl where wfl.ConditionID=cws.ConditionID)) 
    ORDER BY rs.DisplayName,
      rsc.ConditionName;

    set @count = (select count(*) from #statess)
    if @count > 0
      begin
        while @count > 0
          BEGIN
            set @exect = (select top(1) command from #statess)
            if @exect is not null exec sp_executesql @exect

            delete top(1) from #statess 
            set @count = @count - 1 
          END
      END

    --removes from all the current roles but disabled users
    delete from UserRoleAssignments where userid=@mainUserID and RoleID !=  @DisabledUsersRoleID 
    
    --checks if the user wasnt previously put into the Disabled Users role. If not disables, makes IsDeleted=1 and assignes NoLicense. If so, skip this step since the user must already been processed.
    if (select count(*) from UserRoleAssignments where userid=@mainUserID and RoleID =  @DisabledUsersRoleID) = 0 
      begin
        declare @AddRoleResult bit
        exec st_ug_AddUserToRole @userID=@mainUserID, @roleid=@DisabledUsersRoleID, @modifiedBy='sp_Custom_CustomerOne_User_Deletion', @result=@AddRoleResult --adds to the disabled users role
        if @AddRoleResult = 0 begin print N'The user cannot be added to the ''Disabled Users'' role.' end
        update users set isEnabled=0, IsDeleted=1, LicenseTypeID=1 where userid = @mainuserid
      END

    delete top(1) from #tobedisabled 
    set @user_count = @user_count - 1 
  END
END

End
