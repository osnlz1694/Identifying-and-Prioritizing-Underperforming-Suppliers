# Supplier Quality Analysis: Identifying and Prioritizing Underperforming Vendors

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

This is open-source data I found from Isreal Bassey's ["Supplier Quality Analysis"] (https://github.com/BasseyIsrael/Supplier-Quality-Analysis) project. Originally, this is real business data from Obvience that was anonymized. I implemented the exact same schema as the one in [Isreal's project] (https://github.com/BasseyIsrael/Supplier-Quality-Analysis?tab=readme-ov-file#source-of-data) but in MySQL.

The granularity of the data can be split into two parts. On one hand, the granularity of the table `metrics` represents purchase details for each unique order like the date or total downtime of an order. On the other hand, the granularity of all of the other tables represent unique categories of their respective tables like unique plant locations in the table `plant`. And since all of these non-`metrics` tables contain an ID column that references to `metrics`, we will join multiple tables with `metrics` for the majority of this analysis.

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


