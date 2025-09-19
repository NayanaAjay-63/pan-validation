-- creating table pan_card_validation_data_set which has all pan card numbers
create table pan_card_validation_data_set (
    pan_numbers text
);

-- fetching all data after importing
select * from pan_card_validation_data_set;

-- Data cleaning and preprocessing

-- identify missing data
select pan_numbers
from pan_card_validation_data_set
where pan_numbers is null;  -- total rows: 965

-- check for duplicates
select pan_numbers, count(*)
from pan_card_validation_data_set
group by pan_numbers
having count(*) > 1;        -- total rows: 6

-- check for leading/trailing spaces
select pan_numbers
from pan_card_validation_data_set
where pan_numbers <> trim(pan_numbers);   -- total rows: 9

-- check for no leading/trailing spaces
select pan_numbers
from pan_card_validation_data_set
where pan_numbers = trim(pan_numbers);    -- total rows: 9026

-- check for numbers in uppercase
select pan_numbers
from pan_card_validation_data_set
where pan_numbers = upper(pan_numbers);   -- total rows: 8045

-- check for numbers not in uppercase
select pan_numbers
from pan_card_validation_data_set
where pan_numbers <> upper(pan_numbers);  -- total rows: 990

-- Step 1: combine all cleaning techniques
select distinct upper(trim(pan_numbers)) as pan_numbers
from pan_card_validation_data_set
where pan_numbers is not null
  and trim(pan_numbers) <> '';            -- total rows: 9025


-- Step 2: PAN format validation

-- function to check for adjacent characters
create or replace function fun_to_check_for_adjacent_characters(p_num text)
returns boolean
language plpgsql
as $$
begin
    for i in 1..(length(p_num) - 1)
    loop 
        if substring(p_num, i, 1) = substring(p_num, i + 1, 1) then
            return true;  -- true = sequence has adjacent characters
        end if;
    end loop;
    return false;         -- false = no adjacent characters
end;
$$;

select fun_to_check_for_adjacent_characters('WUFAR'); -- false
select fun_to_check_for_adjacent_characters('AXBCD'); -- true

-- function to check for sequence of characters (based on ASCII values)
create or replace function fun_to_check_for_sequence_of_characters(p_num text)
returns boolean
language plpgsql
as $$
begin 
    for i in 1..(length(p_num) - 1)
    loop
        if ascii(substring(p_num, i + 1, 1)) - ascii(substring(p_num, i, 1)) <> 1 then
            return false; -- false = not sequential
        end if;
    end loop;
    return true;          -- true = sequential
end;
$$;

select fun_to_check_for_sequence_of_characters('ABCDW'); -- true
select fun_to_check_for_sequence_of_characters('XACRS'); -- false

-- regex to identify patterns like WUFAR0132H
-- length = 10, first 5 letters, next 4 digits, last letter
select pan_numbers 
from pan_card_validation_data_set
where pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$';


-- Step 3: categorise valid and invalid PANs
with cleaned_pan_cte as (
    select distinct upper(trim(pan_numbers)) as pan_numbers
    from pan_card_validation_data_set
    where pan_numbers is not null
      and trim(pan_numbers) <> ''
),
validate_pan_cte as (
    select *
    from cleaned_pan_cte
    where fun_to_check_for_adjacent_characters(pan_numbers) = false
      and fun_to_check_for_sequence_of_characters(pan_numbers) = false
      and fun_to_check_for_adjacent_characters(substring(pan_numbers, 1, 5)) = false
      and fun_to_check_for_sequence_of_characters(substring(pan_numbers, 6, 4)) = false
      and pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
select c1.pan_numbers,
       case when v1.pan_numbers is not null then 'Valid'
            else 'Invalid'
       end as status
from cleaned_pan_cte c1
left join validate_pan_cte v1
       on c1.pan_numbers = v1.pan_numbers;


-- Step 4: create view and summary report

-- view to store PAN status
create or replace view pan_status_identification as 
with cleaned_pan_cte as (
    select distinct upper(trim(pan_numbers)) as pan_numbers
    from pan_card_validation_data_set
    where pan_numbers is not null
      and trim(pan_numbers) <> ''
),
validate_pan_cte as (
    select *
    from cleaned_pan_cte
    where fun_to_check_for_adjacent_characters(pan_numbers) = false
      and fun_to_check_for_sequence_of_characters(pan_numbers) = false
      and fun_to_check_for_adjacent_characters(substring(pan_numbers, 1, 5)) = false
      and fun_to_check_for_sequence_of_characters(substring(pan_numbers, 6, 4)) = false
      and pan_numbers ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'
)
select c1.pan_numbers,
       case when v1.pan_numbers is not null then 'Valid'
            else 'Invalid'
       end as status
from cleaned_pan_cte c1
left join validate_pan_cte v1
       on c1.pan_numbers = v1.pan_numbers;

select * from pan_status_identification;

--summary report: total, valid, invalid, and missing PAN counts
with summery_cte as (
    select 
        (select count(*) from pan_card_validation_data_set) as total_records,
        count(*) filter (where status = 'Valid')   as valid_pan_count,
        count(*) filter (where status = 'Invalid') as invalid_pan_count
    from pan_status_identification
)
select 
    total_records,
    valid_pan_count,
    invalid_pan_count,
    total_records - (valid_pan_count + invalid_pan_count) as total_missing_pan_count
from summery_cte;
