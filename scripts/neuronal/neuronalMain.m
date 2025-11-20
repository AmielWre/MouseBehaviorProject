% neuronalMain.m
% Driver script for neuronal epoch dataset generation
%
% Description:
%   For each sequence time × boundary pair:
%       • Builds frame-aligned and epoch-averaged neuronal dataset
%       • Saves X (features) and y (labels) for all mice combined
%
% The script relies on `buildDataset.m` to process and align neuronal and
% behavioral data. Model training and evaluation can be added later.
%
% -------------------------------------------------------------------------

clc; clear; close all;

%% === Parameters ===
boundaries = 0 : 0.5 : 5;        % candidate boundaries (cm)
seqTimes   = 0 : 0.5 : 5;        % candidate sequence durations (s)
normalizeMode = "raw";           % 'raw' = use calcium as-is, 'epoch' = normalize per epoch
saveResults = true;              % whether to save the X,y outputs

%% === Output directory ===
baseSaveDir = fullfile("data", "processed", "neuronal_epoch_data_all");
if ~isfolder(baseSaveDir)
    mkdir(baseSaveDir);
end

%% === Main loop ===
for sIdx = 1:numel(seqTimes)
    seqTimeInSec = seqTimes(sIdx);

    for bIdx = 1:numel(boundaries)
        boundaryAllowance = boundaries(bIdx);

        fprintf('\nProcessing pair: Seq = %.1f s | Boundary = %.1f cm\n', ...
            seqTimeInSec, boundaryAllowance);

        try
            % --- Step 1: Build dataset for this (seq, boundary) pair ---
            [X, y] = buildDataset(boundaryAllowance, seqTimeInSec, normalizeMode);

            % --- Step 2: Save combined X, y if requested ---
            if saveResults
                saveDir = fullfile(baseSaveDir, ...
                    sprintf("seq%.1f_b%.1f", seqTimeInSec, boundaryAllowance));
                if ~isfolder(saveDir), mkdir(saveDir); end

                savePath = fullfile(saveDir, ...
                    sprintf("neuronal_dataset_seq%.1f_b%.1f.mat", seqTimeInSec, boundaryAllowance));
                save(savePath, "X", "y", "seqTimeInSec", "boundaryAllowance", "normalizeMode", "-v7.3");

                fprintf('  ✓ Saved combined dataset: %s\n', savePath);
            end

            % --- Step 3: Pause to allow continuation ---
            fprintf('  Done with Seq=%.1f, Boundary=%.1f. Continuing...\n', ...
                seqTimeInSec, boundaryAllowance);

        catch ME
            fprintf(2, '  ⚠️ Error for Seq=%.1f, Boundary=%.1f:\n    %s\n', ...
                seqTimeInSec, boundaryAllowance, ME.message);
            continue; % skip this pair and continue
        end
    end
end

fprintf('\nAll datasets processed and saved successfully.\n');

    

