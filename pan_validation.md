\##
```{=html}
<p align="center">
```
PAN CARD VALIDATION USING SQL
```{=html}
</p>
```
-   ##### `CTE`

-   ##### `PL/pgSQL Functions`

-   ##### `Regular Expressions`

-   ##### `Data Cleaning`

-   ##### `Views`

------------------------------------------------------------------------

### 🗂️ Inspecting Data

``` sql
-- Creating table
CREATE TABLE pan_card_validation_data_set (
   pan_numbers TEXT
);

-- Fetching all data after importing
SELECT * 
FROM pan_card_validation_data_set;
```

------------------------------------------------------------------------

### 🔎 Data Cleaning & Preprocessing

**1️⃣ Identify Missing Data**

``` sql
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers IS NULL;       -- Total rows: 965
```

**2️⃣ Check for Duplicates**

``` sql
SELECT pan_numbers, COUNT(*)
FROM pan_card_validation_data_set
GROUP BY pan_numbers
HAVING COUNT(*) > 1;             -- Total rows: 6
```

**3️⃣ Leading/Trailing Spaces**

``` sql
-- With spaces
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers <> TRIM(pan_numbers);    -- Total rows: 9

-- Without spaces
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers = TRIM(pan_numbers);     -- Total rows: 9026
```

**4️⃣ Uppercase Check**

``` sql
-- Already uppercase
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers = UPPER(pan_numbers);    -- Total rows: 8045

-- Not uppercase
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers <> UPPER(pan_numbers);   -- Total rows: 990
```

**5️⃣ Combine Cleaning**

``` sql
SELECT DISTINCT UPPER(TRIM(pan_numbers)) AS pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers IS NOT NULL 
  AND TRIM(pan_numbers) <> '';             -- Total rows: 9025
```

------------------------------------------------------------------------

### 🧩 PAN Format Validation Functions

**Function 1: Adjacent Characters**

``` sql
CREATE OR REPLACE FUNCTION fun_to_check_for_adjacent_characters(p_num TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
   FOR i IN 1..(LENGTH(p_num)-1) LOOP
      IF SUBSTRING(p_num,i,1) = SUBSTRING(p_num,i+1,1) THEN
         RETURN TRUE;  -- Adjacent characters exist
      END IF;
   END LOOP;
   RETURN FALSE;       -- No adjacent characters
END;
$$;

-- Test
SELECT fun_to_check_for_adjacent_characters('WUFAR');  -- false
SELECT fun_to_check_for_adjacent_characters('AXBCD');  -- true
```

**Function 2: Sequential Characters**

``` sql
CREATE OR REPLACE FUNCTION fun_to_check_for_sequence_of_characters(p_num TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
   FOR i IN 1..(LENGTH(p_num)-1) LOOP
      IF ASCII(SUBSTRING(p_num,i+1,1)) - ASCII(SUBSTRING(p_num,i,1)) <> 1 THEN
         RETURN FALSE; -- Not sequential
      END IF;
   END LOOP;
   RETURN TRUE;        -- Sequential
END;
$$;

-- Test
SELECT fun_to_check_for_sequence_of_characters('ABCDW'); -- true
SELECT fun_to_check_for_sequence_of_characters('XACRS'); -- false
```

**Regex Format Check**

``` sql
-- Valid pattern: 5 letters + 4 digits + 1 letter
SELECT pan_numbers
FROM pan_card_validation_data_set
WHERE pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$';
```

------------------------------------------------------------------------

### 🏷️ Categorisation of Valid & Invalid PANs

``` sql
WITH cleaned_pan_cte AS (
    SELECT DISTINCT UPPER(TRIM(pan_numbers)) AS pan_numbers
    FROM pan_card_validation_data_set
    WHERE pan_numbers IS NOT NULL AND TRIM(pan_numbers) <> ''
),
validate_pan_cte AS (
    SELECT * 
    FROM cleaned_pan_cte
    WHERE fun_to_check_for_adjacent_characters(pan_numbers) = FALSE
      AND fun_to_check_for_sequence_of_characters(pan_numbers) = FALSE
      AND fun_to_check_for_adjacent_characters(SUBSTRING(pan_numbers,1,5)) = FALSE
      AND fun_to_check_for_sequence_of_characters(SUBSTRING(pan_numbers,6,4)) = FALSE
      AND pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
SELECT c1.pan_numbers,
       CASE WHEN v1.pan_numbers IS NOT NULL THEN 'Valid'
            ELSE 'Invalid'
       END AS status
FROM cleaned_pan_cte c1
LEFT JOIN validate_pan_cte v1
ON c1.pan_numbers = v1.pan_numbers;
```

------------------------------------------------------------------------

### 🧮 Summary Report View

``` sql
-- Create a view to store final PAN status
CREATE OR REPLACE VIEW pan_status_identification AS
WITH cleaned_pan_cte AS (
    SELECT DISTINCT UPPER(TRIM(pan_numbers)) AS pan_numbers
    FROM pan_card_validation_data_set
    WHERE pan_numbers IS NOT NULL AND TRIM(pan_numbers) <> ''
),
validate_pan_cte AS (
    SELECT *
    FROM cleaned_pan_cte
    WHERE fun_to_check_for_adjacent_characters(pan_numbers) = FALSE
      AND fun_to_check_for_sequence_of_characters(pan_numbers) = FALSE
      AND fun_to_check_for_adjacent_characters(SUBSTRING(pan_numbers,1,5)) = FALSE
      AND fun_to_check_for_sequence_of_characters(SUBSTRING(pan_numbers,6,4)) = FALSE
      AND pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
SELECT c1.pan_numbers,
       CASE WHEN v1.pan_numbers IS NOT NULL THEN 'Valid'
            ELSE 'Invalid'
       END AS status
FROM cleaned_pan_cte c1
LEFT JOIN validate_pan_cte v1
ON c1.pan_numbers = v1.pan_numbers;
```

**Summary Report**

``` sql
WITH summary_cte AS (
   SELECT 
      (SELECT COUNT(*) FROM pan_card_validation_data_set) AS total_records,
      COUNT(*) FILTER (WHERE status='Valid')   AS valid_pan_count,
      COUNT(*) FILTER (WHERE status='Invalid') AS invalid_pan_count
   FROM pan_status_identification
)
SELECT total_records,
       valid_pan_count,
       invalid_pan_count,
       total_records - (valid_pan_count + invalid_pan_count) AS total_missing_pan_count
FROM summary_cte;
```

------------------------------------------------------------------------

\##
```{=html}
<p align="center">
```
THANK YOU
```{=html}
</p>
```
