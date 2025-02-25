Вывести:
id транзакции
сумму текущего списания/начисления для данной транзакции
общий баланс (списания - начисления) нарастающим итогом
накопительный итог 

with prep as (
    select
        id_transaction,
        case 
            when type = 0 then sum
            else -sum
        end as summ
    from transactions)
select *,
        sum(summ) over (order by id_transaction asc) as cumsum
from prep

нумерация строк
Вывести:
номер чека
дату покупки (без времени)
порядковый номер строки в рамках конкретного чека

select doc_id,
    date("date") as "date",
    row_number() over (partition by doc_id) num
from transactions
order by "date", doc_id, "num"

select *, 
    case
        when lower(username) = lower(email_trunc) then true
        else false
    end isEqual
from (select username, email, 
      substring(email from 1 for position('@' in email)-1) as email_trunc
      from users) as t

Использование substring чтобы обрезать строку до определенного символа
Также есть еще одна интересная задачка. У нас в разных проектах люди зачастую оставляют левую почту и мы не 
можем с ними связаться, даже после регистрации. 
Хотим проверить гипотезу - насколько часто юзернейм (то есть логин) совпадает с началом почты, которое идет до @.

Поэтому нужно написать запрос, который «отрубает» доменное имя и собачку и сравнивает это с полем username. 
Естественно, регистр букв учитывать не нужно.

select *, 
    case
        when lower(username) = lower(email_trunc) then true
        else false
    end isEqual
from (select username, email, 
      substring(email from 1 for position('@' in email)-1) as email_trunc
      from users) as t

Тут синтаксис приведения типов, джойнов и объединений
Давайте посмотрим - сколько дней от момента регистрации каждого пользователя прошло до каждой его активности:
Отправка кода на проверку
Выполнение кода
Старт прохождения теста
Учитываем вообще любую такую активность - причем все одним запросом. 
Только давайте смотреть для тех ребят, у которых id больше 94 - остальные не нужны (это мертвые души). Нужно вывести 5 столбцов:

Почту пользователя
Логин пользователя
Дату активности
Тип активности (submit, run, test)
Количество дней с момента регистрации
Время при расчете отбрасывайте.
Дальше эта история вам пригодится в расчете ретеншена - причем не обычного, а основанного на реальной активности пользователя 
(ведь человек мог просто зайти и ничего не делать).

select u.email, u.username,c.created_at::date as created_at,'submit'as type, extract(day from date_trunc('day',c.created_at)- date_trunc('day',u.date_joined))::int diff
from users u
join codesubmit c on u.id = c.user_id
where u.id > 94
union all
select u.email, u.username, cr.created_at::date as created_at,
    'run' as type, extract(day from date_trunc('day',cr.created_at) -  date_trunc('day',u.date_joined))::int diff
from users u
join coderun cr on u.id = cr.user_id
where u.id > 94
union all
select u.email, u.username,  t.created_at::date as created_at, 'test' as type, extract(day from date_trunc('day',t.created_at) - date_trunc('day', u.date_joined)) ::int diff
from users u
join teststart t on u.id = t.user_id
where u.id > 94

предыдущее-следующее значение lag-lead

select  id,
        doc_id,
        sum,
        lead(sum) over w ld,
        lag(sum) over w lg    
from transactions
window w as (partition by doc_id order by id)
order by id asc

Cумма начислений
Для каждой транзакции сотрудника посчитайте прирост суммы начислений по сравнению с предыдущей транзакцией. 
Списания из расчета необходимо исключить. Если предыдущей транзакции нет, необходимо вывести NULL.

select *, round((sm - lg)/lg::numeric, 2) inc
from
(select employee,
    dt, 
    lag(sm) over (partition by employee order by dt) lg, 
    sm
from
(select employee, 
        sum(sum) sm,
        date dt
from transactions
where type = 0
group by employee, date  
order by employee asc) t1) t2

Как за окно посчитать сумму
Посчитайте суммарный подытог начислений и списаний в рамках каждой транзакции.
with balance as (
        select *,
            lead (sm) over (order by dt) ld,
            lag (sm) over (order by dt) lg
        from 
            (select
                max(date) dt, 
                id_transaction,
                sum(case when type = 0 then sum else - sum end) sm
            from transactions
            group by id_transaction
            ) t1
)
select id_transaction, 
        dt,
        sm as total,
        round((lg+sm+ld)::numeric/3, 2) as sliding
from balance
order by id_transaction

ранжирование без разрывов:
  value  |  rank  |
+---------+--------+
|   10    |    1   |
|    5    |    2   |
|    5    |    2   |
|    1    |    3   |

select employee, 
    type, 
    sum, 
    dense_rank() over (partition by employee order by sum desc) rnk
from transactions
order by employee desc, rnk asc

ранжирование с разрывами:
+---------+--------+
|  value  |  rank  |
+---------+--------+
|   10    |    1   |
|    5    |    2   |
|    5    |    2   |
|    1    |    4   |
+---------+--------+

select employee, 
    type, 
    sum, 
    rank() over (partition by employee order by sum desc) rnk
from transactions
order by employee desc, rnk asc

использование регулярных выражений similar_to:

select c.code, l.name 
from language l
join codesubmit c on c.language_id = l.id
where (l."name" = 'SQL' and lower(c.code) similar to 'drop_%|delete_%|truncate_%|insert_%|create_%')
or (l."name" = 'Python' and lower (c.code) similar to '%exec\(%|%eval\(%|exec_\(%|%eval_\(%')

замена определенного значения на другое coalesce

select coalesce (ptc."name",'NEW! '|| p."name") problem, 11 as company_id 
from problem_to_company ptc
join problem p on p.id = ptc.problem_id 
where ptc.company_id = 3

использование generateseries

select num, p.id problem
from generate_series (1,12) num
cross join problem p

извлекаем разницу в днях с помощью extract

select email, date_joined, extract(day from current_timestamp - date_joined) as diff
from users

ещё один способ откинуть часы до даты:

select u.username, to_char(date_joined, 'dd.MM.YYYY') date_joined
from users u 
where coalesce(company_id, 0) != 2

режем дату datetrunc создаем дату makedate
select *
from users
where date_trunc('day',date_joined) between make_date(2022, 04, 01) and make_date(2022, 04, 10)


синтаксис case-when и between

select email, score,
    case
        when score between 0 and 19 then 'D'
        when score between 20 and 99 then 'C'
        when score between 100 and 499 then 'B'
        else 'A'
    end as class
from users
