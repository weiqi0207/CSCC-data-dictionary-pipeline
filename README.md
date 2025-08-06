---
#Data Dictionary Pipeline

Automated SAS-based pipelines to generate machine-readable and human-readable data dictionaries for clinical research datasets.

---

## Pipeline Descriptions

### Raw Data Dictionary Pipeline (`BP00XXdict.sas`)
Automates the profiling of long-format raw datasets (e.g., BEST Trial baseline/follow-up forms).

**Features:**
- Infers variable types (`string`, `integer`, `decimal`, `date`, `encoded`)
- Parses SAS labels, formats, and code lists
- Computes descriptive stats (N, missing %, percentiles, mean, std)
- Handles complex assumptions:
  - **Encoded values**: MAX is taken as largest value ≤ 90
  - **Missing codes**: Values like 98/99 are *encoded* (not treated as `.`)
- COLLINTERVAL is auto-generated from all distinct non-missing `EVENTNAME`
- Parentheses in labels are parsed as **units** (`(mmHg)` → `UNITS = mmHg`)
- **IMPORTANT:** You *must restart SAS* before running a new dataset due to retained values (e.g., `code_map`)

---

### Meta Data Dictionary Pipeline (`BP00XXdict_raw_revised.sas`)
Parses metadata tables from bookmarked Word requests and aligns them with derived datasets.

**Features:**
- Uses `Word_to_CSV.sas` and a VBS script to extract Word table via bookmark (e.g., `c2b`)
- Infers types for non-encoded variables based on first observation
- Distinguishes and counts encoded value levels
- Adds resolution estimates (e.g., for 1.01, 0.001, etc.)
- Handles stats (min/max, P25, median, P75, mean, std) for numeric vars
- Exports Excel `.xlsx` file compliant with CSCC and repository standards

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

4.	**Run the Pipeline**: Execute the main SAS program. You can do this within SAS Display Manager, SAS Enterprise Guide, SAS Studio, or via command-line SAS. Running the program will trigger all the steps described in the workflow: reading in the data, merging with metadata, and producing outputs. Monitor the SAS log for any warnings or errors (There are also numerous checkpoints in the program, mostly currently commented out, which can be re-enabled for monitoring and debugging purposes).
5.	**Review Outputs**: After a successful run, find the generated data dictionary file (e.g., DataDictionary.xlsx in the output location you specified). Open this file to verify its contents. You should see a table of variables with their descriptions and attributes. Double-check that the information looks correct (spot-check a few variables against your original codebook if available). If any adjustments are needed (for instance, maybe you want to tweak a description or add a note), you can either re-run after updating the metadata input or make minor edits directly in the output Excel before finalizing.
Example: In the repository, we include an example (using a synthetic subset of the BACPAC BEST trial data) to demonstrate usage. The example input metadata file BEST_metadata.xlsx and data file BEST_data.sas7bdat are provided (note: example data may be simulated or de-identified). To run this example, you would update the paths in the SAS program to point to these files and then run it. The expected output BEST_DataDictionary.xlsx will be created, containing entries for variables like AGE, SEX, PAIN_SCORE, etc., each with definitions pulled from the metadata and verified against the data. This can help you confirm that the pipeline is working in your setup before you apply it to your own study data.

---

### Known Limitations:
- **SAS session memory**: Restart SAS before switching datasets to avoid retained variable leaks
- **Resolution rounding**: SAS drops trailing zeroes (e.g., `151.10` → `151.1`); ~10% risk of misclassification
- **Missing handling**: Encoded values (e.g., `98`, `99`) are *not treated as missing*
- **No ontology/harmonization**: This pipeline does not yet map to controlled vocabularies
