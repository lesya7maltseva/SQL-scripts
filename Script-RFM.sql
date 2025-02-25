
/*
 R
 0.13 - 1 40
 0.43 - 3 140
 F
 0.12 - 3 7
 0.70 - 1 39
 M
 0.12 - 3 200 - 3
 0.86 - 1 32 800 - 1
 * */

with preparation as (
		select datetime::date, card,
				max(datetime::date) over() - datetime::date recency,
				sum(summ) monetary		
		from bonuscheques b 
		where length(card) = 13
		group by card, datetime::date),
rfm as (
		select card,
				min(recency) recency,
				count(monetary) frequency,
				sum(monetary) monetary
		from preparation
		group by card),
for_perc_r as (
		select round(recency, -1) recency, count(*)
		from rfm 
		group by round(recency, -1)),
for_perc_f as (
		select frequency, count(*)
		from rfm 
		group by frequency),
for_perc_m as (
		select round(monetary, -2) monetary, count(*)
		from rfm 
		group by round(monetary, -2)),
rfm_groups as(
		select *,
			case 
				when recency <= (select percentile_disc(0.33) within group (order by recency) from for_perc_r)
					then '1 недавние'
				when recency <= (select percentile_disc(0.66) within group (order by recency) from for_perc_r)
					then '2 спящие'
				else '3 уходящие'
			end R,
			case 
				when frequency >= (select percentile_disc(0.1) within group (order by frequency) from for_perc_f)
					then '1 частые'
				when frequency <= (select percentile_disc(0.05) within group (order by frequency) from for_perc_f)
					then '3 разовые'
				else '2 редкие'
			end F,
			case 
				when monetary >= (select percentile_disc(0.70) within group (order by monetary) from for_perc_m)
					then '1 высокий чек'
				when monetary <= (select percentile_disc(0.15) within group (order by monetary) from for_perc_m)
					then '3 низкий чек'
				else '2 средний чек'
			end M
		from rfm),
rfm_classification as (
		select card,
			concat_ws(', ', r,f,m) rfm_groups
		from rfm_groups)
select rfm_groups, count(*) cnt
from rfm_classification
group by rfm_groups
order by rfm_groups asc

-- для удобства процентили посмотреть
with preparation as (
		select datetime::date, card,
				max(datetime::date) over() - datetime::date recency,
				sum(summ) monetary		
		from bonuscheques b 
		where length(card) = 13
		group by card, datetime::date),
rfm as (
		select card,
				min(recency) recency,
				count(monetary) frequency,
				sum(monetary) monetary
		from preparation
		group by card),
for_perc_r as (
		select round(recency, -1) recency, count(*)
		from rfm 
		group by round(recency, -1)),
for_perc_f as (
		select frequency, count(*)
		from rfm 
		group by frequency),
for_perc_m as (
		select round(monetary, -2) monetary, count(*)
		from rfm 
		group by round(monetary, -2))
--select percentile_disc(0.3) within group (order by monetary) from for_perc_m		
--select percentile_disc(0.3) within group (order by recency) from for_perc_r
select percentile_disc(0.1) within group (order by frequency) from for_perc_f




