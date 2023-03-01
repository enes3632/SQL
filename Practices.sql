--My solutions to the problems oublished on sqlpractice.com
--Questions are listed from hard to medium

--Q1
/*Sort the province names in ascending order
 in such a way that the province 'Ontario' is always on top.*/

select province_name 
from
    (select row_number() over()-1, province_name
    from province_names
    where province_name='Ontario'

    union

    select row_number() over(), province_name
    from province_names
    where province_name<>'Ontario');

-----------------------------------------------------------------------
--Q2
/*For each day display the total amount of admissions on that day. 
Display the amount changed from the previous date.*/

select a, b, b-lag(b,1) over()
from
	(select admission_date as a, count(patient_id) as b
	from admissions
	group by admission_date);

-----------------------------------------------------------------------
--Q3
/*Show the percent of patients that have 'M' as their gender. 
Round the answer to the nearest hundreth number and in percent form.*/

select concat(round(c*1.00/sum(c)*100, 2),'%')
from
    (select count(patient_id) as c, gender
    from patients
    group by gender
    order by c desc);

-----------------------------------------------------------------------
--Q4
/*We are looking for a specific patient. Pull all columns for the 
patient who matches the following criteria:
- First_name contains an 'r' after the first two letters.
- Identifies their gender as 'F'
- Born in February, May, or December
- Their weight would be between 60kg and 80kg
- Their patient_id is an odd number
- They are from the city 'Kingston'*/

select * 
from patients
where 
	first_name like '__r%'
    and gender='F'
    and (month(birth_date)=2 or month(birth_date)=5 or month(birth_date)=12)
    and weight between 60 and 80
    and patient_id % 2 = 1
    and city='Kingston';

-----------------------------------------------------------------------
--Q5
/*Show the provinces that has more patients identified as 'M' than 'F'.
Must only show full province_name*/

select province_name 
from(
    select row_number() over() as rowss, province_name, cou, gender
    from(
        select province_name, count(patient_id) as cou, gender
        from province_names
        right join patients
        on patients.province_id=province_names.province_id
        group by province_name, gender
        order by province_name, count(patient_id) desc))
where gender='M' and rowss%2=1;

-----------------------------------------------------------------------
--Q6
/*Each admission costs $50 for patients without insurance, and $10 for 
patients with insurance. All patients with an even patient_id have insurance.

Give each patient a 'Yes' if they have insurance, and a 'No' if they 
don't have insurance. Add up the admission_total cost for each has_insurance group.*/

select 
	case
    	when patient_id%2=0 then 'Yes'
        else 'No'
        end as insurance,
        
    sum(case
    	    when patient_id%2=0 then 10
            else 50
            end) as cost
from admissions
group by insurance;

-----------------------------------------------------------------------
--Q7
/*All patients who have gone through admissions, can see their medical 
documents on our site. Those patients are given a temporary password after 
their first admission. Show the patient_id and temp_password.

The password must be the following, in order:
1. patient_id
2. the numerical length of patient's last_name
3. year of patient's birth_date*/

select distinct(admissions.patient_id), concat(admissions.patient_id, 
    len(patients.last_name), year(patients.birth_date)) as temp_password
from admissions, patients
where patients.patient_id=admissions.patient_id;

-----------------------------------------------------------------------
--Q8
/*Show patient_id, first_name, last_name, and attending doctor's specialty.
Show only the patients who has a diagnosis as 'Epilepsy' and the doctor's 
first name is 'Lisa'

Check patients, admissions, and doctors tables for required information.*/

select patients.patient_id, patients.first_name, patients.last_name, specialty
from patients, admissions, doctors
where patients.patient_id=admissions.patient_id 
    and admissions.attending_doctor_id=doctors.doctor_id 
    and diagnosis='Epilepsy' 
    and doctors.first_name='Lisa';

-----------------------------------------------------------------------
--Q9
/*Show all of the patients grouped into weight groups.
Show the total amount of patients in each weight group.
Order the list by the weight group decending.

For example, if they weight 100 to 109 they are placed in the 100 weight
group, 110-119 = 110 weight group, etc.*/

select round(weight/10)*10 as a , count(patient_id)
from patients
group by a
order by a desc;

-----------------------------------------------------------------------
--Q10
/*Display patient's full name,
height in the units feet rounded to 1 decimal,
weight in the unit pounds rounded to 0 decimals,
birth_date,
gender non abbreviated.

Convert CM to feet by dividing by 30.48.
Convert KG to pounds by multiplying by 2.205.*/

select 
	concat(first_name, ' ', last_name), 
    round(height/30.48, 1), 
    round(weight*2.205, 0), 
    birth_date, 
	case
    	when gender='M' then 'Male'
    	else 'Female'
    	end as Gender
from patients;

-----------------------------------------------------------------------
--Q11
/*display the number of duplicate patients based on their first_name and last_name.*/

select patients.first_name, patients.last_name,count(patient_id)
from patients
group by first_name, last_name
having count(patient_id)>1;

-----------------------------------------------------------------------
--Q12
/*For every admission, display the patient's full name, their admission 
diagnosis, and their doctor's full name who diagnosed their problem*/

select 
    concat(patients.first_name, ' ', 
    patients.last_name), 
    diagnosis, 
    concat(doctors.first_name, ' ', doctors.last_name)
from admissions
left join patients, doctors
on admissions.patient_id=patients.patient_id and admissions.attending_doctor_id=doctors.doctor_id;

-----------------------------------------------------------------------
--Q13
/*Display the total amount of patients for each province. Order by descending.*/

select province_name, count(patient_id)
from patients
left join province_names
on province_names.province_id=patients.province_id
group by patients.province_id
order by count(patient_id) desc;

