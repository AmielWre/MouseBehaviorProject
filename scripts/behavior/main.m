% Main script for analyzing 3-chamber mouse behavior
% This script processes mouse location data to compute behavioral statistics
% for different boundary allowances and sequence times, and visualizes the
% results as stacked bar plots and preference score heatmaps.

clc, clear, close all;

% Parameters
boundaries = 0 : 0.5 : 5;     % Boundary allowances in cm
seqTimes = 0 : 0.5 : 5;       % Sequence times in seconds (minimum stay in ROI)

% % Load cage position struct
% cageStruct = load("chamber_rois_positions/10th_yellow_20240321.mat");
% 
% % Create ExperimentBehave object for analysis
% exp = ExperimentBehave("XY_behave_10th_yellow_20240321_em_R_st_L_3chamber.mat", cageStruct);


% allPsMatrices - dynamic structure
allPsPath = fullfile("results", "3chamber", "boundary&sequence", "allPsMatrices_checkpoint.mat");
if isfile(allPsPath)
    load(allPsPath, 'allPsMatrices');
else
    allPsMatrices = struct();
end

% Define paths
processedDir = fullfile("data","processed");
roiDir       = fullfile("data","processed","chamber_rois_positions");

% Get all groups (folders in processedDir)
groupFolders = dir(processedDir);
groupFolders = groupFolders([groupFolders.isdir] ...
    & ~startsWith({groupFolders.name}, ".") ...
    & endsWith({groupFolders.name}, "th"));

for g = 1:numel(groupFolders)
    groupName = groupFolders(g).name;
    groupPath = fullfile(processedDir, groupName);

    % Get all XY_behave files in this group
    expFiles = dir(fullfile(groupPath, "XY_behave_*.mat"));

    for f = 1:numel(expFiles)
        expFile = expFiles(f).name;

        % Parse group, color, date from filename
        tokens = regexp(expFile, ...
            'XY_behave_(?<group>\d+th)_(?<color>\w+)_(?<date>\d{8})', 'names');

        if isempty(tokens)
            warning("Filename %s does not match expected format", expFile);
            continue;
        end

        % Construct ROI filename
        roiFile = sprintf("%s_%s_%s.mat", tokens.group, tokens.color, tokens.date);
        roiPath = fullfile(roiDir, roiFile);

        if ~isfile(roiPath)
            warning("ROI file not found for %s", expFile);
            continue;
        end

        % Load experiment and ROI
        cageStruct = load(roiPath);
        expPath    = fullfile(groupPath, expFile);

        fprintf("\nProcessing: %s\n", expPath);

        exp = ExperimentBehave(expFile, cageStruct);
        if isnan(exp.XY_behave)
            fprintf('Skipping %s (no XY_behave)\n', expPath);
            continue
        end

        % Create the identifier
        key = sprintf('%s_%s_%s', exp.group, exp.color, exp.date);
        % Convert to valid MATLAB struct field name
        validKey = matlab.lang.makeValidName(key);

        % If we have anlized this experiment already - skeep that one. if
        % you want to analyze again (with new logic\variables\some reason)
        % - COMMENTS THIS IF STATMENT (OR DELETE allPsMatrices_checkpoint)
        if isfield(allPsMatrices, validKey)
            fprintf('Skipping %s (already processed)\n', validKey);
            continue; % Skip this experiment
        end
                
        psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries);
        
        % Store the psMatrix
        allPsMatrices.(validKey) = psMatrix;

        % Save allPsMatrices so if the program will crush it will keep what
        % is stored there until now.
        outDir = fullfile("results", "3chamber", "boundary&sequence");
        if ~exist(outDir,"dir")
            mkdir(outDir);
        end
        save(fullfile(outDir, "allPsMatrices_checkpoint.mat"), "allPsMatrices");

    end
end



outDir = fullfile("results", "3chamber", "boundary&sequence");
if ~exist(outDir,"dir")
    mkdir(outDir);
end

save(fullfile(outDir, "allPsMatrices.mat"), "allPsMatrices");

