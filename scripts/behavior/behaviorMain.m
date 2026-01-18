% 3-Chamber Mouse Behavior Analysis Script
%
% This script serves as the main entry point for a comprehensive analysis of
% 3-chamber mouse behavior. It automates the process of iterating through
% experiment data files, extracting behavioral metrics (specifically,
% preference scores), and saving the results for later visualization and
% analysis. The script is designed to be robust against interruptions by
% implementing a checkpointing mechanism that saves progress incrementally.
%
% Workflow:
% 1. Defines the core analysis parameters: boundary allowances and minimum
%    sequence times.
% 2. Checks for a pre-existing checkpoint file to resume processing if
%    necessary.
% 3. Iterates through all experiment groups (folders) in the processed data
%    directory.
% 4. Within each group, it finds and processes all relevant behavior data
%    files.
% 5. For each experiment file, it loads the corresponding ROI (Region of
%    Interest) data and creates an ExperimentBehave object.
% 6. It then calls the `oneBehaveAnalysis` function to compute a matrix of
%    preference scores across all parameter combinations.
% 7. The results for each experiment are stored in a dynamic structure.
% 8. Progress is saved periodically to a checkpoint file, ensuring that no
%    work is lost if the script is terminated prematurely.
% 9. Finally, all the computed preference scores are saved to a final `.mat`
%    file for future use.
%
% ---
%
% How the Script Runs and What It Saves
%
% This script operates through a two-tiered iteration process to analyze all your
% experiment files and save the results incrementally.
%
% Iteration Process:
%   The script runs for a total of `numel(groupFolders) * numel(expFiles)` times.
%   This means it will process every single XY_behave file found across all
%   the group folders.
%   - The outer loop iterates through each group folder (e.g., '10th', '11th').
%   - The inner loop iterates through each experiment file (`XY_behave_...mat`)
%     found within that group folder.
%
% Saving and Checkpointing:
%   To prevent data loss, the script saves its progress at two key points:
%   1.  After Each Experiment File: After the `oneBehaveAnalysis` function
%       completes for a single experiment file, the main script saves a
%       checkpoint file called `allPsMatrices_checkpoint.mat`. This file stores
%       the cumulative results for all experiments processed so far. If the
%       script is interrupted, it can be re-run and will resume from this point,
%       skipping already completed files.
%       To see what is happening in each experiment and what is saved (a
%       lot is happening in each experiment) - see oneBehaveAnalysis,
%       Processing Flow & Outputs: in the document.
%   2.  At the End: Once all experiment files have been successfully processed,
%       the script performs a final save to a file named `allPsMatrices.mat`.
%       This is the final, complete result of your analysis.
%
clc, clear, close all;

% Parameters
boundaries = 0 : 0.5 : 5;     % Boundary allowances in cm
seqTimes = 0 : 0.5 : 5;       % Sequence times in seconds (minimum stay in ROI)

% If you want to do all the code just for a specific experiment, apply the
% next paragraph (and only that!)
% Load cage position struct
cageStruct = load("chamber_rois_positions/8th_blue_20231119.mat");
% Create ExperimentBehave object for analysis
exp = ExperimentBehave("XY_behave_8th_blue_20231119_em_R_st_L_3chamber.mat", cageStruct);
plotTrackAndBoundary(exp, seqTimes, boundaries);
psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries);


% % allPsMatrices - dynamic structure
% % This structure will store the preference score matrix for each experiment.
% allPsPath = fullfile("results", "3chamber", "boundary&sequence", "allPsMatrices_checkpoint.mat");
% 
% % Check if a checkpoint file exists to resume analysis
% if isfile(allPsPath)
%     load(allPsPath, 'allPsMatrices');
% else
%     allPsMatrices = struct();
% end

% Define paths to data and ROI directories
processedDir = fullfile("data","processed");
roiDir       = fullfile("data","processed","chamber_rois_positions");

% Get all group folders (e.g., "10th", "11th") in the processed data directory.
groupFolders = dir(processedDir);
groupFolders = groupFolders([groupFolders.isdir] ...
    & ~startsWith({groupFolders.name}, ".") ...
    & endsWith({groupFolders.name}, "th"));

