-- comp9311 20T3 Project 1
--
-- MyMyUNSW Solutions
use proj1
-- Q1:
create or replace view Q1(staff_role, course_num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select staff_roles.name as staff_role, count(distinct courses.id) as course_num
from staff_roles, courses, course_staff, semesters
where courses.semester=semesters.id and staff_roles.id=course_staff.role and courses.id=course_staff.course
and semesters.year=2010
group by staff_role
having count(distinct courses.id)>1
order by course_num;

-- Q2:
create or replace view Q2(course_id)
as
--... SQL statements, possibly using other views/functions defined by you ...
select id as course_id
from (select courses.id,  rooms.building, count(*)
from courses,classes,rooms
where courses.id=classes.course and ctype=12 and classes.room=rooms.id
group by courses.id, building
order by courses.id) as q2
group by id
having count(id)>=3
order by id;

-- Q3:
create or replace view Q3(course_num)
as 
--... SQL statements, possibly using other views/functions defined by you ...
select count(distinct course.course) as course_num

from (select distinct courses.id as course --the courses that have at least one int student
      from courses,course_enrolments,students
      where courses.id=course_enrolments.course and students.id=course_enrolments.student and students.stype='intl'
      order by courses.id) as course

inner join (select course, classes.room as room
            from (select room from room_facilities
            where facility=24 or facility=25
            group by room
            having count(facility)=2) as Q3_room,--(the rooms located in the facilities with--
                                                               --wheelchair access for both students and teachers)
            classes --the courses with classes in the suitable facilities

            where Q3_room.room=classes.room) as room

on course.course=room.course;

-- Q4:
create or replace view Q4(unswid,name)
as
--... SQL statements, possibly using other views/functions defined by you ...
select students.unswid as unswid, students.name as name
from (select * from course_enrolments where mark>87) as course_enrolments,--the students with mark>87
     (select people.id, name, unswid from students, people where stype='local' and students.id=people.id) as students,
     (select courses.id  from courses,subjects where subjects.id=courses.subject and offeredby=1507) as courses

where course_enrolments.student=students.id and course_enrolments.course=courses.id

order by students.unswid desc;

--Q5:
create or replace view Q5(course_id)
as
--... SQL statements, possibly using other views/functions defined by you ...
select course_enrolments.course as course_id
from (select course, count(student) as total, avg(mark) as avg
      from course_enrolments
      where mark is not null
      group by course
      having count(student) >= 10
      order by course) as course
right join course_enrolments
on course.course=course_enrolments.course
where course_enrolments.mark>course.avg
group by course_enrolments.course, course.total
having count(student)>(total*4/5);

-- Q6:
create or replace view Q6(semester, course_num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select semesters.longname as semester, count.count as course_num
from (select count(id) as count,semester
from courses,
     (select course from course_enrolments
group by course
having count(student)>=10) as course_enrollments
where course_enrollments.course=courses.id
group by semester
order by count(id) desc
limit 1) as count, semesters
where semesters.id=count.semester;

-- Q7:
create or replace view Q7(course_id, avgmark, semester)
as
--... SQL statements, possibly using other views/functions defined by you ...
select courses.id as course_id, cast(avg(mark) as numeric(4,2)) as avgmark, semesters.name as semester
from courses, course_enrolments, semesters,
     (select course from course_enrolments group by course having count(mark)>19) as enn2
where courses.id=course_enrolments.course and semester=semesters.id and course_enrolments.mark is not null
    and enn2.course=course_enrolments.course
group by semester, courses.id,year,semesters.name
having avg(mark)<80 and avg(mark)>75 and year between 2007 and 2008 and count(course_enrolments.mark)>19
order by courses.id desc;

-- Q8: 
create or replace view Q8(num)
as
--... SQL statements, possibly using other views/functions defined by you ...
select count(distinct a.id)

from (select people.unswid as id
    from students, program_enrolments,semesters, streams, stream_enrolments, people,orgunits
    where program_enrolments.student=students.id and students.stype='intl' and semesters.id=program_enrolments.semester
        and semesters.year between 2009 and 2010 and streams.name='Medicine' and streams.id=stream_enrolments.stream and stream_enrolments.partof=program_enrolments.id
        and program_enrolments.semester=semesters.id  and people.id=students.id and orgunits.id=streams.offeredby
    group by people.unswid) as a

left join

    (select student
--into q8
from program_enrolments
    right join (select orgunits.id as orgid, orgunits.name as name, streams.id as streamsid, offeredby, partof as part
from orgunits,streams, stream_enrolments
where orgunits.id=streams.offeredby and streams.id=stream_enrolments.stream and orgunits.name like '%Engineering%') as b
on program_enrolments.id=b.part
group by student) as q8

on q8.student=a.id;

-- Q9:
create or replace view Q9(year,term,average_mark)
as
--... SQL statements, possibly using other views/functions defined by you ...
select semesters.year, semesters.term, cast(avg(mark) as numeric(4,2)) as average_mark
from course_enrolments, courses, semesters, subjects
where course_enrolments.course=courses.id and semesters.id=courses.semester and subjects.id=courses.subject
    and subjects.name='Database Systems' and course_enrolments.mark is not null
group by semesters.term,semesters.year
order by semesters.year, semesters.term;

-- Q10:
create or replace view Q10(year, num, unit)
as
--... SQL statements, possibly using other views/functions defined by you ...
select distinct student
into q10
from program_enrolments;

select b.longname, max(b.co)
from(
select a.longname, a.year, count(a.student) as co
from
(select orgunits.longname as longname, semesters.year as year, q10.student
from orgunits, streams,stream_enrolments, students,semesters, program_enrolments, q10
where orgunits.id=streams.offeredby and streams.id=stream_enrolments.stream and stream_enrolments.partof=program_enrolments.id
    and q10.student=students.id and students.stype='intl' and semesters.id=semester and q10.student=program_enrolments.student
group by orgunits.longname,semesters.year,q10.student
order by orgunits.longname, semesters.year) as a
group by a.longname, a.year
order by a.longname) as b
group by b.longname;

drop table q10;

-- Q11:
create or replace view Q11(unswid, name, avg_mark)
as
--... SQL statements, possibly using other views/functions defined by you ...
select b.unswid, b.name, b.avg_mark from (
select people.unswid,people.name, cast(avg(mark) as numeric(4,2)) as avg_mark
from courses, course_enrolments, semesters, people
where courses.id=course_enrolments.course and semesters.id=courses.semester and semesters.year=2011 and semesters.term='S1'
    and course_enrolments.mark>=0 and people.id=course_enrolments.student
group by people.unswid, people.name
having count(people.unswid)>=3
order by avg(mark) desc
limit 10) a

    left join
              (select people.unswid,people.name, cast(avg(mark) as numeric(4,2)) as avg_mark
from courses, course_enrolments, semesters, people
where courses.id=course_enrolments.course and semesters.id=courses.semester and semesters.year=2011 and semesters.term='S1'
    and course_enrolments.mark>=0 and people.id=course_enrolments.student
group by people.unswid, people.name
having count(people.unswid)>=3
order by avg(mark) desc) as b

on a.avg_mark=b.avg_mark
group by b.unswid, b.name, b.avg_mark
order by b.avg_mark desc;

-- Q12:
create or replace view Q12(unswid, longname,rate)
as
--... SQL statements, possibly using other views/functions defined by you ...
select c.unswid, c.longname, cast(coalesce(rate, 0) as numeric(4,2))
from (select * from rooms where  rooms.building=111 and rtype=2) as c
    left join
(select unswid,longname, cast(sum(stu)/sum(capacity) as numeric(4,2)) as rate
from(
select unswid,longname,classes.course,classes.id, capacity, count(student) as stu
from classes, courses, course_enrolments,rooms
where courses.id=course_enrolments.course and classes.course=courses.id and classes.room=rooms.id
    and rooms.rtype=2 and building=111 and courses.semester=164
group by longname,classes.course,classes.id,capacity,unswid) as a
group by unswid,longname) as b

on c.longname=b.longname
order by unswid;
