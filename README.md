# brazilian-ecommerce-data-analysis-using-mysql

## Project Overview

The **MySQL Business Intelligence & Analytics** project uses the Brazilian E-Commerce Public Dataset by Olist to analyze e-commerce operations, evaluate business performance, monitor key performance indicators (KPIs), and generate actionable business insights using MySQL 8.0+.

The project demonstrates how raw e-commerce data can be transformed into structured analytical datasets, reusable SQL views, business metrics, data quality checks, and exception alerts to support data-driven decision-making.

## Business Problem

E-commerce businesses generate large amounts of data across orders, customers, products, sellers, payments, reviews, and deliveries. Analyzing these datasets independently can make it difficult to understand business performance, identify operational issues, and measure customer experience consistently.

This project addresses these challenges by bringing related datasets together through SQL-based analysis. It examines sales performance, order activity, payment values, delivery performance, customer reviews, seller performance, and data quality to identify patterns, potential risks, and areas for improvement.

## Project Objectives

- Analyze e-commerce business performance using MySQL.
- Explore and validate data across multiple related datasets.
- Build reusable analytical views to simplify complex queries.
- Calculate and evaluate key business performance indicators.
- Analyze sales trends, order patterns, seller performance, and customer reviews.
- Investigate delivery performance and order cancellations.
- Identify data quality issues and inconsistencies.
- Implement business rules to detect exceptions and generate alerts.
- Translate analytical results into business insights and recommendations.

## Dataset

**Source:** Brazilian E-Commerce Public Dataset by Olist, available on Kaggle.

The dataset contains anonymized information about orders placed through the Olist marketplace in Brazil. It includes multiple related tables covering customers, orders, order items, products, sellers, payments, reviews, and geographical information.

The project uses these datasets to analyze the relationships between commercial activity, order fulfillment, payments, and customer experience.

## Tools and Technologies

- **Database:** MySQL 8.0+
- **Query Language:** SQL
- **Data Analysis:** Aggregations, joins, subqueries, common table expressions (CTEs), window functions, date-based analysis, and conditional logic
- **Data Quality:** Duplicate detection, referential integrity checks, invalid-value detection, and consistency validation
- **Business Intelligence:** Analytical views, KPI calculations, business performance analysis, and exception monitoring

## Key Analytical Areas

### 1. Data Exploration and Quality Validation

- Explore dataset structure, table relationships, and data distributions.
- Identify duplicate records and potential key violations.
- Detect orphan records and referential integrity issues.
- Check for invalid review scores, negative item prices, and negative freight values.
- Investigate missing order items and suspicious payment values.
- Validate important timestamps and business data conditions.

### 2. Analytical Views and KPI Management

Create reusable analytical views to support consistent business reporting and reduce repetitive query logic.

Key analytical areas include:

- Order-level performance
- Order item and merchandise value analysis
- Payment value analysis
- Customer review analysis
- Category and seller performance
- Consolidated order metrics
- KPI results and dashboard-oriented reporting

### 3. E-Commerce Business Performance Analysis

Use SQL queries to answer business questions such as:

- How does merchandise value change over time?
- How does monthly order volume change?
- What are the month-over-month trends in business performance?
- Which sellers generate the highest merchandise value?
- How do merchandise value and freight charges vary across sellers?
- What is the order cancellation rate?
- How efficiently are orders delivered?
- What does the distribution of customer review scores reveal?
- How do payment values compare with merchandise values?
- Which categories and customer segments contribute to business activity?

### 4. KPI Analysis

Evaluate key performance indicators to understand commercial and operational performance.

The KPIs include:

- Total orders
- Delivered orders
- Canceled orders
- Cancellation rate
- Merchandise value
- Freight value
- Average order value
- Average delivery duration
- On-time delivery rate
- Average review score
- Total payment value

These metrics help assess sales activity, fulfillment performance, and customer satisfaction. KPI definitions and results should be interpreted according to the underlying data and the calculation logic used in the SQL views.

### 5. Business Alert and Exception Monitoring

Implement SQL-based business rules to identify conditions requiring further investigation.

The alerting component records information such as:

- Alert identifier and execution run
- Rule code and severity
- Entity type and entity identifier
- Alert message
- Observed value and threshold value
- Detection timestamp

This supports the identification and tracking of business exceptions, such as unusual operational metrics or values that breach configured business rules.

Alerts identify conditions for investigation; they do not automatically establish the underlying cause of an issue.

## Business Value

The project demonstrates how SQL can support practical business analysis by:

- Improving consistency in KPI calculations through reusable views.
- Highlighting trends in orders and merchandise value.
- Supporting comparisons of seller and category performance.
- Identifying delivery and cancellation patterns.
- Revealing potential data quality problems before relying on analytical results.
- Providing structured visibility into business exceptions through alerts.
- Supporting evidence-based business recommendations.

## Skills Demonstrated

- MySQL database querying and relational data analysis
- Multi-table joins and aggregation
- Common table expressions and subqueries
- Window functions and month-over-month analysis
- Date and time-based analysis
- View creation and reusable SQL logic
- KPI definition and calculation
- Data quality and integrity validation
- Business rule implementation and exception monitoring
- Analytical reasoning and business insight generation

## Conclusion

The MySQL Business Intelligence & Analytics project demonstrates the application of SQL to real-world e-commerce data. By combining data validation, reusable analytical views, KPI analysis, business performance queries, and exception monitoring, the project provides a structured approach to understanding business operations and identifying areas that warrant further investigation.

The primary focus is on producing reliable analytical results, answering relevant business questions, and translating data into meaningful insights that support business decision-making.
