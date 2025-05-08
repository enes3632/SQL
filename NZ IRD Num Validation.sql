--Find the New Zealand vendors with an invalid IRD Number -esahin

with cte as (
	SELECT IRD_Number_CLN IRD_Number_CLEAN
			,right('000000000'+cast(IRD_Number_CLN as varchar(30)),9) IRD_PAD
			,Vendor_Number Ven_Num
			,Vendor_Name [Name]
			,ROW_NUMBER() over(partition by vendor_ID, IRD_Number_CLN order by max_inv_dt desc) rw
			,*
	FROM [Schema1].[PREP_Vendors]
	where Country = 'New Zealand'
		and IRD_Number is not null
		and Vendor_Status ='A' 

)
, cte2 as (
	select * 
			,((	 substring(IRD_PAD,1,1) * 3
			+   substring(IRD_PAD,2,1) * 2
			+   substring(IRD_PAD,3,1) * 7
			+   substring(IRD_PAD,4,1) * 6
			+   substring(IRD_PAD,5,1) * 5
			+   substring(IRD_PAD,6,1) * 4
			+   substring(IRD_PAD,7,1) * 3
			+   substring(IRD_PAD,8,1) * 2)
				% 11) Modulus11
			,((	 substring(IRD_PAD,1,1) * 7
			+   substring(IRD_PAD,2,1) * 4
			+   substring(IRD_PAD,3,1) * 3
			+   substring(IRD_PAD,4,1) * 2
			+   substring(IRD_PAD,5,1) * 5
			+   substring(IRD_PAD,6,1) * 2
			+   substring(IRD_PAD,7,1) * 7
			+   substring(IRD_PAD,8,1) * 6)
			% 11) Modulus11_2
	from cte
	where rw = 1
)

select *
from cte2 
where 	len(IRD_Number_CLN ) not in (8,9)
		or cast(IRD_Number_CLN as bigint) not between 10000000 and 150000000
		or (
			(Modulus11 = 0
				and right(IRD_Number_CLN,1) != 0)

			or (Modulus11 != 0
				and
					(
						(11-Modulus11 != 10 
							and	right(IRD_Number_CLN,1) != 11 - Modulus11)

						or (11-Modulus11 = 10 
							and (
									(Modulus11_2 = 0
									and right(IRD_Number_CLN,1) != 0)
								
									or
									(Modulus11_2 != 0
									and right(IRD_Number_CLN,1) != 11-Modulus11_2)
								)
							)
					)
				)
			)
order by Vendor_Name desc
