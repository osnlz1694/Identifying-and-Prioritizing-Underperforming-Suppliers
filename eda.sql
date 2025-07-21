## EDA Part 1a: Identify suppliers responsible for the most defects and downtime

(SELECT v.vendor, SUM(m.defect_qty) AS total_defect_qty
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY vendor
ORDER BY total_defect_qty DESC);

(SELECT v.vendor, SUM(downtime_minutes) AS total_downtime_mins
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY vendor
ORDER BY total_downtime_mins DESC);





## EDA Part 1b: Identify which materials are most defective and who supplies them

CREATE VIEW total_defect_downtime_by_vendor_mat_type AS
(SELECT
	v.vendor,
	mt.material_type,
	SUM(defect_qty) AS total_defect_qty,
	SUM(downtime_minutes) AS total_downtime
FROM metrics AS m
JOIN material_type AS mt ON m.material_type_id = mt.material_type_id
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY material_type, vendor
ORDER BY total_defect_qty DESC);





## EDA Part 2a: Rank suppliers by total defect/downtime into a score

CREATE VIEW sup_perf_metrics AS
(SELECT
	v.vendor,
	supplier.dfq_avg,
	(supplier.dfq_avg - global.dfq_avg) / NULLIF(global.dfq_sd, 0) AS dfq_zscore,
	supplier.dtm_avg,
	(supplier.dtm_avg - global.dtm_avg) / NULLIF(global.dtm_sd, 0) AS dtm_zscore
FROM (
	SELECT
		vendor_id,
		AVG(defect_qty) AS dfq_avg,
        	AVG(downtime_minutes) AS dtm_avg
	FROM metrics
	GROUP BY vendor_id
	HAVING COUNT(*) >= 20
) AS supplier
JOIN vendor AS v ON supplier.vendor_id = v.vendor_id
CROSS JOIN (
	SELECT
		AVG(defect_qty) AS dfq_avg,
        	STDDEV_SAMP(defect_qty) AS dfq_sd,
        	AVG(downtime_minutes) AS dtm_avg,
        	STDDEV_SAMP(downtime_minutes) AS dtm_sd
	FROM metrics
) AS global);

CREATE VIEW sup_perf_ranks AS
(SELECT *, ((0.4 * dfq_zscore) + (0.6 * dtm_zscore)) * 100 AS supplier_score
FROM sup_perf_metrics
ORDER BY supplier_score DESC);





## EDA Part 2b: Rank material types by total defect/downtime into a score

CREATE VIEW mat_perf_metrics AS
(SELECT
	mt.material_type,
	materials.dfq_avg,
	(materials.dfq_avg - global.dfq_avg) / NULLIF(global.dfq_sd, 0) AS dfq_zscore,
	materials.dtm_avg,
	(materials.dtm_avg - global.dtm_avg) / NULLIF(global.dtm_sd, 0) AS dtm_zscore
FROM (
	SELECT
		material_type_id,
		AVG(defect_qty) AS dfq_avg,
        	AVG(downtime_minutes) AS dtm_avg
    	FROM metrics
    	GROUP BY material_type_id
    	HAVING COUNT(*) >= 20
) AS materials
JOIN material_type AS mt ON materials.material_type_id = mt.material_type_id
CROSS JOIN (
	SELECT
		AVG(defect_qty) AS dfq_avg,
        	STDDEV_SAMP(defect_qty) AS dfq_sd,
        	AVG(downtime_minutes) AS dtm_avg,
        	STDDEV_SAMP(downtime_minutes) AS dtm_sd
    	FROM metrics
) AS global);

CREATE VIEW mat_perf_ranks AS
(SELECT *, ((0.4 * dfq_zscore) + (0.6 * dtm_zscore)) * 100 AS material_score
FROM mat_perf_metrics
ORDER BY material_score DESC);





## EDA Part 3a: Check if most problems come from just a few suppliers (Pareto check)

CREATE VIEW percent_problems_by_vendor AS
(SELECT
	v.vendor,
	m.total_dfq,
	ROUND(((m.total_dfq / t.grand_total_dfq) * 100), 2) AS percent_total_dfq,
	m.total_dtm,
	ROUND(((m.total_dtm / t.grand_total_dtm) * 100), 2) AS percent_total_dtm
FROM (
	SELECT
		vendor_id,
        	SUM(defect_qty) AS total_dfq,
        	SUM(downtime_minutes) AS total_dtm
	FROM metrics
	GROUP BY vendor_id
) AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
CROSS JOIN (
	SELECT
		SUM(defect_qty) AS grand_total_dfq,
		SUM(downtime_minutes) AS grand_total_dtm
    	FROM metrics
) AS t);

