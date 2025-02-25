--1
--Выведите названия самолётов, которые имеют менее 50 посадочных мест.

select a.model, count(*) "seats" 
from bookings.aircrafts a 
join bookings.seats s on s.aircraft_code = a.aircraft_code
group by a.model
having count(*) < 50

--2
--Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select t1.dates, t1.overall, round(100*(t1.overall - lag(t1.overall,1) over(order by t1.dates))/lag(t1.overall,1) over(order by t1.dates),2) "percentage" 
from (
	select date_trunc('month',b.book_date)::date as "dates", sum(b.total_amount) as "overall"
	from bookings.bookings b
	group by 1
	order by 1)t1
--3
--Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.

select t1.model
from
	(select a.model, array_agg(s.fare_conditions) as "fare"
	from bookings.aircrafts a 
	left join bookings.seats s on s.aircraft_code = a.aircraft_code
	group by a.aircraft_code)t1
where array_position(t1.fare, 'Business') is null  


--4
--Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день. 
--Учтите только те самолеты, которые летали пустыми и только те дни, 
--когда из одного аэропорта вылетело более одного такого самолёта.
--Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.

with empty_flights as
	(
	select  f.flight_id, f.aircraft_code, f.departure_airport "airport", date_trunc('day',f.actual_departure)::date "flight_date"  
	from bookings.flights f
	left join bookings.boarding_passes bp on f.flight_id = bp.flight_id
	where ticket_no is null and (f.status = 'Arrived' or f.status = 'Departed')
	group by f.flight_id, f.aircraft_code, f.departure_airport
	order by date_trunc('day',f.actual_departure)::date
	),
seats_amount as
	(
	select s.aircraft_code, count(*)"seats"
	from bookings.seats s
	group by s.aircraft_code
	)
select t1.airport,t1.flight_date, t1.seats, sum(t1.seats)over(partition by t1.airport, t1.flight_date rows between unbounded preceding and current row)
from(
	select *, count(ef.flight_id) over (partition by ef.airport,ef.flight_date)
	from empty_flights ef
	join seats_amount sa on sa.aircraft_code = ef.aircraft_code)t1
where t1.count>1


--5
--Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. 
--Выведите в результат названия аэропортов и процентное отношение.
--Используйте в решении оконную функцию.

select t1.dedarture_name, t1.arrival_name, round((100*t1.count/t1.sum),3)
from (select a.airport_name "dedarture_name", f.departure_airport, 
		f.arrival_airport, a2.airport_name "arrival_name", 
		count(*), sum(count(*)) over()
		from bookings.flights f
		join bookings.airports a on a.airport_code = f.departure_airport
		join bookings.airports a2 on a2.airport_code = f.arrival_airport
		group by a.airport_name, f.departure_airport, f.arrival_airport, a2.airport_name)t1



--6
--Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7
select distinct t1.operator_code, count(passenger_name) over (partition by t1.operator_code)
	from (
	select t.passenger_name, substring(t.contact_data->>'phone',3,3) as "operator_code"	
	from bookings.tickets t)t1
order by t1.operator_code asc

select t.passenger_name, substring(t.contact_data->>'phone',3,3) as "operator_code", count(*)	
from bookings.tickets t
group by 1,2

--7
--Классифицируйте финансовые обороты (сумму стоимости перелетов) по маршрутам:
--до 50 млн – low
--от 50 млн включительно до 150 млн – middle
--от 150 млн включительно – high
--Выведите в результат количество маршрутов в каждом полученном классе.


with cte1 as
(select concat (f.departure_airport, ' - ', f.arrival_airport) "direction", sum(tf.amount) "total_amount"
	from bookings.flights f
	left join bookings.ticket_flights tf on f.flight_id = tf.flight_id
	group by 1)
select t1.sorted,count(*)
from (
	select *,
		case 
			when c.total_amount < 50000000 then 'low'
			when c.total_amount <150000000 then 'middle'
			else 'high'
		end sorted	
	from cte1 c)t1
group by t1.sorted


--8
--Вычислите медиану стоимости перелетов, медиану стоимости бронирования и отношение медианы бронирования 
--к медиане стоимости перелетов, результат округлите до сотых.


with cte1 as
(
	select * 
	from bookings.tickets t 
	left join bookings.ticket_flights tf on t.ticket_no = tf.ticket_no
),
cte2 as 
(
	select *  
	from bookings.bookings b
)
select*, round((t1.bookings_median/t1.flights_median)::numeric,2) "medians_ratio"
from (
		select percentile_cont(0.5) within group (order by amount) as "flights_median", 
			(select percentile_cont(0.5) within group (order by total_amount) 
			from cte2) as "bookings_median"
		from cte1)t1
 


--9
--Найдите значение минимальной стоимости одного километра полёта для пассажира. 
--Для этого определите расстояние между аэропортами и учтите стоимость перелета.
--Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. 
--Для работы данного модуля нужно установить ещё один модуль – cube.
--Важно: 
--Установка дополнительных модулей происходит через оператор CREATE EXTENSION название_модуля.
--В облачной базе данных модули уже установлены.
--Функция earth_distance возвращает результат в метрах.
		
-- Для этого задания использовала облачное подключение, поскольку при локальном подключении не работала функция "ll_to_earth" 
-- Пишет ошибку: "SQL Error [42883]: ОШИБКА: функция ll_to_earth(double precision, double precision) не существует".  
-- Хотя запрос был абсолютно такой же. Модули cube и earthdistance подключала последовательно. 

SET search_path TO bookings


with cte1 as ( 
	select f.departure_airport, f.arrival_airport, min(tf.amount) as "min_amount"
	from flights f  
	left join ticket_flights tf on tf.flight_id = f.flight_id
	group by f.departure_airport, f.arrival_airport	
)
select t2.dep_airport, t2.arrival_airport, round(t2.min_amount/t2.distance, 2) "costs_per_km", min(round(t2.min_amount/t2.distance, 2)) over() as "min_costs"
from 
(
	select *, round(earth_distance(ll_to_earth(t1.dep_lat,t1.dep_long),ll_to_earth(t1.arr_lat,t1.arr_long))::numeric/1000, 2) as "distance"
	from
		(select a.airport_name "dep_airport",a.latitude "dep_lat", a.longitude "dep_long", 
				a2.airport_name "arrival_airport", a2.latitude "arr_lat", a2.longitude "arr_long", min_amount 
		from cte1 c
		join airports a on a.airport_code = c.departure_airport
		join airports a2 on a2.airport_code = c.arrival_airport
		where min_amount is not null)t1)t2
order by 3 asc