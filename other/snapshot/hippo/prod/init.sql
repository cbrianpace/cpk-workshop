create table employee (empid int, first_name varchar(40), last_name varchar(40), status varchar(10), hiredt date, terminationdt date);
alter table employee add primary key (empid);
create table department (deptid int, department varchar(40), glcode varchar(20));
alter table department add primary key (deptid);
create table test (chkdate timestamp);

grant all on table employee to public;
grant all on table department to public;
grant all on table test to public;
