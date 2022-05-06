function DS_W = window_data(DS, Settings)
% Window the dataset "DS" into multiple windows (segments), where "DS" is 
% a data structure obtained from "..\Labeling_Tool\package_data_w_label.m".
% Or you can generate "DS" yourself, as long as it meets the following
% structure.
%
% Input:
% Fields in "DS":
% DS.dataset_name     A string of the name of the dataset.
% DS.data_stack       m-by-n stacked data (not normalized). 
%                     Where m is the number of signal channels and
%                     n is the number of data points.
% DS.data_stack_norm  m-by-n stacked normalized data.
%                     Normalized in the sense that each signal channel (i.e.
%                     row) has mean 0 and std 1.
% DS.label_stack      k-by-n integer data labels. Where n is the number of
%                     data points, k is the number of label types.
%                     For example, there can be two types: pose and
%                     motion. For pose type, there can be {1-roll_left,
%                     2-roll_right, 3-roll_up_side_down} classes/categories.
%                     While for motion type, there can be {1-go_straight, 
%                     2-turn_left, 3-turn_right} classes/categories. 
%                     Then a data point can be labeled as [1;2], 
%                     which means the object is 1-rolling_left and
%                     2-truning_left. NOTE: 0 in the label is treated as 
%                     nan, i.e. no label available for that point.
%
% Fields in "Settings":
% Settings.label_good_pct     
%                     Defines the threshold for majority label percentage 
%                     within a window. I.e. for the total w data points 
%                     within a window, the window will obtain a valid 
%                     label if at least "label_good_pct" of these w data 
%                     points share that label.
% Settings.window_size        
%                     Defines the size of the sliding window in number of 
%                     data points.        
% Settings.window_over        
%                     Defines the percentage of overlaps between
%                     consecutive windows.
% Output: 
% DS_W.dataset_name   A string of the name of the dataset.
% DS_W.window_data    1-by-N cell array, each cell contains the un-normalized 
%                     data for a window. Data within each cell is m-by-w, 
%                     where m is the number of signal channels, and w is 
%                     the window size. 
% DS_W.window_data_norm
%                     1-by-N cell array, each cell contains the normalized 
%                     data for a window. Data within each cell is m-by-w, 
%                     where m is the number of signal channels, and w is 
%                     the window size. 
% DS_W.window_data_label
%                     1-by-N cell array, each cell contains the per-point  
%                     labels for a window. Data within each cell is k-by-w, 
%                     where k is the number of label types, and w is 
%                     the window size. 
% DS_W.window_label   k-by-N matrix with each row contains the dominant
%                     labels for a window. N is the number of windows and k
%                     is the number of label types.
%
% =======================
% Ding Zhang
% zhding@umich.edu
% Last Updated: 12/15/2020
% =======================
%

% Window settings.
% Number of samples in each window.
w = ceil(Settings.window_size);
% Virtual window size.
w_vt = (1 - Settings.window_over)*w;
% Total number of windows (frames) can be fitted.
N = floor((size(DS.data_stack, 2) - w + w_vt)/w_vt); 
% Number of label categories.
k = size(DS.label_stack, 1);

% Initialize variables.
DS_W.dataset_name = DS.dataset_name;
DS_W.window_data = cell(1,N);
DS_W.window_data_norm = cell(1,N);
DS_W.window_data_label = cell(1,N);
DS_W.window_label = zeros(k, N);

% Length of data.
N_data = length(DS.data_stack);

% Loop through each window.
for i = 1:N
  % Find start end indices.
  idx_start = round(w_vt * (i-1) + 1);
  idx_end = min(idx_start + w, N_data);
  Idx = idx_start:idx_end;
  
  % Copy window data.
  DS_W.window_data{i} = DS.data_stack(:, Idx);
  DS_W.window_data_norm{i} = DS.data_stack_norm(:, Idx);
  DS_W.window_data_label{i} = DS.label_stack(:, Idx);
  
  % Find dominant label. 
  mode_label = mode(DS_W.window_data_label{i}, 2);
  mode_count = sum(DS_W.window_data_label{i} == mode_label, 2);
  dominant_agree = mode_count./w >= Settings.label_good_pct;
  DS_W.window_label(dominant_agree, i) = mode_label(dominant_agree);
end

disp(['Windowing done for ', DS.dataset_name])
