# [**STEP 10. Data Aggregation & Standardization**](10_Data-Aggregation-and-Standardization)
<img src="../media/image11.png" width="15" height="15" alt="Automation" /> Reading in and standardizing depth data across datasets. <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />

* **00.** Load Data
* **01.** Process Data
    * **01.A.** Depth Correction
    * **01.B.** Data Truncation
    * **01.C.** Data Alignment
    * **Inputs:** MAT files, raw CSV dive data for Sleep, Kami/Stroke,
or TDR-only recordings.

### <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" /><img src="../media/image12.png" width="15" height="15" alt="Glasses Icon | Line Iconset | IconsMind" /> Generate standardized raw files

1.  **Overview:** Create standardized raw data files for kami kami and
    stroke raw data to be used in Costa lab elephant seal dive analysis
    pipeline.

    1.  **Script:**
        <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        ***10_Merge-Stroke-Kami-Data.m***
        <img src="../media/image14.png" width="15" height="15" alt="RStudio logo" />

    2.  **Input:** raw Kami & Stroke text files

    3.  **Outputs:** Raw data CSVs to be used in our dive analysis
        pipeline.