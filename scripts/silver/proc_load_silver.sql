/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

		-- Loading silver.crm_cust_info
        SET @start_time = GETDATE();

	PRINT '>> Truncating Table:silver.crm_cust_info'
	TRUNCATE TABLE silver.crm_cust_info;
	PRINT '>> Inserting data into Table:silver.crm_cust_info'
	INSERT INTO silver.crm_cust_info
	(cst_id,
	cst_key,
	cst_first_name,
	cst_last_name,
	cst_marital_status,
	cst_gndr,
	cst_create_date)
	SELECT
	cst_id,
	cst_key,
	TRIM(t.cst_first_name) AS cst_firstname,
	TRIM(t.cst_last_name) AS cst_lastname,   -- Removing leading and trailing spaces from first and last names |Data Consistency
	CASE WHEN UPPER(cast_material_status)='S' THEN 'Single'
		WHEN UPPER(cast_material_status)='M' THEN 'Married'
		ELSE 'n/a'							-- Data Standardization: Converting marital status codes to full descriptions and handling unexpected values with 'n/a'
	END cst_marital_status,
	CASE WHEN UPPER(cst_gndr)='F' THEN 'Female'
		WHEN UPPER(cst_gndr)='M' THEN 'Male'
		ELSE 'n/a'
	END cst_gndr,							-- Data Standardization: Converting gender codes to full descriptions and handling unexpected values with 'n/a'
	cst_create_date
	FROM
	(
	SELECT
	*,
	RANK() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
	FROM bronze.crm_cust_info c
	WHERE cst_id IS NOT NULL -- Data Quality: Excluding records with NULL customer IDs to ensure integrity of the dataset
	)t
	WHERE flag_last=1  -- Removing Duplicates: Keeping only the most recent record for each customer based on creation date to ensure data accuracy and relevance
	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Loading silver.crm_prd_info
	SET @start_time = GETDATE();
	PRINT '>> Truncating Table:silver.crm_prd_info'
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT '>> Inserting data into Table:silver.crm_prd_info'
	INSERT INTO silver.crm_prd_info(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt)
	SELECT
	prd_id,
	REPLACE(SUBSTRING(TRIM(UPPER(prd_key)),1,5),'-','_') as Cat_id,
	SUBSTRING(TRIM(UPPER(prd_key)),7,LEN(prd_key)) as prd_key,
	prd_nm,
	ISNULL(prd_cost,0) as prd_cost, -- Data Quality: Replacing NULL product costs with 0 to prevent issues in downstream calculations and analyses
	CASE WHEN UPPER(prd_line)='R' THEN 'Road'
		WHEN UPPER(prd_line)='M' THEN 'Mountain'
		WHEN UPPER(prd_line)='S' THEN 'Other Sales'
		WHEN UPPER(prd_line)='T' THEN 'Touring'
		ELSE 'n/a'							-- Data Standardization: Converting product line codes to full descriptions and handling unexpected values with 'n/a'
	END prd_line,
	CAST(prd_start_dt AS DATE) AS prd_start_dt, -- Data Type Consistency: Converting product start date to DATE type for consistency and easier date operations
	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt -- Data Quality: Setting product end date to one day before the next product's start date to ensure accurate product lifecycle representation and prevent overlapping date ranges
	FROM bronze.crm_prd_info;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

    -- Loading crm_sales_details
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table:silver.crm_sales_details'
	TRUNCATE TABLE silver.crm_sales_details;
	PRINT '>> Inserting data into Table:silver.crm_sales_details'
	INSERT INTO silver.crm_sales_details(
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_ORDER_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price)
	SELECT
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_ORDER_dt = 0 or  LEN(sls_ORDER_dt) != 8 THEN NULL -- Data Quality: Setting invalid order dates (0 or not in YYYYMMDD format) to NULL to prevent issues in date analyses and ensure data integrity
		ELSE CAST(CAST(sls_ORDER_dt AS varchar) AS DATE)
	END AS sls_ORDER_dt,
	CASE WHEN sls_due_dt = 0 or  LEN(sls_due_dt) != 8 THEN NULL -- Data Quality: Setting invalid due dates (0 or not in YYYYMMDD format) to NULL to prevent issues in date analyses and ensure data integrity
		ELSE CAST(CAST(sls_due_dt AS varchar) AS DATE)
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt = 0 or  LEN(sls_due_dt) != 8 THEN NULL -- Data Quality: Setting invalid due dates (0 or not in YYYYMMDD format) to NULL to prevent issues in date analyses and ensure data integrity
		ELSE CAST(CAST(sls_due_dt AS varchar) AS DATE)
	END AS sls_due_dt,
	CASE WHEN sls_sales <= 0 or sls_sales is NULL or sls_sales != sls_quantity * ABS(sls_price) 
			THEN sls_quantity * ABS(sls_price) -- Data Quality: Recalculating sales amounts where original sales data is negative, NULL, or inconsistent with quantity and price to ensure accurate financial data
			ELSE sls_sales
		END AS sls_sales,
	sls_quantity,
	CASE when sls_price <= 0 or sls_price is NULL
		THEN sls_sales/NULLIF(sls_quantity,0)-- Data Quality: Recalculating prices where original price data is negative, NULL, or inconsistent with sales and quantity to ensure accurate pricing information
		ELSE sls_price
	END AS sls_price 
	FROM bronze.crm_sales_details
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

	 -- Loading erp_cust_az12
        SET @start_time = GETDATE();
	PRINT '>> Truncating Table:silver.erp_cust_az12'
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT '>> Inserting data into Table:silver.erp_cust_az12'
	INSERT INTO silver.erp_cust_az12 (
	cid,
	bdate,
	gen)
	SELECT 
	CASE WHEN cid like 'NAS%' THEN SUBSTRING(cid,4, LEN(cid))
		ELSE cid
		END cid,
	CASE WHEN bdate > GETDATE() THEN NULL
		ELSE bdate
		END bdate,
	CASE WHEN UPPER(TRIM(gen)) in ('F','FEMALE') THEN 'Female'
		WHEN UPPER(TRIM(gen)) in ('M','MALE') THEN 'Male'
		ELSE 'n/a'
		END gen
	FROM bronze.erp_cust_az12;
		    SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP Tables';
		PRINT '------------------------------------------------';

    -- Loading erp_loc_a101
    SET @start_time = GETDATE();
	PRINT '>> Truncating Table:silver.erp_loc_a101'
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT '>> Inserting data into Table:silver.erp_loc_a101'
	INSERT INTO silver.erp_loc_a101 (
	cid,
	cntry)
	SELECT
	REPLACE(cid,'-','') as cid,
	CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
		WHEN UPPER(TRIM(cntry)) IN ('US','USA') THEN 'United States'
		WHEN UPPER(trim(cntry)) = '' OR cntry IS NULL THEN 'n/a' 
		ELSE trim(CNTRY) -- Data Standardization: Converting country codes to full names, handling empty or NULL values with 'n/a', and trimming whitespace for consistency
	END AS cntry_cleaned
	FROM bronze.erp_loc_a101;
	    SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

	-- Loading erp_px_cat_g1v2
	SET @start_time = GETDATE();
	PRINT '>> Truncating Table:silver.erp_px_cat_g1v2'
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT '>> Inserting data into Table:silver.erp_px_cat_g1v2'
	INSERT INTO silver.erp_px_cat_g1v2 (
	id,
	cat,
	subcat,
	maintenance)
	SELECT 
	id,
	cat,
	subcat,
	maintenance
	from bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
		
	END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END
