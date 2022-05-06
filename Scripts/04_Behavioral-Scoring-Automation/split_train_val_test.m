function D_TVT = split_train_val_test(D_train, D_test, Settings)
% Split data into Training, Validation and Testing set.
% Input:
% D_train     Data structure that to be used for trainging and validation
%             sets.
% D_test      Data structure that to be used for testing set. If 
%             "dataset_name" of both "D_train" and "D_test" are the same,
%             the function will automatically select part of "D_train" for
%             training and validation and the rest of "D_train" for testing.
%
% Settings    Some settings for setting up the split.
%
% Fields in "D_train" and "D_test":
% D.dataset_name      A string of the name of the dataset. If the names of
%                     "D_train" and "D_test" are the same, then "D_train"
%                     will be used for generating both training and testing
%                     sets, regardless of whether data in "D_test" is
%                     different.
%
% D.window_data       1-by-N cell array, each cell contains the un-normalized 
%                     data for a window. Data within each cell is m-by-w, 
%                     where m is the number of signal channels, and w is 
%                     the window size. 
%
% D.window_data_norm  1-by-N cell array, each cell contains the normalized 
%                     data for a window. Data within each cell is m-by-w, 
%                     where m is the number of signal channels, and w is 
%                     the window size. 
%
% D.window_data_label 1-by-N cell array, each cell contains the per-point  
%                     labels for a window. Data within each cell is K-by-w, 
%                     where K is the number of label types, and w is 
%                     the window size. 
%                     For example, there can be two label types: pose and
%                     motion. For pose type, there can be {1-roll_left,
%                     2-roll_right, 3-roll_up_side_down} classes/categories.
%                     While for motion type, there can be {1-go_straight, 
%                     2-turn_left, 3-turn_right} classes/categories. 
%                     Then a data point can be labeled as [1;2], 
%                     which means the object is 1-rolling_left and
%                     2-truning_left. NOTE: 0 in the label is treated as 
%                     nan, i.e. no label available for that point.
%
% D.window_label      K-by-N matrix with each row contains the dominant
%                     labels for a window. N is the number of windows and K
%                     is the number of label types.
%
% Fields in "Settings":
% Settings.balanced_train   Bool variable for whether or not use a balanced
%                           training set. A balanced training set means the
%                           set has same amount of data for each class.
%
% Settings.if_normalize     Bool variable for whether or not using
%                           normalized data.
%
% Settings.target_label     K-by-1 or 1-by-K cell array for specifying the 
%                           target labels to focus on for each label type.
%                           Where k is the number of label types.
%                           For exampl, {[1:4], [1:3]} means we only want
%                           to focus on classes [1:4] for the first label
%                           type and classes [1:3] for the second label
%                           type. Even though there are other classes exist
%                           in the data as well.
%
% Settings.train_pct        The percetage amount of data to use for
%                           training set in "D_train".
%
% Settings.valid_pct        The percetage amount of data to use for
%                           validation set in "D_train".
%
% Settings.seed             Seed for controling random number generation.
%                           When set to 0 or nan, no seed will be used,
%                           random number generation not controled.
%
% Output:
% D_TVT                     Data structure contains following fields:
% D_TVT.train               K-by-1 cell array. Each cell corresponds to
%                           normalized training data of class type k. Data
%                           format within each of the K cells is the same
%                           as "D_train.window_data_norm".
% D_TVT.train_label         K-by-1 cell array. Each cell corresponds to
%                           window label of class type k. Data format 
%                           within each of the K cells is 1-by-N integer
%                           labels, similar to "D_train.window_label".
% D_TVT.valid               K-by-1 cell array for validation data, same
%                           format as "D_TVT.train".
% D_TVT.valid_label         K-by-1 cell array for validation data, same
%                           format as "D_TVT.train_label".
% D_TVT.test                K-by-1 cell array for test data, same
%                           format as "D_TVT.train".
% D_TVT.test_label          K-by-1 cell array for test data, same
%                           format as "D_TVT.train_label".
% D_TVT.train_name          A string of training dataset name.
% D_TVT.test_name           A string of testing dataset name.
%
%
% =======================
% Ding Zhang
% zhding@umich.edu
% Last Updated: 4/27/2020
% =======================

