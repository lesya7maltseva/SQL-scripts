-- ABC-анализ 
with prep as 
	(select s.dr_ndrugs product, 
		sum(s.dr_kol) kol, 
		sum(s.dr_kol * s.dr_croz - s.dr_sdisc) revenue, 
		sum(s.dr_kol*(s.dr_croz-s.dr_czak) - s.dr_sdisc) profit 
	from sales s
	group by s.dr_ndrugs)
select product, 
		case
			when sum(kol)over(order by kol desc)/sum(kol) over() <= 0.8 then 'A'
			when sum(kol)over(order by kol desc)/sum(kol) over() <= 0.95 then 'B'
			else 'C'
		end as amount_abc,
		case
			when sum(profit)over(order by profit desc)/sum(profit) over() <= 0.8 then 'A'
			when sum(profit)over(order by profit desc)/sum(profit) over() <= 0.95 then 'B'
			else 'C'
		end as profit_abc,
		case
			when sum(revenue)over(order by revenue desc)/sum(revenue) over() <= 0.80 then 'A'
			when sum(revenue)over(order by revenue desc)/sum(revenue) over() <= 0.95 then 'B'
			else 'C'
		end as revenue_abc
from prep
order by product asc


--ABC + XYZ-анализ

with prep as 
	(select s.dr_ndrugs product, 
		sum(s.dr_kol) kol, 
		sum(s.dr_kol*(s.dr_croz-s.dr_czak) - s.dr_sdisc) profit, 
		sum((s.dr_kol * s.dr_croz) - s.dr_sdisc)  revenue
	from sales s
	group by s.dr_ndrugs),
	for_xyz as (
		select tn,
			case 
				when stddev_samp(t1.summ)/avg(t1.summ) <= 0.1 then 'X'
				when stddev_samp(t1.summ)/avg(t1.summ) <= 0.25 then 'Y'
				else 'Z'
			end as xyz	
		from (select s.dr_ndrugs TN,
					sum(s.dr_kol) summ, 
					to_char(s.dr_dat, 'YYYY-WW') dt
				from sales s
				group by s.dr_ndrugs, dt) t1      
		group by t1.tn
        having count(distinct t1.dt) >= 4
    )
select product, 
		case
			when sum(kol)over(order by kol desc)/sum(kol) over() <= 0.8 then 'A'
			when sum(kol)over(order by kol desc)/sum(kol) over() <= 0.95 then 'B'
			else 'C'
		end as amount_abc,
		case
			when sum(profit)over(order by profit desc)/sum(profit) over() <= 0.8 then 'A'
			when sum(profit)over(order by profit desc)/sum(profit) over() <= 0.95 then 'B'
			else 'C'
		end as profit_abc,
		case
			when sum(revenue)over(order by revenue desc)/sum(revenue) over() <= 0.80 then 'A'
			when sum(revenue)over(order by revenue desc)/sum(revenue) over() <= 0.95 then 'B'
			else 'C'
		end as revenue_abc,
		f.xyz as xyz_sales		
from prep p
left join for_xyz f on p.product = f.TN
order by product asc 

