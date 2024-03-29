%% 09 Hypnotracks - Pairing sleep data with motion
% Processing Step 09.A: Read in Metadata
s = 9; % PICK A SEAL ID Recording # (see list below)

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



%% Read in Data

load(strcat(SealIDs(s),'_08_PRH_file_5Hzprh.mat'));
hypnogram                = readtable(strcat(SealIDs(s), '_06_Hypnogram_JKB_',num2str(fs),'Hz.csv'));
hypnogram.Seconds(:)     = round(linspace(0,height(hypnogram),height(hypnogram)))/fs;
hypnogram.DN             = datenum(hypnogram.R_Time);
hypno_SamplingInterval   = 86400*((hypnogram.DN(height(hypnogram))-hypnogram.DN(1))/height(hypnogram));

track = table(pitch(tagon), roll(tagon), head(tagon), Ptrack(tagon,1),Ptrack(tagon,2),-Ptrack(tagon,3),...
        geoPtrack(tagon,1),geoPtrack(tagon,2),geoPtrack(tagon,3),speed.manual_JKB(tagon,1),DN(tagon),...
        'VariableNames',{'pitch','roll','heading','x','y','z','geoX','geoY','Depth','speed','DN'});
track.ODBA               = odba(Aw(tagon,:), fs);
track.Seconds(:)         = round(linspace(0,height(track),height(track)))/fs;
track.DN                 = track.DN-0.04/(24*3600);
track.datetime           = datetime(datevec(track.DN));
track_SamplingInterval   = 86400*((track.DN(height(track))-track.DN(1))/height(track));

% Load corrected raw data & make format same as Adult female data
LatLongs                 = readtable(strcat(SealIDs(s), '_08_5HzgeoPtrackLatLong_manualspeed_manualGPScorrection.csv'));
LatLongs.datetime        = datetime(LatLongs.Time,'InputFormat','MM/dd/uuuu HH:mm:ss');
LatLongs.DN              = datenum(LatLongs.datetime);
LatLongs.Seconds(:)      = round(linspace(0,height(track),height(track)))/fs;
latlong_SamplingInterval = 86400*((LatLongs.DN(height(LatLongs))-LatLongs.DN(1))/height(LatLongs));

if datetime(track.datetime(1)) == datetime(hypnogram.R_Time(1)) & hypno_SamplingInterval == track_SamplingInterval
    Time_Stamps_Match   = 'TRUE - Track time and sampling interval matches Hypnogram'; else; 
    Time_Stamps_Match   = 'FALSE'; end

if datetime(LatLongs.datetime(1)) == datetime(hypnogram.R_Time(1)) & hypno_SamplingInterval == latlong_SamplingInterval
    Time_Stamps_Match   = 'TRUE - LatLong time and sampling interval matches Hypnogram'; else 
    Time_Stamps_Match   = 'FALSE'; end

hypnotrack = innerjoin(hypnogram,track,'Keys','Seconds');
hypnotrack = innerjoin(hypnotrack,LatLongs,'Keys','Seconds');

% Add 1 Hz Rates data
rates_file              = strcat(SealIDs(s),'_06_ALL_PROCESSED_Trimmed_withRATES_POWER.txt');
opts                    = detectImportOptions(rates_file);
opts.DataLines          = 10;
opts.VariableNamesLine  = 5;
% Read in data
Rates                   = readtable(rates_file,opts);
Rates.Seconds(:)        = round(linspace(0,height(Rates),height(Rates)));
Rates.Stroke_Rate(find(isnan(Rates.Stroke_Rate))) = 0;
Rates.Heart_Rate(find(isnan(Rates.Heart_Rate))) = 0;
Rates_Power = table(Rates.Seconds, Rates.Stroke_Rate, Rates.Heart_Rate, Rates.L_EEG_Delta, Rates.R_EEG_Delta, Rates.HR_VLF_Power,...
    'VariableNames',{'Seconds','Stroke_Rate','Heart_Rate','L_EEG_Delta','R_EEG_Delta','HR_VLF_Power'});

hypnotrack_1hz = innerjoin(hypnotrack,Rates_Power,'Keys','Seconds');

hypnotrack_30s = downsample(hypnotrack_1hz,30);

