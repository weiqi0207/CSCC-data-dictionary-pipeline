**********************************************************
VB SCRIPT VERSION:
macro to create script and execute
  copies cells from a bookmarked table in SC request and 
  saves them to a csv file
*********************************************************;
options noxwait;

%macro create_run_vbs(outdir=,
                      template_file=,
                      SCrequest=,
                      bookmark=);
options noxwait; 
filename infile "&template_file.";

data temp; 
    length line $250;
    infile infile length=lg lrecl=1000 end=eof;     
    input @1 line $varying250. lg;

    orig_line = line; *for QC purposes;

    if find(line, "FULLFILEPATH") then line = tranwrd(line, "FULLFILEPATH", "&SCrequest.");
    if find(line, "C2XBOOKMARK") then line = tranwrd(line, "C2XBOOKMARK", "&bookmark.");
    if find(line, "OUTPUTLOCATION") then line = tranwrd(line, "OUTPUTLOCATION", "&outdir.\&bookmark..csv");

run;

filename outfile "&outdir.\word_to_csv.vbs";
data _null_;
    file outfile;
    set temp(keep=line);
    put line $char250.;
run;

%sysexec "&outdir.\word_to_csv.vbs";

%mend;
