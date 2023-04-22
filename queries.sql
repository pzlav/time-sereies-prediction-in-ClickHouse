---------------------------------------------------------------------------------------------------------
-- Original query with comments 
---------------------------------------------------------------------------------------------------------

-- Create a table with arrays sales data 
CREATE OR REPLACE VIEW picker_tables.store_sales_view AS
SELECT 
	store_nbr,
	family,  
	y_raw,
	arrayDifference(y_raw) y_diff,                                                           -- Differencing 
	quantileArray(0.96)(arrayMap(x -> abs(x), y_diff)) scale_factor,                         -- Not very best way to scale time series
	arrayMap(x -> x / scale_factor, y_diff) y_scaled,
	ts,
	arrayMap(t -> if(toDayOfWeek(t) = 1, 1, 0), ts) wd1,                                     -- a litte bit of a one-hot encoding 
	arrayMap(t -> if(toDayOfWeek(t) = 2, 1, 0), ts) wd2,
	arrayMap(t -> if(toDayOfWeek(t) = 3, 1, 0), ts) wd3,
	arrayMap(t -> if(toDayOfWeek(t) = 4, 1, 0), ts) wd4,
	arrayMap(t -> if(toDayOfWeek(t) = 5, 1, 0), ts) wd5,
	arrayMap(t -> if(toDayOfWeek(t) = 6, 1, 0), ts) wd6,
	arrayMap(t -> if(toDayOfWeek(t) = 7, 1, 0), ts) wd7,
	arrayMap(t -> if(toQuarter(t) = 1, 1, 0), ts) q1,
	arrayMap(t -> if(toQuarter(t) = 2, 1, 0), ts) q2,
	arrayMap(t -> if(toQuarter(t) = 3, 1, 0), ts) q3,
	arrayMap(t -> if(toQuarter(t) = 4, 1, 0), ts) q4	
FROM 
	(
	SELECT
		store_nbr,
		family,  
		arrayReverseFill(x -> not isNull(x), groupArray(sales)) as y_raw,
		groupArray(`date`) as ts,
		groupArray(onpromotion) as prom_feature 
	FROM 
		picker_tables.store_sales
	WHERE 
		`date` > toDate('2017-03-01')                                                       -- take only recent data for simplification
		AND `date` <= (SELECT max(`date`) - INTERVAL 5 DAY from picker_tables.store_sales)  -- 5 days a test interval
	GROUP BY 
		store_nbr, family
	)
GROUP BY 
	store_nbr, family, y_raw, ts;



-- Create prediction models  for each pair of store and family in Memory engine
CREATE OR REPLACE TABLE my_model ENGINE = Memory AS 
SELECT store_nbr, family, 
	scale_factor,
	y_scaled[-7] t_7,
	y_scaled[-6] t_6,
	y_scaled[-5] t_5,
	y_scaled[-4] t_4,
	y_scaled[-3] t_3,
	y_scaled[-2] t_2,
	y_scaled[-1] t_1,
	ts[-1] last_ts,
	y_raw[-1] last_value,
	arrayPopBack(arrayPushFront(y_scaled, 0)) y1,
	arrayPopBack(arrayPushFront(y1, 0)) y2,
	arrayPopBack(arrayPushFront(y2, 0)) y3,
	arrayPopBack(arrayPushFront(y3, 0)) y4,
	arrayPopBack(arrayPushFront(y4, 0)) y5,
	arrayPopBack(arrayPushFront(y5, 0)) y6,
	arrayPopBack(arrayPushFront(y6, 0)) y7,
	stochasticLinearRegressionStateArray(0.025, 0.25, 10, 'Nesterov')(y_scaled, y1, y2, y3, y4, y5, y6, y7, wd1, wd2, wd3, wd4, wd5, wd6, wd7) as state
FROM 
	picker_tables.store_sales_view
GROUP BY 
	store_nbr, family, scale_factor, y_scaled, y_raw, ts, y_raw;



-- Create a table with predictions for each pair of store and family
CREATE OR REPLACE VIEW picker_tables.store_sales_predictions AS
WITH 
	evalMLMethod(state, t_1, t_2, t_3, t_4, t_5, t_6, t_7, 0, 0, 0, 0, 1, 0, 0) AS y_1,
	evalMLMethod(state, y_1, t_1, t_2, t_3, t_4, t_5, t_6, 0, 0, 0, 0, 0, 1, 0) AS y_2,
	evalMLMethod(state, y_2, y_1, t_1, t_2, t_3, t_4, t_5, 0, 0, 0, 0, 0, 0, 1) AS y_3,
	evalMLMethod(state, y_3, y_2, y_1, t_1, t_2, t_3, t_4, 1, 0, 0, 0, 0, 0, 0) AS y_4,
	evalMLMethod(state, y_4, y_3, y_2, y_1, t_1, t_2, t_3, 0, 1, 0, 0, 0, 0, 0) AS y_5
