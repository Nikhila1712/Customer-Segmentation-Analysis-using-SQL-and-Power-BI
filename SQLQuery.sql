select TOP 10 * from Customer_data;

-- Remove Duplicates
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ID ORDER BY ID) AS row_num
    FROM Customer_Data
)
DELETE FROM Customer_Data
WHERE ID IN (SELECT ID FROM CTE WHERE row_num > 1);

-- Get summary statistics
SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT ID) AS unique_customers,
    AVG(Age) AS average_age,
    AVG(Work_Experience) AS average_work_experience,
    AVG(Family_Size) AS average_family_size
FROM Customer_Data;

-- Normalize Data
UPDATE Customer_Data
SET Gender = LOWER(TRIM(Gender)),
    Ever_Married = LOWER(TRIM(Ever_Married)),
    Graduated = LOWER(TRIM(Graduated)),
    Profession = LOWER(TRIM(Profession)),
    Spending_Score = LOWER(TRIM(Spending_Score)),
    Var_1 = LOWER(TRIM(Var_1)),
    Segmentation = LOWER(TRIM(Segmentation));

-- Fill missing Profession with 'unknown'
UPDATE Customer_Data
SET Profession = 'unknown'
WHERE Profession IS NULL;

-- Fill missing Work_Experience with 0
UPDATE Customer_Data
SET Work_Experience = 0
WHERE Work_Experience IS NULL;

-- Fill missing Spending_Score with 'low'
UPDATE Customer_Data
SET Spending_Score = 'low'
WHERE Spending_Score IS NULL;

-- Fill missing Family_Size with average family size
UPDATE Customer_Data
SET Family_Size = (SELECT AVG(Family_Size) FROM Customer_Data)
WHERE Family_Size IS NULL;

-- Fill missing Var_1 with 'unknown'
UPDATE Customer_Data
SET Var_1 = 'unknown'
WHERE Var_1 IS NULL;

-- Drop Spending_Score_Numeric if it exists
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Customer_Data' AND COLUMN_NAME = 'Spending_Score_Numeric')
BEGIN
    ALTER TABLE Customer_Data DROP COLUMN Spending_Score_Numeric;
END;


--Convert Spending_Score to Numeric Values
ALTER TABLE Customer_Data ADD Spending_Score_Numeric INT;

-- Update the new column with numeric values based on the categorical values
UPDATE Customer_Data
SET Spending_Score_Numeric = CASE
    WHEN Spending_Score = 'low' THEN 1
    WHEN Spending_Score = 'medium' THEN 2
    WHEN Spending_Score = 'high' THEN 3
    ELSE 0 -- Default for any unexpected values
END;
-- Segmentation Analysis
-- Calculate Purchase Frequency and Total Spend
WITH CustomerSpending AS (
    SELECT TOP 10 ID AS customer_id, Age, Profession, COUNT(*) AS purchase_frequency, SUM(Spending_Score_Numeric) AS total_spent
    FROM Customer_Data
    GROUP BY ID, Age, Profession
)
SELECT customer_id, Age, Profession, purchase_frequency, total_spent
FROM (
    SELECT customer_id, Age, Profession, purchase_frequency, total_spent,
           ROW_NUMBER() OVER (PARTITION BY Profession ORDER BY total_spent DESC) AS rnum
    FROM CustomerSpending
) ranked_customers
WHERE rnum <= 10;

-- Insights and Recommendations
-- Segmentation by Age
SELECT Age, COUNT(ID) AS number_of_customers, AVG(total_spent) AS avg_spent
FROM (
    SELECT TOP 10 ID, Age, SUM(Spending_Score_Numeric) AS total_spent
    FROM Customer_Data
    GROUP BY ID, Age
) age_segment
GROUP BY Age

-- Segmentation by Profession
SELECT Profession, COUNT(ID) AS number_of_customers, AVG(total_spent) AS avg_spent
FROM (
    SELECT ID, Profession, SUM(Spending_Score_Numeric) AS total_spent
    FROM Customer_Data
    GROUP BY ID, Profession
) profession_segment
GROUP BY Profession;

-- Segmentation by Spending Behavior
SELECT Spending_Score, COUNT(ID) AS number_of_customers, AVG(total_spent) AS avg_spent
FROM (
    SELECT ID, Spending_Score, SUM(Spending_Score_Numeric) AS total_spent
    FROM Customer_Data
    GROUP BY ID, Spending_Score
) spending_segment
GROUP BY Spending_Score;

-- Drop High_Value_Customer if it exists
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Customer_Data' AND COLUMN_NAME = 'High_Value_Customer')
BEGIN
    ALTER TABLE Customer_Data DROP COLUMN High_Value_Customer;
END;

-- Create High-Value Customer Flag
ALTER TABLE Customer_Data ADD High_Value_Customer BIT;

UPDATE Customer_Data
SET High_Value_Customer = CASE
    WHEN Spending_Score_Numeric > 2 THEN 1
    ELSE 0
END;
SELECT TOP 10 ID, Spending_Score_Numeric, High_Value_Customer
FROM Customer_Data;

-- Calculate Customer Lifetime Value (CLV)
WITH CustomerLifetimeValue AS (
    SELECT ID AS customer_id, SUM(Spending_Score_Numeric) * 12 AS CLV
    FROM Customer_Data
    GROUP BY ID
)
SELECT TOP 10 customer_id, CLV
FROM CustomerLifetimeValue;




