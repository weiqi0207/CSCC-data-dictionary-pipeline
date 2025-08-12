# Data Dictionary Pipeline

Automated SAS-based pipelines to generate machine-readable and human-readable data dictionaries for clinical research datasets.

---

## Prerequisites
1.	**Ensure you have access to SAS 9.4**
2.	**Clone or Download the Repository**:
```
git clone https://github.com/weiqi0207/CSCC-data-dictionary-pipeline
```

3.  **Prepare Input Files**:

***Note: All example input files can be found in the input directories respectively***

### Raw Pipeline

input directory: 

```
/CSCC-data-dictionary-pipeline/input/raw
```
Make sure to have raw datasets, variable label, and code list files ready in this directory:

1. raw dataset: the .sas7bdat file gathered from your clinical research in long format
2. variable label: the .sas7bdat file used to map metavariable Varlabel and Comment1
3. code list: the .sas7bdat file used to map metavariable Values for encoded variables

Also Check the follwings:

---

### Meta Pipeline

input directory:

```
/CSCC-data-dictionary-pipeline/input/BPXXXX
```

Make sure to have derived datasets and labeled request file ready in this directory:

1. meta dataset: the .sas7bdat file combined from multiple raw datsets
2. request: the .docx file containing the specific instructions to create metadatsets (be sure to bookmark the tables that corresponding to the input meta datasets accordingly.)

Also Check the follwings:

1. The variable names from derived dataset and the respected request table should be 100% identical (but the sequences do not have to be the same). Make sure to before running to avoid misclassifications of metavariables like ***TYPE***
2. The sequence of the dslist must 100% match the sequence of bookmark list

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
2. Execute the code all at once

3. A single `.xlsx` file with multiple sheets will be generated in `outdir` specified above

4. Always check the information within the `.xlsx` file

5. Restart the program before next run

6. If needed, manually change the code by referencing the comments within the code according to your demand

---

### Meta Data Dictionary Pipeline (`BP00XXdict_raw_revised.sas`)

1. Turn off all `docx`, `csv` files otherwise the VBS script will not run properly

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
3. Execute the code all at once

4. Whenever the secruity window regarding the VBS script pop out, click Yes

5. Whenever the window said **'Table copied successfully to CSV!'** will pop out, click OK

6. When opening the generated `.xlsx` file, it could pop out a window saying there is something wrong with the content and want to recover it, click Yes

7. Restart the program before next run

8. Verify the generated dictionaries accordingly and modify the code if needed

---
## Known Limitations

1. The current pipeline for both data stcutures was developed and tested exclusively on BACPAC data of CSCC studies and aim to follow BDC requirements **'https://bdcatalyst.gitbook.io/biodata-catalyst-documentation/data-management/data-submission-instructions/data-dictionary-requirement'** which is not generalizable to other purposes. The specific rules of CSCC can be found in the `request.docx` document
2. The current pipeline for both data stcutures do not offer the classiifcation of **Mixed** TYPE by BDC definition, as it is rare
3. EXCEL is unable to read the content in COMMENT1 correctly and will discard these content.


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

##  Maintainers

This repository was originally created by **Weiqi Wang** on behalf of UNC Chapel Hill – CSCC

As of **August 15, 2025**, maintenance has been transferred to:

**Karthik Edupuganti** (UNC Chapel Hill – CSCC)  
GitHub: kedupug2025
Email: kedupug@email.unc.edu

---