%% Save hypnotracks
writetable(hypnotrack,strcat(SealIDs(s),'_09_Hypnotrack_JKB_',num2str(fs),'Hz.csv'));
writetable(hypnotrack_1hz,strcat(SealIDs(s),'_09_Hypnotrack_JKB_1Hz.csv'));
writetable(hypnotrack_30s,strcat(SealIDs(s),'_09_Hypnotrack_JKB_30s.csv'));
disp('Hypnotrack generated successfully.')

gscatter(hypnotrack_1hz.Long, hypnotrack_1hz.Lat, [],'filled',hypnotrack_1hz.Water_Num)
scatter(hypnotrack_1hz.Seconds, hypnotrack_1hz.Depth, [],hypnotrack_1hz.Water_Num,'filled')
%% Get labels
% Get and number unique labels for all a category
[unique_Sleep_Labels, ~, hypnotrack.Sleep_Labels] = unique(hypnotrack.Sleep_Code, 'first');
hypnotrack.Sleep_Labels2 = strcat(num2str(hypnotrack.Sleep_Labels),'-',hypnotrack.Sleep_Code);
unique_Sleep_Labels2 = unique(hypnotrack.Sleep_Labels2);

%%

plot(hypnotrack.Seconds, hypnotrack.Sleep_Labels2)
grid on
xlabel('Time [s]')
ylabel('Label Name')
yticks(label_id)
yticklabels(label_names)



starttime = datenum('04/22/2021 16:53:59','mm/dd/yyyy HH:MM:SS');
endtime = datenum('04/22/2021 17:20:00','mm/dd/yyyy HH:MM:SS');
starttime2 = datenum('04/22/2021 16:56:00','mm/dd/yyyy HH:MM:SS');
endtime2 = datenum('04/22/2021 17:12:08','mm/dd/yyyy HH:MM:SS');

starttime3 = datenum('04/22/2021 13:49:52','mm/dd/yyyy HH:MM:SS');
endtime3 = datenum('04/22/2021 15:30:00','mm/dd/yyyy HH:MM:SS');
starttime4 = datenum('04/23/2021 14:38:00','mm/dd/yyyy HH:MM:SS');
endtime4 = datenum('04/23/2021 16:34:00','mm/dd/yyyy HH:MM:SS');
starttime5 = datenum('04/24/2021 06:20:00','mm/dd/yyyy HH:MM:SS');
endtime5 = datenum('04/24/2021 09:10:00','mm/dd/yyyy HH:MM:SS');
starttime6 = datenum('04/24/2021 13:51:00','mm/dd/yyyy HH:MM:SS');
endtime6 = datenum('04/24/2021 17:51:00','mm/dd/yyyy HH:MM:SS');

[d,a]= min(abs(hypnotrack.DN(:)-starttime3));
[e,b]= min(abs(hypnotrack.DN(:)-endtime3));
plot_hypnotrack = hypnotrack(a:b,:);
s=scatter3(plot_hypnotrack,'x','y','z','filled','ColorVariable','ODBA')
s.SizeData=10;
colorbar
caxis([0 1])
colorbar('TickLabels',label_names)

geoplot(hypnotrack_1hz.Lat,hypnotrack_1hz.Long)
gscatter(hypnotrack_1hz.Lat,hypnotrack_1hz.Long,[],'filled',hypnotrack_1hz.Simple_Sleep_Num)

% sleep on the ground
starttime=datenum('04/05/2021 15:10:00','mm/dd/yyyy HH:MM:SS');
endtime=datenum('04/05/2021 15:50:00','mm/dd/yyyy HH:MM:SS');
% sleep on the ground
starttime=datenum('04/05/2021 22:50:00','mm/dd/yyyy HH:MM:SS');
endtime=datenum('04/05/2021 23:15:00','mm/dd/yyyy HH:MM:SS');
% sleep near the shelf
starttime=datenum('04/06/2021 01:23:00','mm/dd/yyyy HH:MM:SS');
endtime=datenum('04/06/2021 03:26:00','mm/dd/yyyy HH:MM:SS');
% sleep in the open ocean
starttime=datenum('04/06/2021 12:25:00','mm/dd/yyyy HH:MM:SS');
endtime=datenum('04/06/2021 14:43:00','mm/dd/yyyy HH:MM:SS');
% sleep on the shelf
starttime=datenum('04/07/2021 00:18:00','mm/dd/yyyy HH:MM:SS');
endtime=datenum('04/07/2021 02:17:00','mm/dd/yyyy HH:MM:SS');

