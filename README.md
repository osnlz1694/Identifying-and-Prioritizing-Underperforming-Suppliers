# Supplier Quality Analysis: Identifying and Prioritizing Underperforming Vendors


## EDA Part 1: Identify the suppliers responsible for the most defects and downtime.
Quotelane sucks.
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
