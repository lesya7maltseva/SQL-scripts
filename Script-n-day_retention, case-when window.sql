Задание
Давайте еще немного поработаем над вовлеченностью пользователей нашей платформы. 
Мы задались вопросом:
А какой процент заходов на платформу не сопровождается активностью?

То есть надо посчитать % визитов, в которых человек зашел на платформу 
(есть запись в UserEntry за конкретный день), но не проявил активность 
(нет записей в CodeRun, CodeSubmit, TestStart за этот же день).

Столбцы в результате
В результате нужно вывести один столбец - entries_without_activities: 
посчитанный процент в диапазоне 0-100, округленный до 2 знака после запятой.

Обратите внимание
Продублируем важные моменты, о которых мы писали в Главе. 
Они вам пригодятся при решении задачи.


Заходы пользователя на платформу смотрим в таблице UserEntry.

Запись в UserEntry делается только один раз в сутки для каждого юзера - в момент первого визита.
Когда человек отправляет код на Выполнение, делается запись в таблицу CodeRun.
Когда человек отправляет код на Проверку, делается запись в таблицу CodeSubmit.
Когда человек стартует тест, делается запись в таблицу TestStart.

select 
user_id, array_agg(entry_at::date)
from userentry u
group by user_id 



with activities as (
	    select user_id, created_at::date as dt 
		from codesubmit c
		union 
		select user_id, created_at::date as dt 
		from coderun c
		union 
		select user_id, created_at::date as dt 
		from teststart t) 
select round(sum(case when a.user_id is null then 1 else 0 end)* 100.0/count(*),2) entries_without_activities
from userentry u 
left JOIN activities a ON u.entry_at::date = a.dt AND u.user_id = a.user_id

Задание
Есть набор стандартных метрик, которые нужно знать про свой бизнес вне зависимости от того, 
какие услуги вы оказываете или какая у вас модель монетизации. 
К таким метрикам относятся, например, золотая тройка:

DAU
WAU
MAU

Сейчас перед вами стоит задача - написать запрос для расчета MAU 
на основании заходов пользователей на платформу (UserEntry).

Однако, не забудьте несколько важных моментов:
В результате вы должны получить лишь 1 число, а не таблицу.
Если вы будете просто группировать по месяцам, то текущий месяц может испортить статистику, т.к. он неполный (если сегодня не последнее число месяца).
MAU != 4*WAU
MAU != 30*DAU

