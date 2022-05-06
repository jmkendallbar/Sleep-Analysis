hypnogram= readtable('test31_FatiguedFiona_08_Hypnogram_JKB_5Hz.csv');
info = readtable('test31_FatiguedFiona_00_Metadata.csv');
%hypnogram.DN = datenum(info.ON_ANIMAL+(((1:height(hypnogram)).')/fs - 1/fs)/(24*3600));
hypnogram.Seconds = etime(datevec(info.ON_ANIMAL),datevec(track.DN(1))) + ((1:height(hypnogram)).')/fs - 1/fs;
track = table(pitch, roll, head, Ptrack(:,1),Ptrack(:,2),-Ptrack(:,3),geoPtrack(:,1),geoPtrack(:,2),-geoPtrack(:,3),speed.JJ,DN,...
    'VariableNames',{'pitch','roll','heading','x','y','z','geoX','geoY','Depth','speed','DN'});
track.ODBA = odba(Aw, fs);
track.Seconds = ((1:height(track)).')/fs - 1/fs;
track.DN = track.DN-0.04/(24*3600);
hypnotrack = innerjoin(hypnogram,track,'Keys','Seconds');

rates = readtable('test31_FatiguedFiona_05_ALL_PROCESSED_scored_JKB_120521.txt');
rates.Properties.VariableNames={'Time','Date','HeartRate','StrokeRate'};
startsec = track.Seconds(find(track.DN==datenum('2021-04-05 09:34:47','yyyy-mm-dd HH:MM:SS')))
rates.Seconds = startsec+((1:height(rates)).')/fs - 1/fs;
hypnotrack = innerjoin(hypnotrack,rates,'Keys','Seconds');
writetable(hypnotrack,'test31_FatiguedFiona_09_Hypnotrack_JKB_5Hz.csv');

label_stack_str = hypnotrack.Sleep_Code;
label_stack_cat = categorical(hypnotrack.Sleep_Code);

%% Count labels and map from string to numerical.
% Take multiple seconds to finish for long dataset.

% Numerical labels, to be updated soon.
label_stack_org = zeros(length(label_stack_str),1);

M_count = containers.Map;
M_name = containers.Map;
i_type = 0;
for i = 1:length(label_stack_str)
  label = label_stack_str{i};
  
  if ~M_count.isKey(label)
    M_count(label) = 1;
  else
    M_count(label) = M_count(label) + 1;
  end
  
  if ~M_name.isKey(label)
    i_type = i_type + 1;
    M_name(label) = i_type;
  end
  
  label_stack_org(i) = M_name(label);
end

label_names = M_name.keys;
label_id = zeros(size(label_names));
label_count = zeros(size(label_names));

for i = 1:length(label_names)
  label_count(i) = M_count(label_names{i});
  label_id(i) = M_name(label_names{i});
end

%label_types = label_types(label_id);
[label_id, idx_sort] = sort(label_id);
label_names = label_names(idx_sort);
for i_id = 1:length(label_names)
  label_names{i_id} = [num2str(i_id), '-', label_names{i_id}];
end
hypnotrack.Sleep_Color=label_stack_org;

plot(hypnotrack.Seconds, label_stack_org, 'x')
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

% whole track
s=scatter3(hypnotrack,'geoX','geoY','geoZ','filled','ColorVariable','speed2')

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



findpeaks(hypnotrack.ODBA)


vertspeed = [diff(hypnotrack.Depth)/0.2; 0];
diagspeed = smoothdata(vertspeed(:))./sin(hypnotrack.pitch(:));
hypnotrack.speed2 = abs(diagspeed);
hypnotrack.speed2 = smoothdata(hypnotrack.speed2);
hypnotrack.speed2(find(hypnotrack.StrokeRate>5 | hypnotrack.speed2>2))=2.5*hypnotrack.StrokeRate(find(hypnotrack.StrokeRate>5 | hypnotrack.speed2>2))/max(hypnotrack.StrokeRate); % MAX Speed is 2 m/s
%when on the ground make speed 0
hypnotrack.speed2(find(abs(smoothdata(vertspeed))<.01 & hypnotrack.Depth>10 & abs(hypnotrack.speed2)<0.01 & hypnotrack.StrokeRate<5))=0; 
%when upside down (not on the ground), make speed 0.2
hypnotrack.speed2(find(abs(smoothdata(vertspeed))<.05 & abs(smoothdata(vertspeed))>.01 & abs(hypnotrack.roll)>2 & abs(hypnotrack.speed2)>.01 & hypnotrack.StrokeRate<5))=0.25; 
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
