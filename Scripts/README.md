# **Sleep Study Protocol**

For more information on Data Analysis steps and current progress, see
GDrive 🗀 Sleep_Analysis \> 🗀 Scripts \> 00_Data_Analysis_Tracking.xlsx).
Generally, all scripts or settings files used to generate subsequent
data steps are in 🗀 Sleep_Analysis \> 🗀 Scripts and inputs/outputs for
each step are stored in 🗀 Sleep_Analysis \> 🗀 Data. To improve clarity
about which tools and filetypes are required and used by different
programs, we are using the following icons to represent different file
extensions:

-   Text file (.csv or .txt)
-   <img src="./media/image14.png" width="15" height="15" alt="R_logo" /> RStudio (.R script)
-   <img src="./media/image13.png" width="15" height="15" alt="Excel logo" /> Excel (.xlsx worksheet)
-   <img src="./media/image15.png" width="15" height="15" alt="BORIS logo" /> BORIS Behavioral Program ([download
    here](https://boris.readthedocs.io/en/latest/))
-   <img src="./media/image16.png" width="15" height="15" alt="Neurologger Converter & Visualizer Icon"/> Neurologger Software
-   <img src="./media/image17.png" width="15" height="15" alt="EDFBrowser" /> EDF Browser ([download
    here](https://www.teuniz.net/edfbrowser/index.html))
-   <img src="./media/image19.png" width="15" height="15" alt="LabChart" /> LabChart (ADInstruments download here)
-   <img src="./media/image21.png" width="15" height="15" alt="MATLAB"/> MATLAB v2020b 
    * <img src="./media/image21.png" width="15" height="15"  alt="MATLAB" /> EEGLAB MATLAB toolbox
    for EEG research ([download here](https://eeglab.org/download/))  
    * <img src="./media/image21.png" width="15" height="15"  alt="MATLAB" /> CATS MATLAB toolbox for
    Biologging tools ([download
    here](https://github.com/wgough/CATS-Methods-Materials))
-   <img src="./media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" /> ArcGIS Pro (ESRI)
-   <img src="./media/image24.jpeg" width="15" height="15" alt="Autodesk MAYA" /> Autodesk Maya

***Automated or manual review required:***

<img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Manual review required  
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> Automated process  
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Semi-automated process

# Sleep Data Processing Pipeline

## [**STEP 00. Organize Metadata**](./00_Metadata)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Metadata <img src="./media/image13.png" width="15" height="15" alt="Excel logo" /> <img src="./media/image14.png" width="15" height="15" alt="R_logo" /> and Video Scoring <img src="./media/image15.png" width="15" height="15" alt="BORIS logo" /><img src="./media/image14.png" width="15" height="15" alt="R_logo" />

* **00.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Notes <img src="./media/image13.png" width="15" height="15" alt="Excel logo" /> & Sleep_Study_Metadata <img src="./media/image14.png" width="15" height="15" alt="R_logo" />
* **00.B.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Location Data Processing
* **00.C.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Video Scoring <img src="./media/image15.png" width="15" height="15" alt="BORIS logo" /> <img src="./media/image14.png" width="15" height="15" alt="R_logo" />

## [**STEP 01. Convert Raw Data**](http://www.evolocus.com/neurologger-3.htm)
<img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Convert Raw Data. This step uses the [Neurologger Converter & Visualizer from Evolocus LLC](http://www.evolocus.com/neurologger-3.htm)

* **01.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Download and convert data <img src="./media/image16.png" width="15" height="15" alt="Neurologger Converter & Visualizer Icon"/>
* **01.B.** <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Rearrange EDF <img src="./media/image17.png" width="15" height="15" alt="EDFBrowser" />
* **01.C.** <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Visualize Raw Data in LabChart <img src="./media/image19.png" width="15" height="15" alt="LabChart" />
* **01.D.** <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Raw Scoring <img src="./media/image19.png" width="15" height="15" alt="LabChart" />

## [**STEP 02. Process Motion Sensor Data**](./02_Processing-Motion-Env-Sensors)
<img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" />  Processing Motion & Environmental Sensors <img src="./media/image21.png" width="15" height="15" alt="MATLAB"/>

*Scripts:* `02_ProcessingMotionEnvSensors.m` & [`CATS Toolbox`](https://github.com/wgough/CATS-Methods-Materials)

> Cade, D.E., Gough, W.T., Czapanskiy, M.F. et al. Tools for integrating inertial sensor data with video bio-loggers, including estimation of animal orientation, motion, and position. *Anim Biotelemetry* **9**, 34 (2021). https://doi.org/10.1186/s40317-021-00256-w

*Input:* Raw motion & environmental sensor data

* **02.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> [Read in Metadata]()
* **02.B.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Load Motion & Environmental Data 
* **02.C.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Resample Data
* **02.D.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> MAT File setup for CATS Toolbox
* **02.E.** <img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Run [`CATS Toolbox`](https://github.com/wgough/CATS-Methods-Materials)
* **02.F.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Save Calibrated & Processed Data

## [**STEP 03. Pair Motion & Video Data (optional)**](./03_Video-Data-Analysis)
<img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Pairing Motion & Video Data <img src="./media/image14.png" width="15" height="15" alt="R_logo" />

* **03.A.** <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Video Data Synchronization (if needed) <img src="./media/image13.png" width="15" height="15" alt="Excel logo" />
* **03.B.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Pairing Video Data to Motion Data <img src="./media/image14.png" width="15" height="15" alt="R_logo" />

## [**STEP 04. Behavioral Scoring Automation**](./04_Behavioral-Scoring-Automation)
<img src="./media/image11.png" width="15" height="15" alt="Automation" />  Behavioral Scoring Automation <img src="./media/image21.png" width="15" height="15" alt="MATLAB"/>

* **04.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Main Process <img src="./media/image21.png" width="15" height="15" alt="MATLAB"/>

## [**STEP 05. ICA Processing for Electrophysiological Data**](./05_ICA-Processing)
<img src="./media/image11.png" width="15" height="15" alt="Automation" />  <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> ICA Processing for Electrophysiological Data <img src="./media/image21.png" width="15" height="15" alt="MATLAB"/>

* **05.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" />  Load data into EEGLAB <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> 
* **05.B.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Subset Data <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> 
* **05.C.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Run ICA <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> 
* **05.D.** <img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Inspect Results <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> 
* **05.E.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Apply ICA weights to whole dataset <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> 
* **05.F.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Export processed EDF <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />

## [**STEP 06. Qualitative Sleep Analysis**](./06_Sleep-Scoring)
<img src="./media/image12.png" width="15" height="15" alt="Manual icon" /> Manually scoring sleep data <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>

* **06.A.** Load data into LabChart <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>
* **06.B.** Identify scorable segments <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>
* **06.C.** Score Heart Rate (HR) Patterns <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>
* **06.D.** Score Sleep Patterns <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>

## [**STEP 07. Generate Hypnograms for Quantitative Sleep Analysis**](./07_Scored-Sleep-Analysis)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> Generating hypnograms (CSV with sleep state, respiratory state, and water code) for 5Hz, 1s, and 30s intervals. <img src="./media/image14.png" width="15" height="15" alt="R_logo" />

## [**STEP 08. 3D Track Generation & Visualization**](./08_3D-Track-Generation-and-Visualization)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> 3D Track Generation <img src="./media/image14.png" width="15" height="15" alt="RStudio logo" /> <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> <img src="./media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />

* **08.A.** <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Export Rates & Power from LabChart <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>
* **08.B.** <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Export LabChart Calculations <img src="./media/image19.png" width="15" height="15" alt="LabChart"/>
* **08.C.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Estimate Speed from Processed Data <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />
* **08.D.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Return to `CATS Toolbox` for Processing <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />
* **08.E.** <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Review Track Generation <img src="./media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />
* **08.F.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Correct GPS points & rerun (if needed) <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />

## [**STEP 09. Hypnotrack Generation & Visualization**](./09_Hypnotrack-Generation-and-Visualization)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Hypnotrack Visualizations <img src="./media/image14.png" width="15" height="15" alt="RStudio logo" /> <img src="./media/image21.png" width="15" height="15" alt="MATLAB" /> <img src="./media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />

* **09.A.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> Generate **hypnotrack** <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />
* **09.B.** <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> 3D Sleep Maps in Arc GIS <img src="./media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />
* **09.C.** <img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> 3D Sleep Animations in Maya <img src="./media/image24.jpeg" width="15" height="15" alt="Autodesk MAYA" />

## [**STEP 10. Data Aggregation & Standardization**](10_Data-Aggregation-and-Standardization)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> Reading in and standardizing depth data across datasets. <img src="./media/image21.png" width="15" height="15" alt="MATLAB" />

* **00.** Load Data
* **01.** Process Data
    * **01.A.** Depth Correction
    * **01.B.** Data Truncation
    * **01.C.** Data Alignment
    * **Inputs:** MAT files, raw CSV dive data for Sleep, Kami/Stroke,
or TDR-only recordings.

## [**STEP 11. Sleep Estimates: estimating sleep across datasets**](11_Sleep-Estimates)

## [**STEP 12. Summarize all data**](12_Summary)
<img src="./media/image11.png" width="15" height="15" alt="Automation" /> <img src="./media/image12.png" width="15" height="15" alt="Manual Icon" /> Summarizing Sleep Scoring & Restimates Model Output <img src="./media/image14.png" width="15" height="15" alt="RStudio logo" />

*Script:* [`12_Summary.Rmd`]()
