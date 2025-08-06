# Data Dictionary Pipeline

Automated SAS-based pipelines to generate machine-readable and human-readable data dictionaries for clinical research datasets.

---

## Pipeline Descriptions

### Raw Data Dictionary Pipeline (`BP00XXdict.sas`)
Automates the profiling of long-format raw datasets (e.g., BEST Trial baseline/follow-up forms).

---

### Meta Data Dictionary Pipeline (`BP00XXdict_raw_revised.sas`)
Parses metadata tables from bookmarked Word requests and aligns them with derived datasets.

---

## Usage Instructions

This repository contains the SAS programs and template files needed to run the pipeline. Follow these steps to generate a data dictionary for your study:


1.	**Setup SAS Environment**: Ensure you have access to SAS 9.4.
2.	**Clone or Download the Repository**: Obtain the files from this GitHub repository (either via git clone or by downloading the ZIP). The repository includes one or more SAS programs and possibly example data.
3.	**Prepare Input Files**: Put your raw dataset file(s) and metadata specification file into the appropriate location. You may need to edit the SAS program to point to these files. Open the main SAS program in a text editor or SAS editor. Look for a section at the top where file paths or library names are defined. For instance, you might see macro variables or libname statements such as:

---
### **Raw Pipeline Inputs**
```sas
%let indir=.../input/raw;
%let outdir=.../output/raw;
%let ds=raw_input.sas7bdat;
%let cl=codelist.sas7bdat;
%let vl=varlabel.sas7bdat;

%run_it(ds=&ds, cl=&cl, vl=&vl);
```

---

### **Meta Pipeline Inputs**
```sas
%let outdir=.../CSCC-data-dictionary-pipeline;
%let bp=BPXXXX;
%let ds=mock_data;
%let pat=BEST_DERV; /* This is the study title which should be present among all of your request tables. For example, best_derv_phys_assess Variable. Don't worry, SAS is case insensitive. */

%run_it(
  ds=&ds,
  SCrequest=%str(request.docx),
  bkmrk=c2b
);
```

---

Update these paths to match your environment. If the raw data consists of multiple files, also specify each or use a libname directory to point to them, as instructed in the comments. Ensure that the metadata file path and format is correctly specified (e.g., if it's an Excel, the code might use PROC IMPORT or a LIBNAME XLSX to read it).

---

### Known Limitations:
- **SAS session memory**: Restart SAS before switching datasets to avoid retained variable leaks
- **Resolution rounding**: SAS drops trailing zeroes (e.g., `151.10` → `151.1`); ~10% risk of misclassification
- **Missing handling**: Encoded values (e.g., `98`, `99`) are *not treated as missing*
- **No ontology/harmonization**: This pipeline does not yet map to controlled vocabularies
