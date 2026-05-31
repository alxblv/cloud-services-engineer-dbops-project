# dbops-project
Исходный репозиторий для выполнения проекта дисциплины "DBOps"

Выдали пользователю testuser, под которым будут выполняться тесты и миграции, все привилегии, как в уроке 4 (Аспекты безопасности в работе с базами данных)

```
postgres=# create database store with owner johndoe;
CREATE DATABASE
postgres=# create role testuser with login password '123';
CREATE ROLE
postgres=# grant all privileges on database store to testuser;
GRANT
```

Шаг 10: Запрос, возвращающий количество сосисок, проданных за каждый день последней недели. Включили время выполнения запроса, как показано в подсказке:

```
sandbox_db=> \timing
Timing is on.
sandbox_db=> SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
 date_created |  sum   
--------------+--------
 2026-05-25   | 943971
 2026-05-26   | 942396
 2026-05-27   | 944031
 2026-05-28   | 951840
 2026-05-29   | 948941
 2026-05-30   | 943174
 2026-05-31   | 692642
(7 rows)

Time: 600.018 ms
sandbox_db=> 
```

План запроса:

```
sandbox_db=> EXPLAIN ANALYZE SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;


-------
 Finalize GroupAggregate  (cost=266097.83..266120.88 rows=91 width=12) (actual time=724.727..729.047 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=266097.83..266119.06 rows=182 width=12) (actual time=724.701..729.020 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=265097.80..265098.03 rows=91 width=12) (actual time=716.242..716.244 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=265093.93..265094.84 rows=91 width=12) (actual time=716.225..716.228 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Hash Join  (cost=148289.32..264589.09 rows=100968 width=8) (actual time=260.652..709.431 rows=83171 loops=3)
                           Hash Cond: (op.order_id = o.id)
                           ->  Parallel Seq Scan on order_product op  (cost=0.00..105362.15 rows=4166715 width=12) (actual time=0.014..135.143 rows=3333333 loops=3)
                           ->  Parallel Hash  (cost=147027.26..147027.26 rows=100965 width=12) (actual time=260.198..260.198 rows=83171 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 13792kB
                                 ->  Parallel Seq Scan on orders o  (cost=0.00..147027.26 rows=100965 width=12) (actual time=5.838..248.646 rows=83171 loops=3)
                                       Filter: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Rows Removed by Filter: 3250162
 Planning Time: 0.873 ms
 JIT:
   Functions: 54
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.288 ms, Inlining 0.000 ms, Optimization 0.776 ms, Emission 16.754 ms, Total 18.818 ms
 Execution Time: 744.140 ms
(29 rows)
```

Шаг 11: После [добавления индексов](./migrations/V004__create_index.sql):

```
--------------------
 Finalize GroupAggregate  (cost=188104.54..188127.59 rows=91 width=12) (actual time=573.384..579.881 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=188104.54..188125.77 rows=182 width=12) (actual time=573.376..579.871 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=187104.51..187104.74 rows=91 width=12) (actual time=563.829..563.831 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=187100.64..187101.55 rows=91 width=12) (actual time=563.808..563.811 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Hash Join  (cost=70296.64..186595.81 rows=100967 width=8) (actual time=112.208..557.194 rows=83171 loops=3)
                           Hash Cond: (op.order_id = o.id)
                           ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=0.007..136.939 rows=3333333 loops=3)
                           ->  Parallel Hash  (cost=69034.55..69034.55 rows=100967 width=12) (actual time=111.828..111.829 rows=83171 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 13824kB
                                 ->  Parallel Bitmap Heap Scan on orders o  (cost=3320.22..69034.55 rows=100967 width=12) (actual time=25.624..100.514 rows=83171 loops=3)
                                       Recheck Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Heap Blocks: exact=22210
                                       ->  Bitmap Index Scan on orders_status_date_idx  (cost=0.00..3259.64 rows=242320 width=0) (actual time=21.630..21.631 rows=249514 loops=1)
                                             Index Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
 Planning Time: 1.035 ms
 JIT:
   Functions: 57
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.427 ms, Inlining 0.000 ms, Optimization 0.892 ms, Emission 17.759 ms, Total 20.078 ms
 Execution Time: 596.572 ms
(31 rows)     
                                             
```

Удалили индексы и отключили hash join, чтобы оценить ускорение индекса:

