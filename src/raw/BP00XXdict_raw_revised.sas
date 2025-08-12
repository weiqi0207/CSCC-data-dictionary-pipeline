/* Set SAS options for merging, variable naming, and macro operators */
options mergenoby=warn validvarname=upcase minoperator;

%let indir=\CSCC-data-dictionary-pipeline\input\raw; /*Replace this with your input directory */
%let outdir=\CSCC-data-dictionary-pipeline\output\raw; /*Replace this with your output directory */
%let outxlsx = &outdir.\combined_dictionary_raw.xlsx; /*Replace the last element with the intended name of your output .xlsx */
%let dslist=peg pgic;/* Replace this with raw datasets */
%let cl=cl;/* Replace this with codelist */
%let vl=vl;/* Replace this with varlabel */


/* Wrapper Macro to Export All */
ods excel file="&outxlsx" style=excel;
%macro run_it(ds=,cl=,vl=);

    /* Read in the derived dataset */
    data raw_dataset;
        set "&indir.&ds";
    run;
    /* Read in the codelist */
    data cl_dataset;
        set "&indir.&cl";
    run;
    /* Read in the varlabel */
    data vl_dataset;
        set "&indir.&vl";
    run;

	/* Get the variable names */
	proc contents data=raw_dataset out=varlist(keep=name) noprint; run;
	/*proc print data=varlist; run;*/
	proc sort data=varlist out=varlist_sorted;
	    by name;
	run;

	/* proc print data=varlist; run;*/
	/* Mask from vl */
	proc sql;
		create table vl_subset as
		select VARNAME, PROMPT, VARLABEL
		from vl_dataset
		where varname in ( select name from varlist);
	quit;
	/*proc print data=vl_subset; run;*/

	/* Mask from cl */
	proc sql;
		create table cl_subset as
		select VARNAME, CODEDVALUE, TRANSLATEDTEXT
		from cl_dataset
		where upcase(strip(varname)) in (select upcase(strip(name)) from varlist);
	quit;

	/*proc print data=cl_subset; run;*/

	proc sort data=cl_subset out=cl_subset_sorted;
	    by VARNAME;
	run;

	/*proc print data=cl_subset_sorted; run;*/

	/* pipie-separated string using data for cl*/
	data code_mapping_cl;
		length code_map $999 VARNAME $999;
		retain code_map;
		keep VARNAME code_map;

		set cl_subset_sorted;
		by VARNAME;

		if first.VARNAME then code_map = "";
		code_map=catx("|", code_map, cats(CODEDVALUE, "=", TRANSLATEDTEXT));

		if last.VARNAME then output;
	run;

	/*proc print data=code_mapping_cl; run;*/

	/* Extract variable names from ds */
	proc contents data=raw_dataset out=varinfo(keep=name varnum label) noprint;
	run;

	/* VARNAME populated meta-variable-dataset */
	data metadataset;
    	set varinfo(rename=(name=VARNAME label=VARDESC));
    	length VARNAME VARDESC DOCFILE TYPE UNITS RESOLUTION COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES DISTINCT_N $9999;
		format VARNAME VARDESC DOCFILE TYPE UNITS RESOLUTION COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES DISTINCT_N $9999.;
		DOCFILE = "&indir.&ds";
	run;

	/*proc print data=metadataset; run;*/

	/* Everything in code_mapping_cl would be encoded variables */
	data mapping_cl_type;
		set code_mapping_cl;
		inferred_type="encoded";
	run;

	/*proc print data=mapping_cl_type; run;*/

	/* Merge vl and cl*/
	proc sql;
        create table merged_vlcl as
        select 
            a.*, 
            b.prompt
        from 
            (select *, strip(upcase(varname)) as join_key from mapping_cl_type) as a
        left join 
            (select *, strip(upcase(varname)) as join_key from vl_subset) as b
        on 
            a.join_key = b.join_key;
    quit;

	/*proc print data=merged_vlcl; run;*/

	/* Merge VALUES, COMMENT1, and encoded type */
	proc sql;
        create table merged_one as
        select 
            a.*, 
            b.inferred_type, b.code_map, b.prompt
        from 
            (select *, strip(upcase(varname)) as join_key from metadataset) as a
        left join 
            (select *, strip(upcase(varname)) as join_key from merged_vlcl) as b
        on 
            a.join_key = b.join_key;
    quit;

	/*proc print data=merged_one; run;*/
	data merged_two(drop=inferred_type prompt code_map join_key);
        set merged_one;
        if missing(TYPE) then TYPE = inferred_type;
		if missing(COMMENT1) then COMMENT1 = prompt;
		if missing(VALUES) then VALUES = code_map;
    run;
	/* proc print data=merged_two; run; */

	/* Classify everything else outside of encoded */
	data derived_type(keep=VARNAME inferred_type);
	    length VARNAME inferred_type $999 val $100;

	    if _N_ = 1 then do;
	        declare hash seen_num();   /* for numeric variables */
	        seen_num.defineKey('VARNAME');
	        seen_num.defineData('VARNAME');
	        seen_num.defineDone();

	        declare hash seen_char();  /* for character variables */
	        seen_char.defineKey('VARNAME');
	        seen_char.defineData('VARNAME');
	        seen_char.defineDone();
	    end;

	    set raw_dataset;

	    array nums {*} _numeric_;
	    array chars {*} _character_;

	    /* Handle numeric variables */
	    do i = 1 to dim(nums);
	        VARNAME = upcase(vname(nums[i]));

	        rc = seen_num.check();
	        if nums[i] ne . and rc ne 0 then do;
	            if VARNAME = "SUBJECTID" then inferred_type = "string";
	            else if vformat(nums[i]) in ("YYMMDD10.", "DATE9.", "MMDDYY10.") then inferred_type = "date";
	            else if floor(nums[i]) = nums[i] then inferred_type = "integer";
	            else inferred_type = "decimal";

	            seen_num.add();
	            output;
	        end;
	    end;

	    /* Handle character variables */
	    do i = 1 to dim(chars);
	        VARNAME = upcase(vname(chars[i]));
	        if VARNAME in ("VARNAME", "INFERRED_TYPE", "VAL") then continue;

	        rc = seen_char.check();

	        val = strip(vvaluex(VARNAME));
	        numval = input(val, ?? best32.);

	        if rc ne 0 and val ne "" then do;
	            if prxmatch('/^\d{4}-\d{2}-\d{2}$/', val) or prxmatch('/^\d{2}:\d{2}:\d{2}$/', val) then
	                inferred_type = "date";
	            else if not missing(numval) and floor(numval) = numval then
	                inferred_type = "integer";
	            else if not missing(numval) then
	                inferred_type = "decimal";
	            else if prxmatch('/[A-Za-z]/', val) then
	                inferred_type = "string";
	            else
	                inferred_type = "string";  /* fallback */

	            seen_char.add();
	            put VARNAME= val= inferred_type=;
	            output;
	        end;
	    end;
	run;

	/*proc print data=derived_type; run;*/

	/* Merge inferred types back into dictionary */
    proc sql;
        create table merged_three as
        select 
            a.*, 
            b.inferred_type
        from 
            (select *, strip(upcase(varname)) as join_key from merged_two) as a
        left join 
            (select *, strip(upcase(varname)) as join_key from derived_type) as b
        on 
            a.join_key = b.join_key;
    quit;

	data merged_three;
        set merged_three;
        if missing(TYPE) then TYPE = inferred_type;
    run;
	/* Sort the data*/
	proc sort data=merged_three out=merged_three;
	    by varnum;
	run;

	/*proc print data=merged_three; run;*/

	/* Summarize missing, non-missing, and distinct values for each variable */
	/* Get total number of observations */
	proc sql noprint;
	    select count(*) into :total_obs from raw_dataset;
	quit;

	/* Get non-missing counts (N) per numeric variable */
	proc means data=raw_dataset noprint;
	    output out=numeric_n (drop=_TYPE_ _FREQ_);
	run;

	proc transpose data=numeric_n out=n_long name=VARNAME;
	    var _numeric_;
	    id _STAT_;
	run;
	
	/* Compute MISS_N and MISS_PERCENT */
	data miss_n_long;
	    set n_long;
	    length MISS_N MISS_PERCENT 8;
	    MISS_N = &total_obs - N;
	    MISS_PERCENT = round(MISS_N * 100 / &total_obs, 0.1);
	run;

	/* Mask the encoded values because there statistics will be calculated differently */
	proc sql noprint;
		select varname
		into :encoded_vars separated by ''
		from merged_three
		where type="encoded";
	quit;

	/* Get distinct_n for encoded variables */
	data merged_three(drop=inferred_type join_key);
		set merged_three;
		if missing(values) then DISTINCT_N="";
		else DISTINCT_N=countw(strip(values), '|');
	run;

	/*proc print data=merged_three; run;*/
	proc contents data=raw_dataset out=varlist1(keep=name type) noprint; run;
	/* Run PROC UNIVARIATE for each numeric variable and output quantiles */
	data _null_;
	    set varlist1;
			if type=1 then do;
	        call execute("proc univariate data=raw_dataset noprint;");
	        call execute("    var " || strip(name) || ";");
	        call execute("    output out=stats_" || strip(name) || 
	                     " pctlpts=25 50 75 pctlpre=PCT;");
	        call execute("run;");
		end;
	run;

	/* Create empty output to collect results */
	data all_quantiles;
	    length VARNAME $32 PCT25 Median PCT75 8;
	    stop;
	run;

	/* Append all results into one table */
	data _null_;
	    set varlist1;
			if type=1 then do;
	        call execute("data temp; set stats_" || strip(name) || ";");
	        call execute("    length VARNAME $32;");
	        call execute("    VARNAME = '" || strip(name) || "';");
	        call execute("    Median = PCT50;");
	        call execute("    keep VARNAME PCT25 Median PCT75;");
	        call execute("run;");
	        call execute("proc append base=all_quantiles data=temp force; run;");
		end;
	run;

	/* Merge stats into dictionary */
	proc sql;
	    create table merged_four as
	    select a.*, 
	           b.PCT25, b.Median, b.PCT75
	    from merged_three as a
	    left join all_quantiles as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* Merge */
	proc sql;
	    create table merged_five as
	    select a.*, 
	           b.N, b.MIN, b.MAX, b.MEAN, b.STD, b.MISS_N, b.MISS_PERCENT 
	    from merged_four as a
	    left join miss_n_long as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* Remove these statistics associated with encoded values, because they consider missing values */
	data merged_five;
	    set merged_five;
	    if TYPE in ("encoded") then do;
	        MEAN = ""; STD = ""; PCT25 = ""; Median = ""; PCT75 = ""; MIN = ""; MAX="";
	    end;
	run;

	/* To let the final dictionary display yymmdd form of MIN and MAX of date variables, convert MIN and MAX into character */
	data merged_five_updated;
	    set merged_five;

	    length MIN_DATE MAX_DATE $20;

	    if strip(upcase(TYPE)) = "DATE" then do;
	        if not missing(MIN) then MIN_DATE = put(MIN, yymmdd10.);
	        if not missing(MAX) then MAX_DATE = put(MAX, yymmdd10.);
	    end;
	    else do;
	        if not missing(MIN) then MIN_DATE = put(MIN, best12.);
	        if not missing(MAX) then MAX_DATE = put(MAX, best12.);
	    end;
	run;

	data merged_five_updated;
	    set merged_five_updated(drop=MIN MAX);
	    rename MIN_DATE=MIN MAX_DATE=MAX;
	run;

	/*proc print data=merged_five_updated; run;*/

	/* Now rescan the theoretical min and max from the dataset */
	data merged_five;
	    set merged_five_updated;
	    if TYPE = 'encoded' and not missing(VALUES) then do;

	        /* Count number of code=value pairs separated by | */
	        count = countw(VALUES, '|');

	        /* MIN is always the first code */
	        first_code = scan(scan(VALUES, 1, '|'), 1, '=');
	        MIN = strip(first_code);

	        /* Check last code */
	        last_code = scan(scan(VALUES, count, '|'), 1, '=');
	        if input(strip(last_code), best.) <= 90 then do;
	            MAX = strip(last_code);
	        end;
	        else do;
	            /* Scan backward to find first code <= 90 */
	            do i = count to 1 by -1;
	                code = scan(scan(VALUES, i, '|'), 1, '=');
	                if input(strip(code), best.) <= 90 then do;
	                    MAX = strip(code);
	                    leave;
	                end;
	            end;
	        end;
	    end;
	    drop count first_code last_code code i;
	run;

	/*proc print data=merged_five; run;*/

	/* Only leave MIN and MAX for date as requested */
	data merged_five;
	    set merged_five;
	    if TYPE in ("date") then do;
	        MEAN = ""; STD = ""; PCT25 = ""; Median = ""; PCT75 = "";
	    end;
	run;

	/*proc print data=merged_five; run;*/

	proc sql noprint;
		select name into :char_vars separated by ' '
		from varlist1
		where type = 2;
	quit;

	data char_miss;
	    set raw_dataset end=eof;
	    array chars {*} &char_vars;
	    array miss_count[&sqlobs.] _temporary_;

	    do i = 1 to dim(chars);
	        if strip(chars[i]) = "" then miss_count[i] + 1;
	    end;

	    if eof then do;
	        do i = 1 to dim(chars);
				if missing(miss_count[i]) then miss_count[i] = 0;
	            VARNAME = vname(chars[i]);
	            N_missing = miss_count[i];
	            output;
	        end;
	    end;

	    keep VARNAME N_missing;
	run;

	data char_miss;
		length non_miss miss_pct $999;
		set char_miss;
		non_miss = &total_obs - N_missing;
		miss_pct = round(N_missing * 100 / &total_obs, 0.1);
	run;


	/*proc print data=char_miss; run;*/

	proc sql;
        create table merged_five as
        select 
            a.*, 
            b.N_missing, b.non_miss, b.miss_pct
        from 
            (select *, strip(upcase(varname)) as join_key from merged_five) as a
        left join 
            (select *, strip(upcase(varname)) as join_key from char_miss) as b
        on 
            a.join_key = b.join_key;
    quit;

	/*proc print data=merged_five; run;*/

	data merged_five (drop=N_MISSING NON_MISS MISS_PCT);
        set merged_five;
        if missing(MISS_N) then MISS_N = N_missing;
		if missing(N) then N = non_miss;
		if missing(MISS_PERCENT) then MISS_PERCENT = miss_pct;
    run;

	/*proc print data=merged_five; run;*/

	/* Define UNIQUEKEY */
	data merged_five;
	    set merged_five;
	    if upcase(VARNAME) in ("SUBJECTID", "EVENTNAME") then UNIQUEKEY = "X";
	    else UNIQUEKEY = "";
	run;

	/*proc print data=merged_five; run;*/

	/* Compute best resolution per numeric variable */
    data _null_;
        length varname $32 dec_part $10 resval $20;
        if _N_ = 1 then do;
            declare hash seen();
            seen.defineKey('varname');
            seen.defineData('varname');
            seen.defineDone();
        end;
        set raw_dataset end=eof;
        array nums {*} _numeric_;
        do i = 1 to dim(nums);
            varname = upcase(vname(nums[i]));
            rc = seen.check();
            if nums[i] ne . and nums[i] ne floor(nums[i]) and rc ne 0 then do;
                dec_part = scan(put(nums[i], best32.), 2, '.');
                if lengthn(dec_part) > 0 then do;
                    resval = cats('0.', repeat('0', lengthn(dec_part)-1), '1');
                    call symputx(cats('best_res_', varname), resval);
                    seen.add();
                end;
            end;
        end;
    run;

    /* Append resolution to the existing table */
    data merged_five;
        set merged_five;
        length res_sym dec_val $50;
        if TYPE = 'decimal' then do;
            res_sym = cats('best_res_', upcase(VARNAME));
            dec_val = symget(res_sym);
            dot_pos = index(dec_val, '.');
            if dot_pos > 0 then
                RESOLUTION = length(strip(dec_val)) - dot_pos - 1;
            else
                RESOLUTION = 0;
        end;
    run;

	/* Define UNITS */
	data merged_five;
	    set merged_five;

	    /* Extract text inside parentheses in LABEL */
	    UNITS = scan(VARDESC, 2, '()');
	run;

	/*proc print data=merged_five; run;*/

	/* Define COLLINTERVAL */
	proc sql noprint;
	    select distinct eventname into :all_evt separated by '; '
	    from raw_dataset
	    where not missing(eventname);
	quit;

	/* Install COLLINTERVAL */
	data merged_five (drop=JOIN_KEY RES_SYM DEC_VAL DOT_POS);
	    set merged_five;
	    COLLINTERVAL = "Collected in &all_evt";
	run;

	/* proc print data=merged_five; run; */

	/* Restructure the meta-variable sequence */
	proc sql;
	    create table merged_five as
	    select 
	        VARNUM, 
	        VARNAME, 
	        VARDESC, 
	        DOCFILE, 
	        TYPE, 
	        UNITS, 
	        RESOLUTION, 
	        COMMENT1, 
	        COMMENT2, 
	        QC_COMMENTS, 
	        VARIABLE_SOURCE, 
	        SOURCE_VARIABLE_ID, 
	        VARIABLE_MAPPING, 
	        UNIQUEKEY, 
	        COLLINTERVAL, 
	        VALUES, 
	        N, 
	        MISS_N, 
	        MISS_PERCENT, 
	        DISTINCT_N, 
	        MIN, 
	        MAX, 
	        MEAN, 
	        STD, 
	        PCT25, 
	        Median, 
	        PCT75
	    from merged_five;
	quit;



	/* Sort the data*/
	proc sort data=merged_five out=metadataset1_sorted;
	    by varnum;
	run;

	/* Drop VARNUM */
	data metadataset1_sorted;
		set metadataset1_sorted;
		drop VARNUM;
	run;

	/* Reclassify date variable as date type (some variables appear to be date but were not in the SAS date form e.g. MED0AY, MED0AM, MED0AD)*/
	/*data metadataset1_sorted;
	    set metadataset1_sorted;
	    if index(upcase(VARDESC), "YEAR") > 0 or
	       index(upcase(VARDESC), "MONTH") > 0 or
		   index(upcase(VARDESC), "TIME") > 0 or
	       index(upcase(VARDESC), "DATE") > 0 then do;
	        TYPE = "date";
	        MEAN = "";
	        STD = "";
	        PCT25 = "";
	        MEDIAN = "";
	        PCT75 = "";
	    end;
	run;*/

	/* Classify the TYPE of completely missing variable as unknown */
	data metadataset1_sorted;
	    set metadataset1_sorted;
	    if TYPE="" then TYPE = "unknown";
	run;

	/* Final Check Point */
	/*proc print data=metadataset1_sorted; run;*/

	data _null_; retain code_map; code_map = ""; run;

%mend;


%macro export_all;
    %local i thisds;

    %do i = 1 %to %sysfunc(countw(&dslist));
        %let thisds = %scan(&dslist, &i);

        /* Run dictionary pipeline for current dataset */
        %run_it(
            ds=&thisds,
            cl=&cl,
            vl=&vl
        );

        /* Export result to Excel sheet */
        ods excel options(sheet_name="&thisds");
		proc print data=metadataset1_sorted; run;
    %end;
%mend;

%export_all;

ods excel close;



