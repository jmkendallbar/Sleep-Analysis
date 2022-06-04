%% Processing step 10

%% 00.A - READ IN RAW DIVE DATA, MAT FILE, AND STROKE DATA
clear all
%parfor k=191:224
for k=191:196
    close all
    k
    % Data_path = 'C:\Users\fbar\Documents\Sleep_Analysis\Data'
    Data_path='G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data';
    cd(Data_path);
    cd('11_Restimates_Raw');
    
    Raw_Files = dir('*_raw_data*.csv');
    Raw_Filenames = sort({Raw_Files.name}).';
    
    Seals_Used = table(Raw_Filenames);
    disp(height(Seals_Used))

    % Plot Colors
    x = 255;
    recording_col =[25  44  79]/x;
    diving_col =   [47  85  151]/x;
    gliding_col =  [39  150 235]/x;
    sleeping_col = [126 202  85]/x;
    REM_col =      [252 219 100]/x;
    drifting_col =   [19  190 184]/x;
    surfacing_col =  [189 215 238]/x;
    % % Use color picker if needed
    % c = uisetcolor 

    % Find SealID and associated available files.
    SealID = extractBefore(Raw_Files(k).name,'_stroke_raw_data.csv')
    haveStrokeData = ~isempty(SealID); 
    if ~isempty(SealID)
        disp('Stroke Data File'); haveSleepData = 0; haveDiveData = 1;
        Identifier = extractBefore(Raw_Files(k).name,'_stroke_raw_data.csv')
    else
        SealID = extractBefore(Raw_Files(k).name,'_09_sleep_raw_data_Hypnotrack_JKB_1Hz.csv')
        haveSleepData = ~isempty(SealID);
        if ~isempty(SealID)
            haveSleepData = 1; haveDiveData = 0;
            TOPPID = Raw_Files(k).name(1:7); 
            Identifier = extractBefore(Raw_Files(k).name,'_09_sleep_raw_data_Hypnotrack_JKB_1Hz.csv')
            disp('Sleep Data File')
        elseif Raw_Files(k).name(end-18:end)
            TOPPID = Raw_Files(k).name(1:7); 
            haveDiveData = 1
            Identifier = extractBefore(Raw_Files(k).name,'_iknos_raw_data.csv')
            SEALID = extractAfter(Identifier,TOPPID)
            disp('Dive Data File')
        end
    end
    
    %% 00.A - LOAD DIVE DATA
    if haveDiveData & haveStrokeData==0
    % Load raw data; ignore header if has one
        fid= fopen (Raw_Files(k).name,'r');
        for i = 1:60
            mn=fgetl(fid);
            if contains(mn,'Corrected')==1 
                p=i;
                continue
            end
        end

        if p==1
            NewRaw = readtable(Raw_Files(k).name);
        else 
            opts = detectImportOptions(Raw_Files(k).name,'NumHeaderLines',p-1);
            NewRaw = readtable(Raw_Files(k).name,opts);
        end

        NewRaw.difftime = [diff(NewRaw.time)*86400; median(diff(NewRaw.time)*86400)];
        Orig_SamplingInterval = round(median(NewRaw.difftime));

        if sum(Orig_SamplingInterval == [1 4 8])
            NewRaw = downsample(NewRaw,8/Orig_SamplingInterval); % Changing resolution to 1 per 8 sec
        elseif sum(Orig_SamplingInterval == [5 10])
            NewRaw = downsample(NewRaw,10/Orig_SamplingInterval); % Changing resolution to 1 per 10 sec
        end
        
        NewRaw.difftime = [diff(NewRaw.time)*86400; median(diff(NewRaw.time)*86400)];
        SamplingInterval = round(median(NewRaw.difftime));
    end

    %% 00.B - LOAD SEAL SLEEP DATA
    if haveSleepData
        cd(Data_path);
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
            "test34_IndolentIzzy",...     % Recording 12
            "test35_JauntingJuliette"];   % Recording 13

        Identifier = extractBefore(Raw_Files(k).name,'_09_sleep_raw_data_Hypnotrack_JKB_1Hz.csv')
        Nickname = extractAfter(Identifier,'_')
        SEALID = extractBefore(Nickname,'_')
        s = find(SealIDs==SealID); % PICK A SEAL 

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

        % Load in seal-specific metadata
        info = metadata(find(metadata.TestID == string(Nickname)),:);
        info.Properties.RowNames = info.description;

        TOPPID = char(info.value('TOPP.ID'))

        cd('11_Restimates_Raw')
        % Load raw data 
        NewRaw          = readtable(strcat(Identifier,'_09_sleep_raw_data_Hypnotrack_JKB_1Hz.csv')); % load data
        NewRaw.datetime = datetime(NewRaw.R_Time,'InputFormat','uuuu-MM-dd HH:mm:ss');
        NewRaw.Sec      = NewRaw.Seconds-NewRaw.Seconds(1);
        NewRaw.time_s   = NewRaw.Seconds;
        NewRaw.time     = NewRaw.DN;
        NewRaw.difftime = [diff(NewRaw.Seconds); median(diff(NewRaw.Seconds))];
        Orig_SamplingInterval = median(NewRaw.difftime);

        % Data standardization (8 or 10s SamplingInterval & 1m resolution)
        if sum(Orig_SamplingInterval == [1 4 8])
            NewRaw = downsample(NewRaw,8/Orig_SamplingInterval); % Changing resolution to 1 per 8 sec
        elseif sum(Orig_SamplingInterval == [5 10])
            NewRaw = downsample(NewRaw,10/Orig_SamplingInterval); % Changing resolution to 1 per 10 sec
        end

        fs = 1/median(diff(NewRaw.Seconds)); % Updating samples per sec to 1
        % NewRaw.CorrectedDepth = round(2*NewRaw.Depth)/2; % ROUND TO NEAREST 0.5 m 
        NewRaw.CorrectedDepth = round(NewRaw.Depth); % ROUND TO NEAREST meter 
        NewRaw.difftime = [diff(NewRaw.Seconds); median(diff(NewRaw.Seconds))];
        SamplingInterval = median(NewRaw.difftime);
        
        cd(Data_path)
        cd('10_MAT processed files TV3 NESE') %go to mat file directory
        MATfile = dir([num2str(TOPPID) '*.mat']);
        haveMAT = ~isempty(MATfile);           

        cd(Data_path);
        cd('10_NewRaw_Track_Images')

        disp('Section 00.A Complete: Data Imported')
    end
    %% 00.C - LOAD STROKE / KAMI DATA

    if haveStrokeData

        SEALID = extractAfter(SealID,8);
        cd(Data_path);
        cd('10_STROKE data NESE')
        Stroke_Metadata = readtable('StartTime_and_SampFreq_ALL.xlsx');
        Stroke_Metadata2 = readtable('Kami-Stroke-SealsUsed.csv');
        Stroke_Metadata2 = Stroke_Metadata2(find(Stroke_Metadata2.CSV_generated ==1),:);

        StrokeRaw = readtable(strcat(SealID,'_stroke_raw_data.csv'));
        StrokeRaw.CorrectedDepth = StrokeRaw.Depth;
        StrokeRaw = StrokeRaw(~isnan(StrokeRaw.CorrectedDepth),:);
        StrokeRaw.time = fixgaps(StrokeRaw.date); % interpolates across any NaNs

        StrokeRaw.difftime = [86400*diff(StrokeRaw.time); 86400*median(diff(StrokeRaw.time))];
        Orig_SamplingInterval = round(median(StrokeRaw.difftime));
        StrokeRaw = downsample(StrokeRaw,10/Orig_SamplingInterval);
        Stroke_SamplingInterval = round(86400*median(diff(StrokeRaw.time)));

        cd('G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data\10_Raw iknos dive files NESE')

        RAWSTROKEKAMIfile=dir(['*_' num2str(SEALID) '*']);
        TOPPID = RAWSTROKEKAMIfile(1).name(1:7);

        MK10RAWfile=dir([num2str(TOPPID) '_iknos_raw_data.csv']);

        NewRaw = readtable(MK10RAWfile.name);
        SamplingInterval = round(median(diff(NewRaw.time))*86400);   

        cd(Data_path);
        cd('10_NewRaw_Track_Images')

        % Generate conditions to base analysis off of
        haveStrokeCount = sum(strcmp('COUNT',StrokeRaw.Properties.VariableNames));
        haveKami = sum(strcmp('KAMI_L',StrokeRaw.Properties.VariableNames));

        disp('Section 00.B Complete: Stroke Data Imported')
    end
    
