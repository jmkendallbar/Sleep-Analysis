%% Main Process for tag data classification.
% =======================
% Ding Zhang
% zhding@umich.edu
% Last Updated: 12/16/2020
% =======================
clear all

%% Read data from csv file.
file_in = 'C:\Users\Jessie\Documents\Dissertation Sleep\Data\test23_Ashley_V4_VideoMotionData_25Hz.csv';
Table = readtable(file_in);

%%
% Get data from table.
sample_freq = 25; % [Hz]

data_stack_all_raw = table2array(Table(:,22:31)); %Pressure, Acc123, Comp123, Gyr123.

%data_stack_raw = table2array(Table(:,22:31)); %Pressure, Acc123, Comp123, Gyr123.
%data_stack_raw = table2array(Table(:,23:25)); % Just acc.
%data_stack_raw = table2array(Table(:,[22,34,36,37,38])); % Pressure, ODBA, prh
data_stack_raw = table2array(Table(:,[22,34,23,24,25])); % Pressure, ODBA, AccXYZ


data_stack = movmean(data_stack_raw, 0.2*sample_freq);
data_stack_norm = (data_stack - mean(data_stack))./std(data_stack);

% Get label from table.
label_stack_str = Table.Behavioral_Notes;
label_stack_cat = categorical(Table.Behavioral_Notes);


%% Count labels and map from string to numerical.
% Take multiple seconds to finish for long dataset.

% Numerical labels, to be updated soon.
label_stack = zeros(length(label_stack_str),1);

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
  
  label_stack(i) = M_name(label);
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

%% Show all data.
T_sec = (1:length(data_stack_norm))/sample_freq;
np = 4;
figure
ix = 1;
ax(ix) = subplot(np,1,ix);
plot(T_sec, data_stack_all_raw(:,2:4))
grid on
legend
ylabel('Acc')

ix = ix + 1;
ax(ix) = subplot(np,1,ix);
plot(T_sec, data_stack_all_raw(:,5:7))
grid on
legend
ylabel('Comp')

ix = ix + 1;
ax(ix) = subplot(np,1,ix);
plot(T_sec, data_stack_all_raw(:,8:10))
grid on
legend
ylabel('Gyro')

ix = ix + 1;
ax(ix) = subplot(np,1,ix);
plot(T_sec, label_stack, 'x')
grid on
xlabel('Time [s]')
ylabel('Label Name')
yticks(label_id)
yticklabels(label_names)

linkaxes(ax, 'x')

%% Package data into a structure.
DS1.dataset_name = 'jessica_data';
DS1.data_stack = data_stack';
DS1.data_stack_norm = data_stack_norm';
DS1.label_stack = label_stack';


%% Windowing data.
% Within each window, truth label need to exceed this amount.
Settings.label_good_pct = 0.60;
% Overlap between windows.
Settings.window_over = 0.25;

% Size of the sliding window.
%sample_freq = 25; % [Hz]
window_len = 1; % [s]
Settings.window_size = window_len*sample_freq; %[s]*[Hz] = [number of data points]

% Window all data.
DS1_W = window_data(DS1, Settings);


%% Split into train, validation, test sets.
% Whether or not use a balanced training set.
Settings.balanced_train = 0;
% Whether use normalized data.
Settings.if_normalize = 0;

% % Target labels to focus on for each label type.
Settings.target_label = {label_id([1,2,3,4,5,6,7,9,10,11,12,13,14,15,16,17,18,19,20])}; 
Settings.label_name = {label_names([1,2,3,4,5,6,7,9,10,11,12,13,14,15,16,17,18,19,20])}; 
% % Or manually (e.g.):
% Settings.target_label = {[1,2,5,7,10]};
% % Settings.label_name = {{'1-Visibly Breat…'},{'2-Not Visibly B…'},{'3-Grooming'}}

% Manually define the interested label IDs and corresponding names.
% Settings.target_label = {label_id(1:5)};
% Settings.label_names = {label_names(1:5)};
    
% Use this amount of data to train.
Settings.train_pct = 0.5;
% Use this amount of data as validation set to monitor training process.
Settings.valid_pct = 0.1;
% Seed for random number generation.
Settings.seed = 1; 

D_TVT = split_train_val_test(DS1_W, DS1_W, Settings);


%% Getting ready for eveluation.
k = 1;
DS = D_TVT;
X_train = DS.train{k};
Y_train = categorical(DS.train_label{k}');
F_train = feature_gen_v01(X_train);

X_valid = DS.valid{k};
Y_valid = categorical(DS.valid_label{k}');    
F_valid = feature_gen_v01(X_valid);

X_test = DS.test{k};
Y_test = categorical(DS.test_label{k}');    
F_test = feature_gen_v01(X_test);


%% Visualize feature with label.
x_plot = F_train(:,2:4); % Looking at the first 3 features, for example.
label_plot = double(Y_train);
figure
hold on
for i_label = 1:19
  plot3(x_plot(label_plot==i_label,1), x_plot(label_plot==i_label,2),...
    x_plot(label_plot==i_label,3), '.')
end
grid on
legend()
title('Feature plot color coded by labels')
xlabel('Feature 1')
ylabel('Feature 2')
zlabel('Feature 3')


%% Plot confusion matrices.
%----------- Naive Bayes Train and Test ------------
Model_nb = fitcnb(F_train, Y_train);
y_test_nb = predict(Model_nb, F_test);
confus_mat_nb = confusionmat(Y_test, y_test_nb);
accuracy_nb = sum(y_test_nb==Y_test)/length(Y_test)

%----------- SVM Train and Test ------------
Model_svm = fitcecoc(F_train, Y_train);
y_test_svm = predict(Model_svm, F_test);
confus_mat_svm = confusionmat(Y_test, y_test_svm);
accuracy_svm = sum(y_test_svm==Y_test)/length(Y_test)

%----------- KNN Train and Test ------------
Model_knn = fitcknn(F_train, Y_train);
y_test_knn = predict(Model_knn, F_test);
confus_mat_knn = confusionmat(Y_test, y_test_knn);
accuracy_knn = sum(y_test_knn==Y_test)/length(Y_test)

%----------- Decision Tree Train and Test ------------
Model_tree = fitctree(F_train, Y_train);
y_test_tree = predict(Model_tree, F_test);
confus_mat_tree = confusionmat(Y_test, y_test_tree);
accuracy_tree = sum(y_test_tree==Y_test)/length(Y_test)



%% Plot confusion matrix.
figure
confusionchart(confus_mat_nb);
title(['Confusion matrix of Naive Bayes, accuracy: ', num2str(accuracy_nb)]);

figure
confusionchart(confus_mat_svm);
title(['Confusion matrix of Support Vector Machine, accuracy: ',...
  num2str(accuracy_svm)]);

figure
confusionchart(confus_mat_knn);
title(['Confusion matrix of K-Nearest Neighbor, accuracy: ',...
  num2str(accuracy_knn)]);

figure
confusionchart(confus_mat_tree);
title(['Confusion matrix of Decision Tree, accuracy: ',...
  num2str(accuracy_tree)]);

