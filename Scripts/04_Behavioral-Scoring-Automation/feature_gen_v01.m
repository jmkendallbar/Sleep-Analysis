function FData = feature_gen_v01(XData)
% Setup basic feature generation.
%
% Input:
% XData                  K-by-1 cell array. Each cell corresponds to
%                        normalized data with in a window. 
%                        Data within each cell is m-by-w, 
%                        where m is the number of signal channels, and w is 
%                        the window size. 
% Output:
% FData                  K-by-F scalar array, with K being the number of
%                        windows and F being the number of features used.
%
% =======================
% Ding Zhang
% zhding@umich.edu
% Last Updated: 12/15/2020
% =======================

K = length(XData);
[m, w] = size(XData{1});

% Start with just mean and std of each channel as features.
F = 4*m; % Number of features. E.g. 15.
FData = zeros(K, F);

for k = 1:K
  data = XData{k};
  FData(k, 1:m) = [mean(data, 2)]';
  FData(k, m+1:2*m) = [std(data, 0, 2)]';
  FData(k, 2*m+1:3*m) = [max(data, [], 2)]';
  FData(k, 3*m+1:4*m) = [min(data, [], 2)]';
  
  % Examples on designing features individually.
  % FData(k, 1) = mean(data(1,:));
  % FData(k, 2) = std(data(1,:));
  % FData(k, 3) = selfDefinedFunction(data(2,:));
  % FData(k, m+1:2*m) = [std(data,0,2)]';
  
  % Examples on designing features individually.
  % FData(k, 1) = mean(data(1,:));
  % FData(k, 2) = std(data(1,:));
  % FData(k, 3) = selfDefinedFunction(data(2,:));
  % FData(k, 15) = entropy(data(3,:));
  
end

% Normalize the features.
%FData = (FData - mean(FData))./std(FData);
