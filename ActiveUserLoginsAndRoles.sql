  /*** Active user roles and login information - esahin***/

with numLogins as (	select	UserID, count(*) as [NumberOfLogins12Months]
					from UserLogonHistory	
					where AuthenticationStatus = 1 and StatusDate >= dateadd(yy, -1, GETDATE())
					group by UserID	)

select	a.UserName, 
		a.FirstName, 
		a.LastName,
		a.EmailAddress,
		a.LicenseTypeName as 'LicenseType',
		a.UserRoles, 
		isnull(format(convert(datetime,MAX(DATEADD(hour,10,ulh.StatusDate))),'dd MMM yyyy'),'~NoLogin~') AS 'LastLoginDate',
		isnull(cast(max(nl.NumberOfLogins12Months) as varchar),'~NoLogin~') as 'NumberOfLogins12Months'

from (
		select	u.userid,
				u.UserName, 
				u.FirstName, 
				u.LastName,
				EmailAddress,
				lt.LicenseTypeName,
				STRING_AGG(ur.rolename,' | ') within group (order by ur.rolename) as 'UserRoles'

		from users u
		left join licensetype lt on u.LicenseTypeID=lt.LicenseTypeID
		right join UserRoleAssignments ura on u.UserID=ura.UserID
		left join UserRoles ur on ur.roleid=ura.RoleID 

		where IsEnabled=1 and u.LicenseTypeID in (3,4) and ur.RoleTypeID=2
		group by u.userid,u.UserName, u.FirstName, u.LastName,u.EmailAddress,lt.LicenseTypeName
			) a

LEFT JOIN UserLogonHistory ulh ON a.UserID = ulh.UserID
LEFT JOIN numLogins nl ON a.UserID = nl.UserID

group by	a.UserName, 
			a.FirstName, 
			a.LastName,
			a.EmailAddress,
			a.LicenseTypeName,
			a.UserRoles

order by isnull(format(convert(datetime,MAX(DATEADD(hour,10,ulh.StatusDate))),'dd MMM yyyy'),'~NoLogin~') desc