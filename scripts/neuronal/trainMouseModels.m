function trainMouseModels(seqTime, boundary, mlModel, isControl, isEqualClassification, doTuneSVM)
% trainMouseModels - Train multiple ML models per mouse using epoch-level data.
% Inputs:
%   seqTime  - sequence time (numeric)
%   boundary - boundary distance (numeric)
%   mlModel  - string specifying model type: 'SVM', 'Logistic', 'RandomForest', 'kNN'
%   isControl - (optional) if true, shuffle labels before training (default = false)
%   isEqualClassification - (optional) if true, balance classes before split (default = false)
%   doTuneSVM - (optional) if true, perform 5-fold CV hyperparameter optimization for SVM (default = false)
%
% Author: Amiel Wreschner

%% === Setup ===
if nargin < 4, isControl = false; end
if nargin < 5, isEqualClassification = true; end
if nargin < 6, doTuneSVM = false; end

MIN_TRAIN_SAMPLES = 10;   % skip very small datasets

baseDir = sprintf('data/processed/neuronal_epoch_data/seq%.1f/b%.1f/', seqTime, boundary);
saveRoot = fullfile('results', '3chamber', 'boundary&sequence', 'ml_models', mlModel);
if isControl, saveRoot = fullfile(saveRoot, 'control'); end
if ~exist(saveRoot, 'dir'), mkdir(saveRoot); end

regionNames = {'DI','Cl','Cpu','CpuA','AcbShv','AcbC','AcbSh','M1','IL','PrL', ...
               'PrL2','Cg1','BLA','CeL','CPu-GP','CpuP','S1BC','S1BC2','CA3', ...
               'Thl-VPM','Thl-VL','Thl-Po','CA1','DG'};

mouseDirs = dir(baseDir);
mouseDirs = mouseDirs([mouseDirs.isdir]);
mouseDirs = mouseDirs(~ismember({mouseDirs.name}, {'.','..'}));

