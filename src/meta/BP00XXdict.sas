***********************************************************************                                    
    COLLABORATIVE STUDIES COORDINATING CENTER                                                                                                                                                                                                             
                                                                                                                                                                                                                                                          
    REQUEST NUMBER:                                                                                                                                                  
                                                                                                                                                                                                                                                          
    REQUEST TITLE:   Analysis Dataset and Data Dictionary Creation
                                                                                                                                                                                                                                                          
    REQUEST DESCR:   Create dictionaries that meet the BDC dictionaries requirements
                                                                                                                                                                                                                                     
    STUDY:           BEST                                                                                                                                                                               
                                                                                                                                                                                                                                                          
    MANUSCRIPT #:    Practicum Project                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                          
    PROGRAMMER:      Weiqi Wang
 
    REQUESTOR:       Micah McCumber
 
    SUBMITTED BY:    n/a
 
    DATE:            05/13/2025
----------------------------------------------------------------------                                                                                                                                                                                    
    JOBNAME:         BP_dictionary

    JOB DESCRIPTION: Create data dictionary based on raw dataset

    LANGUAGE/VER:    SAS - Ver 9.4

    HISTORY (PROG):  

    RELATED:         n/a

    PROGRAM NOTES:   
-----------------------------------------------------------------------
    INPUT FILES:     derived_data.sas
        
    OUTPUT FILES:    combined_dictionary.xlsx

***********************************************************************;
options mergenoby=warn validvarname=upcase minoperator;

/* === User Parameters === */
%let outdir = J:\BACPAC\Statistics\Special_Projects\DataDictionaryPracticum;
%let bp = BP0060;
%let dslist = best_derv_demographics_240620 best_derv_phys_assess_240620 best_derv_sdoh_240620;
%let bkmrklist = c2a c2b c2c;
%let SCrequest = Practicum_BP00XX_Analysis Dataset and Data Dictionary Creation.docx;
%let outxlsx = &outdir.\dictionary_output\combined_dictionary.xlsx;
%let pat=BEST_DERV;

/* === Libname and Macro Inclusion === */
libname derv "&outdir.\dictionary_input\&bp" access=readonly;
%include "&outdir.\dictionary_input\Word_to_CSV.sas" / source2;

/* === Wrapper Macro to Export All === */
ods excel file="&outxlsx" style=excel;