```
sandbox_db=> SET enable_hashjoin = off;
SET
Time: 0.417 ms
sandbox_db=> SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
 date_created |  sum   
--------------+--------
 2026-05-25   | 943971
 2026-05-26   | 942396
 2026-05-27   | 944031
 2026-05-28   | 951840
 2026-05-29   | 948941
 2026-05-30   | 943174
 2026-05-31   | 692642
(7 rows)

Time: 1477.221 ms (00:01.477)


---------------
 Finalize GroupAggregate  (cost=1027873.37..1028654.36 rows=91 width=12) (actua
l time=1740.154..1749.384 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=1027873.37..1028652.54 rows=182 width=12) (actual ti
me=1738.633..1749.354 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial GroupAggregate  (cost=1026873.34..1027631.50 rows=91 width=12) (actual time=1707.290..1713.105 rows=7 loops=3)
               Group Key: o.date_created
               ->  Sort  (cost=1026873.34..1027125.76 rows=100967 width=8) (actual time=1706.285..1710.072 rows=83171 loops=3)
                     Sort Key: o.date_created
                     Sort Method: external merge  Disk: 1544kB
                     Worker 0:  Sort Method: external merge  Disk: 1432kB
                     Worker 1:  Sort Method: external merge  Disk: 1432kB
                     ->  Merge Join  (cost=995431.50..1018481.20 rows=100967 width=8) (actual time=1410.801..1697.408 rows=83171 loops=3)
                           Merge Cond: (op.order_id = o.id)
                           ->  Sort  (cost=705918.34..716335.00 rows=4166667 width=12) (actual time=695.321..853.642 rows=3333333 loops=3)
                                 Sort Key: op.order_id
                                 Sort Method: external merge  Disk: 89120kB
                                 Worker 0:  Sort Method: external merge  Disk: 82648kB
                                 Worker 1:  Sort Method: external merge  Disk: 82752kB
                                 ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=113.971..268.431 rows=3333333 loops=3)
                           ->  Sort  (cost=289510.35..290116.15 rows=242320 width=12) (actual time=715.431..727.046 rows=249420 loops=3)
                                 Sort Key: o.id
                                 Sort Method: external merge  Disk: 6360kB
                                 Worker 0:  Sort Method: external merge  Disk: 6360kB
                                 Worker 1:  Sort Method: external merge  Disk: 6360kB
                                 ->  Seq Scan on orders o  (cost=0.00..263695.00 rows=242320 width=12) (actual time=0.027..688.874 rows=249514 loops=3)
                                       Filter: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Rows Removed by Filter: 9750486
 Planning Time: 0.326 ms
 JIT:
   Functions: 57
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 2.073 ms, Inlining 98.098 ms, Optimization 142.909 ms, Emission 100.986 ms, Total 344.066 ms
 Execution Time: 1756.527 ms
(34 rows)

```

Вернули индексы:

```
sandbox_db=> SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
 date_created |  sum   
--------------+--------
 2026-05-25   | 943971
 2026-05-26   | 942396
 2026-05-27   | 944031
 2026-05-28   | 951840
 2026-05-29   | 948941
 2026-05-30   | 943174
 2026-05-31   | 692642
(7 rows)

Time: 285.169 ms

-------------------
 Finalize GroupAggregate  (cost=269102.69..269125.74 rows=91 width=12) (actual time=281.790..288.451 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=269102.69..269123.92 rows=182 width=12) (actual time=281.782..288.440 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=268102.66..268102.89 rows=91 width=12) (actual time=273.057..273.059 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=268098.79..268099.70 rows=91 width=12) (actual time=273.042..273.045 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Nested Loop  (cost=3320.66..267593.96 rows=100967 width=8) (actual time=22.922..265.942 rows=83171 loops=3)
                           ->  Parallel Bitmap Heap Scan on orders o  (cost=3320.22..69034.55 rows=100967 width=12) (actual time=22.889..88.609 rows=83171 loops=3)
                                 Recheck Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                 Heap Blocks: exact=21165
                                 ->  Bitmap Index Scan on orders_status_date_idx  (cost=0.00..3259.64 rows=242320 width=0) (actual time=19.481..19.482 rows=249514 loops=1)
                                       Index Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                           ->  Index Scan using order_product_order_id_idx on order_product op  (cost=0.43..1.96 rows=1 width=12) (actual time=0.002..0.002 rows=1 loops=249514)
                                 Index Cond: (order_id = o.id)
 Planning Time: 1.076 ms
 JIT:
   Functions: 45
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.200 ms, Inlining 0.000 ms, Optimization 0.774 ms, Emission 14.455 ms, Total 16.429 ms
 Execution Time: 298.239 ms
(29 rows)
   
```

Т.е. использование индексов ускорило запрос примерно в 5 раз.