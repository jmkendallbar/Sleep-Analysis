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
    
    
    % Create start datenum column based on Stroke data.
    writetable(NewRaw,strcat(SealID,'_stroke_raw_data.csv'))
    SealsUsed.CSV_generated(i) = 1;
    disp(SealID); disp('CSV file processed successfully');
end

writetable(SealsUsed,'Kami-Stroke-SealsUsed.csv');