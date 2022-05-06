%% CUSTOM SPEED ESTIMATION for 3D Visualization
% Author: Jessica Kendall-Bar

%% Processing Step 08.B: Read in Metadata
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

%% ESTIMATE SPEED 

% Get Stroke Rate and Guestimate speed
% Use output from Processed_Trimmed LabChart file downsampled by 500 to get 1Hz with stroke
% rates_file = strcat(SealIDs(s),'_06_ALL_PROCESSED_Trimmed_withRATES_POWER_V2-SecondsNoDate.txt');
rates_file = strcat(SealIDs(s),'_01_ALL_Raw_Trimmed_withRATES_POWER.txt');

opts = detectImportOptions(rates_file);
opts.DataLines = 10;
opts.VariableNamesLine = 5;
% Read in data
Rates = readtable(rates_file,opts);
Rates.Sec(:) = round(linspace(0,height(Rates),height(Rates)));
Rates.Stroke_Rate(find(isnan(Rates.Stroke_Rate))) = 0;

% STILL HAS GAPS - COME BACK TO THIS
Rates.smoothDepth = smoothdata(Rates.Depth,'gaussian',20); % Moving average across 20 depth samples
Rates.smoothDiffDepth = [-diff(Rates.smoothDepth); 0]; % slope; meters per sec
Rates.smoothSecondDeriv = [diff(Rates.smoothDiffDepth); 0];
vertspeed = Rates.smoothDiffDepth;
diagspeed = vertspeed(:) ./ sind(Rates.pitch(:));

% These are assumed values based on previous studies where velocity was measured.
minstrokerate = 10; % Assume minimum stroke rate of 10 strokes per minute for swimming to contribute to forward speed.
maxstrokerate = 80; % Assume maximum stroke rate of 80 strokes per minute (associate this and above with max speed).
maxswimspeed = 2; % Assume that max swimming speed is 2 m/s when stroking at >= maxstrokerate.
minswimspeed = 1; % Assume that min swimming speed is 1 m/s when stroking at <= minstrokerate.
driftspeed = 0.2; % Assume forward speed of 0.2 m/s during drift segments.
bottomspeed = 0; % Speed when animal is on the bottom, not moving.

Rates.speed0 = NaN(height(Rates),1);

% IF Swimming:
swimming = Rates.Stroke_Rate <= maxstrokerate & Rates.Stroke_Rate >= minstrokerate;
% Set maxstrokerate (and above) to maxswimspeed
Rates.speed0(find(Rates.Stroke_Rate >= maxstrokerate)) = maxswimspeed;
% Map maxstrokerate to maxswimspeed and minstrokerate to minswimspeed.
Rates.speed0(find(swimming)) = ((Rates.Stroke_Rate(find(swimming)) - minstrokerate) ...
             * (maxswimspeed - minswimspeed) / (maxstrokerate - minstrokerate)) + minswimspeed;
% Mapping maxstrokerate of 80 to 2 m/s and minstrokerate of 1 to 1 m/s
% ((oldValue - oldMin) * newRange / oldRange) + newMin
         
% IF Gliding:
gliding = Rates.Stroke_Rate <= minstrokerate;
depth_threshold = abs(Rates.smoothDepth) >= 5; % Can't be on the surface
% If gliding up or down upon ascent or descent (with high pitch), make speed = 0.8 m/s
Rates.speed0(find(gliding & abs(Rates.pitch)>40 & abs(Rates.roll)<150 & depth_threshold)) = 0.8;
Rates.speed0(find(gliding & abs(Rates.pitch)<40 & abs(Rates.roll)<150 & depth_threshold)) = 0.8;
% If drifting upside down (causing pitch to be small and positive), make speed 0.2 m/s.
drift_threshold = abs(Rates.smoothDiffDepth) <= 3 & abs(Rates.smoothDiffDepth) >= 0.1; % change from 0.5 for Heidi
bottom_threshold = abs(Rates.smoothDiffDepth) <= 0.1;
Rates.speed0(find(gliding & abs(Rates.pitch)<40 & abs(Rates.roll)>150 & drift_threshold & depth_threshold)) = 0.2;
Rates.speed0(find(gliding & abs(Rates.pitch)<20 & bottom_threshold & depth_threshold)) = 0;

