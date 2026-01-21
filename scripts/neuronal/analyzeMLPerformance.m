function T = analyzeMLPerformance(mousePath, MIN_TEST_EPOCHS, EXCLUDE_NAN, COLOR_LIMITS)
% analyzeMousePerformance
% --------------------------------------------------------------
% Create summary heatmaps (Accuracy, AUC) for one mouse.
%
% INPUTS:
%   mousePath       - full path to mouse folder
%                     e.g. 'results/3chamber/boundary&sequence/ml_models/SVM/10th_blue'
%   MIN_TEST_EPOCHS - minimum number of test epochs required
%   EXCLUDE_NAN     - logical, remove rows with NaN accuracy/AUC
%   COLOR_LIMITS    - 1x2 vector specifying color range for heatmaps (e.g. [0.4 0.9])
%
% OUTPUT:
%   T - filtered table used for plotting
%
% Author: Amiel Wreschner
% --------------------------------------------------------------

%% Locate the performance file
perfFiles = dir(fullfile(mousePath, 'performance_*.xlsx'));
if isempty(perfFiles)
    warning('No performance file found in %s', mousePath);
    T = table();
    return;
end

fpath = fullfile(mousePath, perfFiles(1).name);
fprintf('Processing %s\n', fpath);

% Extract mouse and model names from file name
[~, fname, ~] = fileparts(fpath);
parts = split(fname, '_');  % e.g. performance_all_mice_kNN

if numel(parts) <= 5
    % Normal case: performance_<mouse_id>_<color>_<model>
    mouse_id = strjoin(parts(2:end-1), '_');
    modelName = parts{end};
else
    warning('Unexpected filename format: %s', fname);
    T = table();
    return;
end

%% === Resolution control ===
if ismember(mouse_id, {'10th_yellow','all_mice', 'all_mice_control'})
    exportRes = 1200;
else
    exportRes = 600;
end

%% Load the Excel data
T = readtable(fpath, 'VariableNamingRule', 'preserve');

% Allow flexible column names
colMap = containers.Map(...
    {'Sequence','TestSamples','TestEpoch','Bound','TestEp'}, ...
    {'Seq','TestEpochs','TestEpochs','Boundary','TestEpochs'});

for k = keys(colMap)
    key = k{1}; val = colMap(key);
    if ismember(key, T.Properties.VariableNames)
        T.Properties.VariableNames{strcmp(T.Properties.VariableNames,key)} = val;
    end
end

%% --- Apply filters ---
if ismember('TestEpochs', T.Properties.VariableNames)
    T = T(T.TestEpochs >= MIN_TEST_EPOCHS, :);
end

if EXCLUDE_NAN
    T = T(~isnan(T.Accuracy) & ~isnan(T.AUC), :);
end

if isempty(T)
    warning('No valid rows left after filtering for %s.', mouse_id);
    return;
end

%% --- Prepare output folder ---
summaryDir = fullfile(mousePath, 'summary_figures');
if ~exist(summaryDir, 'dir')
    mkdir(summaryDir);
end

seqVals = unique(T.Seq);
bVals   = unique(T.Boundary);

%% --- Accuracy Heatmap ---
Z_acc = nan(length(seqVals), length(bVals));
for i = 1:length(seqVals)
    for j = 1:length(bVals)
        idx = T.Seq == seqVals(i) & T.Boundary == bVals(j);
        if any(idx)
            Z_acc(i,j) = mean(T.Accuracy(idx));
        end
    end
end

fig1 = figure('Name', sprintf('Accuracy Heatmap - %s %s', modelName, mouse_id), 'Color', 'w');
imagesc(bVals, seqVals, Z_acc);
set(gca, 'YDir', 'normal');
xlabel('Boundary');
ylabel('Sequence Time');
title(sprintf('Accuracy Heatmap. in white - n_epochs tested\n%s - %s', modelName, mouse_id), 'Interpreter', 'none');
colormap(jet);
colorbar;
caxis(COLOR_LIMITS);

% --- Overlay number of test epochs ---
hold on;
for i = 1:length(seqVals)
    for j = 1:length(bVals)
        idx = T.Seq == seqVals(i) & T.Boundary == bVals(j);
        if any(idx)
            nEpochs = sum(T.TestEpochs(idx));  % total test epochs for that cell
            text(bVals(j), seqVals(i), sprintf('%d', nEpochs), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
        end
    end
end
hold off;

exportgraphics(fig1, fullfile(summaryDir, sprintf('acc_heatmap_%s_%s.png', modelName, mouse_id)), ...
    'Resolution', exportRes);
saveas(fig1, fullfile(summaryDir, sprintf('acc_heatmap_%s_%s.fig', modelName, mouse_id)));
close(fig1);

%% --- AUC Heatmap ---
Z_auc = nan(length(seqVals), length(bVals));
for i = 1:length(seqVals)
    for j = 1:length(bVals)
        idx = T.Seq == seqVals(i) & T.Boundary == bVals(j);
        if any(idx)
            Z_auc(i,j) = mean(T.AUC(idx));
        end
    end
end

fig2 = figure('Name', sprintf('AUC Heatmap - %s %s', modelName, mouse_id), 'Color', 'w');
imagesc(bVals, seqVals, Z_auc);
set(gca, 'YDir', 'normal');
xlabel('Boundary');
ylabel('Sequence Time');
title(sprintf('AUC Heatmap. in white - n_epochs\n%s - %s', modelName, mouse_id), 'Interpreter', 'none');
colormap(jet);
colorbar;
caxis(COLOR_LIMITS);

% --- Overlay number of test epochs ---
hold on;
for i = 1:length(seqVals)
    for j = 1:length(bVals)
        idx = T.Seq == seqVals(i) & T.Boundary == bVals(j);
        if any(idx)
            nEpochs = sum(T.TestEpochs(idx));  % total test epochs for that cell
            text(bVals(j), seqVals(i), sprintf('%d', nEpochs), ...
                'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
        end
    end
end
hold off;

exportgraphics(fig2, fullfile(summaryDir, sprintf('auc_heatmap_%s_%s.png', modelName, mouse_id)), ...
    'Resolution', exportRes);
saveas(fig2, fullfile(summaryDir, sprintf('auc_heatmap_%s_%s.fig', modelName, mouse_id)));
close(fig2);

fprintf('  → Saved heatmaps for %s (%s) [Resolution: %d DPI]\n', mouse_id, modelName, exportRes);
end
