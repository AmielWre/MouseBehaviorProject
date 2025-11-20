function trainMouseModels(seqTime, boundary, mlModel)
% trainMouseModels - Train multiple ML models per mouse using epoch-level data.
%
% Inputs:
%   seqTime  - sequence time (numeric)
%   boundary - boundary distance (numeric)
%   mlModel  - string specifying model type: 'SVM', 'Logistic', 'RandomForest', 'kNN'
%
% Author: Amiel Wreschner

%% === Setup ===
baseDir = sprintf('data/processed/neuronal_epoch_data/seq%.1f/b%.1f/', seqTime, boundary);
saveRoot = fullfile('results', '3chamber', 'boundary&sequence', 'ml_models', mlModel);
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
    testDate = dates{end}; trainDates = dates(1:end-1);

    %% --- Load data
    X_train = []; y_train = [];
    for d = 1:length(trainDates)
        dname = trainDates{d};
        expPath = fullfile(mousePath, dname);
        load(fullfile(expPath, ['X_epochs_' mouseName '_' dname '.mat']), 'X_epochs');
        load(fullfile(expPath, ['y_epochs_' mouseName '_' dname '.mat']), 'y_epochs');
        X_train = [X_train; X_epochs];
        y_train = [y_train; y_epochs];
    end

    testPath = fullfile(mousePath, testDate);
    load(fullfile(testPath, ['X_epochs_' mouseName '_' testDate '.mat']), 'X_epochs');
    load(fullfile(testPath, ['y_epochs_' mouseName '_' testDate '.mat']), 'y_epochs');
    X_test = X_epochs; y_test = y_epochs;

    %% --- Data Cleaning
    validCols = ~all(isnan(X_train), 1);
    removedCols = find(~validCols);
    removedRegions = regionNames(removedCols);
    X_train = X_train(:, validCols);
    X_test  = X_test(:,  validCols);

    % Fill NaNs per class
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

    if isempty(X_train)
        fprintf('  Skipping %s (no valid data).\n', mouseName);
        continue;
    end

    %% --- Train Model
    fprintf('  Training %s...\n', mlModel);
    switch upper(mlModel)
        case 'SVM'
            model = fitcsvm(X_train, y_train, 'KernelFunction', 'linear', 'Standardize', true);
        case 'LOGISTIC'
            model = fitclinear(X_train, y_train, 'Learner', 'logistic', 'Solver', 'lbfgs');
        case 'RANDOMFOREST'
            model = TreeBagger(100, X_train, y_train, 'Method', 'classification');
        case 'KNN'
            model = fitcknn(X_train, y_train, 'NumNeighbors', 5, 'Standardize', true);
        otherwise
            error('Unknown model type: %s', mlModel);
    end

    %% --- Evaluate
    switch upper(mlModel)
        case 'RANDOMFOREST'
            [y_pred, scores] = predict(model, X_test);
            y_pred = str2double(y_pred);
        otherwise
            [y_pred, scores] = predict(model, X_test);
    end

    accuracy = mean(y_pred == y_test);
    C = confusionmat(y_test, y_pred);
    try
        [~,~,~,AUC] = perfcurve(y_test, scores(:,end), 1);
    catch
        AUC = NaN;
    end

    %% --- Save per mouse/model
    mouseSave = fullfile(saveRoot, mouseName);
    if ~exist(mouseSave, 'dir'), mkdir(mouseSave); end
    modelFile = fullfile(mouseSave, sprintf('model_seq%.1f_b%.1f.mat', seqTime, boundary));
    save(modelFile, 'model', 'mouseName', 'seqTime', 'boundary', ...
                    'trainDates', 'testDate', 'removedRegions');

    perfFile = fullfile(mouseSave, sprintf('performance_%s_%s.xlsx', mouseName, mlModel));
    if isfile(perfFile)
    T = readtable(perfFile);

    % Ensure consistent column types
    if ismember('RemovedRegions', T.Properties.VariableNames)
        if ~iscell(T.RemovedRegions)
            T.RemovedRegions = cellstr(string(T.RemovedRegions));
        end
    end
    else
        T = table;
    end

    newRow = table(string(mouseName), seqTime, boundary, ...
                   height(X_train), height(X_test), numel(trainDates), string(testDate), ...
                   accuracy, AUC, {strjoin(removedRegions, ', ')}, ...
                   'VariableNames', {'Mouse','Seq','Boundary','TrainEpochs','TestEpochs', ...
                                     'NumTrainExperiments','TestDate','Accuracy','AUC','RemovedRegions'});

    T = [T; newRow];
    T = sortrows(T, 'Accuracy', 'descend');
    writetable(T, perfFile);

    fprintf('  %s done. Accuracy %.2f | AUC %.2f\n', mouseName, accuracy, AUC);
end

fprintf('\nAll mice completed for %s (seq %.1f, b %.1f)\n', mlModel, seqTime, boundary);
end
