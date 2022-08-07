clear all

%for k=381:406 % 406 total
%%
for k=390:390 %parfor k=406:406
    %% 00.A Load Data & Metadata
    close all
    
    Data_path='G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data';
    cd(Data_path);
    cd('10_NewRaw');
    
    Raw_Files = dir('*_NewRaw.csv');
    Raw_Filenames = sort({Raw_Files.name}).';

    k
    
    % Load colors for plots
    x = 255;
    recording_col =[25  44  79]/x;
    diving_col =   [47  85  151]/x;
    gliding_col =  [39  150 235]/x;
    sleeping_col = [126 202  85]/x;
    REM_col =      [252 219 100]/x;
    drifting_col =    [19  190 184]/x;
    surfacing_col =  [189 215 238]/x;
    % % Use color picker if needed
    % c = uisetcolor 

    % Find metadata in filename
    Identifier = extractBefore(Raw_Files(k).name,'_10_NewRaw.csv');
    Type = extractBefore(Identifier,'_');
    TripID = extractAfter(Identifier,'_');
    TOPPID = extractBefore(TripID,'_');
    SEALID = extractAfter(TripID,'_');

    if string(Type) == 'DIVE'
        haveDiveData = 1; haveSleepData = 0; haveStrokeData = 0;
        disp(strcat('Dive Data File loaded for : ',TripID))
    elseif string(Type) == 'STROKE'
        haveDiveData = 0; haveSleepData = 0; haveStrokeData = 1;
        disp(strcat('Stroke Data File loaded for : ',TripID))
    elseif string(Type) == 'SLEEP'
        haveDiveData = 0; haveSleepData = 1; haveStrokeData = 0;
        disp(strcat('Sleep Data File loaded for : ',TripID))
    end

    disp('01.A complete: Metadata loaded.')

    Seals_Used = readtable(strcat(Identifier,'_10_SealsUsed.csv'));
    TOPPIDs = table2array(Seals_Used(:,1));
    Seals_Used = Seals_Used(find(Seals_Used.TOPPID == str2num(TOPPID)),:);
    NewRaw = readtable(strcat(Identifier,'_10_NewRaw.csv'));
    
    cd(Data_path);
    cd('11_Sleep-Estimates_Output');

    %% 00.B - Query columns in data table
    % Check for information on strokes, sleep state, foraging, Lat/Long etc
    haveStrokes = sum(strcmp('Stroke_Rate',NewRaw.Properties.VariableNames));
    haveSleep = sum(strcmp('Simple_Sleep_Num',NewRaw.Properties.VariableNames));
    haveKami = sum(strcmp('KAMI',NewRaw.Properties.VariableNames));
    haveLatLong = sum(strcmp('Lat',NewRaw.Properties.VariableNames));
    haveLight = sum(strcmp('alight',NewRaw.Properties.VariableNames));
    
    % Get sampling resolution
    NewRaw.sampleround = [0; round(abs(diff(NewRaw.CorrectedDepth))*100)/100];
    SampleRes = mink(unique(NewRaw.sampleround),10);
    SamplingResolution = SampleRes(2)
    
    % Get sampling interval
    NewRaw.difftime = [diff(NewRaw.time)*86400; median(diff(NewRaw.time)*86400)];
    SamplingInterval = round(median(NewRaw.difftime));

    Seals_Used.haveStrokes(k) = haveStrokes;
    Seals_Used.haveSleep(k) = haveSleep;
    Seals_Used.haveLatLong(k) = haveLatLong;
    Seals_Used.haveLight(k) = haveLight;
    Seals_Used.SamplingResolution(k) = SamplingResolution;
    Seals_Used.SamplingInterval(k) = SamplingInterval;

    disp('01.B Complete: Raw data loaded & queried successfully')

    %% 01.A - Find dives
    % Set thresholds & Find dives

    % First derivative of dive profile to get rate. divided by sampling rate to get into seconds
    NewRaw.FirstDeriv      = [-diff(NewRaw.CorrectedDepth)/SamplingInterval; 0];    % vertical speed/depth rate of change
    NewRaw.FirstDeriv_next = [0; NewRaw.FirstDeriv(1:height(NewRaw)-1)];            % find next slope
    NewRaw.SecondDeriv     = [diff(NewRaw.FirstDeriv)/SamplingInterval; 0];         % vertical acceleration/change in change in slope
    NewRaw.Day = floor(NewRaw.time);
    NewRaw.Days_Elapsed = NewRaw.Day - NewRaw.Day(1);
    NewRaw.Time_of_day_h = 24*(NewRaw.time - floor(NewRaw.time));  

    % THRESHOLDS
    dive_threshold = 2; % something deeper than 2m counts as a dive
    stroke_threshold = 15; % gliding is anything below 15 strokes per minute
    positive_buoyancy_threshold_day = 80; % exclude possibility of shift to positive buoyancy if trip is shorter than this length in days

    % DRIFT SLEEP ID: DEPTH RATE THRESHOLDS
    first_deriv_drift_threshold = 0.6; % drifts must be shallower than this
    second_deriv_drift_threshold = 0.05; % drifts must have lower acceleration than this
    Diff_quarttothird_2thirdto3quart_threshold = 0.10; % assuring that the change in drift rate from the
    % first chunk of the drift is not more than 0.1 m/s different than in the later
    % portion of the drift segment (helps filter out transit dives).
    smooth_drift_threshold = 0.30; % After positive buoyancy, it is possible to have drift rates within 0.3 m/s of the mean drift rate
    smooth_drift_window = 1/20; % Smooth data across a gaussian window sized a twentieth of the length of the dataset

    % TIME THRESHOLDS
    long_SI_threshold = 10*60; % set threshold for extended surface intervals at 10 minutes
    long_drift_threshold = 200; % set underwater sleep threshold at 200 s
    long_drift_threshold_when_positive = 180; % allow shorter segments when positive
    long_flat_threshold = 200; % set underwater sleep threshold at 4 min
    long_glide_threshold = 200; % set long glide sleep threshold at 5 min
    LONG_threshold = 500 * 60; % Setting maximum duration (in seconds) for a drift segment (500 minutes)

    % Find dives
    % Criteria: dives must be continuous segments deeper than dive_threshold.
    NewRaw.is_dive          = abs(NewRaw.CorrectedDepth) > dive_threshold;
    Dives                   = table(yt_setones(NewRaw.is_dive),'VariableNames',{'Indices'}); 
    if height(Dives)<10
        disp('Issue with Dive ID')
        Seals_Used.Dive_ID_Issue(k) = 1;
        continue
    else
        Seals_Used.Dive_ID_Issue(k) = 0;
    end
    Dives.Duration_s        = (Dives.Indices(:,2)-Dives.Indices(:,1))*SamplingInterval;
    % Eliminate dives with duration 0 or longer than 500 min (false IDs)
    Dives                   = Dives(find(Dives.Duration_s~=0 & Dives.Duration_s < LONG_threshold),:);
    Dives.Start_JulDate     = NewRaw.time(Dives.Indices(:,1));
    Dives.End_JulDate       = NewRaw.time(Dives.Indices(:,2));
    Dives.Start_Light       = NewRaw.light(Dives.Indices(:,1));
    Dives.End_Light         = NewRaw.light(Dives.Indices(:,2));
    Dives.Lat               = NewRaw.Lat(Dives.Indices(:,1));
    Dives.Long              = NewRaw.Long(Dives.Indices(:,2));
    disp('01.A Complete: Dives located successfully')

    %% 01.B - FIND DRIFTS, assess smoothing necessary
    % Finds drifts given a certain smoothing window, reassesses given depth
    % sensor sensitivity.

    depth_smooth_window = 6; % Window for gaussian smooth

    % SET MINIMUM EXPECTED long drifts per day
    reasonable_long_drift_num_threshold = max(NewRaw.Days_Elapsed)*10 % 10 long drifts expected per day

    NewRaw.preSmoothCorrectedDepth = NewRaw.CorrectedDepth; % save pre-smoothed data
    NewRaw.CorrectedDepth = smoothdata(NewRaw.CorrectedDepth,'gaussian',depth_smooth_window);
    NewRaw.CorrectedDepth = round(NewRaw.CorrectedDepth);
    
    post_round_depth_smooth_window = depth_smooth_window;
    NewRaw.CorrectedDepth = smoothdata(NewRaw.CorrectedDepth,'gaussian',post_round_depth_smooth_window);
    
    % Recalc derivatives
    NewRaw.FirstDeriv      = [-diff(NewRaw.CorrectedDepth)/SamplingInterval; 0];    % vertical speed/depth rate of change
    NewRaw.FirstDeriv_next = [0; NewRaw.FirstDeriv(1:height(NewRaw)-1)];            % find next slope
    NewRaw.SecondDeriv     = [diff(NewRaw.FirstDeriv)/SamplingInterval; 0];         % vertical acceleration/change in change in slope

     % Re-find drifts: 
    NewRaw.is_drift(:) = 0;
    NewRaw.is_drift = (abs(NewRaw.CorrectedDepth)> dive_threshold &... % MUST NOT BE AT SURFACE
                            abs(NewRaw.FirstDeriv) <= first_deriv_drift_threshold & ... % Vertical speed must be shallower than the threshold
                            abs(NewRaw.SecondDeriv) <= second_deriv_drift_threshold & ... % Change in vertical speed must be within smaller threshold
                            (sign(NewRaw.FirstDeriv) == sign(NewRaw.FirstDeriv_next))); % or if changes, must be very small

    Drifts              = table(yt_setones(NewRaw.is_drift),'VariableNames',{'Indices'});
    Drifts.Duration_s   = (Drifts.Indices(:,2)-Drifts.Indices(:,1))*SamplingInterval;
    Drifts              = Drifts(find(Drifts.Duration_s~=0),:);

    % Find long drifts (based on shorter, positive buoyancy duration threshold)
    Drifts_long_test    = Drifts(find(Drifts.Duration_s > long_drift_threshold_when_positive),:);
    
    if height(Drifts_long_test) > reasonable_long_drift_num_threshold % at least X long drifts per day
        disp('Reasonable number of long drifts detected') 
    else
        disp('Suspiciously low number of long drifts detected')
        continue
