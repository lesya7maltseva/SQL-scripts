Необходимо изучить сочетаемость товаров. 
Фактически, вам нужно посмотреть, какой товар и как часто встречается 
одновременно с другими товарами в чеке - и так по всем товарам.

with prep as (
	select dr_ndrugs as product , dr_nchk as chk, dr_apt as apt,dr_dat as dt
	from sales s 
	group by dr_ndrugs, dr_nchk, dr_apt, dr_dat),
pairs as	
	(select t1.product as product1, t2.product as product2 
	from prep t1
	cross join prep t2 
	where t1.chk = t2.chk 
		and t1.apt = t2.apt
		and t1.dt = t2.dt
		and t1.product < t2.product)
select product1, product2, count(*) as cnt
from pairs
group by product1, product2
order by cnt desc

Необходимо построить полную таблицу продаж товаров во всех аптеках 
в формате «товар - аптека - продано штук». Если вдруг в какой-то аптеке 
конкретный товар не продавался, то просто выводим null.

with price as(
		select distinct dr_ndrugs as TN 
		from sales
),
drugstores as(
		select distinct dr_apt as id_apt
		from sales s 
),
variances as(
		select *
		from price,drugstores
),
apt_sales as (
		select dr_ndrugs as product, 
				dr_apt as apt, 
				round(sum(dr_kol)::numeric, 2) as cnt 
		from sales 
		group by dr_ndrugs, dr_apt)
select id_apt as apt, tn as drug,  cnt 
from apt_sales
right join variances v on apt = id_apt and product = TN

Посчитать DAU за каждый день 2022 года на основании заходов пользователей 
на платформу
Сделать столбец, где значения DAU будут сглажены с помощью метода скользящего 
среднего
Сделать столбец, где значения DAU будут сглажены с помощью метода медианного сглаживания

В результате должны получиться столбцы:
ymd - столбец с днем (в текстовом формате)
cnt - значение DAU
sliding_average - сглаживание средним
sliding_median - сглаживание медианой

with prep as(
	select to_char(u.entry_at, 'YYYY-mm-dd') dt, 
			count(distinct user_id) DAU
	from userentry u
	where to_char(u.entry_at, 'YYYY') >= '2022'
	group by dt)    
select dt ymd, 
		dau cnt, 
		avg(dau) over (order by dt) sliding_average,
		(select percentile_cont(0.5) within group (order by p2.dau) 
		from prep p2
		where p2.dt <= p1.dt) sliding_median 	
from prep p1

