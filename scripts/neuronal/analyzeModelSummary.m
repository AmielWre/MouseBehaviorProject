% analyzeModelSummary.m
% -------------------------------------------------------------
% Master script to analyze all models and all mice.
% Calls analyzeMLPerformance() for each combination
% and aggregates the resulting tables.
%
% Author: Amiel Wreschner
% -------------------------------------------------------------

clc; clear;

%% === Constants ===
BASE_DIR = 'results/3chamber/boundary&sequence/ml_models';
MODEL_NAMES = {'SVM'};        % add more models later (e.g. 'KNN', 'Tree', 'Ensemble')
MIN_TEST_EPOCHS = 5;
EXCLUDE_NAN = true;
COLOR_LIMITS = [0.4 0.9];

%% === Initialize aggregation structure ===
AllResults = struct();
resultCount = 0;

%% === Loop over models ===
for m = 1:numel(MODEL_NAMES)
    modelName = MODEL_NAMES{m};
    modelPath = fullfile(BASE_DIR, modelName);

    fprintf('\n=== Processing model: %s ===\n', modelName);

    % Get all mouse directories (ignore hidden/system)
    mouseDirs = dir(modelPath);
    mouseDirs = mouseDirs([mouseDirs.isdir]);
    mouseDirs = mouseDirs(~ismember({mouseDirs.name}, {'.','..','summary_overall','summary_overall_average'}));

    %% Loop over each mouse
    for k = 1:numel(mouseDirs)
        mouseName = mouseDirs(k).name;
        mousePath = fullfile(modelPath, mouseName);
        fprintf('  → %s\n', mouseName);

        try
            % Call the per-mouse function
            T = analyzeMLPerformance(mousePath, MIN_TEST_EPOCHS, EXCLUDE_NAN, COLOR_LIMITS);

            % Skip if table empty
            if isempty(T)
                fprintf('    (No valid data)\n');
                continue;
            end

            % Store in structure
            resultCount = resultCount + 1;
            AllResults(resultCount).Model = modelName;
            AllResults(resultCount).Mouse = mouseName;
            AllResults(resultCount).Table = T;

        catch ME
            fprintf('    Error processing %s: %s\n', mouseName, ME.message);
        end
    end
end

%% === Aggregate results into one big table ===
allTables = [];
for i = 1:numel(AllResults)
    T = AllResults(i).Table;
    T.Model = repmat(string(AllResults(i).Model), height(T), 1);
    T.Mouse = repmat(string(AllResults(i).Mouse), height(T), 1);
    allTables = [allTables; T];
end

%% === Save aggregated results ===
summaryDir = fullfile(BASE_DIR, 'summary_overall_average');
if ~exist(summaryDir, 'dir')
    mkdir(summaryDir);
end

save(fullfile(summaryDir, 'AllResults_struct.mat'), 'AllResults');
writetable(allTables, fullfile(summaryDir, 'AllResults_table.xlsx'));

fprintf('\n=== Completed all models. ===\n');
fprintf('Total mice processed: %d\n', numel(AllResults));
fprintf('Aggregated results saved to %s\n', summaryDir);
