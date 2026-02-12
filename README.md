# E-Commerce Revenue, Customer Behavior & Logistics Cost Analysis (SQL)

## Overview
This project analyzes an e-commerce dataset to understand revenue trends, customer purchasing behavior, and logistics cost inefficiencies using SQL.

The goal is to move beyond basic reporting and identify business risks such as revenue concentration, churn patterns, and loss-making orders.

#### Dashboard Link:- 
- https://app.powerbi.com/view?r=eyJrIjoiZWU4NzMyZjYtOWI4MS00ZDliLWJiY2YtOGNkZmViMTk3NDc2IiwidCI6ImQ5OTRjYjA2LTljOTYtNGUxMC05YTQ2LTg4ZGM1OTEyNjc0ZCIsImMiOjZ9

## Business Questions Addressed
- How does revenue change over time?
- Which customers and categories drive most revenue?
- How frequently do customers repeat purchases?
- Are logistics costs eroding profitability?

---

## Dataset
- Brazilian E-commerce Dataset (Olist)
- 100k+ orders
- Tables used: orders, order_items, customers, products

---

## Data Modeling
- Created an order-level analytical view to avoid double counting
- Defined clear grain for revenue and customer analysis
- Designed ER diagram to validate relationships

---

## Key Analyses
### Revenue & Growth
- Monthly revenue trends
- Month-over-Month growth
- Average Order Value (AOV)

### Customer Behavior
- Orders per customer
- One-time vs repeat customers
- Time gap between consecutive orders
- Customers with consistently decreasing order values

### Pareto Analysis
- Top customers and categories contributing majority revenue

### Logistics & Cost Efficiency
- Orders where freight cost exceeded product price
- Freight cost percentage by category and city
- Identification of loss-making orders using freight as a cost proxy

---

## Key Insights
- Revenue follows Pareto distribution: a small segment drives most revenue
- Majority of customers place only one order
- Some delivered orders have negative net value due to high logistics cost

---

## Tools Used
- SQL (MySQL)
- Window Functions, CTEs, Aggregations
- Power BI

---

## Future Improvements
- Add product cost and discount data for true margin analysis
- Incorporate returns and cancellations
- Build dashboard for visualization
