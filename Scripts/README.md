# Seal Sleep Analysis
 Code for my dissertation research on sleep in seals.

## Data Processing Pipeline:

### 00 Metadata: manually entered
Input data:

1. **00_Sleep_Study_Metadata.xlsx** - Metadata for all studies
2. **00_Ethogram.xlsx** - Ethograms
3. testNN_Nickname_**00_Notes.xlsx** - Original data entered in Excel
4. testNN_Nickname_**00_VideoScoringData** - Video Scoring Data

Scripts:

1. **00_Metadata.Rmd** - R code to parse metadata and format

Output Data: 

1. **01_Sleep_Study_Metadata.csv** - Long format metadata for all animals
2. testNN_Nickname_**00_Metadata.csv** - Metadata for single animal

### 01 Raw data: data from Neurologger and converter/visualizer

Data:

1. testNN_Nickname_**01_ALL.dat** - Binary data straight from the tag
2. testNN_Nickname_**01_ALL.mat** - Converted MATLAB file with all data
3. testNN_Nickname_**01_ALL.edf** - Converted EDF file with all data
4. testNN_Nickname_**01_GyroAccelCompass.csv** - Inertial Motion Sensor and Environmental Sensor Data
5. testNN_Nickname_**01_ResetDelaysTimeDuration.csv** - Logger restart timepoints and durations
6. testNN_Nickname_**01_MK10_ID.wch** - MK10 Tag data (only for wild animals)
7. testNN_Nickname_**01_MK10_ID_decoded.csv** - MK10 Decoded Tag data (only for wild animals)

### 02 Inertial Motion Sensor Processing

Scripts:

1. **02_ProcessingMotionEnvSensors.m** - Applying calibration to get pitch, roll, heading, and ODBA

Output data: Inertial Motion Sensor (Accel, Gyro, Compass) and Environmental Sensor Data (Pressure, Temperature, Illumination)
with processed IMU data (pitch, roll, heading, position, ODBA, etc)

1. testNN_Nickname_**02_Calibrated_Processed_MotionEnvSensors_10Hz.csv** - Calibrated and processed at 10Hz
2. testNN_Nickname_**02_Calibrated_Processed_MotionEnvSensors_10Hz.mat** - Calibrated and processed at 10Hz
3. testNN_Nickname_**02_Calibrated_Processed_MotionEnvSensors_25Hz.csv** - Calibrated and processed at 25Hz
4. testNN_Nickname_**02_Calibrated_Processed_MotionEnvSensors_25Hz.mat** - Calibrated and processed at 25Hz

### 03 Behavior and Video: Pairing Motion and Environmental Sensor Data to Video Scoring Data

Scripts:

1. **03_Motion Data and Video Analysis.Rmd**

Output data: Pairing video scoring data to motion and environmental sensors

1. testNN_Nickname_**03_VideoMotionData_25Hz.csv** - Video scoring data paired to motion and environmental sensing data.

### 04 Behavioral Analysis and Automation

Script:

1. **04_Behavioral_Scoring_Automation.py**

### 05 Sleep Scoring

Scripts:

1. **05_EEG_PreProcessing.py** - Script to compile, clean, discretize, and process EDF files. 
2. **05_MakeEEGLABfile.m** - Converts MATLAB file to EEGLAB file for processing (resamples and reshapes .mat array and labels channels)
3. **05_ICA_Automation.m** - This script automates running ICA on subsamples of EEG data.
4. **05_ICA_Model_Runs.xlsx** - Use this spreadsheet to keep track of outputs of ICA Model Runs.

Input data: 

1. testNN_Nickname_**Processed_ALL.edf** - NEED TO make these still
2. testNN_Nickname_**05_Scoring_Land_ALL.edf** - Processed EDFs for sleep scoring
3. testNN_Nickname_**05_Scoring_Water_ALL.edf** - 

Scoring performed in LabChart

Output data:

1. testNN_Nickname_**05_Scoring_ALL.adicht** - Scored data in LabChart
2. testNN_Nickname_ 

### 06 Quantitative Sleep Analysis

Scripts:

1. **06_Sleep_Scoring_Figures.py** - PYTHON Script to make figures with data scored in LabChart.
2. **06_Hypnograms.Rmd** - R script to create hypnogram and related figures.
3. **06_Sleep_Scoring_Figures.Rmd** - R script to create sleep summary plots comparing stages in R.

### 07 Sleep Scoring Automation

Scripts:

1. **staging.py** - staging script to alter from YASA in yasa_seals directory
