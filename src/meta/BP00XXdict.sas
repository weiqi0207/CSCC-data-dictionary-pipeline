/* Set SAS options for merging, variable naming, and macro operators */
options mergenoby=warn validvarname=upcase minoperator;

/* Define macro variables for directories, dataset names, and labels */
%let outdir=C:\Users\YourName\Documents\CSCC-data-dictionary-pipeline; /*Replace ... with your working directory */

%let bp =BPXXXX; /* Replace with bp numbers of your request accordingly */
%let ds=mock_data; /* Replace this with the name your input derived dataset */


%let pat=BEST_DERV;  /* User-defined prefix of bookmarked table in the request .docx file, in the mock request the name is best_derv_demographics Variable */
/* Keep the name as short as possible, because SAS variable name length is limited to 32 characters */

/* Assign libnames for derived dataset and source data */
libname derv "&outdir.\dictionary_input\&bp" access=readonly; /*Have your input files: derived datasets and request.docx file ready in a folder named input under the working directory*/
/* In this case the folder is ...\CSCC-data-dictionary-pipeline\input\BPXXXX */

/* Include external macro for Word to CSV conversion */
%include "&outdir.\input\Word_to_CSV.sas" / source2; /*Incldue Word_to_CSV.sas in your input files*/

/* Main macro for dictionary creation */
%macro run_it(ds=, SCrequest=, bkmrk=);

    /* Run VBS script to convert Word doc to CSV */
    %create_run_vbs(outdir=&outdir.,
                    template_file=&outdir.\input\word_to_csv.txt,
                    SCrequest=&outdir.\input\&SCrequest,
                    bookmark=&bkmrk);

    /* Import generated CSV as input0 */
    proc import datafile="&outdir.\&bkmrk..csv"
                out=input0
                dbms=csv replace;
                guessingrows=max;
    run; /* The csv is created under your main working directory */

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


	/* Count distinct values for encoded variables */
	proc freq data=derived_dataset nlevels noprint;
	    tables _all_ / noprint;
	    ods output nlevels=distinct_all;
	run;

	/* Step: Filter only encoded variables */
	proc sql noprint;
	    select VARNAME into :encoded_vars separated by ' '
	    from input2
	    where TYPE = 'encoded';
	quit;

	/* Step: Loop through each and compute count of distinct values */
	%let var_count = %sysfunc(countw(&encoded_vars));

	data distinct_encoded;
	    length VARNAME $32 DISTINCT_N 8;
	run;

	%do i = 1 %to &var_count;
	    %let var = %scan(&encoded_vars, &i);

	    proc sql noprint;
	        select count(distinct &var) into :dval
	        from derived_dataset;
	    quit;

	    data _append;
	        length VARNAME $32 DISTINCT_N 8;
	        VARNAME = "&var";
	        DISTINCT_N = &dval;
	    run;

	    proc append base=distinct_encoded data=_append force; run;
	%end;

	/*proc print data=distinct_encoded;
	run;*/


    /* Drop encoded variables from derived dataset */
    %if %symexist(encoded_vars) and %superq(encoded_vars) ne %then %do;
        data derived_clean;
            set derived_dataset;
            drop &encoded_vars;
        run;
    %end;
    %else %do;
        data derived_clean;
            set derived_dataset;
        run;
    %end;

	/* Check type */ 
	data derived_type(keep=VARNAME inferred_type);
	    length VARNAME inferred_type $999 val $100;

	    /* Read only the first row */
	    set derived_clean(obs=1);

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
	        b.MISS_PERCENT, 
	        c.DISTINCT_N
	    from (select *, strip(upcase(varname)) as join_key from input2) as a
	    left join (select *, strip(upcase(varname)) as join_key from miss_n_long) as b
	        on a.join_key = b.join_key
	    left join (select *, strip(upcase(varname)) as join_key from distinct_encoded) as c
	        on a.join_key = c.join_key;
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

	/*proc print data=input_final2;
	run;*/

    /* Extract min/max values from encoded VALUES text */
	data input_final3(drop=MIN_VAL MAX_VAL i part code value missing_code);
	    set input_final2;
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
        set derived_clean end=eof;
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
	/* Define UNIQUEKEY */
	data input_final6;
	    set input_final6;
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
	    from input_final6 as a
	    left join stats_long as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* Blank stats for non-numeric types */
	data input_final6;
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
	    create table input_final6_stats as
	    select a.*, 
	           b.PCT25, b.Median, b.PCT75
	    from input_final6 as a
	    left join all_quantiles as b
	    on upcase(a.VARNAME) = upcase(b.VARNAME);
	quit;

	/* For non-numeric variables, blank out stats */
	data input_final6;
	    set input_final6_stats;
	    if TYPE in ("encoded", "string", "date") then do;
	        MEAN = ""; STD = ""; PCT25 = ""; Median = ""; PCT75 = "";
	    end;
	run;


    /* Final arrangement of columns */
    data input_final7 (drop = RES_SYM DEC_VAL DOT_POS JOIN_KEY INFERRED_MIN INFERRED_MAX);
        retain var_order VARNAME VARDESC DOCFILE TYPE UNITS RESOLUTION COMMENT1 COMMENT2 QC_COMMENTS VARIABLE_SOURCE SOURCE_VARIABLE_ID VARIABLE_MAPPING UNIQUEKEY COLLINTERVAL VALUES N MISS_N MISS_PERCENT DISTINCT_N MIN MAX MEAN STD PCT25 Median PCT75;
        set input_final6;
    run;

	/*sort the data to the orignal order */

	proc sort data=input_final7 out=input_final7_sorted;
		by var_order;
	run;

	data input_final8(drop=var_order);
    	set input_final7_sorted;

		if not missing(VALUES) then VALUES = scan(VALUES, 1, ';');

    	array char_vars _character_;
    	do i = 1 to dim(char_vars);
        	char_vars[i] = lowcase(char_vars[i]);
    	end;

    	drop i;
	run;


	/* Check point */
	proc print data=input_final8;
	run;

    /* Export final dictionary as Excel file */
    proc export data=input_final8
        outfile="&outdir.\output\meta\&bkmrk..xlsx"
        dbms=xlsx
        replace;
    run;

%mend;

/* Run macro with specified inputs */
%run_it(
    ds=&ds,
    SCrequest=%str(request.docx), /*Replace this with your request file name */
    bkmrk=c2b /*Replace this with the bookmark of the meta data table in the request document */
);
