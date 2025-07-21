# Identifying and Prioritizing Underperforming Suppliers


## Introduction and Business Problem
Strong supplier performance is essential for keeping operations smooth and minimizing costly disruptions. Defective materials and delays can lead to significant downtime, affecting both efficiency and customer satisfaction. To manage these risks, it’s important to track and evaluate supplier quality using reliable data.

This project focuses on two key metrics: the number of product defects and the total downtime caused by those defects. These metrics help identify suppliers that are negatively impacting operations.

The goal of this analysis is to:

- Identify suppliers responsible for the most defects and downtime.
- Measure the business impact of supplier-related issues.
- Rank suppliers by performance to highlight those requiring quality improvement or replacement.
- Highlight specific materials linked to poor quality.
- Recommend actions to reduce risk and improve supplier reliability.

By using data to evaluate performance, this project supports better supplier decisions and more efficient operations.


## Pre-EDA: Source and Granularity of the Data
This is open-source data I found from Israel Bassey's ["Supplier Quality Analysis"](https://github.com/BasseyIsrael/Supplier-Quality-Analysis) project. Originally, this is real business data from Obvience that was anonymized. I implemented the exact same schema as the one in [Israel's project](https://github.com/BasseyIsrael/Supplier-Quality-Analysis?tab=readme-ov-file#source-of-data) but in MySQL.

The granularity of the data can be split into two parts. On one hand, the granularity of the table `metrics` represents purchase details for each unique order like the date or total downtime of an order. On the other hand, the granularity of all of the other tables represent unique categories of their respective tables like unique plant locations in the table `plant`. And since each of these non-`metrics` tables contain an ID column that references to `metrics`, we will join multiple tables with `metrics` for the majority of this analysis.


## EDA Part 1: Identify the suppliers responsible for the most defects and downtime.
We do this to quickly find out which suppliers performed the worst in terms of quantity. However, this won't tell the full story because not every supplier has the same number of orders in the table `metrics`. So, this part just shows which suppliers we should watch out for later in our analyses.

### Who are the worst suppliers with respect to defect quantity?
To find the worst suppliers with respect to defect quantity, we first make use of the table `metrics`, which contains the column `defect_qty`. Next, we join tables `metrics` and `vendor` by `vendor_id` to get us one step closer to producing a table that shows the total defect quantity for each vendor. Then, we group by `vendor` and aggregate `defect_qty` using `SUM()` to obtain the defect quantity sum for each unique vendor. Lastly, we order by `total_defect` in descending order to see the vendors that have the most defects. To prevent information overflow, only the top five worst suppliers are shown.

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
This part is the Pareto-like analysis.

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

SELECT SUM(percent_total_dfq)
FROM (
	SELECT *
	FROM percent_problems_by_vendor
	ORDER BY percent_total_dfq DESC
	LIMIT 26
) AS v);
# Top 26 out of 320 (approx. 8%) vendors in total defects caused 80% of total defects for our company

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


## Visualization: Recommend actions to reduce risk and improve supplier reliability.
[Tableau Visualization Link](https://public.tableau.com/views/SupplierPerformanceAnalysisIdentifyingandPrioritizingUnderperformingSuppliers/Dashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

<div class='tableauPlaceholder' id='viz1752994094604' style='position: relative'><noscript><a href='#'><img alt='Supplier Performance Analysis: Identifying and Prioritizing Underperforming Suppliers ' src='https:&#47;&#47;public.tableau.com&#47;static&#47;images&#47;Su&#47;SupplierPerformanceAnalysisIdentifyingandPrioritizingUnderperformingSuppliers&#47;Dashboard&#47;1_rss.png' style='border: none' /></a></noscript><object class='tableauViz'  style='display:none;'><param name='host_url' value='https%3A%2F%2Fpublic.tableau.com%2F' /> <param name='embed_code_version' value='3' /> <param name='site_root' value='' /><param name='name' value='SupplierPerformanceAnalysisIdentifyingandPrioritizingUnderperformingSuppliers&#47;Dashboard' /><param name='tabs' value='no' /><param name='toolbar' value='yes' /><param name='static_image' value='https:&#47;&#47;public.tableau.com&#47;static&#47;images&#47;Su&#47;SupplierPerformanceAnalysisIdentifyingandPrioritizingUnderperformingSuppliers&#47;Dashboard&#47;1.png' /> <param name='animate_transition' value='yes' /><param name='display_static_image' value='yes' /><param name='display_spinner' value='yes' /><param name='display_overlay' value='yes' /><param name='display_count' value='yes' /><param name='language' value='en-US' /></object></div>
