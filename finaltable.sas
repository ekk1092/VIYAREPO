libname IPEDS '~/IPEDS';
LIBNAME VIYAREPO '~/VIYAREPO';
options fmtsearch=(IPEDS); 


data CharaPred (keep=unitid iclevel--cbsatype);
	set ipeds.characteristics;
	by unitid;
run;

proc sql;
    create table AidPred as
    select unitid,
		   (uagrntn / scfa2) as GrantRate format=percentn8.2,
		   (uagrntt / scfa2) as GrantAvg,
		   (upgrntn / scfa2) as PellRate format=percentn8.2,
		   (ufloann / scfa2) as LoanRate format=percentn8.2,
		   (ufloant / scfa2) as LoanAvg
    from ipeds.aid;
quit;

data TuitionPred (keep=unitid tuition1--boardamt);
	set ipeds.tuitionandcosts;
	by unitid;
run;

proc sql;
	create table SalPred as
	select salaries.unitid, 
		   (sa09mot / sa09mct) as AvgSalary,
		   (scfa2 / sa09mct) as StuFacRatio
	from ipeds.salaries inner join ipeds.aid
	on salaries.unitid eq aid.unitid;
quit;

data PREIPEDSMRGD;
	merge ipeds.gradrates CharaPred AidPred TuitionPred SalPred;
	by unitid;
run;


proc sort data=PREIPEDSMRGD out=VIYAREPO.FINALTABLE nodupkey;
    by unitid;
run;
