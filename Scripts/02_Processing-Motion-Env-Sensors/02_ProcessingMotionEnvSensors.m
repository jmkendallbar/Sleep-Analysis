%% Header & Setup
% Author: Jessica Kendall-Bar
% Title: Processing Motion & Environmental Sensors
% Overview: Prepares metadata and sensor data for CATS Toolbox processing
% Dependencies: designed to be run in parallel with CATS Toolbox by Dave
% Cade & Will Gough: https://github.com/wgough/CATS-Methods-Materials

clear all

%% Processing Step 02.A: Read in Metadata
s = 13; % PICK A SEAL ID Recording # (see list below)

% Set data directory; change as necessary.
Data_path='G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data';
cd(Data_path);
PRH_Data= 'G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data\PRH_Data';

% Setup data types for metadata
opts = detectImportOptions("01_Sleep_Study_Metadata.csv");
disp([opts.VariableNames' opts.VariableTypes'])
opts = setvartype(opts,{'description','TestID','value'},'categorical');
opts = setvartype(opts,{'R_Time','Matlab_Time'},'string');
opts = setvartype(opts,{'value'},'string');

% Read in metadata exported from R script 00_Metadata.R
metadata = readtable('01_Sleep_Study_Metadata.csv',...
    'TreatAsMissing','NA','ReadRowNames',false);

% Parse datetimes to datenum format
metadata.JulDate = datenum(metadata.Matlab_Time);

% See all SealIDs
SealIDs = ["test12_Wednesday",... % Recording 1
    "test20_SnoozySuzy",...       % Recording 2
    "test21_DozyDaisy",...        % Recording 3
    "test23_AshyAshley",...       % Recording 4
    "test24_BerthaBeauty",...     % Recording 5
    "test25_ComaCourtney",...     % Recording 6
    "test26_DreamyDenise",...     % Recording 7
    "test30_ExhaustedEllie",...   % Recording 8
    "test31_FatiguedFiona",...    % Recording 9
    "test32_GoodnightGerty",...   % Recording 10
    "test33_HypoactiveHeidi",...  % Recording 11
    "test34_IndolentIzzy"...       % Recording 12
    "test35_JauntingJuliette"];

% Load in seal-specific metadata
info = metadata(find(metadata.TestID == SealIDs(s)),:);
info.Properties.RowNames = info.description;

% Storing important metadata as variables
assumedstarttime = info.JulDate('Logger.Start');
timesynctime = info.JulDate('First.Calibration.Event.Start');
lat = str2double(info.value('Deploy.Latitude'));
lon = str2double(info.value('Deploy.Longitude'));

%% Processing Step 02.B: Load Motion & Environmental data

% -- Options: --
% You can load 'Raw' Motion & Environmental data as a CSV, MATLAB
% variable or through an EDF using the steps below.

% Uncomment and use if your data is stored as a CSV:
%Raw = csvread(strcat(SealIDs(s),"_01_ALL_GyroAccelCompass.csv"));

% Uncomment and use if your data is stored as a MAT variable
%load(strcat(SealIDs(s),"_01_ALL.mat")) % Load mat file
%Raw= double(Data.GyroAccelCompass); % Store variable with Motion/Env data

