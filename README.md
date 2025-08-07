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
Make sure to have raw datasets, variable label, and code list files ready in this directory

1. raw dataset: the .sas7bdat file gathered from your clinical research in long format
2. variable label: the .sas7bdat file used to map metavariable Varlabel and Comment1
3. code list: the .sas7bdat file used to map metavariable Values for encoded variables
---

### Meta Pipeline

input directory:

```
/CSCC-data-dictionary-pipeline/input/BPXXXX
```

Make sure to have derived datasets and labeled request file ready in this directory

1. meta dataset: the .sas7bdat file combined from multiple raw datsets
2. request: the .docx file containing the specific instructions to create metadatsets (be sure to bookmark the tables that corresponding to the input meta datasets accordingly.)
---


## Usage

### Raw Data Dictionary Pipeline (`BP00XXdict.sas`)

1. Rename the following macros according to the comment:

```sas
%let indir=../CSCC-data-dictionary-pipeline/input/raw; /* Replace this with the actual physical location */
%let outdir=.../CSCC-data-dictionary-pipeline/output/raw; /* Replace this with the actual physical location (this can be anywhere you want) */
%let ds=raw_input.sas7bdat; /* Replace this with the list of the full name of your input raw datasets */
%let cl=codelist.sas7bdat;  /* Replace this with the name of your code list file */
%let vl=varlabel.sas7bdat;  /* Replace this with the name of your variable label file */
```
2. Execute the code all at once

3. A single `.xlsx` file with multiple sheets will be generated in `outdir` specified above

4. Always check the information within the `.xlsx` file.

5. If needed, manually change the code by referencing the comments within the code according to your demand

---

### Meta Data Dictionary Pipeline (`BP00XXdict_raw_revised.sas`)

1. Turn off all `docx`, `csv` files otherwise the VBS script will not run properly

2. Rename the following macros according to the comment:

```sas

```
3. Execute the code all at once

4. When the secruity window regarding the VBS script pop out, click yes

5. A window said **'Table copied successfully to CSV!'** will pop out, click OK

6. Verify the generated dictionaries accordingly and modify the code if needed

---

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
