% neuronalMain.m
% Driver script for neuronal modeling experiments
%
% This script:
%   1. Defines parameters (boundaries, sequence durations, model types, etc.)
%   2. Loops over boundary × seq pairs
%   3. Builds datasets (X, y) from brain + behavior data
%   4. Trains models using ModelTrainer
%   5. Evaluates performance using evaluateModel
%   6. Saves results and (optionally) visualizes them
%
% NOTE:
%   Actual logic lives in helper functions (buildDataset.m, ModelTrainer.m, etc.)
%   This script is intentionally lightweight and modular.

clc; clear; close all;
    
% --- Parameters ---
boundaries = 0 : 0.5 : 5;         % candidate boundaries (example)
seqTimes = 0 : 0.5 : 5;         % candidate sequence durations
modelTypes   = {'logistic','svm'}; % models to train
splitMethod  = 'holdout';         % 'cv' or 'holdout'
saveResults  = true;
psAveragePath = fullfile("results", "3chamber", "boundary&sequence", ...
    "all_groups", "average.mat");
topN = 20; % number of top pairs to analyze
normalizeMode = "raw";  % "raw" : leave the ca data as is
                        % "epoch" : normalize per social interaction epoch

% --- Storage for results ---
results = struct();
resultID = 1;

topPairs = choosePairs(psAveragePath, seqTimes, boundaries, topN);
% --- Loop over boundary × seq for topPairs ---
for i = 1:height(topPairs)
    s = topPairs.SeqTime(i);
    b = topPairs.Boundary(i);
    psScore = topPairs.PS(i);

    fprintf('Processing pair %2d: Seq=%.1f, Boundary=%.1f, PS=%.3f\n', ...
            i, s, b, psScore);

    % 1. Build dataset
    % ------------------ got to here 18.9.25 ------------
    [X, y] = buildDataset(b, s, normalizeMode); % <- placeholder (to implement)

    % 2. Loop over models
    for m = 1:numel(modelTypes)
        modelType = modelTypes{m};

        % Train model
        mdl = ModelTrainer.trainModel(X, y, modelType, struct());

        % Evaluate
        metrics = evaluateModel(mdl, X, y, splitMethod);

        % Store results
        results(resultID).boundary = b;
        results(resultID).seqTime  = s;
        results(resultID).model    = modelType;
        results(resultID).metrics  = metrics;

        resultID = resultID + 1;
    end
end

% --- Save results ---
if saveResults
    outDir = fullfile("results","neuronal","modeling");
    if ~exist(outDir,"dir"), mkdir(outDir); end
    save(fullfile(outDir,"results.mat"),"results");
end

fprintf('All experiments complete. Results saved.\n');

% ---- Helpers ----
function topPairs = choosePairs(psAveragePath, seqTimes, boundaries, topN)
    % --- Load preference score data ---
    load(psAveragePath, "allNormMatrix");
    
    % --- Rank the pairs by score ---
    vals = allNormMatrix(:);
    [sortedVals, idx] = sort(vals, 'descend', 'MissingPlacement', 'last');
    
    % Take top N values
    topVals = sortedVals(1:topN);
    topIdx  = idx(1:topN);
    
    % Convert linear indices to matrix coordinates
    [numSeq, numBound] = size(allNormMatrix);
    [rowIdx, colIdx] = ind2sub([numSeq, numBound], topIdx);
    
    % Store in a table for readability
    topPairs = table(topVals, ...
                     seqTimes(rowIdx)', ...
                     boundaries(colIdx)', ...
                     'VariableNames', {'PS', 'SeqTime', 'Boundary'});
    
    disp('Top pairs (ranked by PS score):');
    disp(topPairs);
    
    % Save ranking (both .mat and .csv for convenience)
    outDir = fullfile("results", "3chamber", "boundary&sequence", "summary_ps");
    SaveFolders.saveFile(topPairs, [], outDir, sprintf("top%d_pairs", topN), {'mat','csv'}, true);

end
