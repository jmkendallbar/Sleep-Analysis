## [**STEP 03. Pair Motion & Video Data (optional)**](../03_Video-Data-Analysis)
<img src="../media/image11.png" width="15" height="15" alt="Automation" />  <img src="../media/image12.png" width="15" height="15" alt="Manual icon" /> Pairing Motion & Video Data <img src="../media/image14.png" width="15" height="15" alt="R_logo" />

* **03.A.** <img src="../media/image12.png" width="15" height="15" alt="Manual icon" /> Video Data Synchronization (if needed) <img src="../media/image13.png" width="15" height="15" alt="Excel logo" />
* **03.B.** <img src="../media/image11.png" width="15" height="15" alt="Automation" /> Pairing Video Data to Motion Data <img src="../media/image14.png" width="15" height="15" alt="R_logo" />

Output data: Pairing video scoring data to motion and environmental sensors

1. testNN_Nickname_**03_VideoMotionData_25Hz.csv** - Video scoring data paired to motion and environmental sensing data.

### <img src="../media/image11.png" width="15" height="15" alt="Automation"/> <img src="../media/image12.png" width="15" height="15" alt="Manual"/> Pairing Motion & Video Data <img src="../media/image13.png"  width="15" height="15" alt="Microsoft Excel logo" /> <img src="../media/image21.png"  width="15" height="15" />

## **03.A.** <img src="../media/image12.png" width="15" height="15" alt="Manual icon" /> Video Data Synchronization (if needed) <img src="../media/image13.png" width="15" height="15" alt="Excel logo" />

1.  **Overview:** Processing Step 03.A After having scored the video
    data, find synchronization points to adjust time points (ideally 2
    between each logger restart) to use so that video data aligns with
    motion data.

    1.  **Script:**
        <img src="../media/image12.png"  width="15" height="15" alt="Glasses Icon | Line Iconset | IconsMind" /> None; manual.

    2.  **Input/Reference:**
        <img src="../media/image105.png" width="15" height="15" alt="Video Record - Transparent Background Video Icon Png, Png Download , Transparent Png Image - PNGitem" />
        Video files
        &<img src="../media/image74.png"  width="15" height="15" alt="CSV" />
        testNN_Nickname_00_VideoScoringData.csv

    3.  **Outputs: 00_Video_SyncPoints.xlsx & 00_Video_SyncPoints.csv**
        <img src="../media/image74.png"  width="15" height="15" alt="CSV" />**  
        **See example spreadsheet below; after Restart 9 the animal
        entered the water 19 seconds later in the video than in the
        Logger Data.

<img src="../media/image106.png" style="width:6.43189in;height:3.55609in"
alt="Table Description automatically generated" />

4.  Create a simplified version of the sheet above that will be used to
    align timestamps between each restart.  
    <img src="../media/image107.png" style="width:5.5974in;height:2.69764in" alt="Graphical user interface, table, Excel Description automatically generated" />  
    For example, this sheet means that, based on the two sync points
    (offset durations 17s & 19s) between Restart 9 and 10, the logger
    was OFF and not recording for an average of 18s (in addition to
    already added default \~12.5 second correction per restart).

5.  Save this simplified sheet as a .CSV to be used in R:
    **00_Video_SyncPoints.csv**
    <img src="../media/image74.png"  width="15" height="15" alt="CSV" />

## **03.A.** <img src="../media/image12.png" width="15" height="15" alt="Manual icon" /> Video Data Synchronization (if needed) <img src="../media/image13.png" width="15" height="15" alt="Excel logo" />

2.  **Overview:** Processing Step 03.A After having scored the video
    data, find synchronization points to adjust time points (ideally 2
    between each logger restart) to use so that video data aligns with
    motion data.

    1.  **Script:**
        <img src="../media/image11.png"  width="15" height="15" alt="RPA Robotic Process Automation icon PNG and SVG Vector Free Download" />
        03_Video_and_Motion.R
        <img src="../media/image14.png" width="15" height="15" alt="RStudio logo" />

    2.  **Inputs:**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />
        **00_Video_SyncPoints.csv** &
        **testNN_Nickname_00_VideoScoringData.csv**

    3.  **Output:**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />
        **testNN_Nickname_03_VideoMotionData_1Hz.csv &
        testNN_Nickname_03_VideoMotionData_25Hz.csv (to match Motion/Env
        Sensor frequency)**

3.  **What does the script do?**

    1.  **Loads seal metadata & critical timestamps**

    2.  **Loads**
        <img src="../media/image74.png" width="15" height="15" alt="A picture containing text, case Description automatically generated" />
        **00_Video_SyncPoints.csv** &
        **testNN_Nickname_00_VideoScoringData.csv**

    3.  **Creates “Restart-ogram”** with a row for each seconds with the
        value that should be subtracted from the Video R.Time timestamp
        to align it to the motion data.

    4.  **Aligns video & motion data** at full 25Hz resolution for
        Behavioral Automation (Step 04).

    5.  **Group by 1s & 30s time-bins** to match with lower resolution
        or Sleep Scoring Data.