% Map for Sleep Num - use with caxis([0 8])
sleep_cmap = validatecolor({'#D7D7D7','#0c2c84','#225ea8','#BBA9CF','#c7e9b4','#41b6c4','#FCBE46','#FCBE46'},'multiple');
% Map for Simple Sleep Num - use with caxis([0 6])
simple_sleep_cmap = validatecolor({'#D7D7D7','#0c2c84','#225ea8','#c7e9b4','#41b6c4','#FCBE46'},'multiple');


[d,a]= min(abs(hypnotrack.DN(:)-starttime));
[e,b]= min(abs(hypnotrack.DN(:)-endtime));
plot_hypnotrack = hypnotrack(a:b,:);
scatter(plot_hypnotrack,'Seconds','geoZ','filled','ColorVariable','speed2')
caxis([0,1.75])
colorbar

[d,a]= min(abs(hypnotrack.DN(:)-starttime));
[e,b]= min(abs(hypnotrack.DN(:)-endtime));
plot_hypnotrack = hypnotrack(a:b,:);
s=scatter3(plot_hypnotrack,'x','y','z','filled','ColorVariable','speed')
s.SizeData=10;
colormap(simple_sleep_cmap)
colorbar
caxis([-0.5,6.5])
colorbar('TickLabels',{"Unscorable","Active Waking", "Quiet Waking","Drowsiness","Light SWS","Deep SWS","High HRV REM", "Low HRV REM"})

export_fig 3D_Drift_zoomed.pdf
timeofsleep = find(hypnotrack.Sleep_Color==4 | hypnotrack.Sleep_Color==3 | hypnotrack.Sleep_Color==5 | hypnotrack.Sleep_Color==6);

min(abs(hypnotrack.DN(:)-timeofsleep))
%% Make animation file

% Add 1 Hz Rates data
anim_file              = strcat(SealIDs(s),'_06_ALL_PROCESSED_Trimmed_withAnimChannels.txt');
opts                    = detectImportOptions(anim_file);
opts.DataLines          = 10;
opts.VariableNamesLine  = 5;
% Read in data
Anims                   = readtable(anim_file,opts);
Anims.Seconds(:)        = round(linspace(0,height(Anims),height(Anims)));
Anims.Stroke_Rate(find(isnan(Anims.Stroke_Rate))) = 0;
Anims.Heart_Rate(find(isnan(Anims.Heart_Rate))) = 0;
Anims_Power = table(Anims.Seconds, Anims.Stroke_Rate, Anims.Heart_Rate, Anims.L_EEG_Delta, Anims.R_EEG_Delta, Anims.HR_VLF_Power,...
    'VariableNames',{'Seconds','Stroke_Rate','Heart_Rate','L_EEG_Delta','R_EEG_Delta','HR_VLF_Power'});


%% Make higher res 100Hz ECG and EEG data

% Add 1 Hz Rates data
highresECGEEG_file              = strcat(SealIDs(s),'_06_ALL_PROCESSED_Trimmed_AnimExcerpt_ECG-EEGonly.txt');
opts                    = detectImportOptions(highresECGEEG_file);
opts.DataLines          = 10;
opts.VariableNamesLine  = 5;
% Read in data
ECGEEGs                   = readtable(highresECGEEG_file,opts);
ECGEEGs.Sample(:)        = round(linspace(0,height(ECGEEGs),height(ECGEEGs)));

plot(ECGEEGs.ECG_Raw_Ch1)
writetable(ECGEEGs,strcat(SealIDs(s),'_09_ECGEEGs_JKB_100Hz_AnimExcerpt.csv'));


hypnotrack_1Hz = readtable(strcat(SealIDs(s),'_09_Hypnotrack_JKB_1Hz.csv'));
hypnotrack_5Hz = readtable(strcat(SealIDs(s),'_09_Hypnotrack_JKB_5Hz.csv'));

load(strcat(SealIDs(s),'_08_PRH_file_5Hzprh.mat'));


offset_before_ONANIMAL = 86400*(info.JulDate('ON.ANIMAL')-info.JulDate('Start.for.EDF.Files'))
startsec = 168635 % 60763 sec into day
endsec = 171718.9 % 63847 sec into day
startsec = 60763 - offset_before_ONANIMAL
endsec = 63847 - offset_before_ONANIMAL

