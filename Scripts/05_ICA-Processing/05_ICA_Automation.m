%% Processing Step 05: ICA Processing for Electrophysiological Data

clear all
%% Processing Step 05.A: Read in Metadata
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

%% Processing Step 05.B: Load Electrophysiological data

% Using Motion/Env Data stored in an EDF file using EEGLAB toolbox: https://eeglab.org/download/
clear EEG % if running for a new animal, make sure EEG is cleared beforehand (as it will slow things down)
eeglab % this tracks which version of EEGLAB is being used, you may ignore it
cd(Data_path)
filename = strcat(SealIDs(s),'_01_ALL.edf');
filename_path = strcat(Data_path,'\',filename)

%% Load Data
preview_sec = [0 100]; % Only preview first 100 seconds
underwater_sleep = [172813 173527]; % Index (in seconds elapsed since start of raw file) for underwater sleep section to use for ICA

EEG = pop_biosig(convertStringsToChars(filename_path),'blockrange',preview_sec); % read in first 100 seconds of data to check channel structure

if contains(info.value('Configuration.Notes'),'upside down') 
    ephys_indices = [find(strcmp({EEG.chanlocs.labels},{'Ch #6'})),... % ECG channel  
                     find(strcmp({EEG.chanlocs.labels},{'Ch #3'})),... % LEOG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #2'})),... % REOG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #5'})),... % LEMG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #4'})),... % REMG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #7'})),... % LEEG1 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #8'})),... % REEG2 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #12'})),... % LEEG3 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #16'}))];   % REEG4 channel
    ephys_indices
    disp('Connector attached in upside-down configuration for this design iteration.')
else
    ephys_indices = [find(strcmp({EEG.chanlocs.labels},{'Ch #1'})),... % ECG channel  
                     find(strcmp({EEG.chanlocs.labels},{'Ch #2'})),... % LEOG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #3'})),... % REOG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #6'})),... % LEMG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #7'})),... % REMG channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #4'})),... % LEEG1 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #8'})),... % REEG2 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #12'})),... % LEEG3 channel
                     find(strcmp({EEG.chanlocs.labels},{'Ch #16'}))];   % REEG4 channel
    ephys_indices
    disp('Connector attached in right-side-up configuration for this design iteration.')
end

% Read all electrophysiological data into memory
EEG = pop_biosig(convertStringsToChars(filename_path),'channels',ephys_indices, 'blockrange',underwater_sleep); % read in first 100 seconds of data for channel structure
Channelnames =  [{'ECG'} {'LEOG'} {'REOG'} {'LEMG'} {'REMG'} {'LEEG1'} {'REEG2'} {'LEEG3'} {'REEG4'}];
for ii =1:EEG.nbchan
    EEG.chanlocs(ii).labels = Channelnames{ii};
end
topomap_path = strcat(Data_path,'\','00_EEG_Channel_Locations_Topomap.ced')
EEG = pop_editset(EEG, 'run', [], 'chanlocs', 'G:\\My Drive\\Dissertation Sleep\\Sleep_Analysis\\Data\\00_EEG_Channel_Locations_Topomap.ced');

eeglab redraw % If you would like to check the data input

%% RUN ICA 

EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on');
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

pop_topoplot(EEG, 0, [1:9] ,'ICA TopoMap Plots', [3 3] , 0,'electrodes','on','hcolor','none');
print('-painters','-dpng', strcat(SealIDs(s),' ICA TopoMap Plots'))
    
eegplot(EEG.icaact(:,:))

figure; set(gcf, 'Position',  [100, 100, 1400, 900]);
ax1=subplot(9,1,1);
plot(EEG.icaact(1,[1:30000]))
ax2=subplot(9,1,2);
plot(EEG.icaact(2,[1:30000]))
ax3=subplot(9,1,3);
plot(EEG.icaact(3,[1:30000]))
ax4=subplot(9,1,4);
plot(EEG.icaact(4,[1:30000]))
ax5=subplot(9,1,5);
plot(EEG.icaact(5,[1:30000]))
ax6=subplot(9,1,6);
plot(EEG.icaact(6,[1:30000]))
ax7=subplot(9,1,7);
plot(EEG.icaact(7,[1:30000]))
ax8=subplot(9,1,8);
plot(EEG.icaact(8,[1:30000]))
ax9=subplot(9,1,9);
plot(EEG.icaact(9,[1:30000]))
ylabel([ax1 ax2 ax3],['ECG' 'LEOG' 'LEMG'])


% You can also use the graphical user interface:
% File > Import data > Using EEGLAB Functions & Plugins > From EDF/EDF+/GDF
% Select un-rearranged EDF file output from Converter/Visualizer: testNN_Nickname_01_ALL.edf
% Select channels (correspond to motion/env sensor data): [1 2 3 4 5 6 7 8 9 10 11 12]
% See screenshots in Sleep_Analysis > Scripts > 00_Data_Processing_Pipeline
%% SAVING weights

TMP.icawinv = EEG.icawinv;
TMP.icasphere = EEG.icasphere;
TMP.icaweights = EEG.icaweights;
TMP.icachansind = EEG.icachansind;

clear EEG
EEG = pop_biosig(convertStringsToChars(filename_path), 'channels',ephys_indices);
EEG = pop_resample( EEG, 250); % Down sampling to 250 Hz 

EEG.icawinv = TMP.icawinv;
EEG.icasphere = TMP.icasphere;
EEG.icaweights = TMP.icaweights;
EEG.icachansind = TMP.icachansind;

% Recalculating ICA activations
EEG = eeg_checkset(EEG, 'ica');

%% CHOOSE BEST DATA

% PICK ICA COMPONENTS HERE
brain_ICA_component = 8;
heart_ICA_component = 1;
bad_components = [1 2 3 5];

%% 

% Save ICA components that represent brain or heart
raw_data = EEG.data; % storing raw data
ica_data = EEG.icaact; % storing ICA components
brain_ica_data = EEG.icaact(brain_ICA_component,:); % storing maximal brain component
heart_ica_data = EEG.icaact(heart_ICA_component,:); % storing maximal heart component

% Prune bad ICA components from data
EEG = pop_subcomp( EEG, bad_components, 0);

best_EOG = 2; % 2-LEOG or 3-REOG
best_EMG = 4; % 4-LEMG or 5-REMG
best_LEEG = 8; % 6-LEEG1 or 8-LEEG3
best_REEG = 7; % 7-REEG2 or 9-REEG4 
%[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'saveold','EDF file resampled unpruned','gui','off');
pruned_data = vertcat(EEG.data(best_EOG,:), EEG.data(best_EMG,:), EEG.data(best_LEEG,:), EEG.data(best_REEG,:)); 

megadata = vertcat(raw_data(1,:),heart_ica_data,pruned_data,...
    raw_data(best_LEEG,:),raw_data(best_REEG,:),brain_ica_data);

ON_ANIMAL_sec = 24*60*60*(info.JulDate('ON.ANIMAL')-info.JulDate('Start.for.EDF.Files'))
OFF_ANIMAL_sec = 24*60*60*(info.JulDate('OFF.ANIMAL')-info.JulDate('Start.for.EDF.Files'))
EEG = pop_importdata('dataformat','array','nbchan',9,'data','megadata','srate',250);
EEG = pop_select(EEG, 'time', [ON_ANIMAL_sec OFF_ANIMAL_sec]);
Channelnames =  [{'ECG_Raw'} {'ECG_ICA'} ...
    {strcat('EOG_Ch',int2str(best_EOG),'_Pruned')} ...
    {strcat('EMG_Ch',int2str(best_EMG),'_Pruned')} ...
    {strcat('LEEG_Ch',int2str(best_LEEG),'_Pruned')}...
    {strcat('REEG_Ch',int2str(best_REEG),'_Pruned')} ...
    {strcat('LEEG_Ch',int2str(best_LEEG),'_Raw')} ...
    {strcat('LEEG_Ch',int2str(best_LEEG),'_Raw')}...
    {'EEG_ICA'}];
for ii =1:EEG.nbchan
    EEG.chanlocs(ii).labels = Channelnames{ii};
end

%%
filename_out = strcat(SealIDs(s),'_05_ALL_PROCESSED.edf');
filename_out_path = strcat(Data_path,'\',filename_out)

pop_writeeeg(EEG, ...
    convertStringsToChars(filename_out_path), 'TYPE','EDF');



% %% KEEPING REST FOR NOW
% %%
% eeglab redraw
% 
% %% RANDOM FIGURES
% 
% figure;
% metaplottopo( EEG.data, 'plotfunc', 'newtimef', 'chanlocs', EEG.chanlocs, 'plotargs', ...
%                    {EEG.pnts, [EEG.xmin EEG.xmax]*1000, EEG.srate, [0], 'plotitc', 'off', 'ntimesout', 50, 'padratio', 2});
% 
% %% Generating subsets of data for each period of underwater rest
% %fs = 500;
% EEG = pop_select( EEG, 'time', underwater_sleep); %ECG, LEOG, REOG, LEMG, REMG, LEEG1, REEG2, LEEG3, REEG4
% EEG = pop_resample( EEG, 250); % Down sampling to 250 Hz before running ICA
% eeglab redraw % If you would like to check the data input
% 
% EEG = pop_select( EEG, 'nochannel',{'ECG','R EMG'}); %ECG, LEOG, REOG, LEMG, REMG, LEEG1, REEG2, LEEG3, REEG4
% eeglab redraw % If you would like to check the data input

