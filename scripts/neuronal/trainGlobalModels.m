function trainGlobalModels(seqTime, boundary, mlModel)
% trainGlobalModels - Train ML models using pooled (all-mice) data for one (seq,b) pair.
%
%   This function loads one dataset from:
%       data/processed/neuronal_epoch_data_all/seq<seq>_b<boundary>/
%           neuronal_dataset_seq<seq>_b<boundary>.mat
%
%   It trains and evaluates a model (SVM, Logistic, RandomForest, kNN)
%   using an 80/20 random split of all epochs across mice.
%
%   Results are saved under:
%       results/3chamber/boundary&sequence/ml_models/<mlModel>/all_mice/
%       ├── model_allmice_seq<seq>_b<boundary>.mat
%       ├── performance_all_mice_<mlModel>.xlsx
%
% Author: Amiel Wreschner
% -------------------------------------------------------------------------

%% === CONSTANTS ===
DATA_ROOT = fullfile('data','processed','neuronal_epoch_data_all');
RESULTS_ROOT = fullfile('results','3chamber','boundary&sequence','ml_models');
SPLIT_RATIO = 0.8; % 80% train / 20% test
MIN_SAMPLES = 10;  % skip small datasets
rng(1); % for reproducibility
% -------------------------------------------------------------------------

modelDir = fullfile(RESULTS_ROOT, mlModel, 'all_mice');
if ~exist(modelDir, 'dir')
    mkdir(modelDir);
end

fprintf('\n=== Training global model (%s) for seq %.1f | b %.1f ===\n', mlModel, seqTime, boundary);

%% === Load dataset ===
dataFile = fullfile(DATA_ROOT, ...
    sprintf('seq%.1f_b%.1f', seqTime, boundary), ...
    sprintf('neuronal_dataset_seq%.1f_b%.1f.mat', seqTime, boundary));

if ~isfile(dataFile)
    error('Dataset not found: %s', dataFile);
end

S = load(dataFile);
if ~isfield(S,'X') || ~isfield(S,'y')
    error('Invalid dataset format (missing X or y).');
end

X = S.X;
y = S.y;

if size(X,1) < MIN_SAMPLES
    fprintf('  Not enough samples (%d). Skipping.\n', size(X,1));
    return;
end

%% === Train/test split ===
n = size(X,1);
idx = randperm(n);
nTrain = floor(SPLIT_RATIO * n);

trainIdx = idx(1:nTrain);
testIdx = idx(nTrain+1:end);

X_train = X(trainIdx,:);
y_train = y(trainIdx);
X_test  = X(testIdx,:);
y_test  = y(testIdx);

%% === Handle NaNs ===
nanCols = all(isnan(X_train),1);
if any(nanCols)
    fprintf('  Removed %d all-NaN regions.\n', sum(nanCols));
    X_train = X_train(:,~nanCols);
    X_test  = X_test(:,~nanCols);
end

X_train = fillmissing(X_train,'movmean',5);
X_test  = fillmissing(X_test,'movmean',5);

%% === Train model ===
switch lower(mlModel)
    case 'svm'
        fprintf('  Training SVM...\n');
        M = fitcsvm(X_train, y_train, 'KernelFunction','linear','Standardize',true);

    case 'logistic'
        fprintf('  Training Logistic Regression...\n');
        M = fitclinear(X_train, y_train, 'Learner','logistic');

    case 'randomforest'
        fprintf('  Training Random Forest...\n');
        M = TreeBagger(100, X_train, y_train, 'Method','classification');

    case 'knn'
        fprintf('  Training kNN...\n');
        M = fitcknn(X_train, y_train, 'NumNeighbors',5);

    otherwise
        error('Unknown model type: %s', mlModel);
end

%% === Evaluate ===
switch lower(mlModel)
    case 'randomforest'
        [y_pred, scores] = predict(M, X_test);
        y_pred = str2double(y_pred);
        scores = scores(:,2);
    otherwise
        [y_pred, scores] = predict(M, X_test);
        if size(scores,2) == 1
            scores = [1-scores, scores];
        end
end

acc = mean(y_pred == y_test);

try
    [~,~,~,AUC] = perfcurve(y_test, scores(:,2), 1);
catch
    AUC = NaN;
end

fprintf('  Done. Accuracy %.2f | AUC %.2f | Train=%d | Test=%d\n', ...
    acc, AUC, numel(y_train), numel(y_test));

%% === Save model ===
modelFile = fullfile(modelDir, ...
    sprintf('model_allmice_seq%.1f_b%.1f.mat', seqTime, boundary));
save(modelFile, 'M', 'seqTime', 'boundary', 'acc', 'AUC', 'nTrain', 'n', 'mlModel');

%% === Save / Update performance table ===
perfFile = fullfile(modelDir, sprintf('performance_all_mice_%s.xlsx', mlModel));

newRow = table(string(mlModel), seqTime, boundary, acc, AUC, ...
    numel(y_train), numel(y_test), ...
    'VariableNames', {'Model','Seq','Boundary','Accuracy','AUC','TrainSamples','TestSamples'});

if isfile(perfFile)
    T = readtable(perfFile);

    % Align columns
    missingInT = setdiff(newRow.Properties.VariableNames, T.Properties.VariableNames);
    for v = missingInT
        T.(v{1}) = repmat({''}, height(T), 1);
    end
    missingInRow = setdiff(T.Properties.VariableNames, newRow.Properties.VariableNames);
    for v = missingInRow
        newRow.(v{1}) = {''};
    end
    newRow = newRow(:, T.Properties.VariableNames);

    T = [T; newRow];
else
    T = newRow;
end

writetable(T, perfFile);
fprintf('  Results saved to: %s\n', perfFile);

fprintf('\n=== Completed global model for seq %.1f | b %.1f (%s) ===\n', seqTime, boundary, mlModel);
end