for m = 1:length(mouseDirs)
    mouseName = mouseDirs(m).name;
    mousePath = fullfile(baseDir, mouseName);
    fprintf('\n=== %s | seq %.1f | b %.1f | model %s ===\n', mouseName, seqTime, boundary, mlModel);

    %% --- Find experiment folders
    dateDirs = dir(mousePath);
    dateDirs = dateDirs([dateDirs.isdir]);
    dateDirs = dateDirs(~ismember({dateDirs.name}, {'.','..','average'}));
    if isempty(dateDirs)
        fprintf('  No experiments found. Skipping.\n'); continue;
    end

    dates = sort({dateDirs.name});

    %% --- Load all epochs (pool everything)
    X_all = []; y_all = [];
    for d = 1:length(dates)
        dname = dates{d};
        expPath = fullfile(mousePath, dname);
        load(fullfile(expPath, ['X_epochs_' mouseName '_' dname '.mat']), 'X_epochs');
        load(fullfile(expPath, ['y_epochs_' mouseName '_' dname '.mat']), 'y_epochs');
        X_all = [X_all; X_epochs];
        y_all = [y_all; y_epochs];
    end

    %% --- Data Cleaning
    validCols = ~all(isnan(X_all), 1);
    removedCols = find(~validCols);
    removedRegions = regionNames(removedCols);
    X_all = X_all(:, validCols);

    nanRows = any(isnan(X_all), 2);
    if any(nanRows)
        X_all(nanRows, :) = [];
        y_all(nanRows) = [];
    end

    %% --- Optional: Control (shuffle labels)
    if isControl
        y_all = y_all(randperm(numel(y_all)));
        fprintf('  Control mode: shuffled labels.\n');
    end

    %% --- Optional: Equal classification
    if isEqualClassification
        idx1 = find(y_all == 1);
        idx0 = find(y_all == 0);
        nMin = min(numel(idx1), numel(idx0));
        idx1 = idx1(randperm(numel(idx1), nMin));
        idx0 = idx0(randperm(numel(idx0), nMin));
        balancedIdx = [idx1; idx0];
        X_all = X_all(balancedIdx, :);
        y_all = y_all(balancedIdx);
        fprintf('  Equal classification: %d samples per class (%.1f%% 1s).\n', nMin, 100*mean(y_all));
    end

    if isempty(X_all)
        fprintf('  Skipping %s (no valid data).\n', mouseName);
        continue;
    end

    %% --- Train/test split (80/20)
    n = size(X_all, 1);
    idx = randperm(n);
    nTrain = floor(0.8 * n);
    trainIdx = idx(1:nTrain);
    testIdx  = idx(nTrain+1:end);

    X_train = X_all(trainIdx, :);
    y_train = y_all(trainIdx);
    X_test  = X_all(testIdx, :);
    y_test  = y_all(testIdx, :);

    %% --- Skip too-small datasets
    if height(X_train) < MIN_TRAIN_SAMPLES
        fprintf('  Skipping (too few samples: %d)\n', height(X_train));

        mouseSave = fullfile(saveRoot, mouseName);
        perfFile = fullfile(mouseSave, sprintf('performance_%s_%s.xlsx', mouseName, mlModel));
        if isfile(perfFile)
            T = readtable(perfFile);
        else
            T = table;
        end

        % --- ensure consistent column types
        if ~ismember('RemovedRegions', T.Properties.VariableNames)
            T.RemovedRegions = cell(0,1);
        elseif ~iscell(T.RemovedRegions)
            T.RemovedRegions = cellstr(string(T.RemovedRegions));
        end

        placeholderRow = table(string(mouseName), seqTime, boundary, ...
                       height(X_train), height(X_test), string(isControl), string(isEqualClassification), ...
                       NaN, NaN, { "Too few samples" }, ...
                       'VariableNames', {'Mouse','Seq','Boundary','TrainEpochs','TestEpochs', ...
                                         'Control','EqualClassification','Accuracy','AUC','RemovedRegions'});
        % === Ensure same columns between existing and new row ===
        missingInT = setdiff(newRow.Properties.VariableNames, T.Properties.VariableNames);
        for v = missingInT
            T.(v{1}) = repmat({''}, height(T), 1);
        end
        
        missingInRow = setdiff(T.Properties.VariableNames, newRow.Properties.VariableNames);
        for v = missingInRow
            newRow.(v{1}) = {''};
        end
        
        % Reorder columns to match
        newRow = newRow(:, T.Properties.VariableNames);
        
        T = [T; placeholderRow];
        T = enforceColumnOrder(T);
        safeWriteTable(T, perfFile);
        continue;
    end

    %% --- Fill NaNs per class
    for classVal = [0, 1]
        classIdx = (y_train == classVal);
        classData = X_train(classIdx, :);
        colMeans = nanmean(classData, 1);
        nanMask = isnan(X_train) & (y_train == classVal);
        for c = 1:size(X_train, 2)
            X_train(nanMask(:, c), c) = colMeans(c);
        end
    end
    globalMeans = nanmean(X_train, 1);
    for c = 1:size(X_test, 2)
        nanIdx = isnan(X_test(:, c));
        X_test(nanIdx, c) = globalMeans(c);
    end

    %% --- Train Model
    fprintf('  Training %s...\n', mlModel);
    switch upper(mlModel)
        case 'SVM'
            if doTuneSVM
                fprintf('  → Performing 5-fold cross-validation & hyperparameter tuning...\n');
                model = fitcsvm(X_train, y_train, ...
                    'KernelFunction','linear', ...
                    'Standardize',true, ...
                    'OptimizeHyperparameters','auto', ...
                    'HyperparameterOptimizationOptions', struct( ...
                        'ShowPlots',false, ...
                        'Kfold',5, ...
                        'Verbose',0));
                if isfield(model.ModelParameters,'BoxConstraint')
                    bestC = model.ModelParameters.BoxConstraint;
                    fprintf('    Best BoxConstraint (C) = %.4f\n', bestC);
                end
            else
                model = fitcsvm(X_train, y_train, 'KernelFunction', 'linear', 'Standardize', true);
            end

        case 'LOGISTIC'
            model = fitclinear(X_train, y_train, 'Learner', 'logistic', 'Solver', 'lbfgs');

        case 'RANDOMFOREST'
            model = TreeBagger(100, X_train, y_train, 'Method', 'classification');

        case 'KNN'
            model = fitcknn(X_train, y_train, 'NumNeighbors', 5, 'Standardize', true);

        otherwise
            error('Unknown model type: %s', mlModel);
    end

    %% --- Evaluate (on held-out test set)
    switch upper(mlModel)
        case 'RANDOMFOREST'
            [y_pred, scores] = predict(model, X_test);
            y_pred = str2double(y_pred);
        otherwise
            [y_pred, scores] = predict(model, X_test);
    end

    accuracy = mean(y_pred == y_test);
    try
        [~,~,~,AUC] = perfcurve(y_test, scores(:,end), 1);
    catch
        AUC = NaN;
    end

    %% --- Save per mouse/model
    mouseSave = fullfile(saveRoot, mouseName);
    if ~exist(mouseSave, 'dir'), mkdir(mouseSave); end

    modelFile = fullfile(mouseSave, sprintf('model_seq%.1f_b%.1f.mat', seqTime, boundary));
    save(modelFile, 'model', 'mouseName', 'seqTime', 'boundary', 'removedRegions');

    perfFile = fullfile(mouseSave, sprintf('performance_%s_%s.xlsx', mouseName, mlModel));
    if isfile(perfFile)
        T = readtable(perfFile);
    else
        T = table;
    end

    % ensure consistent column types here too
    if ~ismember('RemovedRegions', T.Properties.VariableNames)
        T.RemovedRegions = cell(0,1);
    elseif ~iscell(T.RemovedRegions)
        T.RemovedRegions = cellstr(string(T.RemovedRegions));
    end

    newRow = table(string(mouseName), seqTime, boundary, ...
                   height(X_train), height(X_test), string(isControl), string(isEqualClassification), ...
                   accuracy, AUC, {strjoin(removedRegions, ', ')}, ...
                   'VariableNames', {'Mouse','Seq','Boundary','TrainEpochs','TestEpochs', ...
                                     'Control','EqualClassification','Accuracy','AUC','RemovedRegions'});

    % === Ensure same columns between existing and new row ===
    missingInT = setdiff(newRow.Properties.VariableNames, T.Properties.VariableNames);
    for v = missingInT
        T.(v{1}) = repmat({''}, height(T), 1);
    end
    
    missingInRow = setdiff(T.Properties.VariableNames, newRow.Properties.VariableNames);
    for v = missingInRow
        newRow.(v{1}) = {''};
    end
    
    % Reorder columns to match
    newRow = newRow(:, T.Properties.VariableNames);
        
    T = [T; newRow];
    T = sortrows(T, {'Seq','Boundary'}, {'ascend','ascend'});
    T = enforceColumnOrder(T);
    safeWriteTable(T, perfFile);

    fprintf('  %s done. Accuracy %.2f | AUC %.2f\n', mouseName, accuracy, AUC);
end

fprintf('\nAll mice completed for %s (seq %.1f, b %.1f)\n', mlModel, seqTime, boundary);
end


%% === Local utility ===
function safeWriteTable(T, perfFile)
% Ensure directory exists before writing, then save the table
    perfDir = fileparts(perfFile);
    if ~exist(perfDir, 'dir')
        mkdir(perfDir);
    end
    writetable(T, perfFile);
end


function T = enforceColumnOrder(T)
    desiredOrder = {'Mouse','Seq','Boundary','TrainEpochs','TestEpochs', ...
                    'Control','EqualClassification','Accuracy','AUC','RemovedRegions'};
    existingCols = intersect(desiredOrder, T.Properties.VariableNames, 'stable');
    T = T(:, existingCols);
end
