Необходимо для каждой mcc группы вывести 3 наиболее дорогих транзакции 
за 2019 и 2020 год. Если в рамках какой-то mcc группы за год было 
менее 3 транзакций, то недостающие места должны быть дополнены null.

В результате необходимо вывести столбцы:
group_name - имя группы
year - год
rn - ранг
transaction_value - сумма транзакции

Результат должен быть отсортирован по имени группы, рангу и году по возрастанию всех полей. 
Все суммы округлите до 2 знака после запятой.

with transactions as(
		select group_name,
			date_part('year', transaction_date) "year",
			transaction_value
		from purchases p
		left join mcc_codes mc on p.mcc_code_id = mc.mcc_code_id 
		and p.transaction_date  between mc.valid_from and mc.valid_to
		join mcc_groups mg on mg.group_id  = mc.group_id),
from_2019 as (
		select *
		from
			(select *,
					row_number() over (partition by group_name order by "year") n,
					dense_rank() over (partition by group_name order by "year", transaction_value desc) rnk
			from transactions
			where "year" = '2019') t1
		where n <=3
		order by group_name),
from_2020 as (
		select *
		from
			(select *,
					row_number() over (partition by group_name order by "year") n,
					dense_rank() over (partition by group_name order by "year", transaction_value desc) rnk
			from transactions
			where "year" = '2020') t1
		where n <=3),
variances as 
		(select  group_name, 
				"num"
		from mcc_groups, generate_series(1,3) num 
		order by group_name, "num" asc)
select *
from
	(select v.group_name, 
			coalesce("year", '2020') "year",		
			coalesce(rnk, num) rn,
			round(transaction_value::numeric, 2)
	from variances v
	left join from_2020 f on v.group_name = f.group_name and n = num
	union all
	select v.group_name, 
			coalesce("year", '2019') "year",		
			coalesce(rnk, num) rn,
			round(transaction_value::numeric, 2)
	from variances v
	left join from_2019 f on v.group_name = f.group_name and n = num) t1
order by group_name, rn, "year"


Необходимо рассчитать mcc-группы, по которым было больше всего транзакций в 2019 году. 
Расчет необходимо произвести за каждый месяц в отдельности.
В результате необходимо вывести столбцы:
group_name - имя группы
month - месяц
tr_sum - сумму транзакций
abs_diff - абсолютную разницу со вторым местом по сумме транзакций
rel_diff - относительную разницу со вторым местом по сумме транзакций

Дополнительные условия:
Если в каком-то месяце нет ни одного заказа, то указать null для всех столбцов (кроме month).
Если в каком-то месяце заказы были только по одной mcc-группе, то абсолютную/относительную 
разницу указать как null.
Если в каком-то месяце сумма транзакций совпадает для нескольких групп, то ранжирование 
происходит по лексикографическому признаку.
Все суммы округлите до 2 знака после запятой.
Результат должен быть отсортирован по возрастанию месяца - от 1 к 12

with transactions as(
		select group_name,
			date_trunc('month', transaction_date) "month",
			sum(transaction_value) tr_sum
		from purchases p
		left join mcc_codes mc on p.mcc_code_id = mc.mcc_code_id 
		and p.transaction_date  between mc.valid_from and mc.valid_to
		join mcc_groups mg on mg.group_id  = mc.group_id
		where to_char(transaction_date, 'YYYY') = '2019'
		group by group_name, date_trunc('month', transaction_date) 
		), 
ranked as (
		select *,
			rank() over (partition by "month" order by tr_sum desc, group_name asc) rn
		from transactions),
diffs as (
		select group_name, 
				extract(month from "month") "month",
				tr_sum,
				abs_diff,
				abs_diff/tr_sum as rel_diff
		from
			(select *, 
				tr_sum::numeric - lead (tr_sum) over (order by "month") as abs_diff
			from ranked) q1
		where rn = 1)
select group_name,
		num as "month",
		tr_sum,
		abs_diff,
		rel_diff
from diffs d
right join 
(select num from generate_series(1,12) num) gs 
on gs.num = d.month



with pass_and_addr as(
		select client_id,
				date_change,
				null as av,
				coalesce(passport_value, '***') pv
		from merchant.public.client_passport_change_log cpcl 
		union 
		select client_id,
				date_change,
				coalesce(address_value,'***') av,
				null as pv
		from merchant.public.client_address_change_log cacl),