% IF on land:
% Use shallow depth and low pitch to find periods on land (usually high
% pitch in the water at surface)
land_threshold = abs(Rates.smoothDepth) <= 5 & abs(Rates.pitch)<20;
% If no galumphs are detected, set speed to zero.
Rates.speed0(find(gliding & land_threshold)) = 0;
% IF GALUMPHING set max speed:
galumphing = swimming & land_threshold;

% 0.12–0.71 body lengths s−1 - We are using average standard (straight) body length of 172 
bodylength = str2double(info.value('Standard.Length'))/100; % Body length in meters
maxgalumphspeed = 0.12*bodylength; % VALUES FROM https://journals.biologists.com/jeb/article/221/18/jeb180117/19448/Terrestrial-locomotion-of-the-northern-elephant
mingalumphspeed = 0.71*bodylength; % VALUES FROM https://journals.biologists.com/jeb/article/221/18/jeb180117/19448/Terrestrial-locomotion-of-the-northern-elephant

% Set maxstrokerate (and above) to maxswimspeed
Rates.speed0(find(land_threshold & Rates.Stroke_Rate >= maxstrokerate)) = maxgalumphspeed;
% Map maxstrokerate to maxswimspeed and minstrokerate to minswimspeed.
Rates.speed0(find(galumphing)) = ((Rates.Stroke_Rate(find(galumphing)) - minstrokerate) ...
             * (maxgalumphspeed - mingalumphspeed) / (maxstrokerate - minstrokerate)) + mingalumphspeed;

% Adds interpolated speed estimate where no good estimate parameter exists.
Rates.speed0 = double(fixgaps(Rates.speed0));
Rates.smoothspeed0 = smoothdata(Rates.speed0,'gaussian',50);
% Rates.smoothspeed0 = sgolayfilt(Rates.speed0,5,21); Introduces artifacts
% for estimates with abrupt shifts

ax1=subplot(5,1,[1:2]);
plot(ax1,Rates.Sec, Rates.Depth);
ax1.YDir='reverse';
title([SealIDs(s) 'Speed Plots']);
ylabel('Depth (m)');
xlabel('Seconds');
hold on

ax2=subplot(5,1,3);
plot(ax2,Rates.Sec, Rates.speed0);
ylabel('Speed0');
xlabel('Seconds');
hold on

ax2=subplot(5,1,3);
plot(ax2,Rates.Sec, Rates.smoothspeed0);
ylabel('Speed0');
xlabel('Seconds');
hold on

ax3=subplot(5,1,4);
plot(ax3,Rates.Sec, Rates.pitch, 'Color', [1 0 0 0.3])
ylabel('Degrees');
hold on
plot(ax3,Rates.Sec, Rates.roll, 'Color', [0 1 0 0.3])

ax4=subplot(5,1,5);
plot(ax4,Rates.Sec, Rates.Stroke_Rate, 'Color', [0 0.7 0.25 0.3])
ylabel('Stroke Rate (spm)');

legend(ax2,'Speed Estimate','Smoothed Speed Estimate')
legend(ax3,'Pitch','Roll')

ylim(ax2, [0 2.5])
ylim(ax4, [-10 max(Rates.Stroke_Rate)])
linkaxes([ax1,ax2,ax3,ax4],'x');



%% LINE UP DATA WITH CATS TOOLBOX DATA 
% BEFORE LINKING THESE UP - make sure the beginning and end of your trimmed Rates file is consistent with
% ON.ANIMAL and OFF.ANIMAL tagon times - will use these to match data back
% to prh file
fs = 5;
speed_5hz = interp(Rates.smoothspeed0,fs);
plot(speed_5hz) % how to line up with DN? 
manual_JKB = NaN(height(tagon),1);
manual_JKB(tagon) = speed_5hz(1:height(tagon(tagon)));

if ~exist('speed','var') 
    speed = table(manual_JKB);
else
    speed.manual_JKB(:) = manual_JKB;
end

% Return to CATS Toolbox & run step 13 (once you also have GPS data).