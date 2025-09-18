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

%% --- Parameters ---
boundaries   = [2, 3, 4];         % candidate boundaries (example)
seqTimes     = [1, 2, 3];         % candidate sequence durations
modelTypes   = {'logistic','svm'}; % models to train
splitMethod  = 'holdout';         % 'cv' or 'holdout'
saveResults  = true;

%% --- Storage for results ---
results = struct();
resultID = 1;

%% --- Loop over boundary × seq pairs ---
for b = boundaries
    for s = seqTimes
        fprintf('Processing boundary=%.1f, seq=%.1f ...\n', b, s);

        % 1. Build dataset
        [X, y] = buildDataset(b, s); % <- placeholder (to implement)

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
end

%% --- Save results ---
if saveResults
    outDir = fullfile("results","neuronal","modeling");
    if ~exist(outDir,"dir"), mkdir(outDir); end
    save(fullfile(outDir,"results.mat"),"results");
end

fprintf('All experiments complete. Results saved.\n');
