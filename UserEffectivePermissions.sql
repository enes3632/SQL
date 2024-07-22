/* Shows the user's effective resultsets permissions -esahin */

declare @UserID int,
		@languageId INT

drop table if exists #perms
create table #perms (TypeName nvarchar(100),
					[Module]nvarchar(100),
					[Code] nvarchar(100),
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
where IsEnabled=1


while (select count(*) from #efusers) > 0
begin
	set @UserID = (select top(1) userid from #efusers)

	SELECT @languageId = LanguageID FROM  dbo.UserSettings WHERE  UserID = @UserID;

	WITH RECORDS AS (SELECT u.UserID, FirstName,  LastName, EmailAddress, MobileNumber, LicenseTypeID, UserName
					 FROM [dbo].[Users] u 
					 WHERE  u.userId = @UserID) 			
						
    insert into #perms
	SELECT	rst.TypeName,
			bp.ProcessName as 'Module',
			rs.code as 'Code', 
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
	left join ResultSetTypes rst on rst.TypeID=rs.TypeID

	where t.ObjectDisplayName = 'Result sets'
	and [dbo].[fn_HasPermission](t.ObjectID,u.UserID,3) in (1)	--update this to (0,1) to see the ones that the user does not have permission to see

	ORDER BY  t.TypeId,  t.displayname

	delete top(1) from #efusers
end

select * 
from #perms
where code like '%' and username like '%'
order by Userid,code