%% Get MAT metadata

if haveStrokeData | haveDiveData
        cd(Data_path);
        cd('10_MAT processed files TV3 NESE') %go to mat file directory
        MATfile = dir([num2str(TOPPID) '*.mat']);
        haveMAT = ~isempty(MATfile);     

    %% 01.F - READ IN MAT FILE
        if haveMAT
            t = load(MATfile.name); %load mat file of current record as "t"

            SEALID = convertCharsToStrings(t.MetaData.FieldID);
            Seals_Used.SEALID(k)=convertCharsToStrings(t.MetaData.FieldID); %
            Seals_Used.TOPPID(k)=t.TOPPID; % 
            Seals_Used.FIELDID(k) = convertCharsToStrings(t.MetaData.FieldID);
            Seals_Used.Mortality_Probable(k) = isempty(t.MetaData.ArriveLoc);
            Seals_Used.Deployment_Type(k) = convertCharsToStrings(t.MetaData.DeploymentType);
            Seals_Used.Complete_TDR(k) = t.MetaData.Group.CompleteTDR;
            Seals_Used.Complete_Track(k) = t.MetaData.Group.CompleteTrack;
            Seals_Used.Season(k) = t.MetaData.Group.Season;
            Seals_Used.DepartLoc(k) = convertCharsToStrings(t.MetaData.DepartLoc);
            Seals_Used.ArriveLoc(k) = convertCharsToStrings(t.MetaData.ArriveLoc);
            Seals_Used.DepartAdipose(k) = convertCharsToStrings(t.ForagingSuccess.DeployAdipose);
            Seals_Used.ArriveAdipose(k) = convertCharsToStrings(t.ForagingSuccess.RecoverAdipose);
            Seals_Used.MassGainRate(k) = convertCharsToStrings(t.ForagingSuccess.MassGainRate);
            Seals_Used.Energy_Gain(k) = t.ForagingSuccess.EnergyGain;
            Seals_Used.Trip_Start(k) = t.MetaData.DepartDateTime;
            Seals_Used.Trip_End(k) = t.MetaData.ArriveDateTime;
            Seals_Used.Trip_Duration(k) = t.MetaData.ArriveDate-t.MetaData.DepartDate;   
            

            if t.MetaData.Group.CompleteTDR == 1 |  height(t.DiveType)>10
                Seals_Used.Total_Transit(k) = sum(t.DiveType.DiveType(:)==0);
                Seals_Used.Total_Forage(k) = sum(t.DiveType.DiveType(:)==1);
                Seals_Used.Total_Drift(k) = sum(t.DiveType.DiveType(:)==2);
                Seals_Used.Total_Benthic(k) = sum(t.DiveType.DiveType(:)==3);
                Seals_Used.Total_Dives(k) = length(t.DiveType.DiveType);
                        
                % Plot a random dive to make sure timestamps are aligned
                dix = 115; % Number of random dive
                startix = find(abs(NewRaw.time(:)-t.DiveStat.JulDate(dix)) == min(abs(NewRaw.time(:) - t.DiveStat.JulDate(dix))) );
                endix = find(abs(NewRaw.time(:)-t.DiveStat.JulDate(dix+1)) == min(abs(NewRaw.time(:) - t.DiveStat.JulDate(dix+1))) );

                figure; plot(NewRaw.time(startix:endix), NewRaw.CorrectedDepth(startix:endix),'Color',drifting_col)
                set(gca, 'YDir','reverse');
                title(strcat('Depth Data for Single Dive #',int2str(dix),' for Seal: ',SEALID, ' TOPPID:',TOPPID))
            
                if abs(NewRaw.CorrectedDepth(startix)) > 20 | abs(NewRaw.CorrectedDepth(endix)) > 20
                    if contains(Identifier,t.MetaData.TDRused.Dive2TagID) | (convertCharsToStrings(t.MetaData.TDRused.DiveTagType) ~= 'Mk9' &  convertCharsToStrings(t.MetaData.TDRused.DiveTagType) ~= 'CTD')
                        
                        cd('G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data\10_Raw iknos dive files NESE')
                        
                        if ~isempty(t.MetaData.TDRused.DiveTagID)
                            OtherTDRfile = dir([num2str(TOPPID) '*' t.MetaData.TDRused.DiveTagID '*raw_data.csv']);
                        else
                            OtherTDRfile = dir([num2str(TOPPID) '*' t.MetaData.TDRused.DiveTagType '*raw_data.csv']);
                            
                        end
                        haveOtherTDR = ~isempty(OtherTDRfile);
                        if haveOtherTDR
                            fid= fopen (OtherTDRfile(1).name,'r');
                            for i=1:60
                                mn=fgetl(fid);
                                if contains(mn,'Corrected')==1 
                                    p=i;
                                    continue
                                end
                            end

                            if p==1
                                NewRaw = readtable(OtherTDRfile(1).name);
                            else 
                                opts = detectImportOptions(OtherTDRfile(1).name,'NumHeaderLines',p-1);
                                NewRaw = readtable(OtherTDRfile(1).name,opts);
                            end
                        else
                            disp('No other TDR file found')
                        end
                        
                    else
                        disp('Error: Diving data not aligned with MAT file or depth data is far from zero-offset.')
                        Seals_Used.Dive_data_aligned_with_MAT_file(k) = 0;
                        
                        
                    end
                    % continue % WHEN IN FOR LOOP, go to next seal
                else
                    disp('Diving data aligned with MAT file.')
                    Seals_Used.Dive_data_aligned_with_MAT_file(k) = 1;
                end
                NewRaw = NewRaw(find(NewRaw.time >= t.MetaData.DepartDate & NewRaw.time <t.MetaData.ArriveDate),:);
                
                [Year, Month, Day, Hour, Min, Sec] = datevec(t.MetaData.ArriveDateTime);

                % FIX date time
                datevec(NewRaw.time(1));
                [Year1, Month1, Day1, Hour1, Min1, Sec1] = datevec(NewRaw.time);
                Year1(:) = Year;
                NewRaw.time = datenum([Year1, Month1, Day1, Hour1, Min1, Sec1]);
                disp('Dive data cropped to trip duration')
            end
            %print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_00_Dive-Example.png'))

            cd(Data_path);
            cd('10_Adult_Female_Tracks') %go to track csv directory
            CorrTrackfile = dir([num2str(TOPPID) '*foieGras_crw.csv']);
            haveCorrTrack = ~isempty(CorrTrackfile);

            if haveCorrTrack
                
                CorrTrack = readtable(CorrTrackfile.name);
                CorrTrack.DN = datenum(CorrTrack.date);
                CorrTrack.closest_JulDate = knnsearch(NewRaw.time,CorrTrack.DN);
                CorrTrack.raw_JulDate = NewRaw.time(CorrTrack.closest_JulDate);
                TLL = table(CorrTrack.lat, CorrTrack.lon, CorrTrack.raw_JulDate, 'VariableNames', {'Lat','Long','time'});
                NewRaw = outerjoin(NewRaw,TLL,'Keys','time','MergeKeys',true);
                NewRaw.Lat = fixgaps(NewRaw.Lat); NewRaw.Long = fixgaps(NewRaw.Long); 
                
            elseif height(t.Track_Best)>0
                  
                % Align and upsample track to fit NewRaw dataset
                t.Track_Best.closest_JulDate = knnsearch(NewRaw.time,t.Track_Best.JulDate);
                t.Track_Best.raw_JulDate = NewRaw.time(t.Track_Best.closest_JulDate);
                TLL = table(t.Track_Best.Lat, t.Track_Best.Long, t.Track_Best.raw_JulDate, 'VariableNames', {'Lat','Long','time'});
                NewRaw = outerjoin(NewRaw,TLL,'Keys','time','MergeKeys',true);
                NewRaw.Lat = fixgaps(NewRaw.Lat); NewRaw.Long = fixgaps(NewRaw.Long); 

            else
                Seals_Used.HaveTrackBest(k)=0; %
                NewRaw.Lat(:) = nan;
                NewRaw.Long(:) = nan;
            end
            
            cd(Data_path);
            cd('10_NewRaw_Track_Images')

            % Inspect track for this animal
            figure
            geoplot(NewRaw.Lat,NewRaw.Long,'Color',recording_col,'LineWidth',1);
            legend('Track Best')
            title(strcat('Track for Seal: ',SEALID, ' TOPPID:',TOPPID))
            print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_00_Track.png'))
            
        else
            Seals_Used.haveMAT(k) = haveMAT;
            NewRaw.Lat(:) = nan;
            NewRaw.Long(:) = nan;
        end

        disp('Section 00.C Complete: MAT File queried.')
       
    end
    %%  01.0 - CORRECT DEPTH for NEW RAW
        % Zero offset correction (skip if not needed)
    if haveDiveData | haveStrokeData
        preNewRaw              = NewRaw; % Save pre-depthcorrected data
        NewRaw.FirstDeriv      = [-diff(NewRaw.CorrectedDepth)/SamplingInterval; 0]; % slope; meters per sec
        
        % Find flat chunks
        NewRaw.is_flat_chunk   = abs(NewRaw.FirstDeriv) < 0.1; 
        Flat_Chunks0               = table(yt_setones(NewRaw.is_flat_chunk),'VariableNames',{'Indices'});
        Flat_Chunks0.Duration_s    = (Flat_Chunks0.Indices(:,2)-Flat_Chunks0.Indices(:,1))*SamplingInterval;
        Flat_Chunks0               = Flat_Chunks0(find(Flat_Chunks0.Duration_s > 100),:);
        for i = 1:height(Flat_Chunks0)
            Flat_Chunks0.Median_Depth(i) = median(NewRaw.CorrectedDepth(Flat_Chunks0.Indices(i,1):Flat_Chunks0.Indices(i,2)));
        end

        % Select likely surface intervals by filtering out median depths more than 25 m
        Flat_Chunks0               = Flat_Chunks0(find(abs(Flat_Chunks0.Median_Depth) < 25),:);

        % Place depth during likely surface intervals into a new Depth Correction column
        NewRaw.is_long_flat_chunk(:) = 0;
        NewRaw.DepthCorrection(:) = nan;
        for i = 1:height(Flat_Chunks0)
            startix = Flat_Chunks0.Indices(i,1);
            endix = Flat_Chunks0.Indices(i,2);
            NewRaw.is_long_flat_chunk(startix:endix) = 1;
            NewRaw.DepthCorrection(startix:endix) = Flat_Chunks0.Median_Depth(i);
        end

        if height(Flat_Chunks0)<100
            Seals_Used.ZOCsuccessful(k) = 0;
            disp('Suspiciously few recognized surface intervals')
            continue
        else
            Seals_Used.ZOCsuccessful(k) = 1;
            disp('Reasonable number of recognized surface intervals')
        end
        
        if height(Flat_Chunks0)>10
        % Interpolate gaps where depth correction guesses are not present
            NewRaw.DepthCorrection = fixgaps(NewRaw.DepthCorrection);
        else
            NewRaw.DepthCorrection(:) = 0;
        end
        figure; plot(NewRaw.DepthCorrection); title('NewRaw Depth Correction over time');

        %% 01.A - APPLY ZERO OFFSET CORRECTION

        Initial_SI              = median(Flat_Chunks0.Median_Depth) % PRE-Depth correction surface interval (SI) depth
        NewRaw.CorrectedDepth = NewRaw.CorrectedDepth - NewRaw.DepthCorrection;
        Corrected_SI            = median(NewRaw.CorrectedDepth(find(NewRaw.is_long_flat_chunk))) % POST-Depth correction SI depth
    end

    if haveStrokeData
        %% 01.A - CORRECT DEPTH
        % Zero offset correction (skip if not needed)

        preStrokeRaw              = StrokeRaw; % Save untruncated data
        StrokeRaw.FirstDeriv      = [-diff(StrokeRaw.CorrectedDepth)/Stroke_SamplingInterval; 0]; % slope; meters per sec

        % Find flat chunks
        StrokeRaw.is_flat_chunk   = abs(StrokeRaw.FirstDeriv) < 0.1; 
        Flat_Chunks               = table(yt_setones(StrokeRaw.is_flat_chunk),'VariableNames',{'Indices'});
        Flat_Chunks.Duration_s    = (Flat_Chunks.Indices(:,2)-Flat_Chunks.Indices(:,1))*Stroke_SamplingInterval;
        Flat_Chunks               = Flat_Chunks(find(Flat_Chunks.Duration_s > 100),:);
        for i = 1:height(Flat_Chunks)
            Flat_Chunks.Median_Depth(i) = median(StrokeRaw.CorrectedDepth(Flat_Chunks.Indices(i,1):Flat_Chunks.Indices(i,2)));
        end

        % Select likely surface intervals by filtering out median depths more than 40 m
        Flat_Chunks               = Flat_Chunks(find(abs(Flat_Chunks.Median_Depth) < 40),:);

        % Place depth during likely surface intervals into a new Depth Correction column
        StrokeRaw.is_long_flat_chunk(:) = 0;
        StrokeRaw.DepthCorrection(:) = nan;
        for i = 1:height(Flat_Chunks)
            startix = Flat_Chunks.Indices(i,1);
            endix = Flat_Chunks.Indices(i,2);
            StrokeRaw.is_long_flat_chunk(startix:endix) = 1;
            StrokeRaw.DepthCorrection(startix:endix) = Flat_Chunks.Median_Depth(i);
        end

        if height(Flat_Chunks)<100
            Seals_Used.ZOCsuccessful(k) = 0;
            disp('Suspiciously few recognized surface intervals')
            continue
        else
            Seals_Used.ZOCsuccessful(k) = 1;
            disp('Reasonable number of recognized surface intervals')
        end
        
        % Interpolate gaps where depth correction guesses are not present
        if height(Flat_Chunks)>10
            StrokeRaw.DepthCorrection = fixgaps(StrokeRaw.DepthCorrection);
        else
            StrokeRaw.DepthCorrection(:) = 0;
        end
        
        figure; plot(StrokeRaw.DepthCorrection); title('Depth Correction over time');

        %% 01.A - APPLY ZERO OFFSET CORRECTION
        Initial_SI              = median(Flat_Chunks.Median_Depth) % PRE-Depth correction surface interval (SI) depth
        StrokeRaw.CorrectedDepth = StrokeRaw.CorrectedDepth - StrokeRaw.DepthCorrection;
        Corrected_SI            = median(StrokeRaw.CorrectedDepth(find(StrokeRaw.is_long_flat_chunk))) % POST-Depth correction SI depth

        %% 01.B TRUNCATE STROKE DATA
        % Removes (sometimes very long) flat sections before and after diving data using corrected 
        % depth data and removing long flat chunks at beginning and end of the recording. Creates a 
        % list of flat chunks (combines potential dives and surface intervals because sometimes depth 
        % sensor will hang on a large positive or negative value). This step also generates a list of 
        % potential dives with which to perform data alignment (next step).

        % Find potential dives and surface intervals
        StrokeRaw.is_maybe_dive     = abs(StrokeRaw.CorrectedDepth) > 2;
        StrokeRaw.is_maybe_SI       = abs(StrokeRaw.CorrectedDepth) <=2;
        Maybe_Dives                 = table(yt_setones(StrokeRaw.is_maybe_dive),'VariableNames',{'Indices'});
        Maybe_SIs                   = table(yt_setones(StrokeRaw.is_maybe_SI),'VariableNames',{'Indices'});
        Maybe_Dives.Duration_s      = (Maybe_Dives.Indices(:,2)-Maybe_Dives.Indices(:,1))*Stroke_SamplingInterval;
        Maybe_SIs.Duration_s        = (Maybe_SIs.Indices(:,2)-Maybe_SIs.Indices(:,1))*Stroke_SamplingInterval;
        Maybe_Dives.StartDN         = StrokeRaw.time(Maybe_Dives.Indices(:,1));
        Maybe_SIs.StartDN           = StrokeRaw.time(Maybe_SIs.Indices(:,1));

        % For each potential dive, find stats including time at max depth.
        for d= 1:height(Maybe_Dives)
            startix = Maybe_Dives.Indices(d,1);
            endix = Maybe_Dives.Indices(d,2);
            StrokeRaw_excerpt = StrokeRaw(startix:endix,:);
            Maybe_Dives.Max_depth(d)   = max(StrokeRaw_excerpt.CorrectedDepth);
            Times_at_max_depth = StrokeRaw_excerpt.time(find(StrokeRaw_excerpt.CorrectedDepth == max(StrokeRaw_excerpt.CorrectedDepth)));
            if length(Times_at_max_depth) ~= 0
                Maybe_Dives.Time_max_depth(d) = Times_at_max_depth(1);
            else
                Maybe_Dives.Time_max_depth(d) = nan;
            end
        end

        % Filter out shallow dives (to use for alignment in next step).
        Deep_Dives = Maybe_Dives(find(Maybe_Dives.Max_depth>100),:);

        % For each potential SI, find stats. 
        for d= 1:height(Maybe_SIs)
            startix = Maybe_SIs.Indices(d,1);
            endix = Maybe_SIs.Indices(d,2);
            Maybe_SIs.Max_depth(d)   = max(StrokeRaw.CorrectedDepth(startix:endix));
            Maybe_SIs.Time_max_depth(d) = nan;
        end

        % Concatenate all chunks to find first and last (whether recognized as
        % a dive or a surface interval).
        All_Chunks = vertcat(Maybe_SIs,Maybe_Dives);

        % Truncate by removing the last chunks of stuff
        % Include 1000 samples before and after to avoid truncating dives
        firstix = min(All_Chunks.Indices(:,2)) - 1000; 
        if firstix < 0
            firstix =1;
        end
        lastix  = max(All_Chunks.Indices(:,1)) + 1000;
        if lastix > height(StrokeRaw)
            lastix = height(StrokeRaw);
        end

        % Inspect results
        figure
        plot(preStrokeRaw.time,preStrokeRaw.CorrectedDepth); hold on
        plot(StrokeRaw.time(firstix : lastix),StrokeRaw.CorrectedDepth(firstix : lastix))
        legend('pre-Truncate StrokeRaw','post-Truncate StrokeRaw'); set(gca, 'YDir','reverse');
        title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Inspect Truncation and Depth Correction'));

        disp('Section 01.A Complete: Inspect Truncation')

        %% 01.B - APPLY TRUNCATION
        close all

        StrokeRaw  = StrokeRaw(firstix : lastix,:); 
        disp('Section 01.B Complete: Truncation Applied.')
    end
    
    %% 01.C - TRUNCATE DIVE DATA   
    if haveStrokeData
        
        difftime = [diff(NewRaw.time)*86400; 0];
        jumps = difftime(find(difftime - mean(difftime) >10));
        maxdiffix = find((difftime - mean(difftime)) >10);
        jumpbegin = maxdiffix(find((maxdiffix-1) < (height(NewRaw)-maxdiffix))) % JUMPS NEAR BEGINNING
        jumpend = maxdiffix(find((maxdiffix-1) > (height(NewRaw)-maxdiffix))) % JUMPS AT END
        if ~isempty(jumpbegin) & ~isempty(jumpend)
            NewRaw = NewRaw(max(jumpbegin)+1:min(jumpend)-1,:);
            disp('Long time jumps at beginning and end')
        elseif ~isempty(jumpbegin) & isempty(jumpend)
            NewRaw = NewRaw(max(jumpbegin)+1:height(NewRaw),:);
            disp('Long time jumps at beginning, not at end')
        elseif isempty(jumpbegin) & ~isempty(jumpend)
            NewRaw = NewRaw(1:min(jumpend)-1,:);
            disp('Long time jumps at end, not at beginning')
        else
            disp('No long time jumps')
        end 
    end
        
    %% 01.C - ALIGN DATA
    if haveStrokeData
        
        % Generate potential dive stats for NewRaw (mk10 data) to compare to
        % StrokeRaw.
        NewRaw.is_maybe_dive         = abs(NewRaw.CorrectedDepth) > 2;
        NewRaw.is_maybe_SI           = abs(NewRaw.CorrectedDepth) <=2;
        Maybe_mk10_Dives             = table(yt_setones(NewRaw.is_maybe_dive),'VariableNames',{'Indices'});
        Maybe_mk10_Dives.Duration_s  = (Maybe_mk10_Dives.Indices(:,2)-Maybe_mk10_Dives.Indices(:,1))*SamplingInterval;
        Maybe_mk10_Dives.StartDN     = NewRaw.time(Maybe_mk10_Dives.Indices(:,1));

        for d= 1:height(Maybe_mk10_Dives)
            startix = Maybe_mk10_Dives.Indices(d,1);
            endix = Maybe_mk10_Dives.Indices(d,2);
            NewRaw_excerpt = NewRaw(startix:endix,:);
            Maybe_mk10_Dives.Max_depth(d) = max(NewRaw_excerpt.CorrectedDepth);
            Times_at_max_depth = NewRaw_excerpt.time(find(NewRaw_excerpt.CorrectedDepth == max(NewRaw_excerpt.CorrectedDepth)));

            if length(Times_at_max_depth) ~= 0
                Maybe_mk10_Dives.Time_max_depth(d)  = Times_at_max_depth(1);
            else
                Maybe_mk10_Dives.Time_max_depth(d)  = nan;
            end
        end
        Deep_mk10_Dives = Maybe_mk10_Dives(find(Maybe_mk10_Dives.Max_depth>100),:);

        Deep_Dives.rounded_Max_depth        = round(Deep_Dives.Max_depth/50)*50;
        Deep_mk10_Dives.rounded_Max_depth   = round(Deep_mk10_Dives.Max_depth/50)*50;

        ndives_stroke = round((2/3)*height(Deep_Dives)); % was 40
        ndives_mk10 = round((2/3)*height(Deep_mk10_Dives)); % was 40

        % Find deepest dive within first 50 dives
        Amax = max(Deep_Dives.Max_depth(1:ndives_stroke));
        Bmax = max(Deep_mk10_Dives.Max_depth(1:ndives_mk10));
        Time_Amax = Deep_Dives.Time_max_depth(find(Deep_Dives.Max_depth(1:ndives_stroke) == Amax));
        Time_Bmax = Deep_mk10_Dives.Time_max_depth(find(Deep_mk10_Dives.Max_depth(1:ndives_mk10) == Bmax));
        Offset = Time_Amax - Time_Bmax

        figure

        starttime = floor(NewRaw.time(1))+10;
        endtime = floor(NewRaw.time(1))+12;

        ax1 = subplot(2,1,1); set(gcf,'Position',  [100, 100, 1800, 800]);
        plot(ax1,NewRaw.time,NewRaw.CorrectedDepth,'Color',[recording_col 0.8]); hold on;
        plot(ax1,StrokeRaw.time-Offset,StrokeRaw.Depth,':','Color',[gliding_col 0.8]); hold on; 
        plot(ax1,StrokeRaw.time-Offset,StrokeRaw.CorrectedDepth,'Color',[drifting_col 0.8]); hold on;
        legend('NewRaw','StrokeRaw Depth','StrokeRaw CorrectedDepth');
        title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Inspect Alignment'));

        ax2 = subplot(2,1,2);
        plot(ax2,NewRaw.time,NewRaw.CorrectedDepth,'Color',[recording_col 0.8]); hold on;
        plot(ax2,StrokeRaw.time-Offset,StrokeRaw.Depth,':','Color',[gliding_col 0.8]); hold on; 
        plot(ax2,StrokeRaw.time-Offset,StrokeRaw.CorrectedDepth,'Color',[drifting_col 0.8]);
        xlim([starttime endtime]);
        ylim([ax1 ax2],[ -20 1500 ]);
        legend('NewRaw','StrokeRaw Depth','StrokeRaw CorrectedDepth');
        set([ax1 ax2], 'YDir','reverse');
        title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Close-up to Inspect Alignment'));

        % print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_01_StrokeRaw-NewRaw_Alignment-Check.png'))
        disp('Section 01.C Complete: Inspect Alignment.')
        
        %% 01.D - Apply Offset to Align NewRaw & StrokeRaw

        % IS COARSE ALIGNMENT GOOD?
        good_alignment = 1; % CHANGE TO ZERO IF ALIGNMENT NOT GOOD, then skip merging stroke data.

        Seals_Used.Alignment_Good(k) = good_alignment;

        if good_alignment
            StrokeRaw.oldtime = StrokeRaw.time;
            StrokeRaw.time = StrokeRaw.time - median(Offset);

            % Truncate StrokeRaw based on NewRaw
            StrokeRaw = StrokeRaw(find(StrokeRaw.time > min(NewRaw.time) & StrokeRaw.time < max(NewRaw.time)),:);
            disp('Section 01.D Complete: Alignment Applied Successfully.')
        else
            disp('Section 01.D Complete: Alignment not good enough, skip merging stroke data.')
        end

        %% 01.E - MERGE STROKE DATA
        close all

        % Find closest timestamp to StrokeRaw data in NewRaw data
        StrokeRaw.closest_JulDate = knnsearch(NewRaw.time,StrokeRaw.time);
        StrokeRaw.raw_JulDate = NewRaw.time(StrokeRaw.closest_JulDate);

        Seals_Used.haveKami(k) = haveKami;
        if haveStrokeCount & good_alignment

            StrokeRaw.Stroke_Rate = 60 * (StrokeRaw.COUNT/Orig_SamplingInterval); % Multiply by 60 to transform stroke data in strokes per original sampling interval into strokes per minute.
            
            if haveKami % merge KAMI-L data (lower bound foraging estimate)
                TSK = table(StrokeRaw.CorrectedDepth, StrokeRaw.Stroke_Rate, StrokeRaw.KAMI_L, StrokeRaw.raw_JulDate, ...
                    'VariableNames', {'Depth','Stroke_Rate','KAMI','time'});
                StrokeRaw.KAMI_L(find(StrokeRaw.KAMI_L>10)) = nan; % Values above 10 foraging attempts per 5s are removed (logger hangs at 15 sometimes)
                StrokeRaw.KAMI_L = 60 * (StrokeRaw.KAMI_L/Orig_SamplingInterval); % Get foraging attempts per minute
            else % just merge strokes
                StrokeRaw.KAMI_L(:) = nan;
                haveKami = 1; % Just to keep arrays & stats consistent
                TSK = table(StrokeRaw.CorrectedDepth, StrokeRaw.Stroke_Rate, StrokeRaw.KAMI_L, StrokeRaw.raw_JulDate, ...
                    'VariableNames', {'Depth','Stroke_Rate','KAMI','time'});
            end

            NewRaw = outerjoin(NewRaw,TSK,'Keys','time','MergeKeys',true); % Join datasets
            % NewRaw.KAMI = fixgaps(NewRaw.KAMI);
            NewRaw.Stroke_Rate = fixgaps(NewRaw.Stroke_Rate); NewRaw.Depth = fixgaps(NewRaw.Depth); % Interpolate gaps of nans from timestamps with no nearest neighbor
                
            %% Finescale Alignment
            [NewRaw_aligned StrokeRaw_aligned, D] = alignsignals(NewRaw.CorrectedDepth(50000:100000),NewRaw.Depth(50000:100000));
            
            figure
            plot(NewRaw_aligned); hold on; plot(StrokeRaw_aligned)
            set(gca, 'YDir','reverse');
            title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Testing "Align Signals" function: yields delay D=', int2str(D)));
            % print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_01_Stroking-Dive_Finescale-Alignment.png'))
            
            NewRaw.prealigned_Stroke_Rate = NewRaw.Stroke_Rate;
            NewRaw.prealigned_KAMI = NewRaw.KAMI;
            NewRaw.prealigned_Depth = NewRaw.Depth;
            
            if D < 0 % Stroke Data needs to be delayed by D
                NewRaw.Stroke_Rate(:) = [nan(abs(D),1); NewRaw.prealigned_Stroke_Rate(1:height(NewRaw)-abs(D))];
                NewRaw.Depth(:) = [nan(abs(D),1); NewRaw.prealigned_Depth(1:height(NewRaw)-abs(D))];
                NewRaw.KAMI(:) = [nan(abs(D),1); NewRaw.prealigned_KAMI(1:height(NewRaw)-abs(D))];
            elseif D > 0 % Stroke Data needs to be advanced by D
                NewRaw.Stroke_Rate(:) = [NewRaw.prealigned_Stroke_Rate(1+abs(D):height(NewRaw)); nan(abs(D),1)];
                NewRaw.Depth(:) = [NewRaw.prealigned_Depth(1+abs(D):height(NewRaw)); nan(abs(D),1)];
                NewRaw.KAMI(:) = [NewRaw.prealigned_KAMI(1+abs(D):height(NewRaw)); nan(abs(D),1)];
            end
            
            figure
            ax1 = subplot(2,1,1);
            plot(ax1,NewRaw.time,NewRaw.Stroke_Rate,'Color',[recording_col 0.8]);
            ylim([-20 100]); 
            title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Checking Stroke and Depth Alignment'));

            ax2=subplot(2,1,2); set(gcf,'Position',  [100, 100, 1800, 800]);
            plot(ax2,NewRaw.time,NewRaw.prealigned_Depth,'Color',[1 0 0 0.2]); hold on;
            plot(ax2,NewRaw.time,NewRaw.CorrectedDepth,'Color',[recording_col 0.8]); hold on; 
            plot(ax2,NewRaw.time,NewRaw.Depth,'Color',[drifting_col 0.8]);
            set(gca, 'YDir','reverse'); ylim([-20 1000])
            legend('Depth from New Raw','Depth from Stroke Raw', 'Depth pre-Fine-scale Alignment');
            linkaxes([ax1,ax2],'x'); xlim([starttime endtime]); 

            print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_01_Stroking-Dive_Finescale-Alignment-Check.png'))
            
            Seals_Used.Stroke_Data_Present(k) = 1;
            Seals_Used.Stroke_Data_Merged(k) = 1;

            disp('Section 01.E Complete: Data Merged Successfully.')

        elseif haveStrokeCount & good_alignment==0
            disp('Section 01.E Complete: Alignment not good enough, stroke data not merged.')
            Seals_Used.Stroke_Data_Present(k) = 1;
            Seals_Used.Stroke_Data_Merged(k) = 0;
        end
    end

    difftime = [diff(NewRaw.time)*86400; 0];
    jumps = difftime(find(difftime - mean(difftime) >10));
    longjumps = maxk(jumps,10);

    if max(longjumps) < (8 * 3600) % if gap in data is less than 8 hrs
        Newtimes = [NewRaw.time(1) : SamplingInterval/86400 : NewRaw.time(height(NewRaw))];
        Newtimes = round(Newtimes * 86400)/86400;
        NewRaw.time = round(NewRaw.time* 86400 ) / 86400;
        NewRaw2 = table(Newtimes.','VariableNames',{'time'});
        NewRaw = outerjoin(NewRaw,NewRaw2,'Keys','time','mergekeys',true);
        NewRaw.CorrectedDepth(:) = fixgaps(NewRaw.CorrectedDepth);
    end

    haveStrokes = sum(strcmp('Stroke_Rate',NewRaw.Properties.VariableNames));
    haveSleep = sum(strcmp('Simple_Sleep_Num',NewRaw.Properties.VariableNames));
    haveKami = sum(strcmp('KAMI',NewRaw.Properties.VariableNames));
    haveLatLong = sum(strcmp('Lat',NewRaw.Properties.VariableNames));
    haveLight = sum(strcmp('alight',NewRaw.Properties.VariableNames));
    haveTemp = sum(strcmp('etemp',NewRaw.Properties.VariableNames));
    
    if haveLight
        NewRaw.light = NewRaw.alight;
    else
        NewRaw.light(:) = nan;
    end
    
    if haveTemp
        NewRaw.temp = NewRaw.etemp;
    else
        NewRaw.temp(:) = nan;
    end
    
    cd(Data_path);
    cd('10_NewRaw');
    if haveSleepData
        NewRaw = NewRaw; % Keep all columns if sleep data
        writetable(NewRaw,strcat('SLEEP_',TOPPID,'_',SEALID,'_10_NewRaw.csv'));
        writetable(Seals_Used,strcat('SLEEP_',TOPPID,'_',SEALID,'_10_SealsUsed.csv'));
    elseif haveStrokeData
        NewRaw = NewRaw(:,{'CorrectedDepth','time','light','temp','Lat','Long','Stroke_Rate','KAMI'});
        writetable(NewRaw,strcat('STROKE_',TOPPID,'_',SEALID,'_10_NewRaw.csv'));
        writetable(Seals_Used,strcat('STROKE_',TOPPID,'_',SEALID,'_10_SealsUsed.csv'));
    elseif haveDiveData
        NewRaw = NewRaw(:,{'CorrectedDepth','time','light','temp','Lat','Long'});
        writetable(NewRaw,strcat('DIVE_',TOPPID,'_',SEALID,'_10_NewRaw.csv'));
        writetable(Seals_Used,strcat('DIVE_',TOPPID,'_',SEALID,'_10_SealsUsed.csv'));
    end

end




