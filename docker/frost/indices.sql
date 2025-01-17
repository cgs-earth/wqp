--------- By default FROST does not index in some of the ways we would expect so we 
--------- Need to add additional indices 

--------- These indices are used for the queries on the front page of the UI
-- Index on DATASTREAM_ID for filtering
CREATE INDEX idx_observations_datastream_id ON "OBSERVATIONS" ("DATASTREAM_ID");

-- Composite index on PHENOMENON_TIME_START, PHENOMENON_TIME_END, and ID for sorting
CREATE INDEX idx_observations_sort_order ON "OBSERVATIONS" ("PHENOMENON_TIME_START", "PHENOMENON_TIME_END", "ID");

---------
---- These are helpful for speeding up the query on the UI that fetches the entire dataset to create the table
-- sensorthings=# EXPLAIN select "e0"."RESULT_BOOLEAN", "e1"."OBSERVATION_TYPE", "e1"."PHENOMENON_TIME_START", "e1"."NAME", ST_AsGeoJSON("e1"."OBSERVED_AREA"), "e0"."RESULT_STRING", "e3"."FEATURE", "e0"."RESULT_TYPE", "e0"."VALID_TIME_END", "e1"."PHENOMENON_TIME_END", "e1"."UNIT_NAME", "e1"."RESULT_TIME_START", "e0"."ID", "e0"."RESULT_JSON", "e0"."RESULT_NUMBER", "e1"."RESULT_TIME_END", "e1"."UNIT_SYMBOL", "e0"."RESULT_QUALITY", "e0"."PHENOMENON_TIME_START", "e1"."THING_ID", "e0"."PARAMETERS", "e1"."UNIT_DEFINITION", "e0"."DATASTREAM_ID", "e3"."DESCRIPTION", "e0"."PHENOMENON_TIME_END", "e0"."FEATURE_ID", "e3"."ID", "e1"."PROPERTIES", "e0"."RESULT_TIME", "e1"."ID", "e3"."ENCODING_TYPE", "e1"."OBS_PROPERTY_ID", "e1"."DESCRIPTION", "e3"."NAME", "e0"."VALID_TIME_START", "e3"."PROPERTIES", "e1"."SENSOR_ID" from "OBSERVATIONS" as "e0" left outer join "DATASTREAMS" as "e1" on "e1"."ID" = "e0"."DATASTREAM_ID" left outer join "FEATURES" as "e3" on "e3"."ID" = "e0"."FEATURE_ID" where "e0"."DATASTREAM_ID" = 115035000 order by "e0"."PHENOMENON_TIME_START" asc, "e0"."PHENOMENON_TIME_END" asc, "e0"."ID" asc offset 0 rows fetch next 10001 rows only;
--                                                           QUERY PLAN                                                           
-- -------------------------------------------------------------------------------------------------------------------------------
--  Limit  (cost=156396.54..170477.89 rows=10001 width=651)
--    ->  Nested Loop Left Join  (cost=156396.54..228336.59 rows=51094 width=651)
--          ->  Nested Loop Left Join  (cost=156396.38..163121.55 rows=51094 width=466)
--                Join Filter: (e1."ID" = e0."DATASTREAM_ID")
--                ->  Gather Merge  (cost=156396.23..162346.97 rows=51094 width=175)
--                      Workers Planned: 2
--                      ->  Sort  (cost=155396.21..155449.43 rows=21289 width=175)
--                            Sort Key: e0."PHENOMENON_TIME_START", e0."PHENOMENON_TIME_END", e0."ID"
--                            ->  Parallel Bitmap Heap Scan on "OBSERVATIONS" e0  (cost=564.42..152045.76 rows=21289 width=175)
--                                  Recheck Cond: ("DATASTREAM_ID" = 115035000)
--                                  ->  Bitmap Index Scan on "OBSERVATIONS_DATASTREAM_ID"  (cost=0.00..551.64 rows=51094 width=0)
--                                        Index Cond: ("DATASTREAM_ID" = 115035000)
--                ->  Materialize  (cost=0.15..8.17 rows=1 width=291)
--                      ->  Index Scan using "DATASTREAMS_pkey" on "DATASTREAMS" e1  (cost=0.15..8.17 rows=1 width=291)
--                            Index Cond: ("ID" = 115035000)
--          ->  Memoize  (cost=0.15..0.30 rows=1 width=201)
--                Cache Key: e0."FEATURE_ID"
--                Cache Mode: logical                      
--                ->  Index Scan using "FEATURES_pkey" on "FEATURES" e3  (cost=0.14..0.29 rows=1 width=201)
--                      Index Cond: ("ID" = e0."FEATURE_ID")
--  JIT:
--    Functions: 23
--    Options: Inlining false, Optimization false, Expressions true, Deforming true
-- (23 rows)


CREATE INDEX idx_observations_result_time ON "OBSERVATIONS" ("RESULT_TIME");

CREATE INDEX idx_observations_composite_filter_sort 
ON "OBSERVATIONS" ("DATASTREAM_ID", "RESULT_TIME", "PHENOMENON_TIME_START", "PHENOMENON_TIME_END", "ID");