%         
%         while height(Drifts_long_test) < reasonable_long_drift_num_threshold
%             post_round_depth_smooth_window = post_round_depth_smooth_window + 2 % Expand smoothing window by 2
%             NewRaw.CorrectedDepth = smoothdata(NewRaw.CorrectedDepth,'gaussian',post_round_depth_smooth_window);
%             
%             % Recalculate derivatives
%             NewRaw.FirstDeriv      = [-diff(NewRaw.CorrectedDepth)/SamplingInterval; 0];    % vertical speed/depth rate of change
%             NewRaw.FirstDeriv_next = [0; NewRaw.FirstDeriv(1:height(NewRaw)-1)];            % find next slope
%             NewRaw.SecondDeriv     = [diff(NewRaw.FirstDeriv)/SamplingInterval; 0];         % vertical acceleration/change in change in slope
% 
%              % Re-find drifts: 
%             NewRaw.is_drift(:) = 0;
%             NewRaw.is_drift = (abs(NewRaw.CorrectedDepth)> dive_threshold &... % MUST NOT BE AT SURFACE
%                                     abs(NewRaw.FirstDeriv) <= first_deriv_drift_threshold & ... % Vertical speed must be shallower than the threshold
%                                     abs(NewRaw.SecondDeriv) <= second_deriv_drift_threshold & ... % Change in vertical speed must be within smaller threshold
%                                     (sign(NewRaw.FirstDeriv) == sign(NewRaw.FirstDeriv_next))); % or if changes, must be very small
%             Drifts              = table(yt_setones(NewRaw.is_drift),'VariableNames',{'Indices'});
%             Drifts.Duration_s   = (Drifts.Indices(:,2)-Drifts.Indices(:,1))*SamplingInterval;
%             Drifts              = Drifts(find(Drifts.Duration_s~=0),:);
%             Drifts_long_test    = Drifts(find(Drifts.Duration_s > long_drift_threshold_when_positive),:);
%         end
%         disp(strcat('Smoothing factor of =',int2str(post_round_depth_smooth_window), ' required to obtain reasonable number of long drifts.'))
%         Seals_Used.SmoothingFactorRequired(k) = post_round_depth_smooth_window;
    end

    % Plot a random dive to inspect pre- and post-smooth - Ensure that dive features are not lost.
    
    dix = 5;
    startix = find(abs(NewRaw.time(:)-Dives.Start_JulDate(dix)) == min(abs(NewRaw.time(:) - Dives.Start_JulDate(dix))) );
    endix = find(abs(NewRaw.time(:)-Dives.End_JulDate(dix)) == min(abs(NewRaw.time(:) - Dives.End_JulDate(dix))) );
    
    
    figure; plot(NewRaw.time(startix:endix), NewRaw.preSmoothCorrectedDepth(startix:endix),'Color',[1 0 0 0.2]); hold on; 
    plot(NewRaw.time(startix:endix), NewRaw.CorrectedDepth(startix:endix),'Color',[drifting_col 0.5])
    legend('pre-smooth','post-smooth');
    set(gca, 'YDir','reverse'); 
    title(strcat('Smoothed by window of', int2str(post_round_depth_smooth_window), 'Depth Data for Single Dive #',int2str(dix),' for Seal: ',SEALID, ' TOPPID:',TOPPID))
    % print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_02_Dive-Smooth.png'))
    
    % Calculate drift statistics
    Drifts.Start_JulDate    = NewRaw.time(Drifts.Indices(:,1));
    Drifts.End_JulDate      = NewRaw.time(Drifts.Indices(:,2));
    Drifts.Start_Sec        = Drifts.Indices(:,1) *SamplingInterval;
    Drifts.End_Sec          = Drifts.Indices(:,2) *SamplingInterval;
    Drifts.MeanSec          = Drifts.Start_Sec + Drifts.Duration_s/2;
    Drifts.Start_Depth      = NewRaw.CorrectedDepth(Drifts.Indices(:,1));
    Drifts.End_Depth        = NewRaw.CorrectedDepth(Drifts.Indices(:,2));
    Drifts.Start_Light      = NewRaw.light(Drifts.Indices(:,1));
    Drifts.End_Light        = NewRaw.light(Drifts.Indices(:,2));
    Drifts.DriftRate        = (Drifts.Start_Depth - Drifts.End_Depth) ./ Drifts.Duration_s;
    Drifts.DiffDepth        = (Drifts.Start_Depth - Drifts.End_Depth);
    Drifts.JulDay           = floor(Drifts.Start_JulDate);
    Drifts.Time_of_day_h    = 24*(Drifts.Start_JulDate - Drifts.JulDay);
    Drifts.Days_Elapsed     = Drifts.JulDay-Drifts.JulDay(1); 

    disp('01.B Complete: Depth data smoothed and drifts located.')

    %% 01.C Dive Analysis
    % Find descents, ascents, surface intervals, and glides & sleep (if data present)

    close all
    % Find descents
    % Criteria: descents must be continuous segments deeper than dive_threshold,
    % steeply descending (more than drift segments), and stop when vertical
    % speed switches sign (when start to ascend).
    NewRaw.is_descent       = abs(NewRaw.CorrectedDepth)>dive_threshold & ...
                                NewRaw.FirstDeriv < -first_deriv_drift_threshold & ...
                                sign(NewRaw.FirstDeriv) == sign(NewRaw.FirstDeriv_next);
    Descents                = table(yt_setones(NewRaw.is_descent),'VariableNames',{'Indices'});
    if height(Descents) == 0
        continue
        Seals_Used.Issue_with_Diving_Data(k) = 1;
    end
    Seals_Used.Issue_with_Diving_Data(k) = 0;
    Descents.Duration_s     = (Descents.Indices(:,2)-Descents.Indices(:,1))*SamplingInterval;
    Descents                = Descents(find(Descents.Duration_s~=0 & Descents.Duration_s<LONG_threshold),:);
    Descents.Start_JulDate  = NewRaw.time(Descents.Indices(:,1));
    Descents.End_JulDate    = NewRaw.time(Descents.Indices(:,2));

    % Find ascents
    % Criteria: ascents must be continuous segments deeper than dive_threshold,
    % steeply ascending (more than drift segments), and stop when vertical
    % speed switches sign (when start to descend).
    NewRaw.is_ascent        = abs(NewRaw.CorrectedDepth)>dive_threshold & ...
                                NewRaw.FirstDeriv > first_deriv_drift_threshold & ...
                                sign(NewRaw.FirstDeriv) == sign(NewRaw.FirstDeriv_next);
    Ascents                 = table(yt_setones(NewRaw.is_ascent),'VariableNames',{'Indices'});
    Ascents.Duration_s      = (Ascents.Indices(:,2)-Ascents.Indices(:,1))*SamplingInterval;
    Ascents                 = Ascents(find(Ascents.Duration_s~=0 & Ascents.Duration_s<LONG_threshold),:);
    Ascents.Start_JulDate   = NewRaw.time(Ascents.Indices(:,1));
    Ascents.End_JulDate     = NewRaw.time(Ascents.Indices(:,2));

    % Find surface intervals
    % Criteria: surface intervals must be continuous segments shallower than dive_threshold.
    % Would also include any haulouts.
    NewRaw.is_SI            = abs(NewRaw.CorrectedDepth) < dive_threshold; 
    SIs                     = table(yt_setones(NewRaw.is_SI),'VariableNames',{'Indices'});
    SIs.Duration_s          = (SIs.Indices(:,2)-SIs.Indices(:,1))*SamplingInterval;
    SIs.Start_JulDate       = NewRaw.time(SIs.Indices(:,1));
    SIs.End_JulDate         = NewRaw.time(SIs.Indices(:,2));
    SIs.Start_Depth         = NewRaw.CorrectedDepth(SIs.Indices(:,1));
    SIs.End_Depth           = NewRaw.CorrectedDepth(SIs.Indices(:,2));
    SIs.Start_Light       = NewRaw.light(SIs.Indices(:,1));
    SIs.End_Light         = NewRaw.light(SIs.Indices(:,2));
    SIs.Lat                 = NewRaw.Lat(SIs.Indices(:,1));
    SIs.Long                = NewRaw.Long(SIs.Indices(:,2));
    SIs.JulDay = floor(SIs.Start_JulDate);
    SIs.Time_of_day_h = 24*(SIs.Start_JulDate - SIs.JulDay);
    SIs.Days_Elapsed = SIs.JulDay-SIs.JulDay(1); 
    

    % Only call it a surface interval if it's between the first and last dive
    % (exclude haulouts at beginning and end of recording)
    SIs                     = SIs(find(SIs.Indices(:,1)>Dives.Indices(1,1) & SIs.Indices(:,1)<Dives.Indices(height(Dives),1)),:);
    SIs                     = SIs(find(SIs.Duration_s~=0 & SIs.Duration_s<LONG_threshold),:);
    % Find extended surface intervals (potential behavioral sleep)
    SIs_long                = SIs(find(SIs.Duration_s > long_SI_threshold),:); % Find extended surface intervals using threshold.

    % IF STROKE DATA PRESENT
    % Find gliding segments
    % Criteria: Stroke rate is below stroke_threshold
    if haveStrokes
        NewRaw.is_glide    = zeros(height(NewRaw),1);
        NewRaw.is_glide(find(isnan(NewRaw.Stroke_Rate))) = nan;
        NewRaw.is_glide(find(NewRaw.Stroke_Rate < stroke_threshold)) = 1; % IF Gliding assign 1
        NewRawWithStroke = NewRaw(find(~isnan(NewRaw.is_glide)),:);
        Glides              = table(yt_setones(NewRawWithStroke.is_glide),'VariableNames',{'Indices'});
        Glides.Duration_s   = (Glides.Indices(:,2)-Glides.Indices(:,1))*SamplingInterval;
        Glides              = Glides(find(Glides.Duration_s~=0 & Glides.Duration_s<LONG_threshold),:);
        Glides.Start_JulDate = NewRawWithStroke.time(Glides.Indices(:,1));
        Glides.End_JulDate  = NewRawWithStroke.time(Glides.Indices(:,2));
        Glides_long         = Glides(find(Glides.Duration_s >= long_glide_threshold),:);
        if haveKami
            NewRaw.is_feeding = zeros(height(NewRaw),1);
            NewRaw.is_feeding(find(isnan(NewRaw.KAMI))) = nan;
            NewRaw.is_feeding(find(NewRaw.KAMI > 0)) = 1; % IF Feeding assign 1
        end
    end

    % IF SLEEP RECORDED AND SCORED
    if haveSleep
        % Find naps
        NewRaw.is_sleep     = NewRaw.Simple_Sleep_Num >=4; %IF SWS or REM assign 1
        Naps                = table(yt_setones(NewRaw.is_sleep),'VariableNames',{'Indices'});
        Naps.Duration_s     = (Naps.Indices(:,2)-Naps.Indices(:,1))*SamplingInterval;
        Naps                = Naps(find(Naps.Duration_s~=0 & Naps.Duration_s<LONG_threshold),:);
        Naps.Start_Depth    = NewRaw.CorrectedDepth(Naps.Indices(:,1));
        Naps.End_Depth      = NewRaw.CorrectedDepth(Naps.Indices(:,2));
        Naps.Start_JulDate  = NewRaw.time(Naps.Indices(:,1));
        Naps.End_JulDate    = NewRaw.time(Naps.Indices(:,2));
        Naps.Lat            = NewRaw.Lat(Naps.Indices(:,1));
        Naps.Long           = NewRaw.Long(Naps.Indices(:,2));
        Naps.DriftRate      = (Naps.Start_Depth - Naps.End_Depth) ./ Naps.Duration_s;
        Naps.JulDay         = floor(Naps.Start_JulDate);
        Naps.Time_of_day_h = 24*(Naps.Start_JulDate - Naps.JulDay);
        Naps.Days_Elapsed = Naps.JulDay-Naps.JulDay(1); 

        % Find apnea cycles
        NewRaw.is_apnea     = NewRaw.Resp_Num == -2; % IF Apnea assign 1
        Apneas              = table(yt_setones(NewRaw.is_apnea),'VariableNames',{'Indices'});
        Apneas.Duration_s   = (Apneas.Indices(:,2)-Apneas.Indices(:,1))*SamplingInterval;
        Apneas              = Apneas(find(Apneas.Duration_s~=0 & Apneas.Duration_s<LONG_threshold),:);
        Apneas.Start_JulDate = NewRaw.time(Apneas.Indices(:,1));
        Apneas.End_JulDate  = NewRaw.time(Apneas.Indices(:,2));

        % Find REM segments
        NewRaw.is_REM       = NewRaw.Sleep_Num == 6 | NewRaw.Sleep_Num == 7; % IF REM assign 1
        REMs                = table(yt_setones(NewRaw.is_REM),'VariableNames',{'Indices'});
        REMs.Duration_s     = (REMs.Indices(:,2)-REMs.Indices(:,1))*SamplingInterval;
        REMs                = REMs(find(REMs.Duration_s~=0 & REMs.Duration_s<LONG_threshold),:);
        REMs.Start_JulDate  = NewRaw.time(REMs.Indices(:,1));
        REMs.End_JulDate    = NewRaw.time(REMs.Indices(:,2));
        
    end

    disp('')
    disp(['Seal ' SEALID ' (TOPPID ',TOPPID,') performed: ']) 
    disp([int2str(height(Dives)),' dives, lasting an average of ', int2str(mean(Dives.Duration_s)/60), char(177), int2str(std(Dives.Duration_s)/60),' minutes.']); 
    disp([int2str(height(Descents)),' descents, lasting an average of ', int2str(mean(Descents.Duration_s)/60), char(177), int2str(std(Descents.Duration_s)/60),' minutes.']); 
    disp([int2str(height(Ascents)),' ascents, lasting an average of ', int2str(mean(Ascents.Duration_s)/60), char(177), int2str(std(Ascents.Duration_s)/60),' minutes.']); 
    disp([int2str(height(SIs)),' surface intervals, lasting an average of ', int2str(mean(SIs.Duration_s)/60), char(177), int2str(std(SIs.Duration_s)/60),' minutes.']); 
    disp([int2str(height(SIs_long)),  ' extended surface intervals, lasting an average of ', int2str(mean(SIs_long.Duration_s)/60), char(177), int2str(std(SIs_long.Duration_s)/60),' minutes.']); 

    if haveSleep
        disp([int2str(height(Naps)),  ' naps, lasting an average of ', int2str(mean(Naps.Duration_s)/60),char(177),int2str(std(Naps.Duration_s))])
        disp([int2str(height(REMs)),  ' REM sleep segments, lasting an average of ', int2str(mean(REMs.Duration_s)/60),char(177),int2str(std(REMs.Duration_s)/60)])
        disp([int2str(height(Apneas)),  ' apneas, lasting an average of ', int2str(mean(Apneas.Duration_s)/60),char(177),int2str(std(Apneas.Duration_s)/60)])
        Seals_Used.Naps(k) = height(Naps); 
        Seals_Used.Naps_meanDur_min(k) = mean(Naps.Duration_s/60); 
        Seals_Used.Naps_stdDur_min(k) = std(Naps.Duration_s/60);
        Seals_Used.REMs(k) = height(REMs); 
        Seals_Used.REMs_meanDur_min(k) = mean(REMs.Duration_s/60); 
        Seals_Used.REMs_stdDur_min(k) = std(REMs.Duration_s/60);
        Seals_Used.Apneas(k) = height(Apneas); 
        Seals_Used.Apneas_meanDur_min(k) = mean(Apneas.Duration_s/60); 
        Seals_Used.Apneas_stdDur_min(k) = std(Apneas.Duration_s/60);
    end
    if haveStrokes
        disp([int2str(height(Glides)),  ' glides, lasting an average of ', int2str(mean(Glides.Duration_s)),char(177),int2str(std(Glides.Duration_s))])
        Seals_Used.Glides_long(k) = height(Glides_long); 
        Seals_Used.Glides_long_meanDur_min(k) = mean(Glides_long.Duration_s/60); 
        Seals_Used.Glides_long_stdDur_min(k) = std(Glides_long.Duration_s/60);
    end

    Seals_Used.Dives(k) = height(Dives); 
    Seals_Used.Dives_meanDur_min(k) = mean(Dives.Duration_s/60); 
    Seals_Used.Dives_maxDur_min(k) = max(Dives.Duration_s/60);
    Seals_Used.Dives_stdDur_min(k) = std(Dives.Duration_s/60);
    Seals_Used.Descents(k) = height(Descents); 
    Seals_Used.Descents_meanDur_min(k) = mean(Descents.Duration_s/60); 
    Seals_Used.Descents_stdDur_min(k) = std(Descents.Duration_s/60);
    Seals_Used.Ascents(k) = height(Ascents); 
    Seals_Used.Ascents_meanDur_min(k) = mean(Ascents.Duration_s/60); 
    Seals_Used.Ascents_stdDur_min(k) = std(Ascents.Duration_s/60);
    Seals_Used.SIs(k) = height(SIs); 
    Seals_Used.SIs_meanDur_min(k) = mean(SIs.Duration_s/60); 
    Seals_Used.SIs_stdDur_min(k) = std(SIs.Duration_s/60);
    Seals_Used.SIs_long(k) = height(SIs_long); 
    Seals_Used.SIs_long_meanDur_min(k) = mean(SIs_long.Duration_s/60); 
    Seals_Used.SIs_long_stdDur_min(k) = std(SIs_long.Duration_s/60);
    disp('')
    disp('01.C Complete: Dive analysis completed and summarized.')

    %% 01.D - FIND LONG DRIFTS
    Drifts_long         = Drifts(find(Drifts.Duration_s >= long_drift_threshold_when_positive & ...
        Drifts.Duration_s <= LONG_threshold),:);

    % Calculate statistics to find best criteria for minimizing false positives
    % & false negatives (maximizing specificity & sensitivity)
    for d = 1:height(Drifts_long)
        startix = Drifts_long.Indices(d,1);
        endix = Drifts_long.Indices(d,2);
        duration = (endix-startix)+1;
        Drifts_long.Median_FirstDeriv(d) = median(NewRaw.FirstDeriv(startix:endix));
        Drifts_long.Mean_FirstDeriv(d) = mean(NewRaw.FirstDeriv(startix:endix));
        Drifts_long.Mean_FirstDeriv_quarttothird(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(1/4)):round(startix+duration*(1/3))));
        Drifts_long.Mean_FirstDeriv_2thirdto3quart(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(2/3)):round(startix+duration*(3/4))));
        Drifts_long.Mean_FirstDeriv_end(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(7/8)):round(startix+duration*(8/9))));

        Drifts_long.Diff_quarttothird_2thirdto3quart(d) = Drifts_long.Mean_FirstDeriv_2thirdto3quart(d) - Drifts_long.Mean_FirstDeriv_quarttothird(d);

        Drifts_long.sd_FirstDeriv(d) = std(NewRaw.FirstDeriv(startix:endix));
        Drifts_long.Median_SecondDeriv(d) = median(NewRaw.SecondDeriv(startix:endix)); 
        Drifts_long.Mean_SecondDeriv(d) = mean(NewRaw.SecondDeriv(startix:endix)); 
        Drifts_long.sd_SecondDeriv(d) = std(NewRaw.SecondDeriv(startix:endix));
        if haveStrokes
            Drifts_long.PercentGlideOverlap(d) = 100 * (sum(NewRaw.is_glide(startix:endix))/duration);
            if haveKami
                Drifts_long.PercentSnackOverlap(d) = 100 * (sum(NewRaw.is_feeding(startix:endix))/duration);
            end
        end
        if haveSleep
            Drifts_long.PercentNapOverlap(d) = 100 * (sum(NewRaw.is_sleep(startix:endix))/duration);
        end
        Drifts_long.Lat(d) = mean(NewRaw.Lat(startix:endix));
        Drifts_long.Long(d) = mean(NewRaw.Long(startix:endix));
        NewRaw.is_long_drift(startix:endix) = 1;
    end

    if haveSleep
        for f = 1:height(Apneas)
            startix = Apneas.Indices(f,1);
            endix = Apneas.Indices(f,2);
            duration = (endix-startix)+1;
            Apneas.is_sleep(f) = SamplingInterval * sum(NewRaw.is_sleep(startix:endix));
        end

        for d = 1:height(Naps)
            startix = Naps.Indices(d,1);
            endix = Naps.Indices(d,2);
            duration = (endix-startix)+1;
            Naps.Median_FirstDeriv(d) = median(NewRaw.FirstDeriv(startix:endix));
            Naps.Mean_FirstDeriv(d) = mean(NewRaw.FirstDeriv(startix:endix));
            Naps.Mean_FirstDeriv_quarttothird(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(1/4)):round(startix+duration*(1/3))));
            Naps.Mean_FirstDeriv_2thirdto3quart(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(2/3)):round(startix+duration*(3/4))));
            Naps.Diff_quarttothird_2thirdto3quart(d) = Naps.Mean_FirstDeriv_2thirdto3quart(d) - Naps.Mean_FirstDeriv_quarttothird(d);
            Naps.sd_FirstDeriv(d) = std(NewRaw.FirstDeriv(startix:endix));
            Naps.Median_SecondDeriv(d) = median(NewRaw.SecondDeriv(startix:endix)); 
            Naps.Mean_SecondDeriv(d) = mean(NewRaw.SecondDeriv(startix:endix)); 
            Naps.sd_SecondDeriv(d) = std(NewRaw.SecondDeriv(startix:endix));
            Naps.PercentGlideOverlap(d) = 100 * (sum(NewRaw.is_glide(startix:endix))/duration);
            Naps.PercentDriftOverlap(d) = 100 * (sum(NewRaw.is_drift(startix:endix))/duration);
        end

        for d = 1:height(REMs)
            startix = REMs.Indices(d,1);
            endix = REMs.Indices(d,2);
            duration = (endix-startix)+1;
            REMs.Median_FirstDeriv(d) = median(NewRaw.FirstDeriv(startix:endix));
            REMs.Mean_FirstDeriv(d) = mean(NewRaw.FirstDeriv(startix:endix));
            REMs.Mean_FirstDeriv_quarttothird(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(1/4)):round(startix+duration*(1/3))));
            REMs.Mean_FirstDeriv_2thirdto3quart(d) = mean(NewRaw.FirstDeriv(round(startix+duration*(2/3)):round(startix+duration*(3/4))));
            REMs.Diff_quarttothird_2thirdto3quart(d) = REMs.Mean_FirstDeriv_2thirdto3quart(d) - REMs.Mean_FirstDeriv_quarttothird(d);
            REMs.sd_FirstDeriv(d) = std(NewRaw.FirstDeriv(startix:endix));
            REMs.Median_SecondDeriv(d) = median(NewRaw.SecondDeriv(startix:endix)); 
            REMs.Mean_SecondDeriv(d) = mean(NewRaw.SecondDeriv(startix:endix)); 
            REMs.sd_SecondDeriv(d) = std(NewRaw.SecondDeriv(startix:endix));
            REMs.PercentGlideOverlap(d) = 100 * (sum(NewRaw.is_glide(startix:endix))/duration);
            REMs.PercentDriftOverlap(d) = 100 * (sum(NewRaw.is_drift(startix:endix))/duration);
        end
    end

    disp('Section 02.D Complete: Longer drifts located, drift stats generated.')

    %% 02.E - Write long drifts, SIs, and glides back into dataset

    NewRaw.is_long_drift(:) = 0;
    NewRaw.long_drift_num(:) = 0;
    for f = 1:height(Drifts_long)
        NewRaw.is_long_drift(Drifts_long.Indices(f,1):Drifts_long.Indices(f,2)) = 1;
        NewRaw.long_drift_num(Drifts_long.Indices(f,1):Drifts_long.Indices(f,2)) = f;
    end
    
    % Separate drifts shallower than 500 m for smoothed drift rate
    % calculation in next step.
    NewRaw.is_shallow_long_drift(:) = 0;
    Shallow_Drifts_long = Drifts_long(find(Drifts_long.Start_Depth < 500),:);
    for f = 1:height(Shallow_Drifts_long)
        NewRaw.is_shallow_long_drift(Shallow_Drifts_long.Indices(f,1):Shallow_Drifts_long.Indices(f,2)) = 1;
    end

    NewRaw.is_long_SI(:) = 0;
    NewRaw.long_SI_num(:) = 0;
    SIs_long.PercentGlideOverlap(:) = nan;
    for f = 1:height(SIs_long)
        NewRaw.is_long_SI(SIs_long.Indices(f,1):SIs_long.Indices(f,2)) = 1;
        NewRaw.long_SI_num(SIs_long.Indices(f,1):SIs_long.Indices(f,2)) = f;
        if haveStrokes
            SIs_long.PercentGlideOverlap(f) = 100 * (sum(NewRaw.is_glide(SIs_long.Indices(f,1):SIs_long.Indices(f,2)))/SIs_long.Duration_s(f));
        end
    end

    if haveStrokes
        NewRaw.is_long_glide(:) = nan;
        NewRaw.long_glide_num(:) = nan;
        NewRaw.is_long_glide(find(~isnan(NewRaw.is_glide))) = 0;
        for f = 1:height(Glides_long)
            startix = NewRawWithStroke.time(Glides_long.Indices(f,1));
            endix = NewRawWithStroke.time(Glides_long.Indices(f,2));
            NewRaw.is_long_glide(find(NewRaw.time >= startix & NewRaw.time < endix)) = 1;
            NewRaw.long_glide_num(find(NewRaw.time >= startix & NewRaw.time < endix)) = f;
        end
    end

    disp('Section 02.E Complete: Long segments written into NewRaw.')

    %% 03.A - Prepare drift rate filtering criteria
    % Set criteria to refine sleep identification model.

    % Threshold of days before smoothed drift rate becomes positive to
    % allow the the possibility of a positive drift rate dive.
    backtrack_potential_positive_days_threshold = 20; 

    % Find smoothed drift rate across trip using shallow long drift dives.
    NewRaw.SmoothFirstDeriv(:) = nan(height(NewRaw),1);
    NewRaw.SmoothFirstDeriv(find(NewRaw.is_shallow_long_drift)) = ... 
        smoothdata(NewRaw.FirstDeriv(find(NewRaw.is_shallow_long_drift)),... % smoothing all drifting data
        'gaussian',height(NewRaw)*smooth_drift_window); % smooth with gaussian filter across a window 1/20 size of full dataset
    NewRaw.SmoothFirstDeriv = fixgaps(NewRaw.SmoothFirstDeriv);
    figure
    scatter(NewRaw.time,NewRaw.SmoothFirstDeriv,[],NewRaw.SmoothFirstDeriv,'filled')
    title(strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Pre-filter Smoothed First Deriv'));
    
    % Summarize strokes and feeding attempts per long drift
    for i = 1:height(Drifts_long)
        startix = Drifts_long.Indices(i,1);
        endix = Drifts_long.Indices(i,2);
        Drifts_long.SmoothFirstDeriv(i) = mean(NewRaw.SmoothFirstDeriv(startix:endix));
        if haveStrokes
            Drifts_long.meanStrokeRate(i) = mean(NewRaw.Stroke_Rate(startix:endix));
            if haveKami
                Drifts_long.total_KAMI(i) = sum(NewRaw.KAMI(startix:endix));
            end
        end
    end
    
    % Find the day that the seal probably became positively buoyant and
    % backtrack X days to allow the possibility of positive drift dives
    % before. Criteria: smoothed drift rate must be positive and at least
    % 20 days must have passed (to eliminate high-false-positive-rate
    % beginning of trip).
    positive_likely_day = min(Drifts_long.Days_Elapsed(find(Drifts_long.SmoothFirstDeriv>0 & ...
        Drifts_long.Days_Elapsed > 20))) - backtrack_potential_positive_days_threshold;
    
    % Store the value used for filtering (the first day a positive dive
    % should be allowed).
    if ~isempty(positive_likely_day)
        Seals_Used.positive_day(k) = positive_likely_day;
    elseif isempty(positive_likely_day)
        positive_likely_day=1000;
        Seals_Used.positive_day(k) = nan;
    end

    disp('Section 03.A complete - Drift rate filter criteria prepared.')

    %% 03.B - APPLY Filter criteria

    % Filter Criteria:
    positive_likely_day
    within_smoothed_driftrate = abs(Drifts_long.DriftRate-Drifts_long.SmoothFirstDeriv) < smooth_drift_threshold;
    end_in_flat = abs(Drifts_long.Mean_FirstDeriv_end)<0.01;
    long_drift_threshold = 200; % set underwater sleep threshold at 200 s
    long_drift_threshold_when_positive = 180; % allow shorter segments when positive
    
    % STEP 1: Regardless of buoyancy, eliminate all drifts that do not fit
    % within smoothed drift rate criteria. 
    % Save & set aside all long flats (potential benthic sleep). 
    Flats_long = Drifts_long(find(end_in_flat),:);
    Refined_Drifts_long = Drifts_long(find(...
        within_smoothed_driftrate ...
        & end_in_flat==0),:);

    anti_transit_criteria = Refined_Drifts_long.Diff_quarttothird_2thirdto3quart < Diff_quarttothird_2thirdto3quart_threshold;
    anti_benthic_transit_criteria = (abs(Refined_Drifts_long.DriftRate) > 0.08);
    shallow1 = Refined_Drifts_long.Start_Depth < 200; % Shallow / above 200 m
    
    % STEP 2: Buoyancy-specific drift dive filtering:
    % 
    % NEGATIVE BUOYANCY / Pre-shift to positive buoyancy:
    % 
    % Negative drifts while negative- filter with:
    % 
    % Drifts must be negative
    % Drifts must be LONG (uses new, longer threshold - 200s) 
    % Anti-transit criteria: can't be too curved
    % Anti-benthic-transit criteria: Drift rate can't be too close to zero
    % 
    % POSITIVE BUOYANCY / Post-shift to positive buoyancy:
    % 
    % Positive drifts while positive- filter with:
    % 
    % Drifts must be positive
    % Drifts can be shorter (no new threshold - 180s)
    % Anti-transit criteria: can't be too curved
    % NO Anti-benthic-transit criteria: Drift rate can be close to zero
    %
    % Negative drifts while positive- filter with:
    %
    % Drifts must be negative
    % Drifts must be LONG (uses new, longer threshold - 200s)
    % NO Anti-transit criteria: can be curved because seal decelerating
    % NO Anti-benthic-transit criteria: Drift rate can be close to zero
    
    if positive_likely_day < 20 & positive_likely_day < max(NewRaw.Days_Elapsed)-5
        % IF LEFT WHILE POSITIVELY BUOYANT
        % If she was positively buoyant within 20 first days of trip,
        % and the detected buoyancy change was not within 5 days of arrival, 
        % allow LONG negative drifts & positive drifts that fit
        % anti-transit criteria.
        
        Pos_Filtered_Drifts_long = Refined_Drifts_long(find(Refined_Drifts_long.DriftRate >= 0 ...
            & anti_transit_criteria),:);
        
        Neg_Filtered_Drifts_long = Refined_Drifts_long(find(Refined_Drifts_long.DriftRate <= 0 ...
            & shallow1 == 0 ... % deeper than 200 m
            & Refined_Drifts_long.Duration_s >= long_drift_threshold),:); % negative dives should be longer than threshold
        
        Refined2_Drifts_long = vertcat(Pos_Filtered_Drifts_long,...
            Neg_Filtered_Drifts_long);
    else
        % Otherwise, assume she was "normal" and left while negatively
        % buoyant. Only allow LONG negative drifts that fit the above
        % anti-benthic-transit and anti-transit criteria (unless she ended
        % on the ground at the end of a drift (very low Mean_FirstDeriv_end).
        
        % BEFORE POSITIVE LIKELY DAY:
        Neg_Neg_Filtered_Drifts_long = Refined_Drifts_long(find(Refined_Drifts_long.DriftRate <= 0 ... % must be negative
            & Refined_Drifts_long.Days_Elapsed <= positive_likely_day ... % must be before shift to positive
            & Refined_Drifts_long.Duration_s >= long_drift_threshold ... % must be LONG
            & anti_benthic_transit_criteria ... % slope must not be too small
            & anti_transit_criteria),:); % must not be too curved
        
        % AFTER POSTIIVE LIKELY DAY:
        Pos_Pos_Filtered_Drifts_long = Refined_Drifts_long(find(Refined_Drifts_long.DriftRate >= 0 ... % must be positive
            & Refined_Drifts_long.Days_Elapsed > positive_likely_day ...
            & anti_transit_criteria),:); % must not be too curved
        
        Pos_Neg_Filtered_Drifts_long = Refined_Drifts_long(find(Refined_Drifts_long.DriftRate <= 0 ...
            & Refined_Drifts_long.Days_Elapsed > positive_likely_day ...
            & shallow1 == 0 ... % deeper than 200 m
            & Refined_Drifts_long.Duration_s >= long_drift_threshold),:); % negative dives should be longer than threshold
        
        Refined2_Drifts_long = vertcat(Neg_Neg_Filtered_Drifts_long,...
            Pos_Pos_Filtered_Drifts_long, Pos_Neg_Filtered_Drifts_long);
    end
    
    % STEP 3: Eliminate false positives at the beginning & end of trip
    %
    % Within 15 days of beginning and end (unless positive),
    % recalculate drift rate and filter with smaller threshold around
    % refined smoothed drift rate.
    
    refined_smooth_drift_threshold = 0.15; % Only allow 0.15 m/s deviation from early drift rate at beginning of trip
    
    shallow2 = Refined2_Drifts_long.Start_Depth < 500; % Shallow / above 500 m
    v_early = Refined2_Drifts_long.Days_Elapsed < 15; % within 15 days of beginning
    v_late = Refined2_Drifts_long.Days_Elapsed < max(Refined2_Drifts_long.Days_Elapsed)- 15; % within 15 days of arrival
    v_early_shallow_refined_drifts = Refined2_Drifts_long.DriftRate(find(v_early & shallow2),:);
    v_late_shallow_refined_drifts = Refined2_Drifts_long.DriftRate(find(v_late & shallow2),:);
    
    % Calculate early & late drift rates based on non-flat,
    % preliminary filtered drift dives shallower than 500 m.
    % Weighted average by duration.
    Early_DriftRate = mean((Refined2_Drifts_long.DriftRate(find(v_early & shallow2))...
                .* Refined2_Drifts_long.Duration_s(find(v_early & shallow2)))./Refined2_Drifts_long.Duration_s(find(v_early & shallow2)))
    
    Late_DriftRate = mean((Refined2_Drifts_long.DriftRate(find(v_late & shallow2))...
                .* Refined2_Drifts_long.Duration_s(find(v_late & shallow2)))./Refined2_Drifts_long.Duration_s(find(v_late & shallow2)))
            
    if positive_likely_day < 20 & positive_likely_day < max(NewRaw.Days_Elapsed)-5
        % IF LEFT WHILE POSITIVE, keep all.
        Filtered_Drifts_long = Refined2_Drifts_long;
        
    elseif positive_likely_day < max(NewRaw.Days_Elapsed)-20
        % IF POSITIVE WHEN RETURNED, filter only beginning
        v_early_Filtered_Drifts_long = Refined2_Drifts_long(find(v_early ...
            & abs(Refined2_Drifts_long.DriftRate - Early_DriftRate) < refined_smooth_drift_threshold),:);
        not_early_Filtered_Drifts_long = Refined2_Drifts_long(find(v_early==0),:);
        
        Filtered_Drifts_long = vertcat(v_early_Filtered_Drifts_long, ...
            not_early_Filtered_Drifts_long);
        
    else 
        % IF NEVER POSITIVE, filter beginning & end
        v_early_Filtered_Drifts_long = Refined2_Drifts_long(find(v_early ...
            & abs(Refined2_Drifts_long.DriftRate - Early_DriftRate) < refined_smooth_drift_threshold),:);
        v_late_Filtered_Drifts_long = Refined2_Drifts_long(find(v_late ...
            & abs(Refined2_Drifts_long.DriftRate - Late_DriftRate) < refined_smooth_drift_threshold),:);
        not_early_or_late_Filtered_Drifts_long = Refined2_Drifts_long(find(v_early==0),:);
        
        Filtered_Drifts_long = vertcat(v_early_Filtered_Drifts_long, ...
            v_late_Filtered_Drifts_long, ...
            not_early_or_late_Filtered_Drifts_long);
        
        Flats_long = Flats_long(find(Flats_long.DriftRate < 0.02),:);
    end
    
    % Add back in the long flats
    Filtered_Drifts_long = vertcat(Filtered_Drifts_long,Flats_long);

    Seals_Used.Drifts_long(k) = height(Drifts_long);
    Seals_Used.Drifts_long_meanDur_min(k) = mean(Drifts_long.Duration_s)/60;
    Seals_Used.Drifts_long_stdDur_min(k) = std(Drifts_long.Duration_s)/60;
    Seals_Used.Flats_long(k) = height(Flats_long);
    Seals_Used.Flats_long_meanDur_min(k) = mean(Flats_long.Duration_s)/60;
    Seals_Used.Flats_long_stdDur_min(k) = std(Flats_long.Duration_s)/60;
    Seals_Used.Drifts_long(k) = height(Drifts_long);
    Seals_Used.Drifts_long_meanDur_min(k) = mean(Drifts_long.Duration_s)/60;
    Seals_Used.Drifts_long_stdDur_min(k) = std(Drifts_long.Duration_s)/60;
    Seals_Used.Filtered_Drifts_long(k) = height(Filtered_Drifts_long);
    Seals_Used.Filtered_Drifts_long_meanDur_min(k) = mean(Filtered_Drifts_long.Duration_s)/60;
    Seals_Used.Filtered_Drifts_long_stdDur_min(k) = std(Filtered_Drifts_long.Duration_s)/60;
    
    NewRaw.is_unfiltered_long_drift(:) = 0;
    NewRaw.long_unfiltered_drift_num(:) = 0;
    for f = 1:height(Drifts_long)
        NewRaw.is_unfiltered_long_drift(Drifts_long.Indices(f,1):Drifts_long.Indices(f,2)) = 1;
        NewRaw.long_unfiltered_drift_num(Drifts_long.Indices(f,1):Drifts_long.Indices(f,2)) = f;
    end

    NewRaw.is_filtered_long_drift(:) = 0;
    NewRaw.long_filtered_drift_num(:) = 0;
    for f = 1:height(Filtered_Drifts_long)
        NewRaw.is_filtered_long_drift(Filtered_Drifts_long.Indices(f,1):Filtered_Drifts_long.Indices(f,2)) = 1;
        NewRaw.long_filtered_drift_num(Filtered_Drifts_long.Indices(f,1):Filtered_Drifts_long.Indices(f,2)) = f;
    end
    
    NewRaw.is_long_flat(:) = 0;
    NewRaw.long_flat_num(:) = 0;
    for f = 1:height(Flats_long)
        NewRaw.is_long_flat(Flats_long.Indices(f,1):Flats_long.Indices(f,2)) = 1;
        NewRaw.long_flat_num(Flats_long.Indices(f,1):Flats_long.Indices(f,2)) = f;
    end

    
    
    disp('Section 3.A Complete: Drifts filtered.')

    %% 03.B - PLOT DRIFT / GLIDE / SLEEP STATS
    close all
    if haveSleep | haveStrokes
        figure

        ax0 = subplot(3,2,1);  set(gcf, 'Position',  [100, 100, 1800, 800]);
        % Plot first and second derivatives for sleep segments

        if haveSleep
            scatter(ax0,NewRaw.FirstDeriv(find(NewRaw.is_long_drift)),...
            NewRaw.SecondDeriv(find(NewRaw.is_long_drift)),...
            [],NewRaw.is_sleep(find(NewRaw.is_long_drift)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax0); c1.Label.String = 'Nap Overlap (%)';
        else 
            scatter(ax0,NewRaw.FirstDeriv(find(NewRaw.is_long_drift)),...
            NewRaw.SecondDeriv(find(NewRaw.is_long_drift )),...
            [],NewRaw.is_long_glide(find(NewRaw.is_long_drift )),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.05,'SizeData',10);
            c1= colorbar(ax0); c1.Label.String = 'Glide Overlap (%)';
        end
        xline(ax0,first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(ax0,-first_deriv_drift_threshold,'-','Lower Drift Threshold');
        yline(ax0,second_deriv_drift_threshold,'-','Acceleration Threshold');yline(ax0,-second_deriv_drift_threshold,'-','Acceleration Threshold');
        ylabel(ax0,'Mean Second Derivative (m/s^2'); xlabel(ax0,'Mean First Derivative (m/s)');
        title(ax0,'Long Drifts Identified (each dot is 10s)');  
        % Plot drift segments and indicate overlap with true value 
        % (sleep or long glide)

        ax3 = subplot(3,2,2); ylim([-0.2 0.2]);
        % Plot first and second derivatives for filtered

        if haveSleep
            scatter(ax3,NewRaw.FirstDeriv(find(NewRaw.is_filtered_long_drift)),...
            NewRaw.SecondDeriv(find(NewRaw.is_filtered_long_drift)),...
            [],NewRaw.is_sleep(find(NewRaw.is_filtered_long_drift)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax3); c1.Label.String = 'Nap Overlap (%)';
        else 
            scatter(ax3,NewRaw.FirstDeriv(find(NewRaw.is_filtered_long_drift)),...
            NewRaw.SecondDeriv(find(NewRaw.is_filtered_long_drift)),...
            [],NewRaw.is_long_glide(find(NewRaw.is_filtered_long_drift)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.05,'SizeData',10);
            c1= colorbar(ax3); c1.Label.String = 'Glide Overlap (%)';
        end
        xline(ax3,first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(ax3,-first_deriv_drift_threshold,'-','Lower Drift Threshold');
        yline(ax3,second_deriv_drift_threshold,'-','Acceleration Threshold');yline(ax3,-second_deriv_drift_threshold,'-','Acceleration Threshold');
        ylabel(ax3,'Mean Second Derivative (m/s^2'); xlabel(ax3,'Mean First Derivative (m/s)');
        title(ax3,'Filtered Long Drifts Identified (each dot is 10s)');  
        % Plot drift segments and indicate overlap with true value 
        % (sleep or long glide)

        ax1 = subplot(3,2,3); ylim([min(Drifts_long.Mean_SecondDeriv) max(Drifts_long.Mean_SecondDeriv)]);

        c1= colorbar(ax1);
        if haveSleep
            scatter(ax1,Drifts_long.Mean_FirstDeriv,Drifts_long.Mean_SecondDeriv,...
            [],Drifts_long.PercentNapOverlap,...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax1); c1.Label.String = 'Nap Overlap (%)';
        else
            scatter(ax1,Drifts_long.Mean_FirstDeriv,Drifts_long.Mean_SecondDeriv,...
            [],Drifts_long.PercentGlideOverlap,...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax1); c1.Label.String = 'Glide Overlap (%)';
        end
        title(ax1,'Long Drifts Identified (each dot is a >100s segment)');
        xline(ax1,first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(ax1,-first_deriv_drift_threshold,'-','Lower Drift Threshold');
        yline(ax1,second_deriv_drift_threshold,'-','Acceleration Threshold');yline(ax1,-second_deriv_drift_threshold,'-','Acceleration Threshold');
        ylabel(ax1,'Mean Second Derivative (m/s^2'); xlabel(ax1,'Mean First Derivative (m/s)');

        ax4 = subplot(3,2,4); ylim([-0.2 0.2]); ylim([min(Drifts_long.Mean_SecondDeriv) max(Drifts_long.Mean_SecondDeriv)]);
        if haveSleep
            scatter(ax4,Filtered_Drifts_long.Mean_FirstDeriv,Filtered_Drifts_long.Mean_SecondDeriv,...
            [],Filtered_Drifts_long.PercentNapOverlap,...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax4); c1.Label.String = 'Nap Overlap (%)';
        else
            scatter(ax4,Filtered_Drifts_long.Mean_FirstDeriv,Filtered_Drifts_long.Mean_SecondDeriv,...
            [],Filtered_Drifts_long.PercentGlideOverlap,...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c1= colorbar(ax4); c1.Label.String = 'Glide Overlap (%)';
        end
        title(ax4,'Filtered Long Drifts Identified (each dot is a >100s segment)');
        xline(ax4,first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(ax4,-first_deriv_drift_threshold,'-','Lower Drift Threshold');
        yline(ax4,second_deriv_drift_threshold,'-','Acceleration Threshold');yline(ax4,-second_deriv_drift_threshold,'-','Acceleration Threshold');
        ylabel(ax4,'Mean Second Derivative (m/s^2'); xlabel(ax4,'Mean First Derivative (m/s)');

        % Plot first and second derivatives for sleep segments that are NOT benthic
        % or long Surface Intervals
        ax2 = subplot(3,2,5); ylim([-0.2 0.2]);
        if haveSleep
            % Plot all sleep segments, except those on land, at the surface, or on the seafloor
            % Color yellow if REM; blue if SWS
            scatter(ax2,NewRaw.FirstDeriv(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            NewRaw.SecondDeriv(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            [],NewRaw.is_long_drift(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c2= colorbar; c2.Label.String = 'is identified as long drift';
            title(ax2,'True EEG Sleep (each dot is 10s)');
        else
            % Plot all long glide segments, except those on land, at the surface, or on the seafloor
            % Color yellow if overlaps with identified drift; blue if does not
            scatter(ax2,NewRaw.FirstDeriv(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            NewRaw.SecondDeriv(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            [],NewRaw.is_long_drift(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.01,'SizeData',10);
            c2= colorbar; c2.Label.String = 'is long drift';
            title(ax2,'True Long Glides (each dot is 10s)');
        end

        ylabel('Second Derivative (m/s^2'); xlabel('First Derivative (m/s)');
        yline(second_deriv_drift_threshold,'-','Acceleration Threshold');yline(-second_deriv_drift_threshold,'-','Acceleration Threshold');
        xline(first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(-first_deriv_drift_threshold,'-','Lower Drift Threshold');

        ax5 = subplot(3,2,6); ylim([-0.2 0.2]);
        if haveSleep
            % Plot all sleep segments, except those on land, at the surface, or on the seafloor
            % Color yellow if REM; blue if SWS
            scatter(ax5,NewRaw.FirstDeriv(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            NewRaw.SecondDeriv(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            [],NewRaw.is_filtered_long_drift(find(NewRaw.is_sleep & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0 & NewRaw.Water_Num>0)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.3,'SizeData',10);
            c3= colorbar; c3.Label.String = 'is identified as filtered long drift';
            title(ax5,'True EEG Sleep (each dot is 10s of sleep)');
        else
            % Plot all long glide segments, except those on land, at the surface, or on the seafloor
            % Color yellow if overlaps with identified drift; blue if does not
            scatter(ax5,NewRaw.FirstDeriv(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            NewRaw.SecondDeriv(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            [],NewRaw.is_filtered_long_drift(find(NewRaw.is_long_glide==1 & NewRaw.is_long_flat==0 & NewRaw.is_long_SI==0)),...
            'filled','jitter','on', 'jitterAmount', 0.05,'MarkerFaceAlpha',0.01,'SizeData',10);
            c3= colorbar; c3.Label.String = 'is identified as filtered long drift';
            title(ax5,'All Long Glides (each dot is 10s of long glide)');
        end

        ylabel('Second Derivative (m/s^2'); xlabel('First Derivative (m/s)');
        yline(second_deriv_drift_threshold,'-','Acceleration Threshold');yline(-second_deriv_drift_threshold,'-','Acceleration Threshold');
        xline(first_deriv_drift_threshold,'-','Upper Drift Threshold');xline(-first_deriv_drift_threshold,'-','Lower Drift Threshold');

        ylim([ax0,ax3],[-0.1 0.1]); ylim([ax1,ax4],[-0.01 0.01]); ylim([ax2, ax5], [-0.1 0.15]);
        linkaxes([ax0,ax1,ax2,ax3,ax4,ax5],'x');
        h = colorbar;
        set( h, 'YDir', 'reverse' );
        print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_03_Drift-Dive-Stats.png'))
    end
    

    disp('Section 03.B Complete: Drift stats plotted.')

    %% 03.C EXAMINE DRIFT FILTER OUTPUT
    close all
    
    if haveStrokeData | haveSleepData
    
    % Check elimination of drift dives to make sure it's not too
    % inclusive or restrictive.
    figure

    
    ax1=subplot(2,1,1); set(gcf, 'Position',  [100, 100, 1800, 800]);
    % Plot Depth record
    plot(ax1,NewRaw.time, NewRaw.CorrectedDepth,'Color',recording_col); hold on
    ax1.YDir='reverse'; ylabel('Depth (m)'); xlabel('Time');
    datetick('x','mmm-dd HH:MM')
    title(ax1,strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Rest Dives'));

    % Highlight sections that fit first & second deriv criteria
    a0 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_drift,...
        'ShowBaseline','off','FaceColor',[1 0 0],'LineStyle', 'none','FaceAlpha',0.4); hold on;
    % Highlight sections with unfiltered long drifts
    a1 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_unfiltered_long_drift,...
        'ShowBaseline','off','FaceColor',[1 0 0],'LineStyle', 'none','FaceAlpha',0.1); hold on;
    % Highlight sections with filtered long drifts
    a2 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_filtered_long_drift,...
        'ShowBaseline','off','FaceColor',drifting_col,'LineStyle', 'none','FaceAlpha',1); hold on;
    a3 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_long_flat,...
        'ShowBaseline','off','FaceColor',sleeping_col,'LineStyle', 'none','FaceAlpha',1); hold on;

    if haveSleep
        a4 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_sleep,...
        'ShowBaseline','off','FaceColor',REM_col,'LineStyle', 'none','FaceAlpha',0.4); hold on;
        legend('Depth','Drifts (unfiltered all)','Long Drifts (unfiltered)','Filtered Long Drifts','Sleep');
    elseif haveStrokes | haveKami
        a4 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth.*NewRaw.is_long_glide,...
        'ShowBaseline','off','FaceColor',REM_col,'LineStyle', 'none','FaceAlpha',0.4); hold on;
        if haveKami
            scatter(NewRaw.time(find(NewRaw.is_feeding==1)),NewRaw.CorrectedDepth(find(NewRaw.is_feeding==1)),[],[1 0 0],'filled','SizeData',10,'MarkerFaceAlpha',0.5);
            legend('Depth','Drifts (unfiltered all)','Long Drifts (unfiltered)','Filtered Long Drifts','Long Glides','KAMI data');
        else
            legend('Depth','Drifts (unfiltered all)','Long Drifts (unfiltered)','Filtered Long Drifts','Long Glides');
        end
    else
        legend('Depth','Drifts (unfiltered all)','Long Drifts (unfiltered)','Filtered Long Drifts');
    end

    ax2=subplot(2,1,2);
    title(ax2,strcat('Seal: ',SEALID, ' TOPPID:',TOPPID,' Rest Dive Filtering'));

    err1 = 0.3;

    % Plot regions where smoothing filter will eliminate drifts after day ~100
    drift1 = area(ax2,NewRaw.time(find(NewRaw.is_long_drift)),NewRaw.SmoothFirstDeriv(find(NewRaw.is_long_drift))+err1,'LineStyle', 'none','FaceColor',drifting_col,'BaseValue',-1,'FaceAlpha',0.5); hold on;
    drift2 = area(ax2,NewRaw.time(find(NewRaw.is_long_drift)),NewRaw.SmoothFirstDeriv(find(NewRaw.is_long_drift))-err1,'LineStyle', 'none','FaceColor',recording_col,'BaseValue',-1,'FaceAlpha',0.5); hold on;

    scatter(ax2,NewRaw.time(find(NewRaw.is_long_drift)),NewRaw.FirstDeriv(find(NewRaw.is_long_drift)),[],drifting_col,'filled','SizeData',5);
%     scatter(ax2,Drifts_long.Start_JulDate,Drifts_long.DriftRate,...
%     [],[1 0 0],'filled','MarkerFaceAlpha',0.4,'SizeData',Drifts_long.Duration_s/10);

    if haveSleep
        scatter(ax2,Naps.Start_JulDate,Naps.DriftRate,...
        [],REM_col,'filled','SizeData',Naps.Duration_s/5,'MarkerFaceAlpha',0.6);
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],recording_col,'filled','SizeData',Filtered_Drifts_long.Duration_s/5);
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.PercentNapOverlap,...
        'filled','SizeData',Filtered_Drifts_long.Duration_s/10);
        c3= colorbar('southoutside'); c3.Label.String = 'Nap Overlap (%)';
    elseif haveStrokes
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],recording_col,'filled','SizeData',Filtered_Drifts_long.Duration_s/5);
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.PercentGlideOverlap,...
        'filled','SizeData',Filtered_Drifts_long.Duration_s/10);
        c3= colorbar('southoutside'); c3.Label.String = 'Glide Overlap (%)';
    else
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],recording_col,'filled','SizeData',Filtered_Drifts_long.Duration_s/5);
        scatter(ax2,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.DriftRate,...
        'filled','SizeData',Filtered_Drifts_long.Duration_s/10);
        c3= colorbar('southoutside'); c3.Label.String = 'Drift Rate (m/s)';
    end
    legend('Within Drift Filter','Below Drift Filter','Long Drift First Derivatives','Filtered-out Drifts','outline','Filtered Long Drifts')

    linkaxes([ax1,ax2],'x');
    ylim([min(Filtered_Drifts_long.DriftRate)-0.5 max(Filtered_Drifts_long.DriftRate)+0.5]);
    xlim([min(NewRaw.time) max(NewRaw.time)])
%     print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_03_Drift-Dive-Output.png'))

    disp('Section 03.C Complete: Drift filtering plotted.')

    %% 03.D - SAVE SNAPSHOTS throughout the trip
    % Then save it as a picture:

    t1 = Dives.Start_JulDate(5);
    t2 = Dives.Start_JulDate(height(Dives)-5);
    trip = range(t1:t2);

    % LOOK AT BEGINNING OF TRIP
    % Look at         1%   5%  10% 20% 30% 40% 50% 60% 70% 80% 90% 95%  99%
%     trip_percents = [0.01 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 0.95 0.99];
    trip_percents = [0.01 0.2 0.4 0.5 0.6 0.8 0.99];
    for d = 1:length(trip_percents)
        xlim([t1+trip_percents(d)*trip t1+trip_percents(d)*trip+1]); ylim(ax1,[-1000 1400]);
        datetick(ax2,'x','dd-mmm-yyyy HH:MM:SS')
        print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_03_Drift-Dive-Output_Trip-percent-',num2str(trip_percents(d)*100,'%03d'),'_24h.png'))
    end

    disp('Section 03.D Complete: Snapshots saved.')
    
    end
    %% 04.A - SUMMARIZE REST & ACCURACY ACROSS DIVES
    close all
    NewRaw.is_rest = NewRaw.is_filtered_long_drift + NewRaw.is_long_SI;

    if haveSleep
        for d = 1:height(REMs)
            startix = REMs.Indices(d,1);
            endix = REMs.Indices(d,2);
            duration = (endix-startix)+1;
            REMs.PercentLongGlideOverlap(d) = 100 * (sum(NewRaw.is_long_glide(startix:endix))/duration);
            REMs.PercentLongDriftOverlap(d) = 100 * (sum(NewRaw.is_filtered_long_drift(startix:endix))/duration);
            catC=categorical(convertCharsToStrings(NewRaw.Water_Code(startix:endix)));
            catNames=categories(catC);
            [~,ix] = max(countcats(catC));
            REMs.Water_Code(d) = {catNames{ix}};
        end

        for d = 1:height(Naps)
            startix = Naps.Indices(d,1);
            endix = Naps.Indices(d,2);
            duration = (endix-startix)+1;
            Naps.PercentLongGlideOverlap(d) = 100 * (sum(NewRaw.is_long_glide(startix:endix))/duration);
            Naps.PercentLongDriftOverlap(d) = 100 * (sum(NewRaw.is_filtered_long_drift(startix:endix))/duration);
            catC=categorical(convertCharsToStrings(NewRaw.Water_Code(startix:endix)));
            catNames=categories(catC);
            [~,ix] = max(countcats(catC));
            Naps.Water_Code(d) = {catNames{ix}};
        end

        Dives.TN = NaN(height(Dives),1);
        Dives.FN = NaN(height(Dives),1);
        Dives.FP = NaN(height(Dives),1);
        Dives.TP = NaN(height(Dives),1);
        Dives.accuracy = NaN(height(Dives),1);
        Dives.sensitivity = NaN(height(Dives),1);
        Dives.specificity = NaN(height(Dives),1);
    end

    for d = 1:height(Dives)
        startix = Dives.Indices(d,1);
        endix = Dives.Indices(d,2);
        Dives.max_depth(d) = max(NewRaw.CorrectedDepth (startix:endix) );
        Dives.descenttime(d) = SamplingInterval * sum(NewRaw.is_descent (startix:endix) );
        Dives.ascenttime(d) = SamplingInterval * sum(NewRaw.is_ascent (startix:endix) );
        Dives.bottomtime(d) = Dives.Duration_s(d)-Dives.ascenttime(d)-Dives.descenttime(d);
        Dives.time_drift(d) = SamplingInterval * length(find(NewRaw.is_filtered_long_drift(startix:endix))) + SamplingInterval * length(find(NewRaw.is_long_flat(startix:endix)));
        Dives.is_drift(d) = SamplingInterval * sum(NewRaw.is_drift (startix:endix) );
        Dives.is_long_flat(d) = SamplingInterval * sum(NewRaw.is_long_flat (startix:endix) );
        Dives.is_unfiltered_long_drift(d) = SamplingInterval * sum(NewRaw.is_long_drift (startix:endix) );
        Dives.is_filtered_long_drift(d) = SamplingInterval * sum(NewRaw.is_filtered_long_drift (startix:endix) );
        Dives.is_long_SI(d) = SamplingInterval * sum(NewRaw.is_long_SI (startix:endix) );

        if haveStrokes
            Dives.TN_restglides0(d) = nan; Dives.FN_restglides0(d) = nan; Dives.FP_restglides0(d) = nan; Dives.TP_restglides0(d) = nan;
            Dives.accuracy_restglides0(d) = nan; Dives.sensitivity_restglides0(d) = nan;  Dives.specificity_restglides0(d) = nan;
            
            Dives.TN_restglides(d) = nan; Dives.FN_restglides(d) = nan; Dives.FP_restglides(d) = nan; Dives.TP_restglides(d) = nan;
            Dives.accuracy_restglides(d) = nan; Dives.sensitivity_restglides(d) = nan;  Dives.specificity_restglides(d) = nan;
            
            Dives.is_glide(d) = SamplingInterval * sum(NewRaw.is_glide (startix:endix) );
            Dives.is_long_glide(d) = SamplingInterval * sum(NewRaw.is_long_glide (startix:endix) );
            if haveKami
                Dives.KAMI(d) = sum(NewRaw.KAMI (startix:endix));
            end

            % KNOWN group: long glides, PREDICTED group: UNFILTERED rest identifier
            % For each dive, how good is our (unfiltered) rest identifier at identifying long glides? 
            S0=confusionmat(NewRaw.is_long_glide(startix:endix)+1,NewRaw.is_long_drift(startix:endix)+1);
            if size(S0)==[1 1]
                continue
            end

            TN_restglides0 = S0(1,1); FN_restglides0 = S0(2,1); FP_restglides0 = S0(1,2); TP_restglides0 = S0(2,2);
            
            Dives.TN_restglides0(d) = TN_restglides0; Dives.FN_restglides0(d) = FN_restglides0; 
            Dives.FP_restglides0(d) = FP_restglides0; Dives.TP_restglides0(d) = TP_restglides0;
            Dives.accuracy_restglides0(d) = (TP_restglides0 + TN_restglides0)/sum(S0,'all');
            % Sensitivity or true positivity rate (TP/(TP+FN))
            Dives.sensitivity_restglides0(d) = TP_restglides0/(TP_restglides0+FN_restglides0);
            % Specificity or true negative rate (TN/(TN+FP))
            Dives.specificity_restglides0(d) = TN_restglides0/(TN_restglides0+FP_restglides0);

            % KNOWN group: long glides, PREDICTED group: FILTERED rest identifier
            % For each dive, how good is our (filtered) rest identifier at identifying long glides? 
            S=confusionmat(NewRaw.is_long_glide(startix:endix)+1,NewRaw.is_filtered_long_drift(startix:endix)+1);
            if size(S)==[1 1]
                continue
            end

            TN_restglides = S(1,1); FN_restglides = S(2,1); FP_restglides = S(1,2); TP_restglides = S(2,2);
            Dives.TN_restglides(d) = TN_restglides; Dives.FN_restglides(d) = FN_restglides; 
            Dives.FP_restglides(d) = FP_restglides; Dives.TP_restglides(d) = TP_restglides;
            Dives.accuracy_restglides(d) = (TP_restglides + TN_restglides)/sum(S,'all');
            Dives.sensitivity_restglides(d) = TP_restglides/(TP_restglides+FN_restglides);
            Dives.specificity_restglides(d) = TN_restglides/(TN_restglides+FP_restglides);

        end
        if haveSleep
            Dives.is_sleep(d) = SamplingInterval * sum(NewRaw.is_sleep (startix:endix) );
            Dives.is_REM(d) = SamplingInterval * sum(NewRaw.is_REM (startix:endix) );

            catC=categorical(convertCharsToStrings(NewRaw.Water_Code(startix:endix)));
            catNames=categories(catC);
            [~,ix] = max(countcats(catC));
            Dives.Water_Code(d) = {catNames{ix}};

            % KNOWN group: sleep, PREDICTED group: DRIFTS (all)
            % For each dive, how well does the first deriv/second deriv (alone) estimate the amount of sleep? 
            C00=confusionmat(NewRaw.is_sleep(startix:endix)+1,NewRaw.is_drift(startix:endix)+1);
            if size(C00)==[1 1]
                continue
            end
            TN_restsleeps00 = C00(1,1); FN_restsleeps00 = C00(2,1); FP_restsleeps00 = C00(1,2); TP_restsleeps00 = C00(2,2);
            Dives.TN_restsleeps00(d) = TN_restsleeps00; Dives.FN_restsleeps00(d) = FN_restsleeps00; 
            Dives.FP_restsleeps00(d) = FP_restsleeps00; Dives.TP_restsleeps00(d) = TP_restsleeps00; 
            Dives.accuracy_restsleeps00(d) = (TP_restsleeps00 + TN_restsleeps00)/sum(C00,'all');
            Dives.sensitivity_restsleeps00(d) = TP_restsleeps00/(TP_restsleeps00+FN_restsleeps00);
            Dives.specificity_restsleeps00(d) = TN_restsleeps00/(TN_restsleeps00+FP_restsleeps00);

            % KNOWN group: sleep, PREDICTED group: rest identifier
            % For each dive, how good is our (unfiltered) rest identifier at estimating the amount of sleep? 
            C0=confusionmat(NewRaw.is_sleep(startix:endix)+1,NewRaw.is_long_drift(startix:endix)+1);
            if size(C0)==[1 1]
                continue
            end
            TN_restsleeps0 = C0(1,1); FN_restsleeps0 = C0(2,1); FP_restsleeps0 = C0(1,2); TP_restsleeps0 = C0(2,2);
            Dives.TN_restsleeps0(d) = TN_restsleeps0; Dives.FN_restsleeps0(d) = FN_restsleeps0; 
            Dives.FP_restsleeps0(d) = FP_restsleeps0; Dives.TP_restsleeps0(d) = TP_restsleeps0; 
            Dives.accuracy_restsleeps0(d) = (TP_restsleeps0 + TN_restsleeps0)/sum(C0,'all');
            Dives.sensitivity_restsleeps0(d) = TP_restsleeps0/(TP_restsleeps0+FN_restsleeps0);
            Dives.specificity_restsleeps0(d) = TN_restsleeps0/(TN_restsleeps0+FP_restsleeps0);

            % KNOWN group: sleep, PREDICTED group: rest identifier
            % For each dive, how good is our (filtered) rest identifier at estimating the amount of sleep? 
            C=confusionmat(NewRaw.is_sleep(startix:endix)+1,NewRaw.is_filtered_long_drift(startix:endix)+1);
            if size(C)==[1 1]
                continue
            end
            TN_restsleeps = C(1,1); FN_restsleeps = C(2,1); FP_restsleeps = C(1,2); TP_restsleeps = C(2,2);
            Dives.TN_restsleeps(d) = TN_restsleeps; Dives.FN_restsleeps(d) = FN_restsleeps; 
            Dives.FP_restsleeps(d) = FP_restsleeps; Dives.TP_restsleeps(d) = TP_restsleeps; 
            Dives.accuracy_restsleeps(d) = (TP_restsleeps + TN_restsleeps)/sum(C,'all');
            Dives.sensitivity_restsleeps(d) = TP_restsleeps/(TP_restsleeps+FN_restsleeps);
            Dives.specificity_restsleeps(d) = TN_restsleeps/(TN_restsleeps+FP_restsleeps);

            % KNOWN group: sleep, PREDICTED group: (any length) glides
            % For each dive, how well do glides approximate the amount of sleep an animal gets?
            G=confusionmat(NewRaw.is_sleep(startix:endix)+1,NewRaw.is_glide(startix:endix)+1);
            if size(G)==[1 1]
                continue
            end
            TN_glidesleeps0 = G(1,1); FN_glidesleeps0 = G(2,1); FP_glidesleeps0 = G(1,2); TP_glidesleeps0 = G(2,2);
            Dives.TN_glidesleeps0(d) = TN_glidesleeps0; Dives.FN_glidesleeps0(d) = FN_glidesleeps0; 
            Dives.FP_glidesleeps0(d) = FP_glidesleeps0; Dives.TP_glidesleeps0(d) = TP_glidesleeps0; 
            Dives.accuracy_glidesleeps0(d) = (TP_glidesleeps0 + TN_glidesleeps0)/sum(G,'all');
            Dives.sensitivity_glidesleeps0(d) = TP_glidesleeps0/(TP_glidesleeps0+FN_glidesleeps0);
            Dives.specificity_glidesleeps0(d) = TN_glidesleeps0/(TN_glidesleeps0+FP_glidesleeps0);

            % KNOWN group: sleep, PREDICTED group: long glides
            % For each dive, how well do long glides approximate the amount of sleep an animal gets?
            G=confusionmat(NewRaw.is_sleep(startix:endix)+1,NewRaw.is_long_glide(startix:endix)+1);
            if size(G)==[1 1]
                continue
            end
            TN_glidesleeps = G(1,1); FN_glidesleeps = G(2,1); FP_glidesleeps = G(1,2); TP_glidesleeps = G(2,2);
            Dives.TN_glidesleeps(d) = TN_glidesleeps; Dives.FN_glidesleeps(d) = FN_glidesleeps; 
            Dives.FP_glidesleeps(d) = FP_glidesleeps; Dives.TP_glidesleeps(d) = TP_glidesleeps; 
            Dives.accuracy_glidesleeps(d) = (TP_glidesleeps + TN_glidesleeps)/sum(G,'all');
            Dives.sensitivity_glidesleeps(d) = TP_glidesleeps/(TP_glidesleeps+FN_glidesleeps);
            Dives.specificity_glidesleeps(d) = TN_glidesleeps/(TN_glidesleeps+FP_glidesleeps);

        end
    end

    Seals_Used.Dives_maxDepth(k) = max(Dives.max_depth);
    Seals_Used.Dives_meanmaxDepth(k) = mean(Dives.max_depth);
    Seals_Used.Dives_medianmaxDepth(k) = median(Dives.max_depth);
    Seals_Used.Dives_stdmaxDepth(k) = std(Dives.max_depth);
    
    disp('Section 04.A Complete: Rest summarized across dives.')

    %% 04.B - CALCULATE ACCURACY OF REST-IDENTIFICATION MODEL

    if haveSleep & haveStrokes
        % Find overall performance (filter out time on land and add 1 to both because
        % doesn't work on binary 0 1 original data)

        % KNOWN group: sleep, PREDICTED group: DRIFTS (all)
        % For this seal, how well does the first deriv/second deriv (alone) estimate the amount of sleep? 
        figure
        C00=confusionmat(NewRaw.is_sleep(find(NewRaw.Water_Num>0))+1,NewRaw.is_drift(find(NewRaw.Water_Num>0))+1);

        CC00 = confusionchart(C00); CC00.XLabel = 'Unfiltered Rest Identifier - Predicted Class'; CC00.YLabel = 'EEG Sleep - True Class';
        title('Accuracy of Drifts to Predict Sleep')
        TN_restsleeps00 = C00(1,1); FN_restsleeps00 = C00(2,1); FP_restsleeps00 = C00(1,2); TP_restsleeps00 = C00(2,2);
        Seals_Used.TN_restsleeps00(k) = TN_restsleeps00; Seals_Used.FN_restsleeps00(k) = FN_restsleeps00; 
        Seals_Used.FP_restsleeps00(k) = FP_restsleeps00; Seals_Used.TP_restsleeps00(k) = TP_restsleeps00; 
        Seals_Used.accuracy_restsleeps00(k) = (TP_restsleeps00 + TN_restsleeps00)/sum(C00,'all');
        Seals_Used.sensitivity_restsleeps00(k) = TP_restsleeps00/(TP_restsleeps00+FN_restsleeps00);
        Seals_Used.specificity_restsleeps00(k) = TN_restsleeps00/(TN_restsleeps00+FP_restsleeps00);

        % KNOWN group: sleep, PREDICTED group: unfiltered rest identifier
        % For this seal, how good is our (unfiltered) rest identifier at estimating the amount of sleep? 
        figure
        C0=confusionmat(NewRaw.is_sleep(find(NewRaw.Water_Num>0))+1,NewRaw.is_long_drift(find(NewRaw.Water_Num>0))+1);

        CC0 = confusionchart(C0); CC0.XLabel = 'Unfiltered Rest Identifier - Predicted Class'; CC0.YLabel = 'EEG Sleep - True Class';
        title('Accuracy of Unfiltered Rest Identifier to Predict Sleep')
        TN_restsleeps0 = C0(1,1); FN_restsleeps0 = C0(2,1); FP_restsleeps0 = C0(1,2); TP_restsleeps0 = C0(2,2);
        Seals_Used.TN_restsleeps0(k) = TN_restsleeps0; Seals_Used.FN_restsleeps0(k) = FN_restsleeps0; 
        Seals_Used.FP_restsleeps0(k) = FP_restsleeps0; Seals_Used.TP_restsleeps0(k) = TP_restsleeps0; 
        Seals_Used.accuracy_restsleeps0(k) = (TP_restsleeps0 + TN_restsleeps0)/sum(C0,'all');
        Seals_Used.sensitivity_restsleeps0(k) = TP_restsleeps0/(TP_restsleeps0+FN_restsleeps0);
        Seals_Used.specificity_restsleeps0(k) = TN_restsleeps0/(TN_restsleeps0+FP_restsleeps0);

        % KNOWN group: sleep, PREDICTED group: filtered rest identifier
        % For this seal, how good is our (filtered) rest identifier at estimating the amount of sleep? 
        figure
        C=confusionmat(NewRaw.is_sleep(find(NewRaw.Water_Num>0))+1,NewRaw.is_filtered_long_drift(find(NewRaw.Water_Num>0))+1);

        CC = confusionchart(C); CC.XLabel = 'Filtered Rest Identifier - Predicted Class'; CC.YLabel = 'EEG Sleep - True Class';
        title('Accuracy of Filtered Rest Identifier to Predict Sleep')
        TN_restsleeps = C(1,1); FN_restsleeps = C(2,1); FP_restsleeps = C(1,2); TP_restsleeps = C(2,2);
        Seals_Used.TN_restsleeps(k) = TN_restsleeps; Seals_Used.FN_restsleeps(k) = FN_restsleeps; 
        Seals_Used.FP_restsleeps(k) = FP_restsleeps; Seals_Used.TP_restsleeps(k) = TP_restsleeps; 
        Seals_Used.accuracy_restsleeps(k) = (TP_restsleeps + TN_restsleeps)/sum(C,'all');
        Seals_Used.sensitivity_restsleeps(k) = TP_restsleeps/(TP_restsleeps+FN_restsleeps);
        Seals_Used.specificity_restsleeps(k) = TN_restsleeps/(TN_restsleeps+FP_restsleeps);

        % KNOWN group: sleep, PREDICTED group: (any length) glides
        % For this seal, how well do glides approximate the amount of sleep an animal gets?
        figure
        title('Accuracy of Glides (any length) to Predict Sleep')
        G0=confusionmat(NewRaw.is_sleep(find(NewRaw.Water_Num>0))+1,NewRaw.is_glide(find(NewRaw.Water_Num>0))+1);

        GG0 = confusionchart(G0); GG0.XLabel = 'Glides - Predicted Class'; GG0.YLabel = 'EEG Sleep - True Class';
        title('Accuracy of Glides (any length) to Predict Sleep')
        TN_glidesleeps0 = G0(1,1); FN_glidesleeps0 = G0(2,1); FP_glidesleeps0 = G0(1,2); TP_glidesleeps0 = G0(2,2);
        Seals_Used.TN_glidesleeps0(k) = TN_glidesleeps0; Seals_Used.FN_glidesleeps0(k) = FN_glidesleeps0; 
        Seals_Used.FP_glidesleeps0(k) = FP_glidesleeps0; Seals_Used.TP_glidesleeps0(k) = TP_glidesleeps0; 
        Seals_Used.accuracy_glidesleeps0(k) = (TP_glidesleeps0 + TN_glidesleeps0)/sum(G0,'all');
        Seals_Used.sensitivity_glidesleeps0(k) = TP_glidesleeps0/(TP_glidesleeps0+FN_glidesleeps0);
        Seals_Used.specificity_glidesleeps0(k) = TN_glidesleeps0/(TN_glidesleeps0+FP_glidesleeps0);

        % KNOWN group: sleep, PREDICTED group: long glides
        % For this seal, how well do long glides approximate the amount of sleep an animal gets?
        figure
        G=confusionmat(NewRaw.is_sleep(find(NewRaw.Water_Num>0))+1,NewRaw.is_long_glide(find(NewRaw.Water_Num>0))+1);

        GG = confusionchart(G); GG.XLabel = 'Long Glides - Predicted Class'; GG.YLabel = 'EEG Sleep - True Class';
        title('Accuracy of Long Glides to Predict Sleep')
        TN_glidesleeps = G(1,1); FN_glidesleeps = G(2,1); FP_glidesleeps = G(1,2); TP_glidesleeps = G(2,2);
        Seals_Used.TN_glidesleeps(k) = TN_glidesleeps; Seals_Used.FN_glidesleeps(k) = FN_glidesleeps; 
        Seals_Used.FP_glidesleeps(k) = FP_glidesleeps; Seals_Used.TP_glidesleeps(k) = TP_glidesleeps; 
        Seals_Used.accuracy_glidesleeps(k) = (TP_glidesleeps + TN_glidesleeps)/sum(G,'all');
        Seals_Used.sensitivity_glidesleeps(k) = TP_glidesleeps/(TP_glidesleeps+FN_glidesleeps);
        Seals_Used.specificity_glidesleeps(k) = TN_glidesleeps/(TN_glidesleeps+FP_glidesleeps);

    end

    if haveStrokes

        % KNOWN group: long glides, PREDICTED group: UNFILTERED rest identifier
        % For this seal, how good is our (unfiltered) rest identifier at identifying long glides? 
        figure
        S0=confusionmat(NewRaw.is_long_glide(find(NewRaw.is_dive))+1,NewRaw.is_long_drift(find(NewRaw.is_dive))+1);

        SS0 = confusionchart(S0); SS0.XLabel = 'Filtered Rest Identifier - Predicted Class'; SS0.YLabel = 'Long Glides - True Class';
        title('Accuracy of UNFILTERED Rest Identifier (to detect long glides)')
        TN_restglides0 = S0(1,1); FN_restglides0 = S0(2,1); FP_restglides0 = S0(1,2); TP_restglides0 = S0(2,2);
        Seals_Used.TN_restglides0(k) = TN_restglides0; Seals_Used.FN_restglides0(k) = FN_restglides0; 
        Seals_Used.FP_restglides0(k) = FP_restglides0; Seals_Used.TP_restglides0(k) = TP_restglides0;
        Seals_Used.accuracy_restglides0(k) = (TP_restglides0 + TN_restglides0)/sum(S0,'all');
        % Sensitivity or true positivity rate (TP/(TP+FN))
        Seals_Used.sensitivity_restglides0(k) = TP_restglides0/(TP_restglides0+FN_restglides0);
        % Specificity or true negative rate (TN/(TN+FP))
        Seals_Used.specificity_restglides0(k) = TN_restglides0/(TN_restglides0+FP_restglides0);

        % KNOWN group: long glides, PREDICTED group: FILTERED rest identifier
        % For this seal, how good is our (filtered) rest identifier at identifying long glides? 
        figure
        S=confusionmat(NewRaw.is_long_glide(find(NewRaw.is_dive))+1,NewRaw.is_filtered_long_drift(find(NewRaw.is_dive))+1);

        SS = confusionchart(S); SS.XLabel = 'Filtered Rest Identifier - Predicted Class'; SS.YLabel = 'Long Glides - True Class';
        title('Accuracy of FILTERED Rest Identifier (to detect long glides)')
        TN_restglides = S(1,1); FN_restglides = S(2,1); FP_restglides = S(1,2); TP_restglides = S(2,2);
        Seals_Used.TN_restglides(k) = TN_restglides; Seals_Used.FN_restglides(k) = FN_restglides; 
        Seals_Used.FP_restglides(k) = FP_restglides; Seals_Used.TP_restglides(k) = TP_restglides;
        Seals_Used.accuracy_restglides(k) = (TP_restglides + TN_restglides)/sum(S,'all');
        Seals_Used.sensitivity_restglides(k) = TP_restglides/(TP_restglides+FN_restglides);
        Seals_Used.specificity_restglides(k) = TN_restglides/(TN_restglides+FP_restglides);

    end

    disp('Section 04.B Complete: Accuracy of rest sequence calculated and provided.')

    %% 05.A - IDENTIFY REST SEQUENCES - FIND SLEEP CYCLES / BOUTS OF SLEEP ACROSS MULTIPLE DIVES OR APNEAS
    close all

    if haveSleep
        Dives.is_sleep_bout(find(Dives.is_sleep>0)) = 1;
        Apneas.is_sleep_bout(find(Apneas.is_sleep>0)) = 1;

        Apneas_sleep_bouts = table(yt_setones(Apneas.is_sleep_bout),'VariableNames',{'Indices'});
        Apneas_sleep_bouts.N = 1 + Apneas_sleep_bouts.Indices(:,2)-Apneas_sleep_bouts.Indices(:,1);
        Apneas_sleep_bouts.Start_JulDate = Apneas.Start_JulDate(Apneas_sleep_bouts.Indices(:,1));
        Apneas_sleep_bouts.End_JulDate = Apneas.End_JulDate(Apneas_sleep_bouts.Indices(:,2));
        Apneas_sleep_bouts.Duration_s = round(86400 * (Apneas_sleep_bouts.End_JulDate - Apneas_sleep_bouts.Start_JulDate));

        for f = 1:height(Apneas_sleep_bouts)
            Apneas.is_apnea_sleep_bout(Apneas_sleep_bouts.Indices(f,1):Apneas_sleep_bouts.Indices(f,2)) = 1;
        end

        Dives_sleep_bouts = table(yt_setones(Dives.is_sleep_bout),'VariableNames',{'Indices'});
        Dives_sleep_bouts.N = 1 + Dives_sleep_bouts.Indices(:,2)-Dives_sleep_bouts.Indices(:,1);
        Dives_sleep_bouts.Start_JulDate = Dives.Start_JulDate(Dives_sleep_bouts.Indices(:,1));
        Dives_sleep_bouts.End_JulDate = Dives.End_JulDate(Dives_sleep_bouts.Indices(:,2));
        Dives_sleep_bouts.Duration_s = round(86400 * (Dives_sleep_bouts.End_JulDate - Dives_sleep_bouts.Start_JulDate));

        for f = 1:height(Dives_sleep_bouts)
            NewRaw.is_dive_sleep_bout(Dives_sleep_bouts.Indices(f,1):Dives_sleep_bouts.Indices(f,2)) = 1;
        end
    end

    % Find bouts of sleeping dives (benthic or drift)
    Dives.is_rest_bout(find(Dives.is_filtered_long_drift)) = 1;
    Dives_rest_bouts = table(yt_setones(Dives.is_rest_bout),'VariableNames',{'Indices'});
    Dives_rest_bouts.N = 1 + Dives_rest_bouts.Indices(:,2)-Dives_rest_bouts.Indices(:,1);

    % Getting an index for each bout of drift dives
    Dives.rest_bout_num(:) = nan;
    Dives.rest_bout_num(find(Dives.is_filtered_long_drift)) = 0;
    Dives.rest_bout_num(Dives_rest_bouts.Indices(:,1)) = 1;
    Dives.rest_bout_num2(~isnan(Dives.rest_bout_num)) = cumsum(Dives.rest_bout_num(~isnan(Dives.rest_bout_num)),'omitnan');

    % Getting an index for each dive in a bout of drift dives
    dive_count = 0;
    for i = 1 : height(Dives)
        if ~isnan(Dives.rest_bout_num(i))
            dive_count = dive_count + 1;
            Dives.rest_bout_num3(i) = dive_count;
        else
            dive_count = 0; 
            Dives.rest_bout_num3(i) = nan;
        end
    end

    for f = 1:height(Dives)
        NewRaw.rest_bout_num(Dives.Indices(f,1):Dives.Indices(f,2)) = Dives.rest_bout_num(f);
        NewRaw.rest_bout_num2(Dives.Indices(f,1):Dives.Indices(f,2)) = Dives.rest_bout_num2(f);
        NewRaw.rest_bout_num3(Dives.Indices(f,1):Dives.Indices(f,2)) = Dives.rest_bout_num3(f);
    end

    Seals_Used.dives_rest_bout_num(k) = sum(Dives.rest_bout_num);
    Seals_Used.dives_rest_bout_maxlength(k) = max(Dives_rest_bouts.N);
    if haveSleep
        Seals_Used.dives_sleep_bout_num(k) = height(Dives_sleep_bouts);
        Seals_Used.dives_sleep_bout_maxlength(k) = max(Dives_sleep_bouts.N);
        Seals_Used.apnea_sleep_bout_num(k) = height(Apneas_sleep_bouts);
        Seals_Used.apnea_sleep_bout_maxlength(k) = max(Apneas_sleep_bouts.N);
    end
    
    disp('Section 05.A Complete: Rest sequences identified and enumerated.')

    %% 05.B - SUMMARIZE DAILY DIVING ACTIVITY

    Dives.JulDay = floor(Dives.Start_JulDate);
    Dives.JulTime_of_day = Dives.Start_JulDate - Dives.JulDay;
    [unique_Days, ~, Days] = unique(floor(NewRaw.time), 'first');
    [unique_Dive_Days, ~, Dive_days] = unique(Dives.JulDay, 'first');
    Daily_Activity = table(unique_Days);
    Daily_DiveActivity = table(unique_Dive_Days);
    
    % Calculations done in hours per day        
    Daily_DiveActivity.dailydive_num_filtered_long_drift = accumarray(Dive_days, Dives.is_filtered_long_drift, [], @numel);
    Daily_DiveActivity.dailydive_num_rest_bouts = accumarray(Dive_days, Dives.rest_bout_num);
    Daily_DiveActivity.dailydive_longest_rest_bout = accumarray(Dive_days, Dives.rest_bout_num3, [], @max);
    Daily_DiveActivity.dailydive_drift = accumarray(Dive_days, Dives.is_drift)/3600;
    Daily_DiveActivity.dailydive_long_flat = accumarray(Dive_days, Dives.is_long_flat)/3600;
    Daily_DiveActivity.dailydive_unfiltered_long_drift = accumarray(Dive_days, Dives.is_unfiltered_long_drift)/3600;
    Daily_DiveActivity.dailydive_filtered_long_drift = accumarray(Dive_days, Dives.is_filtered_long_drift)/3600;

    if haveStrokes
        Daily_DiveActivity.dailydive_glide = accumarray(Dive_days, Dives.is_glide)/3600;
        Daily_DiveActivity.dailydive_long_glide = accumarray(Dive_days, Dives.is_long_glide)/3600;
        if haveKami
            Daily_DiveActivity.dailydive_KAMI = accumarray(Dive_days, Dives.KAMI);
        end
    end
    if haveSleep
        Daily_DiveActivity.dailydive_sleep = accumarray(Dive_days, Dives.is_sleep)/3600;
        Daily_DiveActivity.dailydive_REM = accumarray(Dive_days, Dives.is_REM)/3600;
    end

    disp('Section 05.B Complete: Daily diving activity summarized.')

    %% 05.C - SUMMARIZE DAILY ACTIVITY (including land sleep if applicable)

    % Daily activity (includes land sleep)
    Daily_Activity.Days_Elapsed = Daily_Activity.unique_Days -  Daily_Activity.unique_Days(1);
    Daily_Activity.daily_recording = SamplingInterval * accumarray(Days, NewRaw.time(:), [], @numel)/3600;
    Daily_Activity.Lat = accumarray(Days, NewRaw.Lat(:), [], @mean);
    Daily_Activity.Long = accumarray(Days, NewRaw.Long(:), [], @mean);
    Daily_Activity.daily_diving = accumarray(Days, SamplingInterval * NewRaw.is_dive)/3600;
    Daily_Activity.daily_SI = accumarray(Days, SamplingInterval * NewRaw.is_SI)/3600;
    Daily_Activity.daily_long_SI = accumarray(Days, SamplingInterval* NewRaw.is_long_SI)/3600; 
    Daily_Activity.daily_filtered_long_drift = accumarray(Days, SamplingInterval* NewRaw.is_filtered_long_drift)/3600;
    Daily_Activity.daily_filtered_long_drift_long_SI = accumarray(Days, SamplingInterval* NewRaw.is_long_SI)/3600 + accumarray(Days, SamplingInterval* NewRaw.is_filtered_long_drift)/3600;
    Daily_Activity.daily_unfiltered_long_drift = accumarray(Days, SamplingInterval* NewRaw.is_unfiltered_long_drift)/3600;
    Daily_Activity.daily_unfiltered_long_drift_long_SI = accumarray(Days, SamplingInterval* NewRaw.is_long_SI)/3600 + accumarray(Days, SamplingInterval* NewRaw.is_unfiltered_long_drift)/3600;
    Daily_Activity.daily_drift = accumarray(Days, SamplingInterval* NewRaw.is_drift)/3600;
   
    if haveSleep
        Daily_Activity.daily_all_sleep = accumarray(Days, SamplingInterval * NewRaw.is_sleep)/3600;
        Daily_Activity.daily_all_REM = accumarray(Days, SamplingInterval * NewRaw.is_REM)/3600;
    end
    Daily_DiveActivity.unique_Days = Daily_DiveActivity.unique_Dive_Days;
    Daily_Activity = outerjoin(Daily_Activity, Daily_DiveActivity, 'Keys','unique_Days','MergeKeys',true);

    % Eliminate dives that last more than 24 h (mis-identified haulouts)
    Daily_DiveActivity = Daily_DiveActivity(find(Daily_DiveActivity.dailydive_long_flat<24),:);

    % Eliminate days with more than 24 h or less than 6 h
    Full_Days_Daily_Activity = Daily_Activity(find(round(Daily_Activity.daily_recording)<=24 & Daily_Activity.daily_recording>15),:);

    if height(Full_Days_Daily_Activity) < 2
        continue
        Seals_Used.Daily_Stats_Not_Provided(k) = 1;
        disp('Record too short to record summary statistics')
    end 
    
    Seals_Used.Mean_filtered_long_drift_h(k) = mean(Full_Days_Daily_Activity.daily_filtered_long_drift);
    Seals_Used.SD_filtered_long_drift_h(k) = std(Full_Days_Daily_Activity.daily_filtered_long_drift);
    Seals_Used.Mean_filtered_long_drift_with_SI(k) = mean(Full_Days_Daily_Activity.daily_filtered_long_drift + Full_Days_Daily_Activity.daily_long_SI);
    Seals_Used.SD_filtered_long_drift_with_SI(k) = std(Full_Days_Daily_Activity.daily_filtered_long_drift + Full_Days_Daily_Activity.daily_long_SI);
    Seals_Used.Mean_unfiltered_rest_h(k) = mean(Full_Days_Daily_Activity.daily_unfiltered_long_drift);
    Seals_Used.SD_unfiltered_rest_h(k) = std(Full_Days_Daily_Activity.daily_unfiltered_long_drift);
    Seals_Used.Mean_drift_h(k) = mean(Full_Days_Daily_Activity.daily_drift);
    Seals_Used.SD_drift_h(k) = std(Full_Days_Daily_Activity.daily_drift);

    if haveSleep
        Seals_Used.Mean_EEG_sleep(k) = mean(Full_Days_Daily_Activity.daily_all_sleep);
        Seals_Used.SD_EEG_sleep(k) = std(Full_Days_Daily_Activity.daily_all_sleep);
    end

    disp('Section 05.C Complete: Daily activity summarized.')

    %% 05.D CALCULATE SUNRISES / SUNSETS / DAYLENGTHS
    % Find sunrise time, sunset time, and daylengths.

    if haveLatLong
        if haveSleep
            for i = 1:height(Daily_Activity)
            [sunrises(i,1), sunsets(i,1), daylengths(i,1)] = sunrise(Daily_Activity.Lat(i), Daily_Activity.Long(i),...
            0, -7, datevec(Daily_Activity.unique_Days(i)));
            end
        else
            for i = 1:height(Daily_Activity)
                [sunrises(i,1), sunsets(i,1), daylengths(i,1)] = sunrise(Daily_Activity.Lat(i), Daily_Activity.Long(i),...
                0, 0, datevec(Daily_Activity.unique_Days(i)));
            end
        end
    else % if other data, date/time in UTC.
        [sunrises, sunsets, daylengths] = sunrise(37.116121, -122.330722,... % Use Ano coordinates
            0, -7, datevec(unique_Days));
    end

    % make column for nighttime/daytime data
    sunrise_Times = table(sunrises, sunsets, daylengths);
    sunrise_Times.unique_Days = floor(sunrise_Times.sunrises);
    NewRaw.is_night(:) = 1;
    for d = 1:height(sunrise_Times)
        NewRaw.is_night(find(NewRaw.time >= sunrise_Times.sunrises(d) & NewRaw.time <= sunrise_Times.sunsets(d))) = 0 ;
    end

    sunrise_Times.Sunrise_time_of_day = 24*(sunrise_Times.sunrises - floor(sunrise_Times.sunrises));
    sunrise_Times.Sunset_time_of_day = 24*(sunrise_Times.sunsets - floor(sunrise_Times.sunsets));

    Daily_Activity = outerjoin(Daily_Activity, sunrise_Times, 'Keys','unique_Days','MergeKeys',true);

    disp('Section 05.D Complete: Sunrise and sunset times queried.')

    %% 0.6B PLOT SUMMARY DATA - Plot daily activity patterns
    figure

    ax1=subplot(2,1,1); set(gcf, 'Position',  [100, 100, 1400, 900]);

    % Highlight SURFACING
    area(ax1,Daily_Activity.unique_Days,Daily_Activity.daily_recording,'ShowBaseline','off',...
        'FaceColor',surfacing_col,'LineStyle', 'none','FaceAlpha',1); hold on;
    % Highlight DIVING
    area(ax1,Daily_Activity.unique_Days,Daily_Activity.daily_diving,'ShowBaseline','off',...
        'FaceColor',recording_col,'LineStyle', 'none','FaceAlpha',0.8); hold on;
    if haveStrokes % Highlight GLIDING
        area(ax1,Daily_Activity.unique_Days,Daily_Activity.dailydive_long_glide,'ShowBaseline','off',...
            'FaceColor',gliding_col,'LineStyle', 'none','FaceAlpha',0.8); hold on;
    end
    % Highlight DRIFTS + SIs
    area(ax1,Daily_Activity.unique_Days,Daily_Activity.dailydive_unfiltered_long_drift+Daily_Activity.daily_long_SI,...
        'ShowBaseline','off','FaceColor',drifting_col,'LineStyle', 'none','FaceAlpha',0.3); hold on;
    % Highlight DRIFTS
    area(ax1,Daily_Activity.unique_Days,Daily_Activity.dailydive_filtered_long_drift+Daily_Activity.daily_long_SI,...
        'ShowBaseline','off','FaceColor',surfacing_col,'LineStyle', 'none','FaceAlpha',1); hold on;
     % Highlight DRIFTS
    area(ax1,Daily_Activity.unique_Days,Daily_Activity.dailydive_filtered_long_drift+Daily_Activity.daily_long_SI,...
        'ShowBaseline','off','FaceColor',drifting_col,'LineStyle', 'none','FaceAlpha',1); hold on;
    if haveSleep % Highlight SLEEP (SWS + REM)
        area(ax1,Daily_Activity.unique_Days,Daily_Activity.daily_all_sleep,...
        'ShowBaseline','off','FaceColor',sleeping_col,'LineStyle', 'none','FaceAlpha',0.8); hold on;
        area(ax1,Daily_Activity.unique_Days,Daily_Activity.daily_all_REM,...
        'ShowBaseline','off','FaceColor',REM_col,'LineStyle', 'none','FaceAlpha',0.8); hold on;
    end
    yline(2,':') % Plot reference line at 2 h/day
    if haveStrokes & haveSleep
        legend('surface','diving','gliding','Drift (unfiltered long drifts & long surface intervals)','Drift (filtered long drifts only)','Sleep (SWS + REM)','REM Sleep','2h/day')
    elseif haveStrokes & haveSleep==0
        legend('surface','diving','gliding','Drift (unfiltered long drifts & long surface intervals)','Drift (filtered long drifts only)','2h/day')
    else
        legend('surface','diving','Drift (upper bound)','Drift (best estimate)','2h/day')
    end
    ylabel('Hours per day'); xlabel('Date'); ylim([0 24]); datetick('x','mm/dd')

    title(ax1,strcat('TOPPID: ', TOPPID, ' SEAL ID: ', SEALID, ' Daily Activity Patterns'));

    ax2=subplot(2,1,2);
    area(ax2,Daily_Activity.unique_Days,Daily_Activity.daily_recording,...
        'ShowBaseline','off',...
        'FaceColor',surfacing_col,'LineStyle', 'none','FaceAlpha',1);hold on;
    area(ax2,Daily_Activity.unique_Days,Daily_Activity.Sunrise_time_of_day,...
        'ShowBaseline','off',...
        'FaceColor',recording_col,'LineStyle', 'none','FaceAlpha',0.8);hold on;
    area(ax2,Daily_Activity.unique_Days,Daily_Activity.Sunset_time_of_day,...
        'ShowBaseline','off',...
        'FaceColor',surfacing_col,'LineStyle', 'none','FaceAlpha',1);hold on;
    scatter(ax2, Drifts_long.JulDay, Drifts_long.Time_of_day_h,...
    [],[1 0 0],'filled','SizeData',Drifts_long.Duration_s/30,...
    'MarkerFaceAlpha',0.2);

    scatter(ax2, Drifts_long.JulDay, Drifts_long.Time_of_day_h,...
    [],Drifts_long.DriftRate,'filled','SizeData',Drifts_long.Duration_s/30,...
    'MarkerFaceAlpha',0.2);
    scatter(ax2, Filtered_Drifts_long.JulDay, Filtered_Drifts_long.Time_of_day_h,...
    [],Filtered_Drifts_long.DriftRate,'filled','SizeData',Filtered_Drifts_long.Duration_s/30);
    
 c = colorbar('southoutside');
    colormap default;    
    c.Label.String = 'Drift Rate';

scatter(ax2, SIs_long.JulDay, SIs_long.Time_of_day_h,...
    [],recording_col,'SizeData',SIs_long.Duration_s/30);

    legend('Pre-Sunset','Nighttime','Post-Sunrise','Rest Dives', 'Extended Surface Intervals')
    ylabel('Time of Day')
    xlabel('Date')

    title(ax2,strcat('TOPPID: ', TOPPID, ' SEAL ID: ', SEALID, ' Rest and Sunrise Across Trip'));

    linkaxes([ax1,ax2],'x');
    xlim(ax2,[min(Daily_Activity.unique_Days) max(Daily_Activity.unique_Days)]);
    ylim([0 24]);
    datetick('x','mm/dd')
    c = colorbar('southoutside');
    colormap default;
    
    print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_06_Daily-Activity-Patterns_DriftRate.png'))
    
    scatter(ax2, Filtered_Drifts_long.JulDay, Filtered_Drifts_long.Time_of_day_h,...
    [],Filtered_Drifts_long.End_Light,'filled','SizeData',Filtered_Drifts_long.Duration_s/10);
    scatter(ax2, Filtered_Drifts_long.JulDay, Filtered_Drifts_long.Time_of_day_h,...
    [],Filtered_Drifts_long.Start_Light,'filled','SizeData',Filtered_Drifts_long.Duration_s/30);

    scatter(ax2, SIs_long.JulDay, SIs_long.Time_of_day_h,...
    [],recording_col,'SizeData',SIs_long.Duration_s/30);

    c.Label.String = 'Light Level';

    print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_06_Daily-Activity-Patterns_LightLevel.png'))
    disp('Section 06.B Complete: Daily activity patterns plotted.')

    if haveSleep
    %% 06.B - PLOT DEPTH RECORD with identification
    % Plotting depth record 
    close all

    figure
    ax1=subplot(5,1,[1:2]);
    plot(ax1,NewRaw.time, NewRaw.CorrectedDepth,'Color',recording_col);
    ax1.YDir='reverse';
    title([num2str(TOPPID) ' Drift Dives']);
    ylabel('Depth (m)');
    xlabel('Time');
    datetick('x','dd/mmm/yy HH:MM')
    hold on
    set(gcf, 'Position',  [100, 100, 1800, 800]);

    if haveSleep
        a1 = area(ax1, NewRaw.time,NewRaw.CorrectedDepth(:).*NewRaw.is_sleep(:),...
            'ShowBaseline','off',...
            'FaceColor',REM_col,'LineStyle', 'none','FaceAlpha',0.6);
    end

    a2 = area(ax1, NewRaw.time,-100*NewRaw.is_night(:),...
        'ShowBaseline','off',...
        'FaceColor',recording_col,'LineStyle', 'none','FaceAlpha',0.5);

    NewRaw.is_rest_plot(:) = 0; 
    NewRaw.is_rest_plot(find(NewRaw.is_filtered_long_drift==1 | NewRaw.is_long_SI==1)) = NewRaw.CorrectedDepth(find(NewRaw.is_filtered_long_drift==1 | NewRaw.is_long_SI==1));
    
    a3 = area(ax1, NewRaw.time,NewRaw.is_rest_plot(:),...
        'ShowBaseline','off',...
        'FaceColor',drifting_col,'LineStyle', 'none','FaceAlpha',0.6);

    a5 = area(ax1, NewRaw.time,NewRaw.is_drift(:).*NewRaw.CorrectedDepth,...
        'ShowBaseline','off',...
        'FaceColor',drifting_col,'LineStyle', 'none','FaceAlpha',0.15);
    
    if haveKami
        scatter(ax1, NewRaw.time(find(NewRaw.is_feeding==1 & NewRaw.is_dive)), ...
            NewRaw.CorrectedDepth(find(NewRaw.is_feeding==1 & NewRaw.is_dive)),...
        [],[1 0 0],'filled','SizeData',45,'MarkerFaceAlpha',0.6);
    end
    
    % Plot depth
    scatter(ax1, NewRaw.time, NewRaw.CorrectedDepth,[],surfacing_col,'filled','SizeData',20);
    % Plot Dives
    scatter(ax1, NewRaw.time(find(NewRaw.is_dive==1)), NewRaw.CorrectedDepth(find(NewRaw.is_dive==1)),...
    [],diving_col,'filled','SizeData',10);

    if haveStrokes
        % Plot Glides
        scatter(ax1, NewRaw.time(find(NewRaw.is_long_glide==1)), NewRaw.CorrectedDepth(find(NewRaw.is_long_glide==1)),...
        [],gliding_col,'filled','SizeData',10);
        if haveSleep == 0
            a6 = area(ax1, NewRaw.time,NewRaw.is_long_glide(:).*NewRaw.CorrectedDepth,...
            'ShowBaseline','off',...
            'FaceColor',REM_col,'LineStyle', 'none','FaceAlpha',0.15);
        end
    end

    % Plot Long Drifts
    scatter(ax1, NewRaw.time(find(NewRaw.is_filtered_long_drift==1)), NewRaw.CorrectedDepth(find(NewRaw.is_filtered_long_drift==1))+150,...
    [],drifting_col,'filled','SizeData',10);
    % Plot Long SIs
    scatter(ax1, NewRaw.time(find(NewRaw.is_long_SI==1)), NewRaw.CorrectedDepth(find(NewRaw.is_long_SI==1))-20,...
    [],drifting_col,'filled','SizeData',10);

    if haveSleep % Plot SWS & REM in green
        scatter(ax1, NewRaw.time(find(NewRaw.is_sleep==1)), NewRaw.CorrectedDepth(find(NewRaw.is_sleep==1)),...
        [],sleeping_col,'filled','SizeData',15);
        % Plot REM in yellow on top of SWS & REM
        scatter(ax1, NewRaw.time(find(NewRaw.is_REM==1)), NewRaw.CorrectedDepth(find(NewRaw.is_REM==1)),...
        [],REM_col,'filled','SizeData',15);
    end

    % Adding points for begin & end of ID'd drift segments
    scatter(ax1,Filtered_Drifts_long.Start_JulDate, Filtered_Drifts_long.Start_Depth+150,[],recording_col,'filled','SizeData',70) 
    scatter(ax1,Filtered_Drifts_long.End_JulDate, Filtered_Drifts_long.End_Depth+150,[],recording_col,'filled','SizeData',70)
    scatter(ax1,SIs_long.Start_JulDate,   SIs_long.Start_Depth-20,   [],[0.4431    0.7412    0.7412],'filled') 
    scatter(ax1,SIs_long.End_JulDate,     SIs_long.Start_Depth-20,   [],[0.2941    0.5882    0.5882],'filled')

    if haveSleep % Plot Nap Overlap
        scatter(ax1,Filtered_Drifts_long.Start_JulDate, Filtered_Drifts_long.Start_Depth+150,[],Filtered_Drifts_long.PercentNapOverlap,'filled') 
        scatter(ax1,Filtered_Drifts_long.End_JulDate,   Filtered_Drifts_long.End_Depth+150,  [],Filtered_Drifts_long.PercentNapOverlap,'filled')
        c = colorbar('east');
        c.Label.String = 'Percent Nap Overlap';
        colormap default;
    end

    if haveStrokes & haveSleep ==0 % Plot Nap Overlap
        scatter(ax1,Filtered_Drifts_long.Start_JulDate, Filtered_Drifts_long.Start_Depth+150,[],Filtered_Drifts_long.PercentGlideOverlap,'filled') 
        scatter(ax1,Filtered_Drifts_long.End_JulDate,   Filtered_Drifts_long.End_Depth+150,  [],Filtered_Drifts_long.PercentGlideOverlap,'filled')
        c = colorbar('east');
        c.Label.String = 'Percent Glide Overlap';
        colormap default;
    end
    

    ax4=subplot(5,1,5);
    x = Drifts_long.Start_JulDate;
    err1 = 0.25;
    ax4=subplot(5,1,5); hold on;
    plot(ax4,NewRaw.time(find(NewRaw.is_filtered_long_drift)),NewRaw.SmoothFirstDeriv(find(NewRaw.is_filtered_long_drift))); hold on;

    ax4=subplot(5,1,5);
    scatter(ax4,NewRaw.time(find(NewRaw.is_filtered_long_drift)),NewRaw.FirstDeriv(find(NewRaw.is_filtered_long_drift)),[],drifting_col,'SizeData',5);
    % scatter(ax4, Drifts_long.Start_JulDate,Drifts_long.DriftRate,...
    % [],[1 0 0],'filled','SizeData',10,'MarkerFaceAlpha',0.3);
    scatter(ax4,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],recording_col,...
        'filled','SizeData',80);
    if haveSleep
        scatter(ax4,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.PercentNapOverlap,...
        'filled','SizeData',50); c1 = colorbar('east');
        c1.Label.String = 'Percent Nap Overlap';
    elseif haveStrokes & haveSleep ==0
        scatter(ax4,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.PercentGlideOverlap,...
        'filled','SizeData',50); c1 = colorbar('east');
        c1.Label.String = 'Percent Glide Overlap';
    else 
        scatter(ax4,Filtered_Drifts_long.Start_JulDate,Filtered_Drifts_long.DriftRate,...
        [],Filtered_Drifts_long.DriftRate,...
        'filled','SizeData',50); c1 = colorbar('east');
        c1.Label.String = 'Drift Rate (m/s)';
    end

    ax2=subplot(5,1,3);
    plot(ax2,NewRaw.time, NewRaw.FirstDeriv, 'Color', [diving_col 0.3])
    ylabel('First Derivative (m/s)');

    if haveSleep
        ax2=subplot(5,1,3);
        plot(ax2,NewRaw.time, NewRaw.HR_VLF_Power, 'Color', [1 0 0 0.5]);
        hold on; plot(ax2,NewRaw.time, NewRaw.L_EEG_Delta, 'Color', [0 0 1 0.5]);
        ylabel('L EEG Delta (blue) & HR VLF Power (red)');
    else
        ax2=subplot(5,1,3);
        plot(ax2,NewRaw.time, NewRaw.FirstDeriv, 'Color', [diving_col 0.3])
        ylabel('First Derivative (m/s)');
    end

    if haveStrokes
        ax3=subplot(5,1,4);
        plot(ax3,NewRaw.time, NewRaw.Stroke_Rate, 'Color', [recording_col 0.8])
        ylabel('Stroke Rate (strokes per min)');
        ylabel(ax4,'Stroke Rate (spm)');
    end

    linkaxes([ax1,ax2,ax3,ax4],'x');
    xlim([min(NewRaw.time) max(NewRaw.time)])
    ylim(ax1, [-60 max(NewRaw.CorrectedDepth)+150]) 
    ylim(ax2, [0 25])
    ylim(ax3, [0 80])
    ylim(ax4, [min(Drifts_long.DriftRate)-0.25 max(Drifts_long.DriftRate)+0.25])

    % cd(Data_path);
    % cd('Figures')
    % Save as lower-res png
    print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_SleepEstimates.png'))
    % % Save as High-res vector graphic
    % print('-painters','-dsvg', strcat(TOPPID,'_',SEALID,'_10_SleepEstimates.svg')) %

    disp('Section 06.C Complete: Drift identifications plotted.')

    % print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_06_Dive-Identifications.png'))

    %% 06.C - FIND A GOOD SPOT
    % Refresh helpful dateticks
    t1 = Dives.Start_JulDate(5);
    t2 = Dives.Start_JulDate(height(Dives)-5);
    trip = range(t1:t2);

    % LOOK AT BEGINNING OF TRIP
    trip_percents = [0.01 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 0.95 0.99];
    for d = 1:length(trip_percents)
        xlim([t1+trip_percents(d)*trip t1+trip_percents(d)*trip+1]); ylim(ax1,[-500 1400]);
        print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_06_Drift-Dive-Identifications_Trip-percent-',num2str(trip_percents(d)*100,'%03d'),'_24h.png'))
    end

    disp('Section 06.C Complete: Snapshots saved.')
    end

    %% 06.D - Plotting a nap map
    close all

    figure

    title('');
    geoplot(Dives.Lat,Dives.Long); hold on; set(gcf,'Position', [50, 50, 1000, 850]);
    gscatter0 = geoscatter(SIs_long.Lat,SIs_long.Long,[],REM_col,'filled','MarkerFaceAlpha',.5)
    %gscatter2 = geoscatter(Flats_long.Lat,Flats_long.Long,[],gliding_col,'filled','MarkerFaceAlpha',.5) 
    gscatter4 = geoscatter(Filtered_Drifts_long.Lat,Filtered_Drifts_long.Long,[],recording_col,'filled','MarkerFaceAlpha',0.8) 
    gscatter3 = geoscatter(Filtered_Drifts_long.Lat,Filtered_Drifts_long.Long,[],Filtered_Drifts_long.DriftRate,'filled','MarkerFaceAlpha',1) 
    gscatter0.SizeData = SIs_long.Duration_s/60;
    %gscatter2.SizeData = Flats_long.Duration_s;
    gscatter3.SizeData = Filtered_Drifts_long.Duration_s/60;
    gscatter4.SizeData = Filtered_Drifts_long.Duration_s/60*1.5;
    c = colorbar('southoutside');
    colormap default;
    c.Label.String = 'Drift Rate (m/s)';
    latpos = max(NewRaw.Lat)-0.1*range(NewRaw.Lat);
    longpos = max(NewRaw.Long)-0.05*range(NewRaw.Long);  
    min_drift_dur = min(Filtered_Drifts_long.Duration_s/60);
    max_drift_dur = max(Filtered_Drifts_long.Duration_s/60);
    max_SI_dur = max(SIs_long.Duration_s/60);
    geoscatter(latpos, longpos, max_SI_dur, REM_col,'filled','MarkerFaceAlpha',0.5) 
    text(latpos + 0.05*range(NewRaw.Lat), longpos,['Max SI duration: ' int2str(max_SI_dur/60) ' hours'], 'HorizontalAlignment','right')

    geoscatter(latpos - 0.1*range(NewRaw.Lat), longpos, max_drift_dur*1.5,recording_col,'filled','MarkerFaceAlpha',0.8) 
    geoscatter(latpos - 0.1*range(NewRaw.Lat), longpos, max_drift_dur,drifting_col,'filled','MarkerFaceAlpha',1)
    text(latpos - 0.1*range(NewRaw.Lat), longpos - 0.05*range(NewRaw.Long),['Max Drift duration: ' int2str(max_drift_dur) ' minutes \rightarrow'], 'HorizontalAlignment','right')

    geoscatter(latpos - 0.2*range(NewRaw.Lat), longpos, min_drift_dur*1.5,recording_col,'filled') 
    geoscatter(latpos - 0.2*range(NewRaw.Lat), longpos, min_drift_dur,drifting_col,'filled','MarkerFaceAlpha',1)
    text(latpos - 0.2*range(NewRaw.Lat), longpos - 0.02*range(NewRaw.Long), ['Min Drift duration: ' int2str(min_drift_dur) ' minutes \rightarrow'], 'HorizontalAlignment','right')

    print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_06_NapMap.png'))

    if haveSleep
        figure
        % Plotting a nap map
        geoplot(Dives.Lat,Dives.Long); hold on;
        gscatter0 = geoscatter(Naps.Lat,Naps.Long,[],Naps.Duration_s/60,'filled') 
        gscatter0.SizeData = Naps.Duration_s/60;
        c = colorbar('southoutside');
        colormap default;
        c.Label.String = 'Nap Duration (min)';

        % Plotting an accuracy map 
        % (true positives are green; false positives are blue; false negatives are yellow)
        figure
        geoplot(Dives.Lat,Dives.Long); hold on;
        gscatter0 = geoscatter(Naps.Lat,Naps.Long,[],REM_col,'filled') 
        %gscatter2 = geoscatter(Flats_long.Lat,Flats_long.Long,[],gliding_col,'filled','MarkerFaceAlpha',.5) 
        gscatter3 = geoscatter(Filtered_Drifts_long.Lat,Filtered_Drifts_long.Long,[],drifting_col,'filled','MarkerFaceAlpha',.5) 
        gscatter0.SizeData = Naps.Duration_s;
        %gscatter2.SizeData = Flats_long.Duration_s;
        gscatter3.SizeData = Filtered_Drifts_long.Duration_s;
    end

    disp('Section 06.D Complete: Nap map plotted.')

    %% SAVE YOUR DATA
    %save(strcat(TOPPID,'_',SEALID,'_Restimates_Analysis.mat'))
    
    Dives.TOPPID(:) = string(TOPPID);
    Dives.SEALID(:) = string(SEALID);
    
    Daily_Activity.TOPPID(:) = string(TOPPID);
    Daily_Activity.SEALID(:) = string(SEALID);
    
    SIs_long.TOPPID(:) = string(TOPPID);
    SIs_long.SEALID(:) = string(SEALID);
    
    Drifts_long.Label(:) = string('Drifts_long');
    Filtered_Drifts_long.Label(:) = string('Filtered_Drifts_long');
    
    LONG_Drifts = vertcat(Drifts_long,Filtered_Drifts_long);
    LONG_Drifts.TOPPID(:) = string(TOPPID);
    LONG_Drifts.SEALID(:) = string(SEALID);
    
    NewRaw.TOPPID(:) = string(TOPPID);
    NewRaw.SEALID(:) = string(SEALID);
    
    %% 06.A WRITE SUMMARY DATA

    writetable(Daily_Activity, strcat(TOPPID, '_',SEALID,'_','Daily_Activity.csv'));    
    writetable(Dives, strcat(TOPPID, '_',SEALID,'_', 'Dives.csv'));
    writetable(Seals_Used, strcat(TOPPID, '_',SEALID,'_','Seals_Used.csv'));
    writetable(LONG_Drifts, strcat(TOPPID, '_',SEALID,'_', 'LONG_Drifts.csv')); 
    writetable(SIs_long, strcat(TOPPID, '_',SEALID,'_', 'LONG_SIs.csv')); 

    if haveSleepData
        writetable(NewRaw, strcat(TOPPID, '_',SEALID,'_','NewRaw.csv'));  
        writetable(Naps, strcat(TOPPID, '_',SEALID,'_','Naps.csv'));  
    elseif haveStrokeData
        writetable(NewRaw, strcat(TOPPID, '_',SEALID,'_','NewRaw.csv'));   
    end
        
    disp('Section 06.A Complete: Summary CSVs written.')
end