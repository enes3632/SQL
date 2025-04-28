--Compares the two texts and finds the similarity rate with the dice-coefficient method. -esahin

declare @t1 nvarchar(1000) = 'Text1'
		,@t2 nvarchar(1000) = 'Text2'
		,@C int = 1
		,@common decimal
		,@count decimal

drop table if exists #tmp, #tmp2
create table #tmp (sub nvarchar(2)
					,[String] nvarchar(10) )


while @c!=len(@t2)
begin
	while @c < len(@t1)
	begin
		insert into #tmp
		select substring(upper(@t1),@c,2) [sub]
				,'t1' [String]
		set @c = @c + 1
	end

	set @c = 1
	while @c < len(@t2)
	begin
		insert into #tmp
		select substring(upper(@t2),@c,2) [sub]
				,'t2' [String]
		set @c = @c + 1
	end
end

select @common = sum([count])
		,@count = (select count(*) from #tmp)
from(
	select count(*) / 2 [count]
	from #tmp
	group by sub
	having count([String]) > 1 and string_agg([String],',') within group (order by [String]) like '%t1%t2%'
	) a

select format(2 * @common * 100 / @count,'0.00') [MatchPercent]