for g = 1:numel(groupFolders)
    groupName = groupFolders(g).name;
    groupPath = fullfile(processedDir, groupName);
    
    % Get all XY_behave files within the current group folder
    expFiles = dir(fullfile(groupPath, "XY_behave_*.mat"));
    for f = 1:numel(expFiles)
        expFile = expFiles(f).name;
        
        % Parse group, color, and date from the filename using regular expressions
        tokens = regexp(expFile, ...
            'XY_behave_(?<group>\d+th)_(?<color>\w+)_(?<date>\d{8})', 'names');
        if isempty(tokens)
            warning("Filename %s does not match expected format", expFile);
            continue;
        end
        
        % Construct the corresponding ROI filename based on parsed tokens
        roiFile = sprintf("%s_%s_%s.mat", tokens.group, tokens.color, tokens.date);
        roiPath = fullfile(roiDir, roiFile);
        if ~isfile(roiPath)
            warning("ROI file not found for %s", expFile);
            continue;
        end
        
        % Load experiment and ROI data
        cageStruct = load(roiPath);
        expPath    = fullfile(groupPath, expFile);
        fprintf("\nProcessing: %s\n", expPath);
        % Create an ExperimentBehave object for the current experiment file
        exp = ExperimentBehave(expFile, cageStruct);
        
        % To check how mant trials:
        % s = sprintf('%d, ', exp.stim_trials);
        % s = s(1:end-2);  % remove trailing comma and space
        % fprintf('stim_trials: [%s]\n', s);
        % continue

        if isnan(exp.XY_behave)
            fprintf('Skipping %s (no XY_behave)\n', expPath);
            continue
        end

        % % Plot track and boundaries. comment if you don't want or have it
        % % already. save to:
        % % I:\year c project\results\3chamber\boundary&sequence\
        % % mouse track and cage\<mouse_id>.png (and .fig)
        % plotTrackAndBoundarySimple(exp);
        % close all;
        % continue;

        plotTrackAndBoundary(exp, seqTimes, boundaries);
        close all;
        continue;
        
        % Create a unique identifier for this experiment to use as a field name
        % in the allPsMatrices structure
        key = sprintf('%s_%s_%s', exp.group, exp.color, exp.date);
        % Convert the key to a valid MATLAB struct field name
        validKey = matlab.lang.makeValidName(key);
        
        % Check if this experiment has already been processed (using the checkpoint)
        % This allows the script to be re-run without re-analyzing completed data.
        % If you want to analyze again (with new logic\variables\some reason)
        % - COMMENTS THIS IF STATMENT (OR DELETE allPsMatrices_checkpoint)
        if isfield(allPsMatrices, validKey)
            fprintf('Skipping %s (already processed)\n', validKey);
            continue;
        end
        
        % oneBehaveAnalysis - Computes the preference score matrix for a single experiment.
        %
        % Syntax:
        %   psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries)
        %
        % Inputs:
        %   exp       - An ExperimentBehave object containing the experiment's data.
        %   seqTimes  - Array of minimum stay times in ROI (numeric vector).
        %   boundaries - Array of boundary allowance values (numeric vector).
        %
        % Output:
        %   psMatrix  - A matrix of preference scores (numSeqTimes x numBoundaries).
        psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries);
        
        % Store the resulting preference score matrix in the dynamic structure
        allPsMatrices.(validKey) = psMatrix;
        % Save the allPsMatrices structure as a checkpoint after each experiment.
        % This prevents data loss if the program crashes.
        outDir = fullfile("results", "3chamber", "boundary&sequence");
        if ~exist(outDir,"dir")
            mkdir(outDir);
        end
        save(fullfile(outDir, "allPsMatrices_checkpoint.mat"), "allPsMatrices");
    end
end

% Final save of the complete results
outDir = fullfile("results", "3chamber", "boundary&sequence");
if ~exist(outDir,"dir")
    mkdir(outDir);
end
save(fullfile(outDir, "allPsMatrices.mat"), "allPsMatrices");