-----------------------------------------------------------------------
--Q14
/*For each doctor, display their id, full name, and the first and last 
admission date they attended.*/

select 
    attending_doctor_id, 
    concat(first_name, ' ', last_name), 
    min(admission_date), 
    max(admission_date)
from admissions
left join doctors
on doctors.doctor_id=admissions.attending_doctor_id
group by attending_doctor_id;

-----------------------------------------------------------------------
--Q15
/*Show first_name, last_name, and the total number of admissions attended for each doctor.
Every admission has been attended by a doctor.*/

select first_name, last_name, count(patient_id)
from admissions
left join doctors
on doctors.doctor_id=admissions.attending_doctor_id
group by attending_doctor_id;

-----------------------------------------------------------------------
--Q16
/*Show patient_id, attending_doctor_id, and diagnosis for admissions that match
one of the two criteria:
1. patient_id is an odd number and attending_doctor_id is either 1, 5, or 19.
2. attending_doctor_id contains a 2 and the length of patient_id is 3 characters.*/

select patient_id, attending_doctor_id, diagnosis
from admissions
where ( patient_id % 2 = 1 and attending_doctor_id in (1,5,19)) 
    or (attending_doctor_id like '%2%' and len(patient_id)=3);

-----------------------------------------------------------------------
--Q17
/*Show all columns for patient_id 542's most recent admission_date.*/

select *
from admissions
where patient_id=542
order by admission_date desc
limit 1;

-----------------------------------------------------------------------
--Q18
/*Show all of the days of the month (1-31) and how many admission_dates 
occurred on that day. Sort by the day with most admissions to least admissions.*/

select day(admission_date), count(patient_id)
from admissions
group by day(admission_date)
order by count(patient_id) desc;

-----------------------------------------------------------------------
--Q19
/*Show the difference between the largest weight and smallest weight for patients
 with the last name 'Maroni'*/

select max(weight)-min(weight)
from patients
where last_name='Maroni';

-----------------------------------------------------------------------
--Q20
/*Show the province_id(s), sum of height; where the total sum of its 
patient's height is greater than or equal to 7,000.*/

select province_id, sum(height)
from patients
group by province_id
having sum(height)>=7000;

-----------------------------------------------------------------------
--Q21
/*We want to display each patient's full name in a single column. Their 
last_name in all upper letters must appear first, then first_name in all
lower case letters. Separate the last_name and first_name with a comma. Order
the list by the first_name in decending order
EX: SMITH,jane*/

select concat(upper(last_name), ',', lower(first_name))
from patients
order by first_name desc;

-----------------------------------------------------------------------
--Q22
/*Show all patient's first_name, last_name, and birth_date who were born
in the 1970s decade. Sort the list starting from the earliest birth_date.*/

select first_name, last_name, birth_date
from patients
where year(birth_date) between 1970 and 1979
order by birth_date;

-----------------------------------------------------------------------
--Q23
/*Show all allergies ordered by popularity. Remove NULL values from query.*/

select allergies, count(patient_id)
from patients
group by allergies
having allergies is not null
order by count(patient_id) desc;

-----------------------------------------------------------------------
--Q24
/*Show first name, last name and role of every person that is either patient or doctor.
The roles are either "Patient" or "Doctor"*/

select 
    case
        when patient_id is not null then patients.first_name
        else doctors.first_name
        end as first_name, 
    case
        when patient_id is not null then patients.last_name
        else doctors.last_name
        end as last_name,
    case
        when patient_id is not null then 'Patient'
        else 'Doctor'
        end as role
from patients
full outer join doctors
on specialty=allergies ;

-----------------------------------------------------------------------
--Q25
/*Show patient_id, diagnosis from admissions. Find patients admitted 
multiple times for the same diagnosis.*/

select patient_id, diagnosis
from admissions
group by patient_id, diagnosis
having count(diagnosis)>1;

-----------------------------------------------------------------------
--Q26
/*Show first and last name, allergies from patients which have allergies 
to either 'Penicillin' or 'Morphine'. Show results ordered ascending by 
allergies then by first_name then by last_name.*/

select first_name, last_name, allergies
from patients
where allergies in ('Penicillin','Morphine')
order by allergies, first_name, last_name;

-----------------------------------------------------------------------
--Q27

/*Show the total amount of male patients and the total amount of female 
patients in the patients table.
Display the two results in the same row.*/

select count(patient_id), 
    (select count(patient_id) 
    from patients 
    where gender='F')
from patients
where gender='M';

-----------------------------------------------------------------------
--Q28
/*Display every patient's first_name.
Order the list by the length of each name and then by alphbetically*/

select first_name
from patients
order by len(first_name), first_name;

-----------------------------------------------------------------------
--Q29
/*Show patient_id, first_name, last_name from patients whos diagnosis is 'Dementia'.
Primary diagnosis is stored in the admissions table.*/

select patients.patient_id, first_name, last_name
from patients
left join admissions
on admissions.patient_id=patients.patient_id
where diagnosis='Dementia';

-----------------------------------------------------------------------
--Q30
/*Show patient_id and first_name from patients where their first_name 
start and ends with 's' and is at least 6 characters long.*/

select patient_id, first_name
from patients
where first_name like 's__%__s';

-----------------------------------------------------------------------
--Q31
/*Show unique first names from the patients table which only occurs once in the list.
For example, if two or more people are named 'John' in the first_name column then 
don't include their name in the output list. If only 1 person is named 'Leo' then 
include them in the output.*/

select a.first_name
from patients a, patients b
where a.first_name=b.first_name
group by a.first_name
having count(a.first_name)=1;

-----------------------------------------------------------------------
--Q32
/*Show unique birth years from patients and order them by ascending.*/

select distinct(year(birth_date))
from patients
order by birth_date;