/* SUDISH BASNET, 301250603 */
/***BE SURE TO DROP ALL TABLES IN WORK THAT BEGIN WITH "CASE_"***/

/*Set Time Zone*/
set time_zone='-4:00';
select now();
USE work;

/***PRELIMINARY ANALYSIS***/

/*Create a VIEW in WORK called CASE_SCOOT_NAMES that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/
CREATE OR REPLACE VIEW work.case_scoot_name AS
	SELECT * FROM ba710case.ba710_prod
    WHERE product_type = 'scooter';

SELECT * FROM work.case_scoot_name;


/*The following code uses a join to combine the view above with the sales information.
  Can the expected performance be improved using an index?
  A) Calculate the EXPLAIN COST.
  B) Create the appropriate indexes.
  C) Calculate the new EXPLAIN COST.
  D) What is your conclusion?:  
*/
create table work.case_scoot_sales as 
	select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
	from work.case_scoot_name a 
	inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
select * from work.case_scoot_sales;

/*A*/
EXPLAIN FORMAT=JSON select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
	from work.case_scoot_name a 
	inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
/* cost  : 4587.09 */

DESCRIBE ba710case.ba710_sales;
DESCRIBE work.case_scoot_name;

/*B*/
CREATE INDEX indx_pid ON work.case_scoot_sales(product_id);
CREATE INDEX indx_pid ON ba710case.ba710_sales(product_id);

DROP INDEX indx_pid ON work.case_scoot_sales;
DROP INDEX indx_pid ON ba710case.ba710_sales;

/*C*/
EXPLAIN FORMAT=JSON select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
	from work.case_scoot_name a 
	inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
/* cost  : 615.68 */

/* D
The query cost dropped by almost 7.5 times after using index on product id which 
locate data on the basic of index rather than going through all the data 
*/


    
/***PART 1: INVESTIGATE BAT SALES TRENDS***/  
    
/*The following creates a table of daily sales and will be used in the following step.*/

CREATE TABLE work.case_daily_sales AS
	select p.model, p.product_id, date(s.sales_transaction_date) as sale_date, 
		   round(sum(s.sales_amount),2) as daily_sales
	from ba710case.ba710_sales as s 
    inner join ba710case.ba710_prod as p
		on s.product_id=p.product_id
    group by date(s.sales_transaction_date),p.product_id,p.model;

select * from work.case_daily_sales;

/*Examine the drop in sales.*/
/*Create a table of cumulative sales figures for just the Bat scooter from
the daily sales table you created.
Using the table created above, add a column that contains the cumulative
sales amount (one row per date).
Hint: Window Functions, Over*/
CREATE TABLE work.case_cumulative_sales AS
	SELECT *,ROUND(SUM(daily_sales) OVER (ORDER BY sale_date),2) AS cumulative_sales 
    FROM work.case_daily_sales
    WHERE model = 'bat';

SELECT * FROM work.case_cumulative_sales;




/*Using the table above, create a VIEW that computes the cumulative sales 
for the previous 7 days for just the Bat scooter. 
(i.e., running total of sales for 7 rows inclusive of the current row.)
This is calculated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records).
*/
CREATE VIEW work.case_cumulative_sales_7days AS 
	SELECT *, ROUND(SUM(daily_sales) OVER(ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS sum_cumulative_sales_7days
    FROM work.case_cumulative_sales;


SELECT * FROM work.case_cumulative_sales_7days;


/*Using the view you just created, create a new view that calculates
the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).

See the Word document for an example of the expected output for the Blade scooter.*/
CREATE VIEW work.case_weekly_sales_growth AS
	SELECT *,ROUND(((cumulative_sales-LAG(cumulative_sales,7) OVER())/LAG(cumulative_sales,7) OVER())*100,2) AS pct_weekly_increase_cumu_sales
    FROM work.case_cumulative_sales_7days;

SELECT * FROM work.case_weekly_sales_growth;



/*Questions: On what date does the cumulative weekly sales growth drop below 10%?
Answer:  For the first sale date 2016-12-06, the cumulative weekly sales growth drop below 10% and 904 total data below 10%

Question: How many days since the launch date did it take for cumulative sales growth
to drop below 10%?
Answer:  It take 57 days since the launch date for cumulative sales growth to drop below 10% 
                     */
SELECT sale_date,pct_weekly_increase_cumu_sales FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*) FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*)
FROM work.case_weekly_sales_growth
WHERE sale_date < '2016-12-06';

