with AlessaPermissions as (

    select isnull(u.UserName, ur.RoleName) as Principal
		,'Workflow' as 'ObjectType'
        ,rs.Code + ' ~ ' + isnull(rsc.ConditionName, '[Default]') + ' ~' as ObjectName
        ,case when pa.PermissionValue & 8 = 8 then 'N' when pa.PermissionValue & 1024 = 1024 then 'Y'  else '' end as 'Create'
        ,case when pa.PermissionValue & 4 = 4 then 'N' when pa.PermissionValue & 512 = 512 then 'Y' else '' end as 'View'
        ,case when pa.PermissionValue & 2 = 2 then 'N' when pa.PermissionValue & 256 = 256 then 'Y' else '' end as 'Modiify'
        ,case when pa.PermissionValue & 1 = 1 then 'N' when pa.PermissionValue & 128 = 128 then 'Y' else '' end as 'Delete'
    
	from PermissionAssignments pa
    left join Users u on pa.PrincipalID = u.UserID
    left join UserRoles ur on pa.PrincipalID = ur.RoleID
    join ResultSetConditions rsc on pa.ObjectID = rsc.ConditionID
    join ResultSets rs on rsc.ResultSetID = rs.ResultSetID

    where isnull(ur.RoleTypeID, 2) = 2
        and pa.PrincipalID not in (select UserID from Users where LicenseTypeID in (6,7))
        and pa.PermissionValue != 0

    union

    select isnull(u.UserName, ur.RoleName) as Principal
        ,'Column' as 'ObjectType'
		,rs.Code + ' || ' + rscol.ColumnName + ' ||' as ObjectName
        ,case when pa.PermissionValue & 8 = 8 then 'N' when pa.PermissionValue & 1024 = 1024 then 'Y'  else '' end as 'Create'
        ,case when pa.PermissionValue & 4 = 4 then 'N' when pa.PermissionValue & 512 = 512 then 'Y' else '' end as 'View'
        ,case when pa.PermissionValue & 2 = 2 then 'N' when pa.PermissionValue & 256 = 256 then 'Y' else '' end as 'Modiify'
        ,case when pa.PermissionValue & 1 = 1 then 'N' when pa.PermissionValue & 128 = 128 then 'Y' else '' end as 'Delete'

    from PermissionAssignments pa
    left join Users u on pa.PrincipalID = u.UserID
    left join UserRoles ur on pa.PrincipalID = ur.RoleID
    join ResultSetColumns rscol on pa.ObjectID = rscol.ColumnID
    join ResultSets rs on rscol.ResultSetID = rs.ResultSetID

    where isnull(ur.RoleTypeID, 2) = 2
        and pa.PrincipalID not in (select UserID from Users where LicenseTypeID in (6,7))
        and pa.PermissionValue != 0

    union

    select isnull(u.UserName, ur.RoleName) as Principal
        ,'Indicator' as 'ObjectType'
		,isnull(ig.GroupName, '[Default]') +'->'+ isnull(ic.CategoryName, '[Default]') +'->'+ i.IndicatorName as ObjectName
        ,case when pa.PermissionValue & 8 = 8 then 'N' when pa.PermissionValue & 1024 = 1024 then 'Y'  else '' end as 'Create'
        ,case when pa.PermissionValue & 4 = 4 then 'N' when pa.PermissionValue & 512 = 512 then 'Y' else '' end as 'View'
        ,case when pa.PermissionValue & 2 = 2 then 'N' when pa.PermissionValue & 256 = 256 then 'Y' else '' end as 'Modiify'
        ,case when pa.PermissionValue & 1 = 1 then 'N' when pa.PermissionValue & 128 = 128 then 'Y' else '' end as 'Delete'

    from PermissionAssignments pa
    left join Users u on pa.PrincipalID = u.UserID
    left join UserRoles ur on pa.PrincipalID = ur.RoleID
    join Indicators i on pa.ObjectID = i.IndicatorID
	left join IndicatorCategories ic on ic.CategoryID=i.CategoryID
	left join IndicatorGroups ig on ig.GroupID=i.GroupID

    where isnull(ur.RoleTypeID, 2) = 2
        and pa.PrincipalID not in (select UserID from Users where LicenseTypeID in (6,7))
        and pa.PermissionValue != 0
)

select * from AlessaPermissions

where ObjectType like '%'

order by Principal, ObjectType desc, ObjectName