% Using Motion/Env Data stored in an EDF file using EEGLAB toolbox: https://eeglab.org/download/
clear EEG % if running for a new animal, make sure EEG is cleared beforehand (as it will slow things down)
eeglab % this tracks which version of EEGLAB is being used, you may ignore it
cd(Data_path)
filename = strcat(SealIDs(s),'_01_ALL.edf');
filename_path = strcat(Data_path,'\',filename)
%% Load Data

EEG = pop_biosig(convertStringsToChars(filename_path),'channels',[1:12]); % only channels 1 through 12 (Motion/Env/Sensors)
Raw = double(EEG.data.'); % If import using EEGLAB
eeglab redraw % If you would like to check the data input

% You can also use the graphical user interface:
% File > Import data > Using EEGLAB Functions & Plugins > From EDF/EDF+/GDF
% Select un-rearranged EDF file output from Converter/Visualizer: testNN_Nickname_01_ALL.edf
% Select channels (correspond to motion/env sensor data): [1 2 3 4 5 6 7 8 9 10 11 12]
% See screenshots in Sleep_Analysis > Scripts > 00_Data_Processing_Pipeline

%% Looks good?

% Clear EEG from EDF memory
clear EEG

%% Processing Step 02.C: Resample data

% Change sampling rate from current value (250/7 Hz) to fs (integer frequency of choice)
Raw(:,13) = (1:size(Raw)); %Make new column 13 = Sample Number
Raw(:,14) = Raw(:,13)/(250/7); %Make new column 14 Time in Seconds. 250Hz/7 = 35.7143Hz

%For sample rate of 25Hz: 
fs = 25;

p = fs*7; %Desired sample rate  
q = 250; %Original sample rate (250/7)*7)

clear Out % Clear previous data if present
Out(:,1)  = resample(Raw(:,1),p,q);    % 1: Gyr1/GyrX
Out(:,2)  = resample(Raw(:,2),p,q);    % 2: Gyr2/GyrY
Out(:,3)  = resample(Raw(:,3),p,q);    % 3: Gyr3/GyrZ
Out(:,4)  = resample(Raw(:,4),p,q);    % 4: Acc1/AccX
Out(:,5)  = resample(Raw(:,5),p,q);    % 5: Acc2/AccY
Out(:,6)  = resample(Raw(:,6),p,q);    % 6: Acc3/AccZ
Out(:,7)  = resample(Raw(:,7),p,q);    % 7: Comp1/MagX
Out(:,8)  = resample(Raw(:,8),p,q);    % 8: Comp2/MagY
Out(:,9)  = resample(Raw(:,9),p,q);    % 9: Comp3/MagZ
Out(:,10)  = resample(Raw(:,10),p,q);  %10: Illumination/Light
Out(:,11)  = resample(Raw(:,11),p,q);  %11: Pressure (bars)
Out(:,12)  = resample(Raw(:,12),p,q);  %12: Temperature (C)

Out(:,13)  = resample(Raw(:,13),p,q);  %13: Resampled Sample Number
Out(:,14)  = resample(Raw(:,14),p,q);  %14: Resampled Time in Seconds
Out(:,15) = round(100*(1:size(Out))/fs) - 100/fs;  %15: New sample number
Out(:,16) = (1:size(Out))/fs - 1/fs;               %16: New Time in Seconds

%% Optional: save unprocessed data, re-sampled to CSV 
csvwrite(strcat(SealIDs(s),"_02_Resampled_MotionEnvSensors.csv"),Out);
%% Optional: read re-sampled data from CSV
%Out = readmatrix(strcat(SealIDs(s),"_02_Resampled_MotionEnvSensors.csv"));
%% Processing Step 02.D: MAT File setup for CATS Toolbox Processing

starttime = info.JulDate('Start.for.EDF.Files'); % Set to start MATLAB Date Time for beginning of record
DN = double(starttime+double(Out(:,16))/86400);

% Optional: Uncomment and run if you need to check the exact start time based on the location of a sync event
% figure(1); clf;
% fs = double(round(1/mean(diff(Out(1:20,15))))); % sample rate
% a = round((timesynctime-assumedstarttime)*24*60*60*fs); % how many seconds passed presumed start
% range = a-10*fs:a+10*fs;
% plot(range,Out(range,6));%Plot AccZ to find sync point 
% title('click on time sync point'); 
% [x,~] = ginput(1); 
% x = double(round(x));
% starttime = timesynctime-x/fs/24/60/60;
% disp(['Actual start time = ' datestr(starttime,'dd-mmm-yyyy HH:MM:SS.fff')]);

varnames = {'Date','Time','Pressure',...
    'Acc1','Acc2','Acc3',...
    'Comp1','Comp2','Comp3',...
    'Gyr1','Gyr2','Gyr3','Light','Temp'};
data = table(floor(DN),double(DN-floor(DN)),Out(:,11),Out(:,4),Out(:,5),Out(:,6),Out(:,7),...
    Out(:,8),Out(:,9),Out(:,1),Out(:,2),Out(:,3),Out(:,10),Out(:,12),...
    'VariableNames', varnames);

Adata = Out(:,4:6); % Save accelerometer data separately
Atime = double(starttime + double(Out(:,14))/24/60/60); % Save JulDate for Accelerometer separately
Afs = fs;
ODN = data.Date(1)+data.Time(1);

% Saving sampling frequencies and the fact that we used local time (UTC-7)
Hzs = struct('accHz',fs,'gyrHz',fs,'magHz',fs,'pHz',fs,'lHz',fs,'THz',fs,'UTC',-7,'datafs',fs);

% Finds restarts where blanks were added with non-sensical data.
restarts = find(data.Pressure<-100);
restartdif = diff(restarts); 
sections = [0; find(restartdif>1); length(restarts)];
restarts2 = [];
for i = 1:length(sections)-1
    restarts2 = [restarts2; (max(restarts(sections(i)+1)-25,1):min(restarts(sections(i+1))+25,length(data.Pressure)))'];
end
restarts = restarts2;

% Adds interpolated data where restarts occurred.
for i = 3:14
    data{restarts,i}= NaN;
    data{:,i} = double(fixgaps(data{:,i}));
end

% maybe add nopress manually
nopress = false;

save(strcat(PRH_Data,'/',SealIDs(s),'_RawMotionDatatruncate.mat'), 'Afs','ODN','info','Adata','data','Atime', 'Hzs', 'restarts', '-v7.3');

%% Processing Step 02.E: Run CATS Toolbox 

% Open and run MainCATSprhTool_JKB.m (lightly modified to work with seals) according to these instructions

% Start by running Section 2 (DON'T RUN SECTION 1).
% Select truncated .mat file generated in Step 02.D above.

%       (1)	Section 1: DON’T RUN.

%       (2)	Section 2: Run to load in data.
%           (a)	Select CATS data (imported mat file): testNN_Nickname_RawMotionDatatruncate.mat    
%               *Pro tip: if the file ends with ‘truncate.mat’ it will automatically assume it’s been truncated already.
%           (b)	Select header file: Customized header file according to this template.
  
%       (3)	Section 3: Run and will use truncated file uploaded in Section 2.
%           (a)	Select CATS cal file: 01_CATS_calibration_file_for_Neurologger_L2.mat 
%               (instrument-specific calibration file)

%       (4)	Section 4: Run (even without video files)

%       (5)	Section 5: Run to get tagon and tagoff times.
%           (a)	IF (like I do) you want your own tagon and tagoff times (based on previously identified 
%               ON.ANIMAL & OFF.ANIMAL times stored in ‘info’):
%               You will use the 4 lines I have added into my version of
%               MainCATSprhTool_JKB.m
%           (b)	Note: If you do this, you’ll have to say “1 = yes” in Section 6 to this question:
%           Previous cell has not been completed, continue anyway? 1 = yes, 2 = no

%       (6)	Section 6: Run pressure calibration & preliminary bench calibration to other sensors.
%           (a)	Select best option for depth correction (in-situ [2] is usually best)
%           (b)	Other figure will pop up; can close and wait for “Section 6 done”

%       (7)	Section 7: Run in-situ cals.
%           (a)	7a: Select best option for Acc calibration
%           (b)	7b: Mag spherical calibration will process

%       (8)	Section 8: Tag orientation v animal orientation
%           (a)	8a: Tag slip identification: does not apply to my data with a fixed tag location, so press Enter.
%           (b)	8b: Identify:
%               (i)     1 segment of time where animal is stationary on belly
%               (ii)	1 segment of time where animal is galumphing (~ only pitch is changing)
%               (iii)	Zoom into a dive to check the results
%                   1.	Pitch should be a high negative value during the beginning of a descent.
%                   2.	Roll should be minimal during galumphing (whereas pitch should change more).
%                   3.	Follow instructions closely to avoid losing your
%                       work! Press Enter a few times (wait for response in between).
%                   4.	Wait until “Section 8.2 done” visible and then can move on.
%           (c)	At this point, you want to save your calibrated data. 
%               Your Info MAT file generated by the CATS Toolbox should keep track of where you 
%               are so that you can go back and resume at Section 9 later.
%
%   You may continue... :)

%% Processing Step 02.F: AFTER RUNNING CATS PRH TOOL

% Must change tagon to match decimation factor used in CATS processing
tagon = false(size(data.Pressure));
[~,a] = min(abs(DNorig-info.JulDate('ON.ANIMAL')));
[~,b] = min(abs(DNorig-info.JulDate('OFF.ANIMAL')));
tagon(a:b) = true;
tagon_dec = downsample(tagon,decfac);

% To check output before saving:
ax1 = subplot(5,1,[1:2])
plot(ax1,DN,Depth) % plots entire length of processed Depth data
hold on
plot(ax1,DN(tagon_dec),Depth(tagon_dec)) % plots Depth data from ON.ANIMAL to OFF.ANIMAL - this highlighted section will be exported
ax1.YDir='reverse';
ylabel('Depth (m)');
hold on

ax2 = subplot(5,1,3)
plot(ax2, DN,pitch)
hold on
plot(ax2, DN(tagon_dec),pitch(tagon_dec))
ylabel('Pitch (rad)')

ax3 = subplot(5,1,4)
plot(ax3, DN,roll)
hold on
plot(ax3, DN(tagon_dec),roll(tagon_dec))
ylabel('Roll (rad)')

ax4 = subplot(5,1,5)
plot(ax4, DN,head)
hold on
plot(ax4, DN(tagon_dec),head(tagon_dec))
ylabel('Heading (rad)')

linkaxes([ax1,ax2,ax3,ax4],'x');

% If needed, adjust pitch by a factor of -1 to make sure that descent is
% negative (error might happen randomly based on calibration period selected)
% pitch = -pitch;

%% Save Processed Data 

ProcessedData = table(Aw(tagon_dec,1),Aw(tagon_dec,2),Aw(tagon_dec,3),Mw(tagon_dec,1),Mw(tagon_dec,2),Mw(tagon_dec,3),Gw(tagon_dec,1),Gw(tagon_dec,2),Gw(tagon_dec,3),...
'VariableNames',{'Ax','Ay','Az','Mx','My','Mz','Gx','Gy','Gz'}); %putting all processed data into table
ProcessedData.Depth = Depth(tagon_dec);
ProcessedData.pitch = pitch(tagon_dec);
ProcessedData.roll = roll(tagon_dec);
ProcessedData.heading = head(tagon_dec);
ProcessedData.temp = Temp(tagon_dec);
ProcessedData.illum = Light(tagon_dec);
ProcessedData.tagon = tagon(tagon_dec);
ProcessedData.Date_Time = datestr(DN(tagon_dec),'mm/dd/yyyy HH:MM:SS.fff');
ProcessedData.JulDateTime = DN(tagon_dec);


% Set data directory; change as necessary.
Data_path='G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data';
cd(Data_path);
PRH_Data= 'G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data\PRH_Data';

s = 13; % PICK A SEAL ID Recording # (see list below)

% See all SealIDs
SealIDs = ["test12_Wednesday",... % Recording 1
    "test20_SnoozySuzy",...       % Recording 2
    "test21_DozyDaisy",...        % Recording 3
    "test23_AshyAshley",...       % Recording 4
    "test24_BerthaBeauty",...     % Recording 5
    "test25_ComaCourtney",...     % Recording 6
    "test26_DreamyDenise",...     % Recording 7
    "test30_ExhaustedEllie",...   % Recording 8
    "test31_FatiguedFiona",...    % Recording 9
    "test32_GoodnightGerty",...   % Recording 10
    "test33_HypoactiveHeidi",...  % Recording 11
    "test34_IndolentIzzy"...       % Recording 12
    "test35_JauntingJuliette"];

writetable(ProcessedData,strcat(SealIDs(s),'_02_Calibrated_Processed_MotionEnvSensors_',num2str(decfac),'Hz_',datestr(ProcessedData.JulDateTime(1),'mmddyy-HHMMSSfff'),'.csv'));

% Save all the random variables you have open in case you need them later
save(strcat(Data_path,'/',SealIDs(s),'_02_Calibrated_Processed_MotionEnvSensors_',num2str(decfac),'Hz_',datestr(ProcessedData.JulDateTime(1),'mmddyy-HHMMSSfff'),'.mat'),...
    'ProcessedData');

%% Optional: Example of how to write data as EDF
ProcessedDataArray = table2array(ProcessedData(:,1:15)).'; 
eeglab
EEG = pop_importdata('dataformat','array','nbchan',0,'data','ProcessedDataArray','srate',5,'pnts',0,'xmin',0);
pop_writeeeg(EEG, 'G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data\FILENAME.edf', 'TYPE','EDF');
eeglab redraw

