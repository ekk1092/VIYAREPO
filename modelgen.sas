libname IPEDS '~/IPEDS';
LIBNAME VIYAREPO '~/VIYAREPO';
options fmtsearch=(IPEDS); 

proc sql;
   create table GradRates as
   select enroll.unitid label="School Identifier", 
          enroll.Total as cohort label="Incoming Cohort Size",
          (grad.Total / enroll.Total) as Rate format=percentn8.2 label="Graduation Rate"
   from (select unitid, total
         from IPEDS.graduation
         where group eq "Incoming cohort (minus exclusions)"
        ) as enroll 
   inner join (select unitid, total, men, women 
		        from ipeds.graduation
		        where group eq "Completers within 150% of normal time"
	      	   ) as grad
   on enroll.unitid eq grad.unitid;
quit;

proc sql;
    create table RC as 
    select g.*, 
           c.iclevel, c.control, c.hloffer, 
           c.locale, c.instcat, c.c21enprf, c.cbsatype
    from GradRates as g 
    left join ipeds.characteristics as c
    on g.unitid = c.unitid;
quit;

proc sql;
    create table RCA as
	select *
	from RC left join (
	select unitid label="School Identifier",
		   (uagrntn / scfa2) as GrantRate label="Percent of undergraduate students awarded federal, state, local, institutional or other sources of grant
aid" format=percentn8.2,
		   (uagrntt / scfa2) as GrantAvg label="
Average amount of federal, state, local, institutional or other sources of grant aid awarded to undergraduate
students",
		   (upgrntn / scfa2) as PellRate label="
Percent of undergraduate students awarded Pell grants" format=percentn8.2,
		   (ufloann / scfa2) as LoanRate label="
Percent of undergraduate students awarded federal student loans" format=percentn8.2,
		   (ufloant / scfa2) as LoanAvg label="Average amount of federal student loans awarded to undergraduate students"
    from ipeds.aid) as a
	on rc.unitid = a.unitid;
quit;

proc sql;
	create table RCAT as
	select *
	from RCA left join (
	select t.unitid, 
	case
		when tuition1 ne tuition2 then 1
	else 0
	end as InDistrictT label = "Has distinct in-district tuition rate", 
	abs(tuition2 - tuition1) as InDistrictTDiff label = "
Difference between in-district and in-state tuition",
	case
		when fee1 ne fee2 then 1
	else 0
	end as InDistrictF label = "Has distinct in-district fee rate", 
	abs(fee2 - fee1) as InDistrictFDiff label = "Difference between in-district and in-state fees",
	tuition2 as InStateT label = "In-state average tuition for full-time undergraduates",
	fee2 as InstateF label = "In-state required fees for full-time undergraduates",
	case
		when tuition3 ne tuition2 then 1
	else 0
	end as OutStateT label = "Has distinct out-of-state tuition rate",
	abs(tuition3 - tuition2) as OutStateTDiff label = "
In-state average tuition for full-time undergraduates",   
	case
		when fee3 ne fee2 then 1
	else 0
	end as OutStateF label = "
In-state average tuition for full-time undergraduates", 
	abs(fee3 - fee2) as OutStateFDiff label = "
In-state average tuition for full-time undergraduates",
	case 
		when room eq 1 then 1
	else 0
	end as Housing label = "
In-state average tuition for full-time undergraduates",
	sum(a.scfa2 ) /sum(t.roomcap) as ScaledHousingCap label = "Student to Room Ratio",
	case 
		when board eq 0 then 0
	else board
	end as board label = "Institution provides board or meal plan",
	case 
		when room eq . then 0
	else room
	end as roomamt label = "Typical room charge for academic year",
	case 
		when board eq . then 0
	else boardamt
	end as boardamt label = "Typical board charge for academic year"
	from ipeds.tuitionandcosts as t inner join ipeds.aid as a
    on t.unitid = a.unitid) as TC
	on RCA.unitid = TC.unitid;
quit;

proc sql;
	create table RCATS as
	select * 
	from RCAT left join (
		select salaries.unitid, 
			   sum(sa09mot) / sum(sa09mct) as AvgSalary label = "Average Salary for 9-month faculty",
			   mean(scfa2) / sum(sa09mct) as StuFacRatio label = "Student to Faculty Ratio" format=comma5.1
		from ipeds.salaries left join ipeds.aid
		on salaries.unitid = aid.unitid
		group by salaries.unitid) as s
	on rcat.unitid = s.unitid;
quit;


proc glmselect data=work.rcats;
  model rate = InStateT cohort iclevel--StuFacRatio  / 
      selection=stepwise(select=sbc) stat=(aic);
run;