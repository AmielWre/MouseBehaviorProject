clc; clear;

realT = readtable('results/3chamber/boundary&sequence/ml_models/SVM/all_mice/performance_all_mice_SVM.xlsx');
ctrlT = readtable('results/3chamber/boundary&sequence/ml_models/SVM/all_mice/control/performance_all_mice_SVM_control.xlsx');

% Rename control variables before joining
ctrlT.Properties.VariableNames{'Accuracy'} = 'Acc_Control';
ctrlT.Properties.VariableNames{'AUC'} = 'AUC_Control';

merged = innerjoin(realT, ctrlT, 'Keys', {'Seq','Boundary', 'StrangerPct'});

% Compute differences
merged.AccDiff = merged.Accuracy - merged.Acc_Control;
merged.AUCDiff = merged.AUC - merged.AUC_Control;

% === Detect StrangerPct column name ===
if ismember('StrangerPct', merged.Properties.VariableNames)
    strangerVar = 'StrangerPct';
else
    strangerVar = merged.Properties.VariableNames(contains(merged.Properties.VariableNames,'Stranger','IgnoreCase',true));
    strangerVar = strangerVar{1};
    fprintf('Detected StrangerPct column as: %s\n', strangerVar);
end

strangerPct = merged.(strangerVar);

% === Figure 1: Accuracy difference vs class imbalance ===
figure('Name','Accuracy Difference vs Class Imbalance','Color','w');
scatter(strangerPct, merged.AccDiff, 60, 'filled');
xlabel('Stranger %');
ylabel('Accuracy (Real - Control)');
title('Accuracy Improvement vs. Class Imbalance');
grid on;
yline(0,'--k','LineWidth',1.2);
set(gca, 'FontSize', 12);

% === Figure 2: AUC difference vs class imbalance ===
figure('Name','AUC Difference vs Class Imbalance','Color','w');
scatter(strangerPct, merged.AUCDiff, 60, 'filled');
xlabel('Stranger %');
ylabel('AUC (Real - Control)');
title('AUC Improvement vs. Class Imbalance');
grid on;
yline(0,'--k','LineWidth',1.2);
set(gca, 'FontSize', 12);