clients_group as( 
		select client_id, 
				date_change,
				max(av) av,
				max(pv) pv
		from pass_and_addr
		group by client_id, date_change
),
ranked_clients as(
		select client_id,
				date_change as valid_from,
				lead (date_change,1, to_date('6000.01.01', 'yyyy.mm.dd'))
				over (partition by client_id order by date_change) - 1 as valid_to,
				av,
				sum(case when av is null then 0 else 1 end) 
					over (partition by client_id order by date_change) client_av,
				pv,	
				sum(case when pv is null then 0 else 1 end) 
					over (partition by client_id order by date_change) client_pv
		from clients_group)
select rc.client_id,
c.client_name,
valid_from,
valid_to,
case
	when first_value(av) over (partition by rc.client_id, client_av order by valid_from) != '***'
	then first_value(av) over (partition by rc.client_id, client_av order by valid_from)
end,
case
	when first_value(pv) over (partition by rc.client_id, client_pv order by valid_from) != '***'
	then first_value(pv) over (partition by rc.client_id, client_pv order by valid_from)
end
from ranked_clients rc
join clients c on c.client_id = rc.client_id

with pass_and_addr as(
		select client_id,
				date_change,
				null as av,
				coalesce(passport_value, '***') pv
		from merchant.public.client_passport_change_log cpcl 
		union 
		select client_id,
				date_change,
				coalesce(address_value,'***') av,
				null as pv
		from merchant.public.client_address_change_log cacl),
clients_group as( 
		select client_id, 
				date_change,
				max(av) av,
				max(pv) pv
		from pass_and_addr
		group by client_id, date_change
)
select client_id,
		date_change as valid_from,
		lead (date_change,1, to_date('6000.01.01', 'yyyy.mm.dd'))
		over (partition by client_id order by date_change) - 1 as valid_to,
		av,
		sum(case when av is null then 0 else 1 end) 
			over (partition by client_id order by date_change) client_av,
		pv,	
		sum(case when pv is null then 0 else 1 end) 
			over(partition by client_id order by date_change) client_pv
from clients_group

Посчитать DAU за каждый день 2022 года на основании заходов пользователей на платформу
Сделать столбец, где значения DAU будут сглажены с помощью метода скользящего среднего
Сделать столбец, где значения DAU будут сглажены с помощью метода медианного сглаживания

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


Еще одна интересная метрика - как менялось пиковое значение по ежедневному 
количеству регистраций на платформе.
Давайте возьмем период с 01.01.2022 и последующие 110 дней. А потом найдем:

dt - какая дата (тип данных timestamp)
cnt - сколько людей зарегистрировалось в этот день
max_cnt - нарастающее значение максимума регистраций
diff - разница между текущим значением и актуальным максимумом

with prep as 
		(select date_joined::date dt, 
				count(u.id) cnt
		from users u 
		group by date_joined::date
		having date_joined::date between '2022-01-01'::date and '2022-01-01'::date + 111
		),
calendar as
		(select generate_series('2022-01-01'::date, '2022-01-01'::date +110, '1 day')::timestamp  dt_c)
select date_trunc('hour',dt_c ) dt,
		coalesce(cnt, 0) cnt,
		max(cnt) over (order by dt) as max_cnt,
		coalesce(cnt, 0) - max(cnt) over (order by dt) as diff
from prep
right join calendar on dt = dt_c
order by dt

Раз уж мы заговорили про динамику, то обязательно нужно посмотреть, как менялось 
количество уникальных активных пользователей с течением времени. 
Потому что люди могли регистрироваться и не заходить потом. Или же задачи могли 
решать постоянно одни и те же люди.

На основании того, как пользователи решают задачи 
(таблицы coderun и codesubmit), найдите:

ymd - дата активности
unique_cnt - количество уникальных пользователей в период с 
01.01.2022
 по текущий день
Примечание: Здесь учитываем только те дни, в которые активность реально была.

with union_res as (
		select date_trunc('day',c.created_at) dt,
				user_id 
		from codesubmit c
		where date_trunc('day',c.created_at)>= '01.01.2022'
		union all
		select date_trunc('day',c2.created_at) dt,
				c2.user_id
		from coderun c2	
		where date_trunc('day',c2.created_at)>='01.01.2022'),
first_user as (
		select dt, 
				user_id,
				case 
					when lag(user_id) over (partition by user_id order by dt) is null then 1 
					else 0
				end is_first
		from union_res
		group by dt, user_id)
select dt::date as ymd,
		sum(uniq_u) over (order by dt) as unique_cnt
from
	(select dt, 
			sum(is_first)::int uniq_u   
	from first_user
	group by dt
	order by dt) t1