clear hypnotrack_excerpt
hypnotrack_excerpt = hypnotrack_1Hz(find(hypnotrack_1Hz.Seconds > startsec...
    & hypnotrack_1Hz.Seconds <= endsec),:);

plot(hypnotrack_excerpt.Depth)

writetable(hypnotrack_excerpt,strcat(SealIDs(s),'_09_Hypnotrack_JKB_1Hz_AnimExcerpt.csv'));

plot(Gw(:,3))

%%
DataPath = 'G:\My Drive\Visualization\Data';
cd(DataPath)
NewRaw = readtable('04_Sleep-at-Sea_JKB_00_test33_HypoactiveHeidi_09_Hypnotrack_JKB_1Hz_AnimExcerpt.csv');
NewRaw_10s = downsample(NewRaw,10);
writetable(NewRaw_10s,'04_Sleep-at-Sea_JKB_00_test33_HypoactiveHeidi_09_Hypnotrack_JKB_10s_AnimExcerpt.csv');

%%
% Read in hypnotrack to play with

NewRaw = readtable(strcat(SealIDs(s),'_09_Hypnotrack_JKB_1Hz.csv'));

%% CALCULATE SLEEP SPIRAL STATISTICS

% DEFINITIONS:
% Nap: consecutive segment of sleep
% Right Turn: turning right (diff(heading) between  0 and POS. pi or jumping to NEG. ~2pi
% Left Turn: turning left (diff(heading) between  0 and NEG. pi or jumping to POS. ~2pi
% Right Spin: turning right past 180 causing jump of NEG. 2pi
% Left Spin: turning left past 180 causing jump of POS. 2pi
% Spiral: two (or more) consecutive spins past 180 in the same direction
% Loop: a single loop of a spiral (between two same-direction spins past 180)

NewRaw.is_sleep = NewRaw.Simple_Sleep_Num >=4; %IF SWS or REM assign 1
NewRaw.is_REM   = NewRaw.Sleep_Num == 6 | NewRaw.Sleep_Num == 7; % if REM, assign 1

% Calculate heading change (1st derivative of heading)
NewRaw.headdiff  = [0; diff(NewRaw.heading)]; 
NewRaw.RightSpin = NewRaw.headdiff < -pi ; % a right spin past 180 South is a diff of ~ -2*pi
NewRaw.LeftSpin  = NewRaw.headdiff > pi ;  % a left spin past 180 South is a diff of ~ +2*pi

% Creating heading column that does not jump between 180 and -180 (for smooth animations)
% 1. Create cumulative sum of right turns and left turns to keep track of
% overall turning (past 180 South) to the left or right.
NewRaw.CumulTurns_Rpos = cumsum(NewRaw.RightSpin - NewRaw.LeftSpin); 
% 2. Correct heading to add 2*pi to the heading for every right spin past 180 (and
% subtract 2*pi from the heading for every left spin past 180).
NewRaw.headcorr_CumulTurns = NewRaw.heading + 2*pi*(NewRaw.CumulTurns_Rpos);
% 3. Check that that gets rid of large jumps in heading for smooth animations.
NewRaw.headcorrdiff = [diff(NewRaw.headcorr_CumulTurns); 0];
max(NewRaw.headcorrdiff)

% Defining turning left and turning right
% LEFT TURNS: either slow (< pi/s or < 180 degrees/second) turns to the left (negative)
% OR sudden jumps (> 180 deg/s) "to the right" (positive)
NewRaw.TurningLeftCriteria = ((NewRaw.headdiff <= 0 & NewRaw.headdiff >= -pi) | ...
                        (NewRaw.headdiff > pi ));
% RIGHT TURNS: either slow (< pi/s or < 180 degrees/second) turns to the right (positive)
% OR sudden jumps (> 180 deg/s) "to the left" (negative)
NewRaw.TurningRightCriteria = ((NewRaw.headdiff <= pi & NewRaw.headdiff >= 0) | ...
                        (NewRaw.headdiff < -pi ));                        

% Create table with each consecutive (OCEAN) nap                   
Nap_Criteria        = NewRaw.is_sleep & NewRaw.Water_Num ~= 0; % Looking for naps NOT on land
Naps                = table(yt_setones(Nap_Criteria),'VariableNames',{'Indices'});
Naps.Duration_s     = (Naps.Indices(:,2)-Naps.Indices(:,1));
Naps                = Naps(find(Naps.Duration_s~=0),:);

NewRaw.SleepSpinNum(:) = nan;
for d = 1:height(Naps)
    startix = Naps.Indices(d,1);
    endix = Naps.Indices(d,2);
    duration = (endix-startix)+1;
    Naps.MostlySimpleSleepNum(d) = mode(NewRaw.Simple_Sleep_Num(startix:endix)); % Most common sleep stage for the nap period
    Naps.REM_seconds(d) = sum(NewRaw.is_REM(startix:endix)); % seconds spent in REM in the nap
    Naps.REM_percentage(d) = sum(NewRaw.is_REM(startix:endix))/sum(NewRaw.is_sleep(startix:endix));  % percent of nap spent in REM
    NewRaw.standardsleepxposition(startix:endix) = NewRaw.x(startix:endix)-NewRaw.x(startix) + d*20; % zero'd x position plus offset
    NewRaw.standardsleepyposition(startix:endix) = NewRaw.y(startix:endix)-NewRaw.y(startix); % zero'd y position 
    NewRaw.standardsleepzposition(startix:endix) = NewRaw.z(startix:endix)-NewRaw.z(startix); % zero'd z position
    Naps.RightSpins(d) = sum(NewRaw.RightSpin(startix:endix)); % count number of right spins past 180 during nap
    Naps.LeftSpins(d)  = sum(NewRaw.LeftSpin(startix:endix));  % count number of left spins past 180 during nap
    Naps.OverallSpins(d) = Naps.RightSpins(d) - Naps.LeftSpins(d); % overall spins right or left
    % Creating a new column in NewRaw where 0 is no turn, positive is a right spin past 180
    % and negative is a left spin past 180
    NewRaw.SleepSpinNum(startix:endix) = cumsum(NewRaw.RightSpin(startix:endix))-cumsum(NewRaw.LeftSpin(startix:endix));
end

NewRaw.diffSleepSpinNum = [0; diff(NewRaw.SleepSpinNum)];

% FIND SPIRALS
% Criteria: Find consecutive chunks where there are no spins or spins (past 180) to
% the left. Filter results by showing only spirals with at least 2 left spins.
LeftSpirals = table(yt_setones(NewRaw.diffSleepSpinNum <= 0 & NewRaw.diffSleepSpinNum >= -1),'VariableNames',{'Indices'});
LeftSpirals.Duration_s   = (LeftSpirals.Indices(:,2)-LeftSpirals.Indices(:,1));
LeftSpirals.direction(:) = {'left'};

RightSpirals = table(yt_setones(NewRaw.diffSleepSpinNum >= 0 & NewRaw.diffSleepSpinNum <= 1),'VariableNames',{'Indices'});
RightSpirals.Duration_s   = (RightSpirals.Indices(:,2)-RightSpirals.Indices(:,1));
RightSpirals.direction(:) = {'right'};

Spirals = vertcat(LeftSpirals,RightSpirals);
Spirals.Start_Turns    = NewRaw.SleepSpinNum(Spirals.Indices(:,1));
Spirals.End_Turns      = NewRaw.SleepSpinNum(Spirals.Indices(:,2));
Spirals.totalturns     = Spirals.End_Turns - Spirals.Start_Turns;
Spirals                = Spirals(find(abs(Spirals.totalturns) > 1),:);
Spirals.Start_Depth    = NewRaw.Depth(Spirals.Indices(:,1));
Spirals.End_Depth      = NewRaw.Depth(Spirals.Indices(:,2));
Spirals.Start_SleepCode    = NewRaw.Simple_Sleep_Code(Spirals.Indices(:,1));
Spirals.End_SleepCode      = NewRaw.Simple_Sleep_Code(Spirals.Indices(:,2));

scatter3(NewRaw.standardsleepxposition, NewRaw.standardsleepyposition, NewRaw.standardsleepzposition,...
    [],NewRaw.Simple_Sleep_Num,'filled')

NewRaw.standardspiralxposition(:) = nan;
NewRaw.standardspiralyposition(:) = nan;
NewRaw.standardspiralzposition(:) = nan;

for d = 1:height(Spirals)
    startix = Spirals.Indices(d,1);
    endix = Spirals.Indices(d,2);
    duration = (endix-startix)+1;
    Spirals.MostlySimpleSleepNum(d) = mode(NewRaw.Simple_Sleep_Num(startix:endix));
    Spirals.REM_seconds(d) = sum(NewRaw.is_REM(startix:endix));
    Spirals.REM_percentage(d) = sum(NewRaw.is_REM(startix:endix))/sum(NewRaw.is_sleep(startix:endix));
    Spirals.sleep(d) = sum(NewRaw.is_sleep(startix:endix));
    NewRaw.is_SleepSpiral(startix:endix) = 1;
    NewRaw.SleepSpiralDirection(startix:endix) = {Spirals.direction(d)};
    NewRaw.SleepSpiralTurns(startix:endix) = Spirals.totalturns(d);
    NewRaw.SleepSpiralDuration_s(startix:endix) = Spirals.Duration_s(d);
    NewRaw.standardspiralxposition(startix:endix) = NewRaw.x(startix:endix)-NewRaw.x(startix) + d*20;
    NewRaw.standardspiralyposition(startix:endix) = NewRaw.y(startix:endix)-NewRaw.y(startix);
    NewRaw.standardspiralzposition(startix:endix) = NewRaw.z(startix:endix)-NewRaw.z(startix);
    %Spirals.LeftTurns(d) = sum(NewRaw.LeftSpin(startix:endix));
    %NewRaw.SleepSpirals(startix:endix) = 1;
    % Creating a new column where 0 is no turn, negative are turns to left and
    % positive are turns to the right
    %NewRaw.SpiralNum(startix:endix) = cumsum(NewRaw.RightSpin(startix:endix))-cumsum(NewRaw.LeftSpin(startix:endix));
end

scatter3(NewRaw.standardspiralxposition, NewRaw.standardspiralyposition, NewRaw.standardspiralzposition,...
    [],NewRaw.Simple_Sleep_Num,'filled')

Loop_Criteria        = NewRaw.is_SleepSpiral & NewRaw.diffSleepSpinNum == 0; % Looking for curls in sleep spirals (between areas where a spin is detected (diffSleepSpinNum==1))
Loops                = table(yt_setones(Loop_Criteria),'VariableNames',{'Indices'});
Loops.Duration_s     = (Loops.Indices(:,2)-Loops.Indices(:,1));
Loops                = Loops(find(Loops.Duration_s~=0),:);

NewRaw.standardloopxposition(:) = nan;
NewRaw.standardloopyposition(:) = nan;
NewRaw.standardloopzposition(:) = nan;

for d = 1:height(Loops)
    startix = Loops.Indices(d,1);
    endix = Loops.Indices(d,2);
    duration = (endix-startix)+1;
    Loops.MostlySimpleSleepNum(d) = mode(NewRaw.Simple_Sleep_Num(startix:endix));
    Loops.REM_seconds(d) = sum(NewRaw.is_REM(startix:endix));
    Loops.REM_percentage(d) = sum(NewRaw.is_REM(startix:endix))/sum(NewRaw.is_sleep(startix:endix));
    Loops.sleep(d) = sum(NewRaw.is_sleep(startix:endix));
    Loops.mean_speed(d) = mean(NewRaw.speed(startix:endix));
    Loops.diameter(d) = (Loops.mean_speed(d) * Loops.Duration_s(d))/pi;
    NewRaw.LoopNum(startix:endix) = d;
    NewRaw.LoopDur(startix:endix) = Loops.Duration_s(d);
    NewRaw.LoopModeSleepCode(startix:endix) = Loops.MostlySimpleSleepNum(d);
    NewRaw.standardloopxposition(startix:endix) = NewRaw.x(startix:endix)-NewRaw.x(startix);
    NewRaw.standardloopyposition(startix:endix) = NewRaw.y(startix:endix)-NewRaw.y(startix);
    NewRaw.standardloopzposition(startix:endix) = NewRaw.z(startix:endix)-NewRaw.z(startix) + d*20;
end

Loops_Only = NewRaw(find(~isnan(NewRaw.standardloopxposition)),:);
Naps_Only = NewRaw(find(~isnan(NewRaw.standardsleepxposition)),:);
Spirals_Only = NewRaw(find(~isnan(NewRaw.standardspiralxposition)),:);


scatter3(NewRaw.standardloopxposition, NewRaw.standardloopyposition, NewRaw.standardloopzposition,...
    [],NewRaw.Simple_Sleep_Num,'filled')

writetable(Spirals,strcat(SealIDs(s),'_09_Spirals_Stats.csv'));
writetable(Loops,strcat(SealIDs(s),'_09_Loops_Stats.csv'));
writetable(Loops_Only,strcat(SealIDs(s),'_09_Hypnotrack_1Hz_All_Loops.csv'));
writetable(Spirals_Only,strcat(SealIDs(s),'_09_Hypnotrack_1Hz_All_Sleep_Spirals.csv'));
writetable(Naps_Only,strcat(SealIDs(s),'_09_Hypnotrack_1Hz_All_Naps.csv'));

R_Spirals_Only = Spirals_Only(find(Spirals_Only.SleepSpiralTurns > 0),:); % FIND RIGHT SPIRALS
L_Spirals_Only = Spirals_Only(find(Spirals_Only.SleepSpiralTurns < 0),:); % FIND RIGHT SPIRALS
for d = 1:height(Spirals_Only)    
    p = plot_gaussian_ellipsoid([Spirals_Only.standardxposition(d) Spirals_Only.standardyposition(d) Spirals_Only.standardzposition(d)], [1 0 0; 0 1 0; 0 0 1],0.5);
    if Spirals_Only.Simple_Sleep_Num(d) == 6 |  Spirals_Only.Simple_Sleep_Num(d) == 6
        p.FaceColor = [0 1 0];
    elseif Spirals_Only.Simple_Sleep_Num(d) == 4 |  Spirals_Only.Simple_Sleep_Num(d) == 5
        p.FaceColor = [1 0 0];
    end
    hold on
end

p.FaceLighting = 'gouraud';
p.AmbientStrength = 0.6;
p.DiffuseStrength = 0.6;
p.SpecularStrength = 0.9;
p.SpecularExponent = 50;
p.BackFaceLighting = 'unlit';

p.FaceColor = [0 1 0];
for d = 1:height(R_Spirals_Only)   
    p = plot_gaussian_ellipsoid([R_Spirals_Only.standardxposition(d) R_Spirals_Only.standardyposition(d) R_Spirals_Only.standardzposition(d)], [1 0 0; 0 1 0; 0 0 1],0.5);
    
    hold on
end

view(90,0)
lightangle(10,30)

p.FaceLighting = 'gouraud';
p.AmbientStrength = 0.6;
shading interp
p.DiffuseStrength = 0.6;
p.SpecularStrength = 0.9;
p.SpecularExponent = 50;
p.BackFaceLighting = 'unlit';




scatter3(NewRaw.standardxposition, NewRaw.standardyposition, NewRaw.standardzposition,...
    [],NewRaw.Simple_Sleep_Num,'filled')




scatter3sph(NewRaw.standardxposition, NewRaw.standardyposition, NewRaw.standardzposition, 'size', 10); 
,...
    NewRaw.Simple_Sleep_Num,'filled')

ax1=subplot(2,1,1); set(gcf, 'Position',  [100, 100, 1800, 800]);
plot(ax1,NewRaw.Seconds, NewRaw.Depth,'Color',recording_col); hold on
scatter(ax1,NewRaw.Seconds(find(NewRaw.is_sleep)),...
            NewRaw.Depth(find(NewRaw.is_sleep)),...
            [],NewRaw.Simple_Sleep_Num(find(NewRaw.is_sleep)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
caxis([4,6])
ax1.YDir='reverse';
ylabel('Depth (m)'); xlabel('Time');
ax2=subplot(2,1,2);
plot(ax2,NewRaw.Seconds, NewRaw.heading,'Color',recording_col); hold on
plot(ax2,NewRaw.Seconds, NewRaw.headdiff,'Color',sleeping_col); hold on
plot(ax1,NewRaw.Seconds, 400*NewRaw.RightSpin,'Color',REM_col); hold on

plot(ax2,NewRaw.Seconds, NewRaw.SleepSpirals*4,'Color',sleeping_col); hold on

plot(ax2,NewRaw.Seconds, NewRaw.RightTurnCriteria,'Color',drifting_col); hold on
plot(ax2,NewRaw.Seconds, NewRaw.SpiralNum-5,'Color',REM_col); hold on
plot(ax2,NewRaw.Seconds, NewRaw.diffSpiralNum-10,'Color',drifting_col); hold on

linkaxes([ax1,ax2],'x');


scatter(ax1,NewRaw.Seconds(find(NewRaw.is_sleep)),...
            400*NewRaw.headjumps(find(NewRaw.is_sleep)),...
            [],...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);