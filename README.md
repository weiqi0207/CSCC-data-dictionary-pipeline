# Data Dictionary Pipeline

Automated SAS-based pipelines to generate both machine-readable and human-readable data dictionaries for clinical research datasets.

---

## Prerequisites
1.	**Ensure you have access to SAS 9.4 (or later)**
2.	**Clone or Download the Repository**:
```
git clone https://github.com/weiqi0207/CSCC-data-dictionary-pipeline
```

3.  **Prepare Input Files**:

***Example input files are available in the corresponding input directories.***

### Raw Pipeline

input directory: 

```
/CSCC-data-dictionary-pipeline/input/raw
```
Make sure to have raw datasets, variable label, and code list files ready in this directory:

1. Raw dataset – .sas7bdat file in long format from your clinical research.
2. Variable label file – .sas7bdat file mapping metavariables Varlabel and Comment1.
3. Code list file – .sas7bdat file mapping metavariable Values for encoded variables.

Before running, check:

1. File names match the macro parameters in the SAS script.
2. Data files are complete and located in the specified directory.
3. The Varnames between raw datasets, cl, vl, are exactly the same.

---

### Meta Pipeline

input directory:

```
/CSCC-data-dictionary-pipeline/input/BPXXXX
```

Make sure to have derived datasets and labeled request file ready in this directory:

1. Meta dataset – .sas7bdat file combined from multiple raw datasets.
2. Request file – .docx file containing instructions for creating meta datasets, with bookmarked tables for each dataset.

Also Check the follwings:

1. Variable names in the derived dataset and request table are identical (order does not matter).
2. The dataset list (dslist) is in the same sequence as the bookmark list (bkmrklist), as inputs.

---


## Usage

### Raw Data Dictionary Pipeline (`BP00XXdict.sas`)

1. Rename the following macros according to the comment:

```sas
%let indir=...\CSCC-data-dictionary-pipeline\input\raw; /*Replace this with your input directory */
%let outdir=...\CSCC-data-dictionary-pipeline\output\raw; /*Replace this with your output directory */
%let outxlsx = &outdir.\combined_dictionary_raw.xlsx; /*Replace the last element with the intended name of your output .xlsx */
%let dslist=peg pgic;/* Replace this with raw datasets */
%let cl=cl;/* Replace this with codelist */
%let vl=vl;/* Replace this with varlabel */
```
2. Run the entire program.

3. A single `.xlsx` file with multiple sheets will be generated in `outdir`

4. Restart the program before next run

5. Modify the code as needed, using the in-code comments for guidance.

---

### Meta Data Dictionary Pipeline (`BP00XXdict_raw_revised.sas`)

1. Close all `docx`, `csv` files (required for the VBS script to execute).

2. Rename the following macros according to the comment:

```sas
%let outdir = ...\CSCC-data-dictionary-pipeline; /*Replace this with your input directory */
%let bp = BPXXXX; /* Replace with BP number */
%let dslist = demographics physical_assessment sdoh; /*Replace the name of input derived_datasets */
%let bkmrklist = c2a c2b c2c; /*Replace the name of the bookmarks of tables in the request */
%let SCrequest = Request.docx; /*Replace the name of the request file */
%let outxlsx = &outdir.\output\meta\combined_dictionary.xlsx; /*Replace the last element with the intended name of your output .xlsx */
%let pat=BEST_DERV; /*Replace this with the pattern of the name of the bookmarked table (e.g. the example tables all start with BEST_DERV */
```
3. Run the entire program.

4. When prompted by the VBS script security warning, click Yes.

5. When the message **"Table copied successfully to CSV!"** appears, click OK.

6. Restart SAS before the next run.

7. Review the generated dictionaries and adjust code if necessary.

---
## Known Limitations

1. Pipelines were developed and tested exclusively on BACPAC data from CSCC studies and follow **BDC requirements**. They may not be generalizable to other datasets.
2. The current pipeline for both data stcutures do not offer the classiifcation of **Mixed** TYPE by BDC definition, as it is rarely used.


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

##  Maintainers

This repository was originally created by **Weiqi Wang** (UNC Chapel Hill – CSCC).

As of **August 15, 2025**, maintenance has been transferred to:

**Karthik Edupuganti** (UNC Chapel Hill – CSCC)  
GitHub: kedupug2025
Email: kedupug@email.unc.edu

---