/* Main macro for dictionary creation */
%macro run_it(ds=, SCrequest=, bkmrk=);

    /* Run VBS script to convert Word doc to CSV */
    %create_run_vbs(outdir=&outdir.,
                    template_file=&outdir.\dictionary_input\word_to_csv.txt,
                    SCrequest=&outdir.\dictionary_input\&SCrequest,
                    bookmark=&bkmrk);

    /* Import generated CSV as input0 */
    proc import datafile="&outdir.\&bkmrk..csv"
                out=input0
                dbms=csv replace;
                guessingrows=max;
    run;

	/* Dynamically extract VARNAME column (BEST_DERV*) but replace accordingly if needed */
    proc sql noprint;
    select name into :vname_col trimmed
    from dictionary.columns
    where libname = "WORK" 
          and memname = "INPUT0"
          and name like "%upcase(&pat)%";
    quit;

    /* Rename columns from input0 for consistency */
    proc datasets library=work nolist;
        modify input0;
        rename
            &vname_col = varname_raw
            Values_and_Format = values_raw
            LABEL = vardesc_raw
            DEFINITION = comment1_raw
            NOTES = comment2_raw;
    quit;

    /* Clean and transform raw input */
    data input1;
        length VARNAME VARDESC DOCFILE UNITS COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES $9999;
		retain var_order;
        format VARNAME VARDESC DOCFILE UNITS COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES $9999.;
        set input0;
        VARNAME = varname_raw;
        VARDESC = vardesc_raw;
        VALUES = values_raw;
        DOCFILE = "&ds.";
        UNITS = scan(VARDESC, 2, '()');
        COMMENT1 = comment1_raw;
        COMMENT2 = comment2_raw;
        if missing(VARNAME) then delete;
        var_order = _n_;

        /* Clean formatting artifacts */
        array vars _character_;
        do over vars;
            vars = tranwrd(vars, '@@', '|');
            vars = compress(vars, '{}');
            vars = compress(vars, , 'kw');
        end;
    run;

    /* Identify encoded variables (non-boolean string sets) */
	data input2/*(drop=clean_values)*/;
	    set input1;
	    length TYPE $999;

	    clean_values = compress(strip(VALUES), '"');

	    /* If any number exists in clean_values, classify as encoded */
	    if prxmatch('/\b\d+\s*=/', clean_values) then TYPE = 'encoded';
		else if upcase(VARNAME) = "EVENTNAME" then TYPE = 'string';
	run;


    /* Store encoded variable names in macro variable */
    proc sql noprint;
        select VARNAME into :encoded_vars separated by ' '
        from input2
        where TYPE = 'encoded';
    quit;

	/* Read in the derived dataset */
    data derived_dataset;
        set derv.&ds;
    run;

	/* Summarize missing, non-missing, and distinct values for each variable */
	/* Step 1: Get total number of observations */
	proc sql noprint;
	    select count(*) into :total_obs from derived_dataset;
	quit;

	/* Step 2: Get non-missing counts (N) per numeric variable */
	proc means data=derived_dataset noprint;
	    output out=numeric_n (drop=_TYPE_ _FREQ_);
	run;

	proc transpose data=numeric_n out=n_long name=VARNAME;
	    var _numeric_;
	    id _STAT_;
	run;

	/* Step 3: Compute MISS_N and MISS_PERCENT */
	data miss_n_long;
	    set n_long;
	    length MISS_N MISS_PERCENT 8;
	    MISS_N = &total_obs - N;
	    MISS_PERCENT = round(MISS_N * 100 / &total_obs, 0.1);
	run;

	/* Step 1: Get character variable names from the DERV library */
	proc sql noprint;
	    select name into :char_vars separated by ' '
	    from dictionary.columns
	    where libname='DERV' and memname="%upcase(&ds)" and type='char';
	    
	    select count(*) into :total_obs
	    from derv.&ds;
	quit;

	/* Step 2: Calculate missing/non-missing counts and percentages */
	%let nvars = %sysfunc(countw(&char_vars));

	data char_miss;
	    set derived_dataset end=eof;

	    array chars {*} &char_vars;
	    array miss_count[&nvars.] _temporary_ ( &nvars.*0 );  /* initialize to 0 */

	    length varname $32 N_missing N_N MISS_PERCENTAGE OBS 8;
	    length value $500;

	    do c = 1 to dim(chars);
	        value = chars[c];
	        if missing(value) then miss_count[c] + 1;  /* OR: miss_count[c] = miss_count[c] + 1; */
	    end;

	    if eof then do;
	        do c = 1 to dim(chars);
	            varname = vname(chars[c]);
	            N_missing = miss_count[c];
	            N_N = &total_obs - N_missing;
	            MISS_PERCENTAGE = round(N_missing * 100 / &total_obs, 0.1);
	            OBS = &total_obs;
	            output;
	        end;
	    end;

	    keep varname N_missing N_N MISS_PERCENTAGE OBS;
	run;

	/* Check type */ 
	data derived_type(keep=VARNAME inferred_type);
	    length VARNAME inferred_type $999 val $100;

	    /* Read only the first row */
	    set derived_dataset(obs=1);

	    array nums {*} _numeric_;
	    array chars {*} _character_;

	    /* Handle numeric variables */
	    do i = 1 to dim(nums);
	        VARNAME = vname(nums[i]);

	        /* Force SUBJECTID as string */
	        if upcase(VARNAME) = "SUBJECTID" then do;
	            inferred_type = "string";
	        end;
	        /* Check for date formats */
	        else if vformat(nums[i]) in ("YYMMDD10.", "DATE9.", "MMDDYY10.") then do;
	            inferred_type = "date";
	        end;
	        else if nums[i] = . then do;
	            inferred_type = "unknown";
	        end;
	        else if floor(nums[i]) = nums[i] then do;
	            inferred_type = "integer";
	        end;
	        else do;
	            inferred_type = "decimal";
	        end;

	        output;
	    end;

	    /* Handle character variables */
	    do i = 1 to dim(chars);
	        VARNAME = vname(chars[i]);

	        if upcase(VARNAME) = "SUBJECTID" then do;
	            inferred_type = "string";
	        end;
	        else do;
	            val = strip(vvaluex(VARNAME));
	            if val = "" then inferred_type = "unknown";
	            else if prxmatch('/[A-Za-z]/', val) then inferred_type = "string";
	            else if prxmatch('/^\d+\.\d+$/', val) then inferred_type = "decimal";
	            else if prxmatch('/^\d+$/', val) then inferred_type = "integer";
	            else inferred_type = "string";
	        end;

	        output;
	    end;
	run;

	/* Merge summary stats into input_final */
	proc sql;
	    create table input_final as
	    select 
	        a.*, 
	        b.N, 
	        b.MISS_N, 
	        b.MISS_PERCENT
	    from (select *, strip(upcase(varname)) as join_key from input2) as a
	    left join (select *, strip(upcase(varname)) as join_key from miss_n_long) as b
	        on a.join_key = b.join_key;
	quit;

    /* Merge inferred types back into dictionary */
    proc sql;
        create table input_final1 as
        select 
            a.*, 
            b.inferred_type
        from 
            (select *, strip(upcase(varname)) as join_key from input_final) as a
        left join 
            (select *, strip(upcase(varname)) as join_key from derived_type) as b
        on 
            a.join_key = b.join_key;
    quit;

    data input_final1(keep=var_order inferred_type TYPE VARNAME VARDESC DOCFILE UNITS COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES N MISS_N MISS_PERCENT DISTINCT_N MEAN STD PCT25 Median PCT75);
        set input_final1;
    run;

	/* Finalize TYPE using inference if missing */
    data input_final2(drop=inferred_type);
        set input_final1;
        if missing(TYPE) then TYPE = inferred_type;
    run;

	/* Classify DISTINCT_N for variables that TYPE = encoded */
	data input_final2;
		set input_final2;
		length DISTINCT_N 8;

		if upcase(TYPE) = 'ENCODED' and not missing(VALUES) then do;
			DISTINCT_N = countw(strip(VALUES), '|');
		end;
	run;

	/* Merge N-related variables for character variables back into dictionary */
	proc sql;
	    create table input_final3 as
	    select 
	        a.*, 
	        b.N_N,
	        b.N_missing,
	        b.MISS_PERCENTAGE
	    from 
	        (select *, strip(upcase(varname)) as join_key from input_final2) as a
	    left join 
	        (select *, strip(upcase(varname)) as join_key from char_miss) as b
	    on 
	        a.join_key = b.join_key;
	quit;

	/* Finalize N-related variables using inference if missing */
	data input_final3(drop=N_N N_missing MISS_PERCENTAGE);
	    set input_final3;
	    if missing(N) then N = N_N;
	    if missing(MISS_N) then MISS_N = N_missing;
	    if missing(MISS_PERCENT) then MISS_PERCENT = MISS_PERCENTAGE;
	run;

	/* Extract min/max values from encoded VALUES text */
	data input_final3(drop=MIN_VAL MAX_VAL i part code value missing_code);
	    set input_final3;
	    length RESOLUTION $50 MIN $50 MAX $50;
	    length missing_code $10;

	    /* Only process if encoded and VALUES is non-missing */
	    if TYPE = 'encoded' and not missing(VALUES) then do;

	        /* Extract missing code from pattern like '...;Missing=98' */
	        if index(VALUES, ';Missing=') then do;
	            missing_code = scan(scan(VALUES, 2, ';'), 2, '=');
	        end;

	        do i = 1 to countw(scan(VALUES, 1, ';'), '|');
	            part = scan(scan(VALUES, 1, ';'), i, '|');
	            code = scan(part, 1, '=');
	            if notdigit(strip(code)) = 0 and strip(code) ne missing_code then do;
	                value = input(strip(code), best.);
	                if missing(min_val) or value < min_val then min_val = value;
	                if missing(max_val) or value > max_val then max_val = value;
	            end;
	        end;

	        MIN = strip(put(min_val, best.));
	        MAX = strip(put(max_val, best.));
	    end;
	run;

    /* Compute best resolution per numeric variable */
    data _null_;
        length varname $32 dec_part $10 resval $20;
        if _N_ = 1 then do;
            declare hash seen();
            seen.defineKey('varname');
            seen.defineData('varname');
            seen.defineDone();
        end;
        set derived_dataset end=eof;
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

    /* Append resolution to final table */
    data input_final4;
        set input_final3;
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

	/* Use PROC MEANS to extract numeric min/max values */
    proc means data=derived_dataset noprint;
        output out=numeric_summary (drop=_TYPE_ _FREQ_);
    run;

    proc transpose data=numeric_summary out=min_long name=VARNAME;
        var _numeric_;
        id _STAT_;
        where _STAT_ = 'MIN';
    run;
    data min_long(rename=(MIN=inferred_min));
        set min_long;
    run;

    proc transpose data=numeric_summary out=max_long name=VARNAME;
        var _numeric_;
        id _STAT_;
        where _STAT_ = 'MAX';
    run;
    data max_long(rename=(MAX=inferred_max));
        set max_long;
    run;

	/* Join inferred min/max with final output */
    proc sql;
        create table numeric_min as
        select a.*, b.inferred_min
        from (select *, strip(upcase(varname)) as join_key from input_final4) as a
        left join (select *, strip(upcase(varname)) as join_key from min_long) as b
        on a.join_key = b.join_key;
    quit;

    data input_final5;
        set numeric_min;
        if missing(MIN) then MIN = inferred_min;
    run;

	 proc sql;
        create table numeric_max as
        select a.*, b.inferred_max
        from (select *, strip(upcase(varname)) as join_key from input_final5) as a
        left join (select *, strip(upcase(varname)) as join_key from max_long) as b
        on a.join_key = b.join_key;
    quit;

    data input_final6;
        set numeric_max;
        if missing(MAX) then MAX = inferred_max;
    run;

	/* Empty the MIN and MAX for variable that type=date for later use (I have to do this to reformat the MIN and MAX to display actual date) */
	/* I have ruled out some more straight forward methods for this whole operation, but they all did not work */
	data input_final6;
		set input_final6;
		if upcase(TYPE) = 'DATE' then do;
			MIN = '';
			MAX = '';
		end;
	run;

	/* proc print data = input_final6; run; */

	/* Get the variables that type=date to link them back to the derived dataset */
	proc sql noprint;
	    select VARNAME into :date_vars separated by ' '
	    from input_final6
	    where upcase(TYPE) = 'DATE';
	quit;

	%put &=date_vars;

	/* Classify MIN and MAX for date variables */
	%macro format_date_min_max;
	    %let n = %sysfunc(countw(&date_vars));

	    data input_final6_updated;
	        set input_final6;
	    run;

	    %do z = 1 %to &n;
	        %let var = %scan(&date_vars, &z);

	        /* Get numeric min and max from derived_dataset */
	        proc sql noprint;
	            select min(&var), max(&var)
	            into :min_&z, :max_&z
	            from derived_dataset;
	        quit;

	        /* Format as yyyy-mm-dd */
	        %let min_fmt_&z = %sysfunc(putn(&&&min_&z, yymmdd10.));
	        %let max_fmt_&z = %sysfunc(putn(&&&max_&z, yymmdd10.));

	        /* Update the MIN/MAX columns for this varname */
	        data input_final6_updated;
	            set input_final6_updated;
	            if upcase(VARNAME) = "%upcase(&var)" then do;
	                MIN = "&&min_fmt_&z";
	                MAX = "&&max_fmt_&z";
	            end;
	        run;
	    %end;
	%mend;

	%format_date_min_max

	/* Define UNIQUEKEY */
	data input_final6_updated;
	    set input_final6_updated;
	    if upcase(VARNAME) in ("SUBJECTID", "EVENTNAME") then UNIQUEKEY = "X";
	    else UNIQUEKEY = "";
	run;
	
	/* Compute summary statistics (mean, std, P25, median, P75) for numeric variables only */
	/* Automatically excludes missing values (non-missing summary) */

	proc means data=derived_dataset noprint;
	    output out=full_stats (drop=_TYPE_ _FREQ_);
	run;

	proc transpose data=full_stats out=stats_long name=VARNAME;
	    var _numeric_;
	    id _STAT_;
	run;

	data stats_long(rename=(mean=MEAN std=STD));
	    set stats_long;
	run;

	/* Merge computed stats back into dictionary */
	proc sql;
	    create table input_final6_stats as
	    select a.*, 
	           b.MEAN, b.STD
	    from input_final6_updated as a
	    left join stats_long as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* Blank stats for non-numeric types */
	data input_final6_stats;
	    set input_final6_stats;
	    if TYPE in ("encoded", "string", "date") then do;
	        MEAN = ""; STD = "";
	    end;
	run;

	/* Extract variable names and types */
	proc contents data=derived_dataset out=varlist(keep=name type) noprint;
	run;

	/* Run PROC UNIVARIATE for each numeric variable and output quantiles */
	data _null_;
	    set varlist;
	    if type = 1 then do;
	        call execute("proc univariate data=derived_dataset noprint;");
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
	    set varlist;
	    if type = 1 then do;
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
	    create table input_final6_stats2 as
	    select a.*, 
	           b.PCT25, b.Median, b.PCT75
	    from input_final6_stats as a
	    left join all_quantiles as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* For non-numeric variables, blank out stats */
	data input_final6_stats3;
	    set input_final6_stats2;
	    if TYPE in ("encoded", "string", "date") then do;
	        MEAN = ""; STD = ""; PCT25 = ""; Median = ""; PCT75 = "";
	    end;
	run;

	/*proc print data=input_final6_stats3; run;*/


	/*sort the data to the orignal order */
	proc sort data=input_final6_stats3 out=input_final7_sorted;
		by var_order;
	run;

	/* Define COLLINTERVAL */
	proc sql noprint;
	    select VALUES into :all_evt separated by ''
	    from input_final7_sorted
	    where upcase(VARNAME) = "EVENTNAME";
	quit;

	/* Install COLLINTERVAL */
	data input_final7_sorted;
	    set input_final7_sorted;
		length COLLINTERVAL $9999;
	    COLLINTERVAL = cats("Collected in ", symget("all_evt"));
	run;


	/* Final arrangement of columns */
	proc sql;
	    create table input_final8 as
	    select 
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
			MAX,
			MIN,
	        MEAN, 
	        STD, 
	        PCT25, 
	        Median, 
	        PCT75
	    from input_final7_sorted;
	quit;

	/*Typically comment1 start with a = sign, which excel would treat it as a command, so I added a ' before = to avoid the issue*/
	data input_final8;
	    set input_final8;
	    if not missing(COMMENT1) and char(COMMENT1,1)='=' then COMMENT1 = cats("'", COMMENT1);
	    if not missing(COMMENT2) and char(COMMENT2,1)='=' then COMMENT2 = cats("'", COMMENT2);
	run;




%mend;

%macro export_all;
    %local i thisds thisbkmrk;

    %do i = 1 %to %sysfunc(countw(&dslist));
        %let thisds = %scan(&dslist, &i);
        %let thisbkmrk = %scan(&bkmrklist, &i);

        /* Run dictionary pipeline for current dataset */
        %run_it(
            ds=&thisds,
            SCrequest=%str(&SCrequest),
            bkmrk=&thisbkmrk
        );

        /* Export result to Excel sheet */
        ods excel options(sheet_name="&thisds");
		proc print data=input_final8; run;
    %end;
%mend;

%export_all;

ods excel close;

