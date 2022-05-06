%% 09 Hypnotracks - Pairing sleep data with motion
% Processing Step 09.A: Read in Metadata
s = 11; % PICK A SEAL ID Recording # (see list below)

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

%% Save hypnotracks
writetable(hypnotrack,strcat(SealIDs(s),'_09_Hypnotrack_JKB_',num2str(fs),'Hz.csv'));
writetable(hypnotrack_1hz,strcat(SealIDs(s),'_09_Hypnotrack_JKB_1Hz.csv'));
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
