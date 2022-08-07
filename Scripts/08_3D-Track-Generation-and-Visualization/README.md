# [**STEP 08. 3D Track Generation & Visualization**](../08_3D-Track-Generation-and-Visualization)
<img src="../media/image11.png" width="15" height="15" alt="Automation" /> <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> 3D Track Generation <img src="../media/image14.png" width="15" height="15" alt="RStudio logo" /> <img src="../media/image21.png" width="15" height="15" alt="MATLAB" /> <img src="../media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />

* **08.A.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Export Rates & Power from LabChart <img src="../media/image19.png" width="15" height="15" alt="LabChart"/>
* **08.B.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Export LabChart Calculations <img src="../media/image19.png" width="15" height="15" alt="LabChart"/>
* **08.C.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Estimate Speed from Processed Data <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />
* **08.D.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Return to `CATS Toolbox` for Processing <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />
* **08.E.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Review Track Generation <img src="../media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />
* **08.F.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Correct GPS points & rerun (if needed) <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />

### <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" /><img src="../media/image12.png" width="15" height="15" alt="Glasses Icon | Line Iconset | IconsMind" /> 3D Track Generation <img src="../media/image14.png" width="15" height="15" alt="RStudio logo" /> <img src="../media/image21.png" width="15" height="15" /> <img src="../media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />

## **08.A.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Export Rates & Power from LabChart <img src="../media/image19.png" width="15" height="15" alt="LabChart"/>

1.  **Overview:** Export 1Hz data on Heart Rate, Stroke Rate, and Delta
    EEG Power (L & R) data exported from LabChart.

    1.  **Script:**
        <img src="../media/image12.png" width="15" height="15" alt="Glasses Icon | Line Iconset | IconsMind" /> None; manual.

    2.  **Input:** **testNN_Nickname_05_ALL_PROCESSED_Trimmed.**adicht

    3.  **Output:
        testNN_Nickname_06_ALL_PROCESSED_Trimmed_withRATES_POWER.txt**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />**  
        **Exported LabChart Text File (downsampled 500X from original)
        <img src="../media/image21.png" width="15" height="15" />

2.  **Verify ‘Heart_Rate’ & ‘Stroke_Rate’ channels are properly named
    (after ‘Pressure’)**

3.  **Create new channels:**

    1.  **L_EEG_Delta** (best L EEG channel spectral power calculation
        between 4 Hz & 0.5Hz)

    2.  **R_EEG_Delta** (best R EEG channel spectral power calculation
        between 4 Hz & 0.5Hz)

    3.  **HR_VLF_Power** (spectral power calculation between 0.005 Hz &
        0 Hz)

<img src="../media/image115.png" style="width:6.9806in;height:0.90539in"
alt="A screenshot of a computer Description automatically generated" />

4.  **HR_VLF_Power** Spectrum settings:  
    <img src="../media/image116.png" style="width:2.48849in;height:2.89975in" alt="Graphical user interface Description automatically generated" />

5.  **EEG_Delta** Spectrum settings:  
    <img src="../media/image117.png" style="width:2.4651in;height:2.86785in" alt="Graphical user interface, application Description automatically generated" />

<!-- -->  

6.  **Export as LabChart text file with these settings (will save first
    column as Time of day in seconds):  
    **<img src="../media/image118.png" style="width:2.84029in;height:2.35383in" alt="Graphical user interface, application, Word Description automatically generated" /><img src="../media/image119.png" width="15" height="15"/>

## **08.B.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Export LabChart Calculations <img src="../media/image19.png" width="15" height="15" alt="LabChart"/>

7.  Open data pad 

8.  Delete all existing information from data pad

9.  Make sure that the best EEG channel is chosen for the EEG analysis

10.  Make the following changes/additions in Columns X, Y, Z

> <img src="../media/image120.png"/><img src="../media/image121.png" alt="Graphical user interface, application, table, Excel Description automatically generated" /><img src="../media/image122.png" />

1.  Change the Time Mode (by right-clicking in the timeline on the
    bottom of the Chart View in LabChart) to **“Show as time of day”**
    and **uncheck** Show time as seconds.

> <img src="../media/image123.png" style="width:1.72727in;height:1.88232in" alt="Graphical user interface Description automatically generated" />

10. Click on **Multiple Add to Data Pad** keeping the following settings
    –

> <img src="../media/image124.png" style="width:2.11549in;height:1.40625in" alt="Graphical user interface, application, table, Excel Description automatically generated" />

11. Wait while it generates the data

12. Copy paste all generated data onto a blank Excel file

