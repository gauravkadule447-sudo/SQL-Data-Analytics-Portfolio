SET SQL_SAFE_UPDATES = 0;
## Chapter:- SQL Advanced: Supply Chain Analytics

### Module: Create a Helper Table

-- Create fact_act_est table

SET SQL_SAFE_UPDATES = 0;
drop table if exists fact_act_est;

	create table fact_act_est
	(
        	select 
                    s.date as date,
                    s.fiscal_year as fiscal_year,
                    s.product_code as product_code,
                    s.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
                    fact_sales_monthly s
        	left join fact_forecast_monthly f 
        	using (date, customer_code, product_code)
	)
	union
	(
        	select 
                    f.date as date,
                    f.fiscal_year as fiscal_year,
                    f.product_code as product_code,
                    f.customer_code as customer_code,
                    s.sold_quantity as sold_quantity,
                    f.forecast_quantity as forecast_quantity
        	from 
		    fact_forecast_monthly  f
        	left join fact_sales_monthly s 
        	using (date, customer_code, product_code)
	);

	update fact_act_est
	set sold_quantity = 0
	where sold_quantity is null;

	update fact_act_est
	set forecast_quantity = 0
	where forecast_quantity is null;
    
### Module: Temporary Tables & Forecast Accuracy Report

-- Forecast accuracy report using cte (It exists at the scope of statements)

	WITH forecast_err_table AS (
    SELECT
        s.customer_code AS customer_code,
        c.customer AS customer_name,
        c.market AS market,

        SUM(s.sold_quantity) AS total_sold_qty,
        SUM(s.forecast_quantity) AS total_forecast_qty,

        SUM(
            CAST(s.forecast_quantity AS SIGNED) -
            CAST(s.sold_quantity AS SIGNED)
        ) AS net_error,

        ROUND(
            SUM(
                CAST(s.forecast_quantity AS SIGNED) -
                CAST(s.sold_quantity AS SIGNED)
            ) * 100.0 /
            NULLIF(SUM(s.forecast_quantity), 0),
            1
        ) AS net_error_pct,

        SUM(
            ABS(
                CAST(s.forecast_quantity AS SIGNED) -
                CAST(s.sold_quantity AS SIGNED)
            )
        ) AS abs_error,

        ROUND(
            SUM(
                ABS(
                    CAST(s.forecast_quantity AS SIGNED) -
                    CAST(s.sold_quantity AS SIGNED)
                )
            ) * 100.0 /
            NULLIF(SUM(s.forecast_quantity), 0),
            2
        ) AS abs_error_pct

    FROM fact_act_est s

    JOIN dim_customer c
        ON s.customer_code = c.customer_code

    WHERE s.fiscal_year = 2021

    GROUP BY s.customer_code
)

SELECT
    *,
    IF(
        abs_error_pct > 100,
        0,
        100.0 - abs_error_pct
    ) AS forecast_accuracy

FROM forecast_err_table

ORDER BY forecast_accuracy DESC;

-- Forecast accuracy report using temporary table (It exists for the entire session)

DROP TEMPORARY TABLE IF EXISTS forecast_err_table;

CREATE TEMPORARY TABLE forecast_err_table
SELECT
    s.customer_code AS customer_code,
    c.customer AS customer_name,
    c.market AS market,

    SUM(s.sold_quantity) AS total_sold_qty,

    SUM(s.forecast_quantity) AS total_forecast_qty,

    -- Net Error
    SUM(
        CAST(s.forecast_quantity AS SIGNED)
        - CAST(s.sold_quantity AS SIGNED)
    ) AS net_error,

    -- Net Error %
    ROUND(
        SUM(
            CAST(s.forecast_quantity AS SIGNED)
            - CAST(s.sold_quantity AS SIGNED)
        ) * 100.0
        / NULLIF(SUM(s.forecast_quantity), 0),
        1
    ) AS net_error_pct,

    -- Absolute Error
    SUM(
        ABS(
            CAST(s.forecast_quantity AS SIGNED)
            - CAST(s.sold_quantity AS SIGNED)
        )
    ) AS abs_error,

    -- Absolute Error %
    ROUND(
        SUM(
            ABS(
                CAST(s.forecast_quantity AS SIGNED)
                - CAST(s.sold_quantity AS SIGNED)
            )
        ) * 100.0
        / NULLIF(SUM(s.forecast_quantity), 0),
        2
    ) AS abs_error_pct

FROM fact_act_est s

JOIN dim_customer c
    ON s.customer_code = c.customer_code

WHERE s.fiscal_year = 2021

GROUP BY s.customer_code;


SELECT
    *,
    IF(
        abs_error_pct > 100,
        0,
        100.0 - abs_error_pct
    ) AS forecast_accuracy

FROM forecast_err_table

ORDER BY forecast_accuracy DESC;
	


