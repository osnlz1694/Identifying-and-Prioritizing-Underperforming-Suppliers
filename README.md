# Identifying and Prioritizing Underperforming Suppliers


## Introduction and Business Problem
Strong supplier performance is essential for keeping operations smooth and minimizing costly disruptions. Defective materials and delays can lead to significant downtime, affecting both efficiency and customer satisfaction. To manage these risks, it’s important to track and evaluate supplier quality using reliable data.

This project focuses on two key metrics: the number of product defects and the total downtime caused by those defects. These metrics help identify suppliers that are negatively impacting operations.

The goals for this analysis are to:

- Assess the source and granularity of the data.
- Identify suppliers responsible for the most defects and downtime.
- Measure the business impact of supplier-related issues.
- Rank suppliers by performance to highlight those requiring quality improvement or replacement.
- Highlight specific materials linked to poor quality.
- Explore monthly trends and other attributes.
- Recommend actions to reduce risk and improve supplier reliability.

By using data to evaluate performance, this project supports better supplier decisions and more efficient operations.


## Table of Contents
- [Pre-EDA: Assess the source and granularity of the data.](#pre-eda-assess-the-source-and-granularity-of-the-data)
- [EDA Part 1: Identify the suppliers responsible for the most defects and downtime.](#eda-part-1-identify-the-suppliers-responsible-for-the-most-defects-and-downtime)
- [EDA Part 2: Measure the business impact of supplier-related issues.](#eda-part-2-measure-the-business-impact-of-supplier-related-issues)
- [EDA Part 3: Rank suppliers by performance to highlight those requiring quality improvement or replacement.](#eda-part-3-rank-suppliers-by-performance-to-highlight-those-requiring-quality-improvement-or-replacement)
- [EDA Part 4: Highlight specific materials linked to poor quality.](#eda-part-4-highlight-specific-materials-linked-to-poor-quality)
- [EDA Addendum: Explore monthly trends and other attributes.](#eda-addendum-explore-monthly-trends-and-other-attributes)
- [Visualization: Recommend actions to reduce risk and improve supplier reliability.](#visualization-recommend-actions-to-reduce-risk-and-improve-supplier-reliability)
- [References](#references)


## Pre-EDA: Assess the source and granularity of the data.
This is open-source data I found from Israel Bassey's ["Supplier Quality Analysis"](https://github.com/BasseyIsrael/Supplier-Quality-Analysis) project. Originally, this is real business data from Obvience that was anonymized. I implemented the exact same schema as the one in [Israel's project](https://github.com/BasseyIsrael/Supplier-Quality-Analysis?tab=readme-ov-file#source-of-data) but in MySQL.

The granularity of the data can be split into two parts. On one hand, the granularity of the table `metrics` represents purchase details for each unique order like the date or total downtime of an order. On the other hand, the granularity of all of the other tables represent unique categories of their respective tables like unique plant locations in the table `plant`. And since each of these non-`metrics` tables contain an ID column that references to `metrics`, we will join multiple tables with `metrics` for the majority of this analysis.

**Note:** Throughout the document, the terms "supplier" and "vendor" are interchangeable, but "supplier" will be primarily used.


## EDA Part 1: Identify the suppliers responsible for the most defects and downtime.
We do this to quickly find out which suppliers performed the worst in terms of quantity. However, this won't tell the full story because not every supplier has the same number of orders in the table `metrics`. So, this part just shows which suppliers we should watch out for later in our analyses.

### Who are the worst suppliers with respect to defect quantity?
To find the worst suppliers with respect to defect quantity, we first make use of the table `metrics`, which contains the column `defect_qty`. Next, we join tables `metrics` and `vendor` by `vendor_id` to get us one step closer to producing a table that shows the total defect quantity for each supplier. Then, we group by `vendor` and aggregate `defect_qty` using `SUM()` to obtain the defect quantity sum for each unique supplier. Lastly, we order by `total_defect` in descending order to see the suppliers that have the most defects. To prevent information overflow, only the top five worst suppliers are shown.

```sql
SELECT v.vendor, SUM(m.defect_qty) AS total_defect
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY vendor
ORDER BY total_defect DESC;
```

<img width="195" height="104" alt="Screenshot 2025-07-11 at 1 19 43 PM" src="https://github.com/user-attachments/assets/8c832f43-bd22-4a4b-80bb-70e5024f0ce2" />

### Who are the worst suppliers with respect to downtime?
This query is exactly the same as the one that found the worst suppliers with respect to defect quantity. But, instead of using `defect_qty` as the metric, we used `downtime_minutes` as the new metric. Again, only the top five worst suppliers are shown to prevent information overflow.

```sql
SELECT v.vendor, SUM(downtime_minutes) AS total_downtime
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY vendor
ORDER BY total_downtime DESC;
```

<img width="217" height="103" alt="Screenshot 2025-07-11 at 1 56 41 PM" src="https://github.com/user-attachments/assets/b9e0a191-56da-4dd6-8930-51e85956fc57" />


## EDA Part 2: Measure the business impact of supplier-related issues.
The first part of the analysis shows which suppliers performed the worst in terms of total defects and downtime. But, it doesn't actually show how much suppliers' performances impact the business as a whole. With that in mind, we measure the business impact using something similar to Pareto analysis. That is, we find the percent of causes, in this case the number of suppliers, that lead to 80% of total defects/downtime.

The query below conducts percentage analyses for each unique supplier, giving us the percentage of total defects/downtime a unique supplier has within the data.

```sql
CREATE VIEW percent_problems_by_vendor AS
SELECT
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
) AS t;
```

<img width="435" height="105" alt="Screenshot 2025-07-24 at 11 34 13 AM" src="https://github.com/user-attachments/assets/e4b0208c-366d-4916-a605-51834885799c" />

After we calculate the percentage of total defects/downtime for each unique supplier, we find out how many of the top suppliers contribute to 80% of total defects/downtime. This query uses the table `percent_problems_by_vendor` then orders the total defect quantity by descending order. Lastly, we test out different values for our `LIMIT` statement until we get the closest `SUM(percent_total_dfq)` to 80%.

```sql
SELECT SUM(percent_total_dfq)
FROM (
	SELECT *
	FROM percent_problems_by_vendor
	ORDER BY percent_total_dfq DESC
	LIMIT 26
) AS v);
# Top 26 out of 320 (approx. 8%) vendors in total defects caused 80% of total defects for our company
```

The query below is the exact same as the one above but is for total downtime.

```sql
SELECT SUM(percent_total_dtm)
FROM (
	SELECT *
	FROM percent_problems_by_vendor
	ORDER BY percent_total_dtm DESC
	LIMIT 15
) AS v);
# Top 15 out of 320 (approx. 4.69%) vendors in total downtime caused 80% of total downtime for our company
```


## EDA Part 3: Rank suppliers by performance to highlight those requiring quality improvement or replacement.
This part is the ranking by supplier score one.

z-score calculations here.
```sql
CREATE VIEW sup_perf_metrics AS
SELECT
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
) AS global;
```

supplier score calculation and ranking here.
```sql
CREATE VIEW sup_perf_ranks AS
SELECT *, ((0.4 * dfq_zscore) + (0.6 * dtm_zscore)) * 100 AS supplier_score
FROM sup_perf_metrics
ORDER BY supplier_score DESC;
```


## EDA Part 4: Highlight specific materials linked to poor quality.
This part is the one with total dfq/dtm by vendor and material type.

```sql
SELECT
	v.vendor,
	mt.material_type,
	SUM(defect_qty) AS total_defect_qty,
	SUM(downtime_minutes) AS total_downtime
FROM metrics AS m
JOIN material_type AS mt ON m.material_type_id = mt.material_type_id
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY material_type, vendor
ORDER BY total_defect_qty DESC;
```


## EDA Addendum: Explore monthly trends and other attributes.
monthly trends stuff here.
```sql
SELECT
	v.vendor,
	STR_TO_DATE(DATE_FORMAT(STR_TO_DATE(m.date, '%d/%m/%Y %H:%i'), '%Y-%m-01'), '%Y-%m-%d') AS yr_mth,
	SUM(defect_qty) AS monthly_defects,
	SUM(downtime_minutes) AS monthly_downtime
FROM metrics AS m
JOIN vendor AS v ON m.vendor_id = v.vendor_id
GROUP BY v.vendor, yr_mth;
```

full database join here.
```sql
CREATE VIEW other_stuff AS
SELECT
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
JOIN vendor AS v ON m.vendor_id = v.vendor_id;
```

example queries here.
```sql
# Which types of vendors experience the most defects/downtime?
SELECT sub_category, SUM(defect_qty) AS total_defect, SUM(downtime_minutes) AS total_downtime
FROM other_stuff
GROUP BY sub_category;

# Which types of defects experience the most defects?
(SELECT defect, defect_type, SUM(defect_qty) AS total_defect
FROM other_stuff
GROUP BY defect, defect_type
ORDER BY total_defect DESC;

# Which plant locations experience the most defects/downtime?
SELECT plant, SUM(defect_qty) AS total_defect, SUM(downtime_minutes) AS total_downtime
FROM other_stuff
GROUP BY plant;
```


## Visualization: Recommend actions to reduce risk and improve supplier reliability.
[Tableau Visualization Here](https://public.tableau.com/views/SupplierPerformanceAnalysisIdentifyingandPrioritizingUnderperformingSuppliers/Dashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

<img width="1026" height="770" alt="Screenshot 2025-07-21 at 2 02 22 PM" src="https://github.com/user-attachments/assets/e9522cd8-735b-4888-a4ef-cfd1291e3bfe" />


## References
Bassey, Israel. "Supplier Quality Analysis." Accessed 28 June 2025, https://github.com/BasseyIsrael/Supplier-Quality-Analysis