SELECT 
	store_nbr,
	family, 
	last_value,
	y_1 * scale_factor + last_value  AS pred1_t,
	IF(pred1_t < 0, 0, pred1_t) AS pred1,
	y_2 * scale_factor + pred1 AS pred2_t,
	IF(pred2_t < 0, 0, pred2_t) AS pred2,
	y_3 * scale_factor + pred2 AS pred3_t,
	IF(pred3_t < 0, 0, pred3_t) AS pred3,
	y_4 * scale_factor + pred3 AS pred4_t,
	IF(pred4_t < 0, 0, pred4_t) AS pred4,
	y_5 * scale_factor + pred4 AS pred5_t,
	IF(pred5_t < 0, 0, pred5_t) AS pred5
FROM my_model;




-------------------------------------------------------------------------------------------------
-- Formated version of the code above for article
-------------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW store_sales_view AS
SELECT 
	store_nbr,
	family,  
	y_raw,
	arrayDifference(y_raw) AS y_diff,                                                          
	quantileArray(0.95)(arrayMap(x -> abs(x), y_diff)) AS scale_factor,                         
	arrayMap(x -> x / scale_factor, y_diff) AS y_scaled,
	ts,
	arrayMap(t -> if(toDayOfWeek(t) = 1, 1, 0), ts) AS wd1,                                     
	arrayMap(t -> if(toDayOfWeek(t) = 2, 1, 0), ts) AS wd2,
	arrayMap(t -> if(toDayOfWeek(t) = 3, 1, 0), ts) AS wd3,
	arrayMap(t -> if(toDayOfWeek(t) = 4, 1, 0), ts) AS wd4,
	arrayMap(t -> if(toDayOfWeek(t) = 5, 1, 0), ts) AS wd5,
	arrayMap(t -> if(toDayOfWeek(t) = 6, 1, 0), ts) AS wd6,
	arrayMap(t -> if(toDayOfWeek(t) = 7, 1, 0), ts) AS wd7
FROM 
	(
	SELECT
		store_nbr,
		family,  
		arrayReverseFill(x -> not isNull(x), groupArray(sales)) AS y_raw,
		groupArray(`date`) AS ts,
		groupArray(onpromotion) AS prom_feature 
	FROM 
		store_sales
	WHERE 
		`date` > toDate('2017-03-01')                                                       
		AND `date` <= (SELECT max(`date`) - INTERVAL 5 DAY FROM store_sales)  
	GROUP BY 
		store_nbr, family
	)
GROUP BY 
	store_nbr, family, y_raw, ts;




CREATE OR REPLACE TABLE my_model ENGINE = Memory AS 
SELECT 
	store_nbr,
	family, 
	scale_factor,
	y_scaled[-7] AS t_7,
	y_scaled[-6] AS t_6,
	y_scaled[-5] AS t_5,
	y_scaled[-4] AS t_4,
	y_scaled[-3] AS t_3,
	y_scaled[-2] AS t_2,
	y_scaled[-1] AS t_1,
	y_raw[-1] AS last_value,
	arrayPopBack(arrayPushFront(y_scaled, 0)) AS y1,
	arrayPopBack(arrayPushFront(y1, 0)) AS y2,
	arrayPopBack(arrayPushFront(y2, 0)) AS y3,
	arrayPopBack(arrayPushFront(y3, 0)) AS y4,
	arrayPopBack(arrayPushFront(y4, 0)) AS y5,
	arrayPopBack(arrayPushFront(y5, 0)) AS y6,
	arrayPopBack(arrayPushFront(y6, 0)) AS y7,
	stochasticLinearRegressionStateArray(0.025, 0.25, 10, 'Nesterov')
	  (y_scaled, y1, y2, y3, y4, y5, y6, y7,
	  wd1, wd2, wd3, wd4, wd5, wd6, wd7) AS state
FROM 
	store_sales_view
GROUP BY 
	store_nbr, family, scale_factor, y_scaled, y_raw, ts, y_raw;



CREATE OR REPLACE VIEW store_sales_predictions AS
WITH 
	evalMLMethod(state, t_1, t_2, t_3, t_4, t_5, t_6, t_7, 0, 0, 0, 0, 1, 0, 0) AS y_1,
	evalMLMethod(state, y_1, t_1, t_2, t_3, t_4, t_5, t_6, 0, 0, 0, 0, 0, 1, 0) AS y_2,
	evalMLMethod(state, y_2, y_1, t_1, t_2, t_3, t_4, t_5, 0, 0, 0, 0, 0, 0, 1) AS y_3,
	evalMLMethod(state, y_3, y_2, y_1, t_1, t_2, t_3, t_4, 1, 0, 0, 0, 0, 0, 0) AS y_4,
	evalMLMethod(state, y_4, y_3, y_2, y_1, t_1, t_2, t_3, 0, 1, 0, 0, 0, 0, 0) AS y_5
SELECT 
	store_nbr,
	family, 
	last_value,
	y_1 * scale_factor + last_value  AS pred1,
	y_2 * scale_factor + pred1 AS pred2,
	y_3 * scale_factor + pred2 AS pred3,
	y_4 * scale_factor + pred3 AS pred4,
	y_5 * scale_factor + pred4 AS pred5
FROM my_model;





