/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
*/
DROP TABLE work.case_cumulative_sales;
CREATE TABLE work.case_cumulative_sales AS
	SELECT *,ROUND(SUM(daily_sales) OVER (ORDER BY sale_date),2) AS cumulative_sales 
    FROM work.case_daily_sales
    WHERE model = 'Bat Limited Edition';

SELECT * FROM work.case_cumulative_sales;



DROP VIEW work.case_cumulative_sales_7days;
CREATE VIEW work.case_cumulative_sales_7days AS 
	SELECT *, ROUND(SUM(daily_sales) OVER(ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS sum_cumulative_sales_7days
    FROM work.case_cumulative_sales;

SELECT * FROM work.case_cumulative_sales_7days;



DROP VIEW work.case_weekly_sales_growth;
CREATE VIEW work.case_weekly_sales_growth AS
	SELECT *,ROUND(((cumulative_sales-LAG(cumulative_sales,7) OVER())/LAG(cumulative_sales,7) OVER())*100,2) AS pct_weekly_increase_cumu_sales
    FROM work.view_cumulative_sales;

SELECT * FROM work.case_weekly_sales_growth;



SELECT sale_date,pct_weekly_increase_cumu_sales FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*) FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*)
FROM work.case_weekly_sales_growth
WHERE sale_date < '2017-04-29';

/* sales dropped by 10% since 2017-04-29 and the total number of data that dropped below 10% is 742*/
/* sales dropped after 73 days of opening */


/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the 2013 Lemon model.*/

DROP TABLE work.case_cumulative_sales;
CREATE TABLE work.case_cumulative_sales AS
	SELECT *,ROUND(SUM(daily_sales) OVER (ORDER BY sale_date),2) AS cumulative_sales 
    FROM work.case_daily_sales
    WHERE model = 'lemon';

SELECT * FROM work.case_cumulative_sales;



DROP VIEW work.case_cumulative_sales_7days;
CREATE VIEW work.case_cumulative_sales_7days AS 
	SELECT *, ROUND(SUM(daily_sales) OVER(ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS sum_cumulative_sales_7days
    FROM work.case_cumulative_sales;

SELECT * FROM work.case_cumulative_sales_7days;



DROP VIEW work.case_weekly_sales_growth;
CREATE VIEW work.case_weekly_sales_growth AS
	SELECT *,ROUND(((cumulative_sales-LAG(cumulative_sales,7) OVER())/LAG(cumulative_sales,7) OVER())*100,2) AS pct_weekly_increase_cumu_sales
    FROM work.view_cumulative_sales;

SELECT * FROM work.case_weekly_sales_growth;



SELECT sale_date,pct_weekly_increase_cumu_sales FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*) FROM work.case_weekly_sales_growth
WHERE pct_weekly_increase_cumu_sales < 10;

SELECT count(*)
FROM work.case_weekly_sales_growth
WHERE sale_date < '2010-06-11';

/* sales dropped by 10% since 2010-06-11 and the total number of data that dropped below 10% is 2707*/
/* sales dropped after 77 days of opening */


DROP TABLE work.case_daily_sales;
DROP TABLE work.case_scoot_sales;
DROP TABLE work.case_cumulative_sales;
DROP VIEW work.case_cumulative_sales_7days;
DROP VIEW work.case_weekly_sales_growth;