Поэтому при расчетах давайте руководствоваться следующим соглашением:
Учитываем только месяцы, в которые были заходы на платформу в течение 25 
или более дней (не обязательно подряд

select date_trunc('month',entry_at), count(distinct u.user_id)
from userentry u
group by date_trunc('month',entry_at)

select round(avg(active_users), 2) MAU
from ( select date_trunc('month',entry_at), 
			count(distinct date_part('day',entry_at)), 
			count(distinct u.user_id) as active_users
			from userentry u
			group by date_trunc('month',entry_at)
			having count(distinct date_part('day',entry_at)) >=25) t1

			
В рамках исследования с целью смены модели монетизации на платформе IT Resume нам очень интересно
посчитать метрику - классический n-day retention. Это поможет нам лучше понять активность 
пользователей и ответить на многие вопросы. Например:

Нужно ли вводить бесплатный период или пользователи в целом довольно быстро уходят с платформы?
Какое сейчас значение ретеншен и насколько сильно нам его нужно повышать, чтобы хотя
бы несколько месяцев получать деньги за подписку?
На какой день основная масса людей отваливается?
Нас интересуют конкретные N-дни (по сути, это самые распространенные отсечки времени на практике): 
0, 1, 3, 7, 14, 30, 60 и 90 дня. У нас не так много данных, поэтому ограничимся кварталом 😄

Важный момент: Пользователей давайте разобьем по когортам - так намного показательней.
В качестве признака когорты будем использовать месяц регистрации пользователя.

На выходе вы должны получить таблицу следующего вида (это просто форма, значения не точные):
Столбцы в результате
cohort - столбец с когортами (год - месяц)
N (%) - n-day, где N - конкретное число
Значения в таблице округлите до 2 знака после запятой.

Сортировка
Столбцы в результате остортируйте по возрастанию когорт.

Обратите внимание
Продублируем важные моменты, о которых мы писали в Главе. 
Они вам пригодятся при решении задачи.
Заходы пользователя на платформу смотрим в таблице UserEntry.
Когорты при расчете retention формируем по месяцам регистрации пользователей 
и только начиная с 2022 года.
Для некоторых пользователей в таблице UserEntry нет данных об их входе в самый первый день. 
Поэтому при расчете ретеншена 0 дня учитывайте пользователей, которые заходили в 0 день.

При расчетах опирайтесь на реальные дни - 24 часа. Если я зарегистрировался сегодня в 23:59, 
то не нужно считать, что через 1 минуту уже пошел 1 день. Первый день начнется завтра в 23:59.
Это правильней.

with cte as (
	select to_char(u.date_joined, 'YYYY-mm') cohort, 
			ue.user_id, 
			ue.entry_at::date dt_entry, 
			u.date_joined::date dt_birthday,
			extract(days from ue.entry_at - u.date_joined) dt_diff    
	from userentry ue 
	left join users u on u.id = ue.user_id
	where to_char(u.date_joined, 'YYYY') = '2022'  	
	)
select cohort,
		round(count(distinct case when dt_diff = 0 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2) as "0(%)",
		round(count(distinct case when dt_diff = 1 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric , 2) as "1(%)",
		round(count(distinct case when dt_diff = 3 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2)as "3(%)",
		round(count(distinct case when dt_diff = 7 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric , 2)as "7(%)",
		round(count(distinct case when dt_diff = 14 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2)as "14(%)",
		round(count(distinct case when dt_diff = 30 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2)as "30(%)",
		round(count(distinct case when dt_diff = 60 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2)as "60(%)",
		round(count(distinct case when dt_diff = 90 then user_id end)*100/count(distinct case when dt_diff = 0 then user_id end)::numeric, 2)as "90(%)"
from cte
group by cohort

Как мы обсудили в прошлой задаче, когда считали N-day retention - метрика rolling retention 
для нас намного более показательная. Человек мог зайти на платформу спустя 20 дней после 
регистрации, но не прийти в 7:

n-day retention 7 дня покажет, что мы потеряли человека
rolling retention 7 дня покажет, что человек все еще с нами, потому что эта метрика 
учитывает текущий день и все последующие дни

Нас снова интересуют конкретные N-дни: 0, 1, 3, 7, 14, 30, 60 и 90 дня.

Важный момент: Пользователей опять разбиваем по когортам - так намного показательней. 
В качестве признака когорты будем использовать месяц регистрации пользователя.

На выходе вы должны получить таблицу следующего вида (это просто форма, значения не точные):

with cte as (
	select to_char(u.date_joined, 'YYYY-mm') cohort, 
			ue.user_id, 
			ue.entry_at::date dt_entry, 
			u.date_joined::date dt_birthday,
			extract(days from ue.entry_at - u.date_joined) dt_diff    
	from userentry ue 
	left join users u on u.id = ue.user_id
	where to_char(u.date_joined, 'YYYY') = '2022'  	
	)
	select cohort,
		round(count(distinct case when dt_diff >= 0 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2) as "0(%)",
		round(count(distinct case when dt_diff >= 1 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric , 2) as "1(%)",
		round(count(distinct case when dt_diff >= 3 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2)as "3(%)",
		round(count(distinct case when dt_diff >= 7 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric , 2)as "7(%)",
		round(count(distinct case when dt_diff >= 14 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2)as "14(%)",
		round(count(distinct case when dt_diff >= 30 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2)as "30(%)",
		round(count(distinct case when dt_diff >= 60 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2)as "60(%)",
		round(count(distinct case when dt_diff >= 90 then user_id end)*100/count(distinct case when dt_diff >= 0 then user_id end)::numeric, 2)as "90(%)"
from cte
group by cohort

У нас есть гипотеза по поводу введения подписки на платформе IT Resume:
А что если ограничивать количество задач и тестов, которые доступны пользователям бесплатно?
Грубо говоря - решил 5 задач, и все, остальное по подписке.
Чтобы принять такое решение, нам нужно понимать - а сколько вообще в среднем задач и тестов 
решают/проходят наши пользователи.
Соответственно, ваша задача посчитать:
сколько в среднем задач решает один пользователь (пусть даже неправильно, но хотя 
бы делает попытку)
сколько в среднем тестов начинает проходить один пользователь (пусть даже не заканчивает)
Но все мы знаем анекдот про «среднюю температуру по больнице» и «среднюю зарплату». 
Так и здесь.
В аналитике очень рекомендуется также оценивать медиану. Если медиана и среднее значение
примерно совпадают - значит все хорошо, перекосов нет. А если возникают сильные отличия, 
значит какие-то пользователи сильно много/мало решают задач и сбивают статистику 
(сильно отклоняются от большей массы других пользователей), а медиана это нивелирует.
Поэтому дополнительно давате посчитаем то же самое, но с точки зрения медианы:

медианное значение решаемых задач
медианное значение проходимых тестов
Важный момент: Это все должно быть посчитано одним запросом.
Столбцы в результате
problems_avg - среднее число решаемых задач
tests_avg - среднее число проходимых тестов
problems_median - медианное число решаемых задач
tests_median - медианное число проходимых тестов

Средние значения округлите до 2 знака после запятой.

Обратите внимание
Продублируем важные моменты, о которых мы писали в Главе. 
Они вам пригодятся при решении задачи.

Когда пользователь начинает тест, данные попадают в TestStart.
Когда пользователь отправляет код на проверку, данные попадают в CodeSubmit.
Когда пользователь отправляет код на выполнение, данные попадают в CodeRun.
	
with tasks as (
	select t1.user_id, count (distinct t1.problem_id) as cnt_tasks
	from (	
		select c.user_id,c.problem_id  
		from codesubmit c
		union all
		select c.user_id, c.problem_id 
		from coderun c) t1	
	group by t1.user_id),
tests as ( 
		select user_id,count(distinct test_id) as cnt_tests
		from teststart
		group by user_id)
select round(avg(cnt_tasks),2) problems_avg,
round(avg(cnt_tests), 2) tests_avg,
percentile_cont(0.5) within group (order by cnt_tasks) problems_median,
percentile_cont(0.5) within group (order by cnt_tests) tests_median
from tasks t1
full join tests t2 on t1.user_id = t2.user_id

На основании таблиц с активностью (CodeRun, CodeSubmit, TestStart)
нужно найти распределение активности по часам суток (от 0 до 23).

Примечание: Учитываем все записи в этих таблицах.
Столбцы в результате
В результате нужно вывести столбцы:
hour - номер часа в числовом формате (0, 1, 2, ...)
cnt - количество активностей
Результат отсортируйте по возрастанию часа.

with activities as (
	    select user_id, created_at as dt 
		from codesubmit c
		union 
		select user_id, created_at as dt 
		from coderun c
		union 
		select user_id, created_at as dt 
		from teststart t) 
select date_part('hours', dt), dt::date, count(*)
from activities
group by dt::date, date_part('hours', dt)
order by dt::date asc, date_part('hours', dt) asc

На основании таблиц с активностью (CodeRun, CodeSubmit, TestStart) 
нужно найти распределение активности по дням недели.

Примечание: Учитываем все записи в этих таблицах.
Столбцы в результате
В результате нужно вывести столбцы:

day - числовой номер дня (1 - понедельник, 2 - вторник, ...) в текстовом формате
cnt - количество активностей
Результат отсортируйте по возрастанию дня недели.

with activities as (
	    select user_id, created_at as dt 
		from codesubmit c
		union 
		select user_id, created_at as dt 
		from coderun c
		union 
		select user_id, created_at as dt 
		from teststart t) 
select to_char(dt, 'Day'), count(*)
from activities
group by to_char(dt, 'Day')
order by to_char(dt, 'Day') asc

with activities as (
	    select user_id, created_at as dt 
		from codesubmit c
		union 
		select user_id, created_at as dt 
		from coderun c
		union 
		select user_id, created_at as dt 
		from teststart t) 
select extract (isodow from dt) "day", count(*) cnt
from activities
group by extract (isodow from dt)
order by extract (isodow from dt) asc

with activities as (
    select user_id, created_at as dt
    from coderun c
    union all
    select user_id, created_at as dt
    from codesubmit c2
    union all
    select user_id, created_at as dt
    from teststart
)
select
    to_char(dt, 'ID') as day,
    count(*) as cnt
from activities
group by day