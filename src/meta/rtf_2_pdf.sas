/*********************************************************************************

The macro inputs are

    template_file   :: the path for the template text file
    
    rtf_dir         :: the directory where the RTFs for concatenation are located
    
    pdf_dir         :: the directory of all macro output files (.PDF and .VBS)
    
    big_name        :: the name given to the 'big' PDF (DO NOT ADD the .PDF suffix)
                    :: if blank, then the 'big' PDF will not be produced
    
----------------------------------------------------------------------------------

The macro is a combination of two procedures

    a) Create PDFs of all of the RTFs
        -- makes a PDF copy of each RTF listing in rtf_dir, saving the
           copied PDF file(s) to pdf_dir
        -- uses a template text file (template_file) in order to create
           the .VBS file that accomplishes this feat
    b) Stack all of the PDFs into one
        -- makes a 'big' PDF from all of the 'little' PDFs produced in a)
        -- creates the .VBS file itself in order to accomplish this feat
        -- pages of the 'big' PDF will be ordered alphabetically according
           to the naming/numbering used for the RTFs (so plan accordingly)

    ----- Caution -----

    In step b), all PDF files found in pdf_dir will be stacked together.

    If it is necessary to recompile the 'big' PDF, then it will be necessary
    to delete the 'big' PDF from the pdf_dir directory beforehand.

    The macro should be re-run ONLY after having done this bit of clean-up.

    Otherwise you'll find that the 'big' PDF will have duplicated itself!

----------------------------------------------------------------------------------

Example call of the macro

%rtf_2_pdf(template_file = J:\ARIC\SC\dgarb\Macros\template\rtf_2_pdf_template.txt,
           rtf_dir       = J:\ARIC\SC\dgarb\Macros\rtf,
           pdf_dir       = J:\ARIC\SC\dgarb\Macros\pdf,
           big_name      = alltabs)
          
**********************************************************************************/

%macro rtf_2_pdf(template_file = , rtf_dir = , pdf_dir = , big_name = );

    *************************************
    *** a) Create PDFs of all of the RTFs
    *************************************;

    *** Source: https://stackoverflow.com/questions/46217133/how-to-convert-rtf-files-in-folder-to-pdf;
    *** Template text file (.txt) of the VBS program;
    filename infile "&template_file.";

    data temp; 
        length line $250;
        infile infile length=lg lrecl=1000 end=eof;     
        input @1 line $varying250. lg;

        orig_line = line;

        if find(line, "FOLDERFOLDER") then line = tranwrd(line, "FOLDERFOLDER", "&rtf_dir.");
        if find(line, "OUTOUTOUT")    then line = tranwrd(line, "OUTOUTOUT",    "&pdf_dir.");
    run;

    filename outfile "&pdf_dir.\make_little_pdfs.vbs";
    data _null_;
        file outfile;
        set temp(keep=line);
        put line $char250.;
    run;

    %sysexec "&pdf_dir.\make_little_pdfs.vbs";

    %if &big_name. ne %then %do;

        *************************************
        *** b) Stack all of the PDFs into one
        *************************************;

        *** Source: https://analytics.ncsu.edu/sesug/2011/BB15.Welch.pdf;

        ********************;
        *GET FOLDER CONTENTS;
        ********************;

        *PART 1;
        DATA prep;
            folder = strip("&pdf_dir.");
            rc = filename('files',folder);
            did = dopen('files');
            numfiles = dnum(did);
            iter = 0;
            do i = 1 to numfiles;
                text = dread(did,i);
                if index(upcase(text),".PDF") then do;
                   iter + 1;
                   output;
                end;
                call symput("FileNum",put(iter,8.));
            end;
            rc = dclose(did);
        RUN;

        %put NUMBER OF PDF FILES TO STACK: %cmpres(&FileNum);

        ****************;
        *BUILD VB SCRIPT;
        ****************;

        *PART 2;
        DATA indat1;
            length code $150;
            set prep;
            code = 'Dim Doc'||compress(put(_n_,8.));
            order = 1;
            output;
            code = 'Set Doc'||compress(put(_n_,8.))||'= CreateObject("AcroExch.PDDoc")';
            order = 2;
            output;
            code =  'file'||compress(put(_n_,8.))||
                    ' = Doc'||compress(put(_n_,8.))||
                    '.Open("'||strip("&pdf_dir.\")||strip(text)||'")';
            order = 3;
            output;
        RUN;

        PROC SORT data = indat1;
            by order;
        RUN;

        *PART 3;
        DATA indat2;
            length code $150;
            set prep end = eof;
            code = 'Stack = Doc1.InsertPages(Doc1.GetNumPages - 1, Doc'||
                    compress(put((_n_ - 1) + 2,8.))||
                    ', 0, Doc'||
                    compress(put((_n_ - 1) + 2,8.))||
                    '.GetNumPages, 0)';
            if eof then code =  'SaveStack= Doc1.Save(1, "'||
                                strip("&pdf_dir.\")||
                                strip("&big_name.")||'.pdf"'||')';
        RUN;

        ********************;
        *END BUILD VB SCRIPT;
        ********************;

        *OUTPUT VB SCRIPT;
        filename temp "&pdf_dir.\make_big_pdf.vbs";
        DATA allcode;
            set indat1 indat2;
            file temp;
            put code;
        RUN;

        *RUN VB SCRIPT;
        %sysexec "&pdf_dir.\make_big_pdf.vbs";
 
    %end;

%mend;
