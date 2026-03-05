# Gold Layer Data Catalog

## Overview
The Gold Layer represents business-ready data for analytics and reporting, organized into dimension and fact tables.

- Dimension tables: Descriptive attributes such as customers and products.
- Fact tables: Transactional metrics such as sales.

---

## Table: gold.dim_customers

**Purpose:** Stores customer details enriched with demographic and geographic data.

| Column Name    | Data Type    | Description                                                                 |
| -------------- | ------------ | --------------------------------------------------------------------------- |
| customer_key   | INT          | Surrogate key uniquely identifying each customer record in the dimension.  |
| customer_id    | INT          | Unique numerical identifier assigned to each customer.                     |
| customer_number| NVARCHAR(50) | Alphanumeric identifier representing the customer for tracking/reference.  |
| first_name     | NVARCHAR(50) | Customer's first name as recorded in the system.                           |
| last_name      | NVARCHAR(50) | Customer's last or family name.                                            |
| country        | NVARCHAR(50) | Country of residence (for example, `Australia`).                           |
| marital_status | NVARCHAR(50) | Marital status (for example, `Married`, `Single`).                         |
| gender         | NVARCHAR(50) | Gender (for example, `Male`, `Female`, `n/a`).                             |
| birthdate      | DATE         | Date of birth in `YYYY-MM-DD` format.                                      |
| create_date    | DATE         | Date and time when the customer record was created.                        |

---

## Table: gold.dim_products

**Purpose:** Provides information about products and their attributes.

| Column Name         | Data Type    | Description                                                                 |
| ------------------- | ------------ | --------------------------------------------------------------------------- |
| product_key         | INT          | Surrogate key uniquely identifying each product record in the dimension.   |
| product_id          | INT          | Unique identifier assigned to the product for internal tracking.           |
| product_number      | NVARCHAR(50) | Structured alphanumeric code representing the product.                     |
| product_name        | NVARCHAR(50) | Descriptive name including type, color, and size.                          |
| category_id         | NVARCHAR(50) | Unique identifier for the product's category.                              |
| category            | NVARCHAR(50) | Broad classification (for example, `Bikes`, `Components`).                 |
| subcategory         | NVARCHAR(50) | More detailed classification within the category (for example, type).      |
| maintenance_required| NVARCHAR(50) | Indicates whether the product requires maintenance (`Yes`/`No`).           |
| cost                | INT          | Base price or cost of the product in whole currency units.                 |
| product_line        | NVARCHAR(50) | Product line or series (for example, `Road`, `Mountain`).                  |
| start_date          | DATE         |

## Table: gold.fact_sales

**Purpose:** Stores transactional sales data for analytical purposes.

| Column Name   | Data Type    | Description                                                                 |
| ------------- | ------------ | --------------------------------------------------------------------------- |
| order_number  | NVARCHAR(50) | Unique alphanumeric identifier for each sales order (for example, `SO54496`). |
| product_key   | INT          | Surrogate key linking to `gold.dim_products.product_key`.                   |
| customer_key  | INT          | Surrogate key linking to `gold.dim_customers.customer_key`.                 |
| order_date    | DATE         | Date when the order was placed.                                             |
| shipping_date | DATE         | Date when the order was shipped to the customer.                            |
| due_date      | DATE         | Date when payment for the order was due.                                    |
| sales_amount  | INT          | Total monetary value of the sale for the line item.                         |
| quantity      | INT          | Number of product units ordered for the line item.                          |
| price         | INT          | Price per unit of the product for the line item.                            |
