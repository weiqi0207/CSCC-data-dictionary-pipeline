# CSCC Data Dictionary Pipeline

Automated SAS-based pipelines to generate machine-readable and human-readable data dictionaries for clinical research datasets at the **Collaborative Studies Coordinating Center (CSCC)**, UNC-Chapel Hill.

---

## Repository Structure
```

CSCC-data-dictionary-pipeline/
│
├── input/
│ ├── BPXXXX/ # For meta pipeline only — contains derived dataset
│ │ └── mock_data.sas7bdat
│ ├── raw/ # For raw pipeline — contains inputs for raw data
│ │ ├── raw_input.sas7bdat
│ │ ├── codelist.sas7bdat
│ │ └── varlabel.sas7bdat
│ ├── Word_to_CSV.sas # Macro for extracting table from Word doc
│ └── word_to_csv.txt # Template used by VBS script
│
├── output/
│ ├── raw/ # Output Excel files for raw data dictionaries
│ └── meta/ # Output Excel files for meta data dictionaries
│
├── src/
│ ├── raw_pipeline.sas # Full macro for raw data dictionary generation
│ └── meta_pipeline.sas # Full macro for metadata dictionary generation
│
├── word_to_csv.vbs # Script to extract Word bookmark to CSV
├── README.md # You are here
└── .gitignore # Ignore *.log, *.bak, etc.
```

---

## Background

The **Collaborative Studies Coordinating Center (CSCC)** at UNC has a 50+ year history of managing multi-site clinical studies, coordinating data collection and producing thousands of research publications. A core part of its mission is the dissemination of study findings and **public datasets** to the broader research community. In recent years, funding agencies and data repositories have required that study data be shared along with comprehensive **data dictionaries** (codebooks) in machine-readable formats. This shift is driven by the rise of data science and AI, which demand standardized, computer-readable metadata to interpret datasets. 

However, preparing detailed data documentation for sharing is time-consuming if done manually. Traditional codebooks (human-readable data documentation) must be updated to meet new **machine-readable** requirements for repositories. Every CSCC study must submit data to a repository so it can be reused by other researchers, which means creating a data dictionary for each dataset. To streamline this process, the CSCC is developing an automated workflow to generate these documentation files efficiently across studies. This project was motivated by the need to **modernize data documentation practices** – ensuring that both old-school (human reviewers) and new-generation (machine algorithms) users can understand the data.

## Project Overview and Goals

The goal of this project is to build a **pipeline** that automatically generates a comprehensive data dictionary from a given study dataset, in formats suitable for data repository submission. In particular, the pipeline is designed to meet the requirements of the **NIH/NHLBI BioData Catalyst (BDC)** repository, which largely aligns with **dbGaP** standards for data dictionaries. The initial use case for development is a subset of data from the NIH Back Pain Consortium **(BACPAC) BEST** Trial – a large clinical trial – but the approach is intended to be generalizable to other studies.

### Key objectives of the pipeline include:
- **Automating Data Dictionary Creation**: The pipeline reads the study's raw dataset and its metadata specifications to produce a dictionary file without manual transcription. This reduces labor and errors in documenting variables.
- **Machine-Readable Output**: The output dictionary conforms to repository standards (e.g. columns for variable name, description, type, allowed values) so that it can be directly ingested by systems like BDC or dbGaP. For example, NIH guidelines specify columns such as VARNAME (variable name), VARDESC (description), TYPE (data type), and VALUES (encoded values or allowable codes) in the data dictionary.
- **Reusability Across Studies**: Although prototyped on the BEST trial data, the pipeline is being built as a reusable tool that can be applied to other CSCC studies (and even studies from other institutions) with minimal modifications. Users can plug in their own datasets and metadata to generate dictionaries, making the process more efficient and transferable across research projects.

_(Note: BEST = Biomarkers for Evaluating Spine Treatment trial, a NIAMS-sponsored back pain study, used here as a case study for the pipeline.)_

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

## Limitations and Future Improvements

While this pipeline greatly streamlines the creation of data dictionaries, there are some current limitations and important assumptions to be aware of:

•	**SAS-Dependent Implementation**: The current version is written in SAS, which is common in biostatistics but may not be readily available to all researchers. You will need a SAS environment to run it. In the future, we may consider translating key parts of the pipeline to open-source languages (like R or Python) to broaden accessibility, or provide a containerized environment for those without SAS licenses.

•	**Input Format Expectations**: The pipeline assumes the raw data is well-structured and that a complete metadata file is provided. If your metadata is incomplete or outdated (for example, missing a new variable), the pipeline will flag it but cannot magically document that variable without input from you. It’s important to maintain the metadata alongside data collection. Similarly, the pipeline relies on either SAS formats or the metadata file to provide value-level details (code meanings). The code was developed and explicitly tested on the most recent BACPAC study, following CSCC-specific encoding and formatting conventions. Always review the **assumptions** file in the main repository before running the code to ensure compatibility.

•	**Output Format**: The default output is an Excel file tailored to the BioData Catalyst (and by extension dbGaP) format. This is suitable for many NIH repositories. If another repository or journal requires a different format (for instance, a JSON metadata schema or an XML file), this pipeline would need extension or conversion of the output. We focused on Excel/CSV because it is both machine-readable and easily reviewed by humans. Future enhancements might include generating JSON schema or other formats for direct integration with data portals.

•	**Quality Assurance**: While the pipeline reduces manual effort, it is not a substitute for human quality checks. Users should still review the output dictionary for accuracy. The automation ensures consistency, but if the input metadata had an error (e.g., a typo in a description or a mis-specified code), that will propagate to the output. Future versions might include more automatic checks, such as detecting if numeric variables have unexpected code values in data (potential data errors) or verifying that categorical codes listed in metadata actually appear in the data, and vice versa, to catch discrepancies.

•	**Collaboration and Parallel Efforts**: This project is being developed alongside internal CSCC efforts to improve data documentation processes. There may be parallel development of similar tools, and we aim to incorporate the best ideas from each. We welcome collaboration – for instance, if another study group has a SAS macro or R script for generating codebooks, integrating those could enhance the pipeline. In the near future, an interactive interface could be considered (for example, a web app where users upload data and get a dictionary), but currently the usage is through running the SAS code.
Despite these limitations, the pipeline provides a strong starting point for efficient data documentation. Ongoing work will address some of the above issues. In particular, a planned next step is to generalize the code further so that adding a new study’s data might be as simple as pointing to a folder of datasets and a metadata file, without editing the code for each study. We also intend to update the pipeline as repository requirements evolve (ensuring compatibility with any changes in dbGaP/BDC standards).

### Known Limitations:
- **SAS session memory**: Restart SAS before switching datasets to avoid retained variable leaks
- **Resolution rounding**: SAS drops trailing zeroes (e.g., `151.10` → `151.1`); ~10% risk of misclassification
- **Missing handling**: Encoded values (e.g., `98`, `99`) are *not treated as missing*
- **No ontology/harmonization**: This pipeline does not yet map to controlled vocabularies

---

## Contact

This project is maintained by **Weiqi Wang** UNC Chapel Hill. For any questions, feedback, or assistance with running the pipeline, please contact Weiqi Wang at **wang0207@unc.edu**. We encourage users from other institutions or centers to reach out if you are interested in using or adapting this pipeline for your own data sharing needs.

---
