function trainGlobalModels(seqTime, boundary, mlModel, isControl)
% trainGlobalModels - Train ML models using pooled (all-mice) data for one (seq,b) pair.
%
%   This function loads one dataset from:
%       data/processed/neuronal_epoch_data_all/seq<seq>_b<boundary>/
%           neuronal_dataset_seq<seq>_b<boundary>.mat
%
%   It trains and evaluates a model (SVM, Logistic, RandomForest, kNN)
%   using an 80/20 random split of all epochs across mice.
%
%   If isControl = true, labels are shuffled before training.
%
%   Results are saved under:
%       results/3chamber/boundary&sequence/ml_models/<mlModel>/all_mice/(control)/
%       ├── model_allmice_seq<seq>_b<boundary>[_control].mat
%       ├── performance_all_mice_<mlModel>[_control].xlsx
%
% Author: Amiel Wreschner
% -------------------------------------------------------------------------

%% === CONSTANTS ===
DATA_ROOT = fullfile('data','processed','neuronal_epoch_data_all');
RESULTS_ROOT = fullfile('results','3chamber','boundary&sequence','ml_models');
SPLIT_RATIO = 0.8; % 80% train / 20% test
MIN_SAMPLES = 10;  % skip small datasets
rng(2); % for reproducibility
BALANCE_CLASSES = true;  % set to false if you want to keep raw proportions

% -------------------------------------------------------------------------

%% === Control mode handling ===
if nargin < 4
    isControl = false;
end

if isControl
    modeLabel = 'CONTROL';
else
    modeLabel = 'REAL';
end

subFolder = 'all_mice';
if isControl
    subFolder = fullfile(subFolder, 'control');
end

modelDir = fullfile(RESULTS_ROOT, mlModel, subFolder);
if ~exist(modelDir, 'dir')
    mkdir(modelDir);
end

fprintf('\n=== Training %s global model (%s) for seq %.1f | b %.1f ===\n', ...
    mlModel, modeLabel, seqTime, boundary);

%% === Load dataset ===
dataFile = fullfile(DATA_ROOT, ...
    sprintf('seq%.1f_b%.1f', seqTime, boundary), ...
    sprintf('neuronal_dataset_seq%.1f_b%.1f.mat', seqTime, boundary));

if ~isfile(dataFile)
    fprintf('  Dataset not found: %s\n', dataFile);
    return;
end

S = load(dataFile);
if ~isfield(S,'X') || ~isfield(S,'y')
    fprintf('  Invalid dataset format (missing X or y).\n');
    return;
end

% === Load full dataset ===
X = S.X;
y = S.y;

% === Remove NaN columns and rows if necessary ===
nanCols = all(isnan(X),1);
if any(nanCols)
    fprintf('  Removed %d all-NaN regions.\n', sum(nanCols));
    X = X(:,~nanCols);
end

nanRows = any(isnan(X),2);
if any(nanRows)
    fprintf('  Removed %d rows with NaNs.\n', sum(nanRows));
    X = X(~nanRows,:);
    y = y(~nanRows);
end

%% === Control mode: shuffle labels ===
if isControl
    y = y(randperm(length(y)));
end


% === Balance classes before split ===
if BALANCE_CLASSES
    idx1 = find(y == 1);
    idx0 = find(y == 0);

    nMin = min(numel(idx1), numel(idx0));

    idx1 = idx1(randperm(numel(idx1), nMin));
    idx0 = idx0(randperm(numel(idx0), nMin));

    balancedIdx = [idx1; idx0];
    X = X(balancedIdx, :);
    y = y(balancedIdx);

    % Optional shuffle
    shuff = randperm(numel(y));
    X = X(shuff, :);
    y = y(shuff);

    fprintf('  → Balanced dataset: %d samples per class (total %d)\n', nMin, numel(y));
    fprintf('  Stranger %% after balance: %.1f%%\n', 100 * mean(y));
end

% === Now do the train/test split ===
n = size(X,1);
idx = randperm(n);
nTrain = floor(SPLIT_RATIO * n);

trainIdx = idx(1:nTrain);
testIdx = idx(nTrain+1:end);

X_train = X(trainIdx,:);
y_train = y(trainIdx);
X_test  = X(testIdx,:);
y_test  = y(testIdx,:);


if size(X,1) < MIN_SAMPLES
    fprintf('  Not enough samples (%d). Skipping.\n', size(X,1));
    return;
end


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

%% === Save / Update performance table ===
perfFile = fullfile(modelDir, ...
    sprintf('performance_all_mice_%s%s.xlsx', mlModel, ternary(isControl,'_control','')));

% Compute class balance (before split)
strangerPct = mean(y == 1) * 100;

newRow = table(string(mlModel), seqTime, boundary, acc, AUC, ...
    numel(y_train), numel(y_test), logical(isControl), strangerPct, ...
    'VariableNames', {'Model','Seq','Boundary','Accuracy','AUC','TrainSamples','TestSamples','Control','StrangerPct'});

if isfile(perfFile)
    T = readtable(perfFile);
    T = [T; newRow];
else
    T = newRow;
end

writetable(T, perfFile);
fprintf('  Results saved to: %s\n', perfFile);


fprintf('\n=== Completed %s global model for seq %.1f | b %.1f (%s) ===\n', ...
    modeLabel, seqTime, boundary, mlModel);
end

%% === Helper function ===
function out = ternary(cond, a, b)
% Simple inline ternary operator
if cond
    out = a;
else
    out = b;
end
end