(SELECT SUM(percent_total_dfq)
FROM (
	SELECT *
	FROM percent_problems_by_vendor
    	ORDER BY percent_total_dfq DESC
	LIMIT 26
) AS v);
# The top 26 out of 320 (approx. 8%) vendors in total defect quantity caused 80% of total defects for our company

(SELECT SUM(percent_total_dtm)
FROM (
	SELECT *
	FROM percent_problems_by_vendor
    	ORDER BY percent_total_dtm DESC
	LIMIT 15
) AS v);
# The top 15 out of 320 (approx. 4.69%) vendors in total downtime caused 80% of total downtime for our company





## EDA Part 3b: Check if most problems come from just a few material types (Pareto check)

CREATE VIEW percent_problems_by_mat_type AS
(SELECT
	mt.material_type,
	m.total_dfq,
	ROUND(((m.total_dfq / t.grand_total_dfq) * 100), 2) AS percent_total_dfq,
    	m.total_dtm,
    	ROUND(((m.total_dtm / t.grand_total_dtm) * 100), 2) AS percent_total_dtm
FROM (
	SELECT
		material_type_id,
        	SUM(defect_qty) AS total_dfq,
        	SUM(downtime_minutes) AS total_dtm
	FROM metrics
	GROUP BY material_type_id
) AS m
JOIN material_type AS mt ON m.material_type_id = mt.material_type_id
CROSS JOIN (
	SELECT
		SUM(defect_qty) AS grand_total_dfq,
        	SUM(downtime_minutes) AS grand_total_dtm
    	FROM metrics
) AS t);

(SELECT SUM(percent_total_dfq)
FROM (
	SELECT *
	FROM percent_problems_by_mat_type
    	ORDER BY percent_total_dfq DESC
	LIMIT 5
) AS mt);
# The top 5 out of 22 (approx. 22.7%) material types in total defect quantity caused 80% of total defects for our company

(SELECT SUM(percent_total_dtm)
FROM (
	SELECT *
	FROM percent_problems_by_mat_type
    	ORDER BY percent_total_dtm DESC
	LIMIT 4
) AS mt);
# The top 4 out of 22 (approx. 18.18%) material types in total downtime caused 80% of total downtime for our company





## EDA Part 4: Monthly trend of defects per supplier

CREATE VIEW monthly_trend AS
(SELECT
	v.vendor,
    	STR_TO_DATE(DATE_FORMAT(STR_TO_DATE(m.date, '%d/%m/%Y %H:%i'), '%Y-%m-01'), '%Y-%m-%d') AS yr_mth,
    	SUM(defect_qty) AS monthly_defects,
    	SUM(downtime_minutes) AS monthly_downtime
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY v.vendor, yr_mth);





## EDA Part 5: Explore other attributes

CREATE VIEW other_stuff AS
(SELECT
	m.date,
    	m.defect_qty,
    	m.downtime_minutes,
    	c.sub_category,
    	df.defect,
    	dt.defect_type,
    	mt.material_type,
    	pl.plant,
    	v.vendor
FROM metrics AS m
JOIN category AS c ON m.sub_category_id = c.sub_category_id
JOIN defect_data AS df ON m.defect_id = df.defect_id
JOIN defect_type AS dt ON m.defect_type_id = dt.defect_type_id
JOIN material_type AS mt ON m.material_type_id = mt.material_type_id
JOIN plant_location AS pl ON m.plant_id = pl.plant_id
JOIN vendor AS v ON m.vendor_id = v.vendor_id);

# Which types of vendors experience the most defects/downtime?
(SELECT sub_category, SUM(defect_qty) AS total_defect, SUM(downtime_minutes) AS total_downtime
FROM other_stuff
GROUP BY sub_category);

# Which types of defects experience the most defects?
(SELECT defect, defect_type, SUM(defect_qty) AS total_defect
FROM other_stuff
GROUP BY defect, defect_type
ORDER BY total_defect DESC);

# Which plant locations experience the most defects/downtime?
(SELECT plant, SUM(defect_qty) AS total_defect, SUM(downtime_minutes) AS total_downtime
FROM other_stuff
GROUP BY plant);

# EDA Part 5 can be further developed to find complex relationships between certain attributes