D_TVT.train_name = D_train.dataset_name;
D_TVT.test_name = D_test.dataset_name;
if Settings.seed
  rng(Settings.seed)
end

% Number of label types.
K = length(Settings.target_label);

% Initialization for the smallest class instances within each type,
% for later balanced training set seperation.
small_class_num = inf(K,1);
% Initialization for the window indices for each type and class: IDX{k}{c}
IDX = cell(K,1); % For "D_train".
IDX_test = cell(K,1); % For "D_test".

for k = 1:K
  IDX{k} = cell(max(Settings.target_label{k}),1);
  for c = Settings.target_label{k}
    IDX{k}{c} = find(D_train.window_label(k,:) == c);
    small_class_num(k) = min(small_class_num(k), length(IDX{k}{c}));
    IDX_test{k}{c} = find(D_test.window_label(k,:) == c);
  end
end


% Initialization for the window indices for train and validation.
Idx_train = cell(K,1);
Idx_valid = cell(K,1);
Idx_rest = cell(K,1);
Idx_test = cell(K,1); % For later use of "D_test".
% Split the indices for train and validation.
for k = 1:K
  for c = Settings.target_label{k}
    if Settings.balanced_train
      n_train = round(Settings.train_pct*small_class_num(k));
      n_valid = round(Settings.valid_pct*small_class_num(k));
    else
      n_train = round(Settings.train_pct*length(IDX{k}{c}));
      n_valid = round(Settings.valid_pct*length(IDX{k}{c}));
    end
    % Per class indices.
    i_train = randsample(IDX{k}{c}, n_train);
    i_valid = randsample(setdiff(IDX{k}{c}, i_train), n_valid);
    i_rest = setdiff(IDX{k}{c}, [i_train, i_valid]);
    % Stack.
    Idx_train{k} = [Idx_train{k}, i_train];
    Idx_valid{k} = [Idx_valid{k}, i_valid];
    Idx_rest{k} = [Idx_rest{k}, i_rest];
    Idx_test{k} = [Idx_test{k}, IDX_test{k}{c}];
    
  end
  % Sort the stacked indices.
  Idx_train{k} = sort(Idx_train{k});
  Idx_valid{k} = sort(Idx_valid{k});
  Idx_rest{k} = sort(Idx_rest{k});
  Idx_test{k} = sort(Idx_test{k});
  
end


% Package training/validation data, use normalized data.
D_TVT.train = cell(K,1);
D_TVT.train_label = cell(K,1);
D_TVT.valid = cell(K,1);
D_TVT.valid_label = cell(K,1);
for k = 1:K
  if Settings.if_normalize
    D_TVT.train{k} = D_train.window_data_norm(1, Idx_train{k});
    D_TVT.valid{k} = D_train.window_data_norm(1, Idx_valid{k});
  else
    D_TVT.train{k} = D_train.window_data(1, Idx_train{k});
    D_TVT.valid{k} = D_train.window_data(1, Idx_valid{k});
  end
  D_TVT.train_label{k} = D_train.window_label(k, Idx_train{k});
  D_TVT.valid_label{k} = D_train.window_label(k, Idx_valid{k});
end


% Manage testing data.
D_TVT.test = cell(K,1);
D_TVT.test_label = cell(K,1);

if strcmp(D_train.dataset_name, D_test.dataset_name)
  % D_train and D_test is the same, use "Idx_rest" for test set.
  for k = 1:K
    if Settings.if_normalize
      D_TVT.test{k} = D_train.window_data_norm(1, Idx_rest{k});
    else
      D_TVT.test{k} = D_train.window_data(1, Idx_rest{k});
    end
    D_TVT.test_label{k} = D_train.window_label(k, Idx_rest{k});
  end  
else
  % Extract test set from "D_test", use "Idx_test" for test set.
  for k = 1:K
    if Settings.if_normalize
      D_TVT.test{k} = D_test.window_data_norm(1, Idx_rest{k});
    else
      D_TVT.test{k} = D_test.window_data(1, Idx_rest{k});
    end
    D_TVT.test_label{k} = D_test.window_label(k, Idx_test{k});
  end
end