13. Add columns for Seal_ID and Date_Time, format timestamps to
    ‘mm/dd/yyyy hh:mm:ss’

14. Save your data as:

## **08.C.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Estimate Speed from Processed Data <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />

1.  **Overview:** Use Processing Step 08.B in **08_Speed-Estimation.m**
    <img src="../media/image21.png" width="15" height="15" /> to estimate speed
    manually using 1Hz Stroke Rate data exported from LabChart and
    pitch, roll, heading.

    1.  **Script:**
        <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        **08_Speed_Estimation.m** <img src="../media/image21.png" width="15" height="15" />

    2.  **Input:**
        **testNN_Nickname_06_ALL_PROCESSED_Trimmed_withRATES_POWER.txt**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />**  
        **Exported LabChart Text File (downsampled 500X from original)
        <img src="../media/image21.png" width="15" height="15" />

    3.  **Outputs:** Speed vector to be used in CATS Processing

2.  Instructions:

## **08.D.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Return to `CATS Toolbox` for Processing <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />

1.  **Overview:** Processing Step 02.H Return to Section 9 in CATS
    toolbox (should be able to re-import ‘…truncate.mat’ file and it
    will recognize your progress based on the ‘…Info.mat’ file.

    1.  **Script:**
        <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        **MainCATSprhTool_JKB.m**

    2.  **Input:** Previous PRH .mat file, additional manual speed
        variable, and GPS hits spreadsheet
        <img src="../media/image21.png" width="15" height="15" />

    3.  **Outputs:** Pseudotrack & Geo-referenced pseudotrack based on
        speed
        estimates<img src="../media/image12.png" width="15" height="15" alt="Glasses Icon | Line Iconset | IconsMind" />

## **08.E.** <img src="../media/image12.png" width="15" height="15" alt="Manual Icon" /> Review Track Generation <img src="../media/image23.jpeg" width="15" height="15" alt="ArcGIS logo" />

2.  **Overview:** Manual inspection of the generated tracks in ArcGIS
    and/or Matlab. Remove and/or adjust inaccurate GPS points (making
    notes of any manipulation/justification in the “Notes” column).

    1.  **Script:**
        <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        **MainCATSprhTool_JKB.m** <img src="../media/image21.png"  width="15" height="15" /> **& Review in Google
        Maps or ArcGIS**

    2.  **Input:** testNN_Nickname_GPShits.xlsx
        <img src="../media/image13.png" width="15" height="15" alt="Microsoft Excel logo" /> &
        testNN_Nickname_08_5HzgeoPtrackLatLong.csv
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />

    3.  **Outputs:** testNN_Nickname_GPShits**\_UserModified**.xlsx
        <img src="../media/image13.png" width="15" height="15" alt="Microsoft Excel logo" />

3.  **Instructions:**

    1.  Open generated track
        **testNN_Nickname_08_5HzgeoPtrackLatLong.csv** in ArcGIS Pro
        (drag & drop CSV into Contents panel).

    2.  Convert **XY Point Data**:  
        <img src="../media/image125.png" style="width:2.89494in;height:3.03504in" alt="Graphical user interface, text, application, email Description automatically generated" />

    3.  **Drag & drop geoPtrack CSV** from Contents panel to “Input
        Table” field.  
        <img src="../media/image126.png" style="width:2.9527in;height:2.33207in" alt="Graphical user interface, text, application, email Description automatically generated" />

    4.  Press “Run”

    5.  Click on a point to see what time it was recorded at. Use ArcGIS
        or Google Maps to re-associate that point in time to a more
        accurate GPS point based on animal observations or landmasses
        (nearest coastal interface for inland points).

##  **08.F.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Correct GPS points & rerun (if needed) <img src="../media/image21.png" width="15" height="15" alt="MATLAB" />

4.  **Overview:** Re-run section 13b and import corrected GPS points to
    re-generate track.

    1.  **Script:**
        <img src="../media/image11.png" width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        **MainCATSprhTool_JKB.m**<img src="../media/image21.png" width="15" height="15" />

    2.  **Input:** Previous PRH .mat file, additional manual speed
        variable, and corrected GPS hits spreadsheet:
        testNN_Nickname_GPShits**\_UserModified**.xlsx
        <img src="../media/image13.png" width="15" height="15" alt="Microsoft Excel logo" />

    3.  **Outputs:
        testNN_Nickname_08_5HzgeoPtrackLatLong_manualspeed_manualGPScorrection.csv**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />

> Pseudotrack & Geo-referenced pseudotrack based on speed estimates

