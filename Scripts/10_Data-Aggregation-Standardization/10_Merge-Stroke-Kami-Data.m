%% Merge kami and stroke data
close all
clear all
Data_path='G:\My Drive\Dissertation Sleep\Sleep_Analysis\Data';
cd(Data_path);

cd('10_STROKE data NESE')
Stroke_Metadata = readtable('StartTime_and_SampFreq_ALL.xlsx');

Stroke_Files = dir('*_Stroke_Depth+Stroke.txt');
Kami_Files = dir('*_Kami_Depth+Temp+Kami.txt');

SealsUsed = table(Stroke_Files);

for i = 1:length(Stroke_Files)
    i=12
    clearvars -except i Stroke_Files Kami_Files Stroke_Metadata SealsUsed
    
    % Find SealID and associated available files.
    SealID = extractBefore(Stroke_Files(i).name,'_Stroke_Depth+Stroke.txt');
    SealsUsed.SealID(i) = {SealID};
    Seal_Files = dir([SealID '*.txt']);

    % Read stroke data and metadata.
    Stroke_data = readtable(strcat(SealID,'_Stroke_Depth+Stroke.txt'));
    Stroke_Start = datenum(Stroke_Metadata.ExcelStart(strcmp(Stroke_Metadata.FileName, strcat(SealID,'_Stroke_Depth+Stroke.txt'))));
    Stroke_SamplingInterval = Stroke_Metadata.SamplingInterval(strcmp(Stroke_Metadata.FileName, strcat(SealID,'_Stroke_Depth+Stroke.txt')));
    
    % If no start time was provided in metadata, skip file.
    if isempty(Stroke_Start)
        disp(SealID); disp('Stroke data not available due to logger malfunction - start time not provided')
        continue
    end
    
    % Calculate seconds elapsed based on provided SamplingInterval
    Stroke_data.Seconds(:) = round(linspace(0,height(Stroke_data)*Stroke_SamplingInterval,height(Stroke_data)));
    % Rename depth column to match required CSV format.
    Stroke_data.Depth = Stroke_data.DEPTH;
    
    % Get Kami metadata.
    Kami_Start = datenum(Stroke_Metadata.ExcelStart(strcmp(Stroke_Metadata.FileName, strcat(SealID,'_Kami_Depth+Temp+Kami.txt'))));
    Kami_SamplingInterval = Stroke_Metadata.SamplingInterval(strcmp(Stroke_Metadata.FileName, strcat(SealID,'_Kami_Depth+Temp+Kami.txt')));    
    
    % If there is Kami data and metadata, pair the two datastreams.
    if length(Seal_Files)==2 & ~isempty(Kami_Start)
        Kami_data = readtable(strcat(SealID,'_Kami_Depth+Temp+Kami.txt')); % load kami data
        
        % Calculate seconds elapsed based on provided SamplingInterval
        Kami_data.Seconds(:) = round(linspace(0,height(Kami_data)*Kami_SamplingInterval,height(Kami_data)));
        
        % Align kami data to stroke data.
        Timediff_s = round(86400*(Stroke_Start - Kami_Start)); % Find start time in seconds relative to Stroke data.
        Kami_data.Seconds = Kami_data.Seconds - Timediff_s; % Adjust Kami seconds to match Stroke seconds.
        NewRaw = outerjoin(Stroke_data, Kami_data, 'Keys','Seconds'); % Join kami & stroke using stroke-based seconds.
        NewRaw.date = Stroke_Start + NewRaw.Seconds_Stroke_data/86400;
        SealsUsed.Kami_Stroke_data_found(i) = 1;
        SealsUsed.Stroke_data_found(i) = 1;
        disp(SealID); disp('Both kami and stroke data found and imported.');
        
    elseif length(Seal_Files)==1 | isempty(Kami_Start) % If there is no Kami data or metadata
        NewRaw = Stroke_data; % Use the stroke data alone.
        NewRaw.date = Stroke_Start + NewRaw.Seconds/86400;
        SealsUsed.Stroke_data_found(i) = 1;
        disp(SealID); disp('Stroke data found and imported.');
    end
    
    %% Finescale Alignment
    [StrokeRaw_aligned KamiRaw_aligned, D] = alignsignals(NewRaw.DEPTH_Stroke_data(50000:100000),NewRaw.DEPTH_Kami_data(50000:100000));
    
    figure
    plot(StrokeRaw_aligned); hold on; plot(KamiRaw_aligned)
    set(gca, 'YDir','reverse');
    title(strcat('Seal: ',SealID,' Testing "Align Signals" function: yields delay D=', int2str(D)));
    % print('-painters','-dpng', strcat(TOPPID,'_',SEALID,'_10_01_Stroking-Dive_Finescale-Alignment.png'))
    
    NewRaw.prealigned_Stroke_Rate = NewRaw.COUNT;
    NewRaw.prealigned_KAMI = NewRaw.KAMI_L;
    NewRaw.prealigned_Depth = NewRaw.DEPTH_Stroke_data;
    
    if D < 0 % Stroke Data needs to be delayed by D
        NewRaw.COUNT(:) = [nan(abs(D),1); NewRaw.prealigned_Stroke_Rate(1:height(NewRaw)-abs(D))];
        NewRaw.Depth(:) = [nan(abs(D),1); NewRaw.prealigned_Depth(1:height(NewRaw)-abs(D))];
        NewRaw.KAMI_L(:) = [nan(abs(D),1); NewRaw.prealigned_KAMI(1:height(NewRaw)-abs(D))];
    elseif D > 0 % Stroke Data needs to be advanced by D
        NewRaw.COUNT(:) = [NewRaw.prealigned_Stroke_Rate(1+abs(D):height(NewRaw)); nan(abs(D),1)];
        NewRaw.Depth(:) = [NewRaw.prealigned_Depth(1+abs(D):height(NewRaw)); nan(abs(D),1)];
        NewRaw.KAMI_L(:) = [NewRaw.prealigned_KAMI(1+abs(D):height(NewRaw)); nan(abs(D),1)];
    else
        NewRaw.COUNT(:) = [NewRaw.prealigned_Stroke_Rate(1+abs(D):height(NewRaw))];
        NewRaw.Depth(:) = [NewRaw.prealigned_Depth(1+abs(D):height(NewRaw))];
        NewRaw.KAMI_L(:) = [NewRaw.prealigned_KAMI(1+abs(D):height(NewRaw))];
    end
    
        NewRaw.is_maybe_glide     = abs(NewRaw.Depth) > 15;
        NewRaw.is_maybe_swim       = abs(NewRaw.Depth) <= 15;
        Maybe_Glides                 = table(yt_setones(NewRaw.is_maybe_glide),'VariableNames',{'Indices'});
        Maybe_Swims                   = table(yt_setones(NewRaw.is_maybe_swim),'VariableNames',{'Indices'});
        Maybe_Glides.Duration_s      = (Maybe_Glides.Indices(:,2)-Maybe_Glides.Indices(:,1))*Stroke_SamplingInterval;
        Maybe_Swims.Duration_s        = (Maybe_Swims.Indices(:,2)-Maybe_Swims.Indices(:,1))*Stroke_SamplingInterval;
        Maybe_Glides = Maybe_Glides(find(Maybe_Glides.Duration_s~=0),:);
        Maybe_Swims = Maybe_Swims(find(Maybe_Swims.Duration_s~=0),:);

    % Concatenate all chunks to find first and last (whether recognized as
        % a dive or a surface interval).
        All_Chunks = vertcat(Maybe_Swims,Maybe_Glides);
        All_Chunks = sortrows(All_Chunks,'Indices');

        % Truncate by removing the last chunks of stuff
        % Include 1000 samples before and after to avoid truncating dives
        firstix = min(All_Chunks.Indices(:,2)) - 1000; 
        if firstix < 0
            firstix =1;
        end
        lastix  = max(All_Chunks.Indices(:,1)) + 1000;
        if lastix > height(NewRaw)
            lastix = height(NewRaw);
        end

        
        All_Chunks = All_Chunks(2:height(All_Chunks)-1,:);

        for i=1:height(All_Chunks)
            if All_Chunks.Duration_s(i)>10000
                NewRaw.COUNT(All_Chunks.Indices(i,1):All_Chunks.Indices(i,2)) = nan;
            end
        end

        % Take off first and last chunk
        NewRaw = NewRaw(firstix:lastix,:);

    NewRaw2 = table(NewRaw.Depth, NewRaw.COUNT, NewRaw.KAMI_L, NewRaw.date,'VariableNames',{'Depth','COUNT','KAMI_L','date'});

    % Create start datenum column based on Stroke data.
    writetable(NewRaw2,strcat(SealID,'_stroke_raw_data.csv'))
    SealsUsed.CSV_generated(i) = 1;
    disp(SealID); disp('CSV file processed successfully');
end

writetable(SealsUsed,'Kami-Stroke-SealsUsed.csv');