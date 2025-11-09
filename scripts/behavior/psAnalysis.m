% psAnalysis.m
% Analyze Preference Score (PS) matrices for all mice in allPsMatrices.
%
% Description:
%   This script performs the final step of the behavioral analysis pipeline.
%   It loads all preference score (PS) matrices computed by `oneBehaveAnalysis`
%   and aggregates them by mouse. For each mouse, it generates:
%       • A figure of all session heatmaps + averaged matrix
%       • A figure of the average matrix only
%       • MAT + table + Excel summaries of PS data
%   It then computes and saves the grand average across all mice.
%
% Outliers near ±1 are masked out using a `threshold` value, shown in white,
% and excluded from averages.
%
% ─────────────────────────────────────────────────────────────────────────
% Saved Outputs — Folder Structure and Contents
%
% When running this script, all outputs are organized under:
%   results/3chamber/boundary&sequence/summary_ps/threshold_<threshold_value>/
%
% This folder contains both visual results and numeric data ready for future analysis.
%
% ─────────────────────────────────────────────────────────────────────────
% 1. GRAPHS  (summary_ps/threshold_<threshold>/graphs/)
% ─────────────────────────────────────────────────────────────────────────
%   • all_days/             — For each mouse, subplot figure showing all sessions + average
%   • per_mouse/            — Average-only figure for each mouse
%   • all_groups_average/   — Grand average across all mice
%
%   Files:
%       <group>_<color>_all_days.png / .fig
%       average_ps_<group>_<color>.png / .fig
%       average.png / .fig   (grand average)
%
% ─────────────────────────────────────────────────────────────────────────
% 2. DATA + MATRICES  (summary_ps/threshold_<threshold>/matfiles_and_data/)
% ─────────────────────────────────────────────────────────────────────────
%   A. per_mouse/
%      ├── <group>_<color>/
%      │    ├── <date>_raw.mat           — Raw PS matrix per session
%      │    ├── <date>_processed.mat     — Normalized/masked PS matrix
%      │    └── average/
%      │         ├── <group>_<color>_avgMatrix.mat   — Average (and normalized) PS across sessions
%      │         ├── <group>_<color>_PS_table.mat     — MATLAB table sorted by PS value
%      │         └── <group>_<color>_PS_summary.xlsx  — Excel sheet for visualization
%
%      The .mat tables are ready for numerical post-analysis in MATLAB;
%      the Excel files mirror the table structure for inspection or external use.
%
%   B. all_mice/
%      ├── all_mice_avgMatrix.mat   — Average PS matrix across all mice
%      ├── all_mice_PS_table.mat    — Sorted MATLAB table of PS values (mean of all mice)
%      └── all_mice_PS_summary.xlsx — Excel visualization of grand-average PS data
%
% ─────────────────────────────────────────────────────────────────────────
% 3. LOG FILE
% ─────────────────────────────────────────────────────────────────────────
%   • run_log_<timestamp>.txt
%
%   Records:
%       - Date and time of run
%       - Threshold used
%       - Mice processed + session count for each
%       - Base folder of all saved outputs
%
% ─────────────────────────────────────────────────────────────────────────
% Purpose of each saved output:
%   - .mat files → precise numeric results (for computation and scripts)
%   - .xlsx files → quick viewing, comparison, or external sharing
%   - .fig/.png   → publication-quality visualization
%   - log file    → reproducibility and batch record keeping
%
% Notes:
%   Each run creates a new “threshold_<value>” folder,
%   keeping data from different outlier thresholds separate and reproducible.
% -------------------------------------------------------------------------
%
% How to Use:
%   1. Make sure allPsMatrices.mat exists in results/3chamber/boundary&sequence/
%   2. Run this script from MATLAB (no inputs needed)
%   3. New folders will be automatically created per threshold
%
% -------------------------------------------------------------------------

clc; clear; close all;

%% === Parameters ===
boundaries   = 0:0.5:5;            % Boundary distances (cm)
seqTimes     = 0:0.5:5;            % Sequence times (s)
threshold    = 0.0;                % Outlier tolerance from ±1
modePerExp   = "normalize";        % 'none', 'normalize', or 'zscore'
modePerMouse = "normalize";

% Fixed color range for average heatmaps (symmetric around zero)
USE_CLIM = true;          % true = use fixed range, false = auto
CLIM_RANGE = [-0.7, 0.7]; % color scale limits

baseDir  = fullfile("results", "3chamber", "boundary&sequence");
dataPath = fullfile(baseDir, "allPsMatrices.mat");
load(dataPath, 'allPsMatrices');

summaryDir = fullfile(baseDir, "summary_ps", sprintf("threshold_%.2f", threshold));
if ~isfolder(summaryDir), mkdir(summaryDir); end

%% === Collect all mouse IDs ===
allFields = fieldnames(allPsMatrices);
mouseIDs  = unique(cellfun(@(f) extractMouseID(f), allFields, 'UniformOutput', false));
allMatrices = {};     % Stores average normalized matrices per mouse
mouseSessionCounts = {};
mouseInfo = {};       % Stores group and color info for logging

%% === Process each mouse ===
for m = 1:numel(mouseIDs)
    close all;
    mouseID = regexp(mouseIDs{m}, '\d.*', 'match', 'once');
    mouseFields = allFields(contains(allFields, mouseID));
    if isempty(mouseFields)
        warning('No matrices found for mouse %s', mouseID);
        continue;
    end

    % --- Initialization ---
    sumMatrix = 0;  % To calculate average
    nSessions = numel(mouseFields);
    mouseSessionCounts{end+1, 1} = mouseID;   % mouse name
    mouseSessionCounts{end, 2} = nSessions;   % session count

    % --- Setup subplot figure ---
    fig = figure('Color','w','Name',sprintf('Mouse %s - All Sessions',mouseID));
    nCols = ceil(sqrt(nSessions+1));
    nRows = ceil((nSessions+1)/nCols);

    % === Mouse-specific folders ===
    parts = split(mouseID, '_');
    group = parts{1}; color = parts{2};
    mouseDir = fullfile(summaryDir, 'matfiles_and_data', 'per_mouse', sprintf('%s_%s', group, color));
    if ~isfolder(mouseDir), mkdir(mouseDir); end

    % --- Loop over sessions ---
    for i = 1:nSessions
        fieldName = mouseFields{i};
        rawMatrix = allPsMatrices.(fieldName);
        % Reminder - PS calculate like that:
        %        (a-b)/(a+b)
        %        where a=strangerTime, b=emptyTime.
        %        Returns NaN if denominator=0.
        psMatrix  = preprocessMatrix(rawMatrix, threshold, modePerExp);
        sumMatrix = sumMatrix + psMatrix;

        % Extract date and prepare display matrix
        parts = split(fieldName, '_');
        sessionDate = parts{3};
        mask = (abs(rawMatrix) > (1 - threshold));
        displayMatrix = rawMatrix; displayMatrix(mask) = NaN;

        % Save per-day raw & processed matrices
        rawFile = fullfile(mouseDir, sprintf('%s_%s_%s_raw.mat', group, color, sessionDate));
        procFile = fullfile(mouseDir, sprintf('%s_%s_%s_processed.mat', group, color, sessionDate));
        save(rawFile, 'rawMatrix', 'boundaries', 'seqTimes');
        save(procFile, 'psMatrix', 'boundaries', 'seqTimes');

        % Plot this session
        subplot(nRows, nCols, i);
        plotHeatmap(boundaries, seqTimes, displayMatrix, sessionDate);
    end

    % === Compute average ===
    avgMatrix = sumMatrix / nSessions;
    fprintf("For mouse: %s, %s — max PS: %.2f, min PS: %.2f, mean PS: %.2f\n", ...
    group, color, max(avgMatrix(:)), min(avgMatrix(:)), mean(avgMatrix(:), 'omitnan'));
    subplot(nRows, nCols, nSessions+1);
    plotAverageHeatmap(boundaries, seqTimes, avgMatrix, nSessions, true, USE_CLIM, CLIM_RANGE);

    sgtitle(sprintf('%s, %s - Outliers (|value| > %.1f) excluded', ...
        group, color, 1-threshold), 'FontSize', 10, 'Interpreter', 'none');
    set(findall(gcf,'Type','axes'),'TitleFontSizeMultiplier',0.9);

    % === Save figures ===
    SaveFolders.saveFile([], fig, fullfile(baseDir, group, color), 'all_days', {'png','fig'}, false);
    SaveFolders.saveFile([], fig, fullfile(summaryDir, 'graphs', 'all_days'), ...
        sprintf('summary_ps_%s_%s_all_days', group, color), {'png','fig'}, false);

    % === Save average-only figure ===
    figAvg = createAverageFigure(boundaries, seqTimes, avgMatrix, ...
        nSessions, group, color, threshold, USE_CLIM, CLIM_RANGE);
    SaveFolders.saveFile([], figAvg, fullfile(baseDir, group, color), 'average', {'png','fig'}, false);
    SaveFolders.saveFile([], figAvg, fullfile(summaryDir, 'graphs', 'per_mouse'), ...
        sprintf('average_ps_%s_%s', group, color), {'png','fig'}, false);

    % === Process and save averages ===
    % avgNormMatrix = preprocessMatrix(avgMatrix, threshold, modePerMouse);
    % allMatrices{end+1} = avgNormMatrix;
    allMatrices{end+1} = avgMatrix;
    mouseInfo{end+1, 1} = group;
    mouseInfo{end, 2} = color;

    avgDir = fullfile(mouseDir, 'average');
    if ~isfolder(avgDir), mkdir(avgDir); end

    % Save matrices and summary tables
    save(fullfile(avgDir, sprintf('%s_%s_avgMatrix.mat', group, color)), 'avgMatrix', 'boundaries', 'seqTimes');

    psTable = createPSTable(avgMatrix, seqTimes, boundaries);
    save(fullfile(avgDir, sprintf('%s_%s_PS_table.mat', group, color)), 'psTable');
    writetable(psTable, fullfile(avgDir, sprintf('%s_%s_PS_summary.xlsx', group, color)));
end

%% === Combine all mice ===
allNormMatrix = aggregateMatrices(allMatrices);
figAll = createAverageFigure(boundaries, seqTimes, allNormMatrix, ...
    numel(allMatrices), 'All', 'Experiments', threshold, false, CLIM_RANGE);

SaveFolders.saveFile([], figAll, fullfile(summaryDir, 'graphs', 'all_groups_average'), ...
    'average', {'png','fig'}, false);

% === Save combined data ===
allMiceDir = fullfile(summaryDir, 'matfiles_and_data', 'all_mice');
if ~isfolder(allMiceDir), mkdir(allMiceDir); end

save(fullfile(allMiceDir, 'all_mice_avgMatrix.mat'), 'allNormMatrix', 'boundaries', 'seqTimes');

allMiceTable = createPSTable(allNormMatrix, seqTimes, boundaries);
save(fullfile(allMiceDir, 'all_mice_PS_table.mat'), 'allMiceTable');
writetable(allMiceTable, fullfile(allMiceDir, 'all_mice_PS_summary.xlsx'));

%% === Logging ===
logFile = fullfile(summaryDir, sprintf('run_log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM')));
fid = fopen(logFile, 'w');

fprintf(fid, 'psAnalysis.m run completed successfully\n');
fprintf(fid, 'Date: %s\nThreshold: %.2f\n\n', datestr(now), threshold);

% --- clim configuration ---
USE_CLIM = true;       % <--- set this constant
CLIM_RANGE = [-0.7, 0.7];  % <--- define your symmetric color limits
if USE_CLIM
    fprintf(fid, 'Color scaling (clim) applied to average heatmaps: [%0.2f, %0.2f]\n\n', CLIM_RANGE(1), CLIM_RANGE(2));
else
    fprintf(fid, 'Color scaling (clim) not applied (automatic scaling used)\n\n');
end

% --- Mouse/session summary ---
fprintf(fid, 'Processed mice and session counts:\n');
for k = 1:size(mouseSessionCounts, 1)
    fprintf(fid, '  - %s (%d sessions)\n', mouseSessionCounts{k,1}, mouseSessionCounts{k,2});
end

fprintf(fid, '\nMouse-specific PS ranges (averaged matrices):\n');
for k = 1:numel(allMatrices)
    group = mouseInfo{k,1};
    color = mouseInfo{k,2};
    avgMatrix = allMatrices{k};
    fprintf(fid, '  - %s, %s — max PS: %.2f, min PS: %.2f, mean PS: %.2f\n', ...
        group, color, max(avgMatrix(:)), min(avgMatrix(:)), mean(avgMatrix(:), 'omitnan'));
end

fprintf(fid, '\nOutputs saved under:\n  %s\n', summaryDir);
fclose(fid);

disp('✓ psAnalysis completed successfully.');


%% === Helper Functions ===

% -------------------------------------------------------------------------
function mouseID = extractMouseID(fieldName)
    % extractMouseID - Extracts mouse ID (group + color) from field name.
    %
    % Description:
    %   Takes a field name like 'x8th_blue_20231112' and returns '8th_blue'.
    %
    % Args:
    %   fieldName (char): name of field in allPsMatrices.
    %
    % Output:
    %   mouseID (char): extracted group_color identifier.
    %
    % How to Use:
    %   id = extractMouseID('x8th_blue_20231112');
    % -------------------------------------------------------------------------
    parts = split(fieldName, '_');
    mouseID = strjoin(parts(1:2), '_');
end

% -------------------------------------------------------------------------
function psMatrix = preprocessMatrix(rawMatrix, threshold, mode)
    % preprocessMatrix - Preprocesses preference score matrices.
    %
    % Description:
    %   1. Masks out extreme values near ±1, optionally normalizes or z-scores.
    %   2. Set Nan values from the original matrix to 0 (Nan values originly
    %      are becuase there where non ephocs for empty or stranger at all).
    %
    % Args:
    %   rawMatrix (double): input matrix.
    %   threshold (double): exclusion range near ±1.
    %   mode (string): 'none', 'normalize', or 'zscore'.
    %
    % Output:
    %   psMatrix (double): processed matrix, masked values set to 0.
    %
    % How to Use:
    %   ps = preprocessMatrix(raw, 0.2, 'normalize');
    % -------------------------------------------------------------------------
    mask = (abs(rawMatrix) > (1 - threshold));
    psMatrix = rawMatrix; psMatrix(mask) = NaN;
    switch mode
        case 'normalize'
            minVal = min(psMatrix(:), [], 'omitnan');
            maxVal = max(psMatrix(:), [], 'omitnan');
            if maxVal > minVal
                psMatrix = 2*((psMatrix - minVal)/(maxVal - minVal)) - 1;
            end
        case 'zscore'
            mu = mean(psMatrix(:), 'omitnan');
            sigma = std(psMatrix(:), 'omitnan');
            if sigma > 0
                psMatrix = (psMatrix - mu)/sigma;
            end
    end
    psMatrix(mask) = 0;
    psMatrix(isnan(psMatrix)) = 0;
end

% -------------------------------------------------------------------------
function aggMatrix = aggregateMatrices(matrixList)
    % aggregateMatrices - Aggregates multiple matrices.
    %
    % Description:
    %   Computes element-wise average of all matrices in the list.
    %
    % Args:
    %   matrixList (cell): list of matrices.
    %
    % Output:
    %   aggMatrix (double): averaged matrix.
    % -------------------------------------------------------------------------
    if isempty(matrixList), aggMatrix = []; return; end
    n = numel(matrixList);
    aggMatrix = 0;
    for i = 1:n
        aggMatrix = aggMatrix + matrixList{i};
    end
    aggMatrix = aggMatrix / n;
end

% -------------------------------------------------------------------------
function plotHeatmap(boundaries, seqTimes, matrix, titleText)
    % plotHeatmap - Plots a single session PS heatmap.
    %
    % Args:
    %   boundaries (double): boundary values.
    %   seqTimes (double): sequence times.
    %   matrix (double): PS matrix with NaNs for masked values.
    %   titleText (char): title string.
    %
    % How to Use:
    %   plotHeatmap(boundaries, seqTimes, matrix, '20231112');
    % -------------------------------------------------------------------------
    h = imagesc(boundaries, seqTimes, matrix);
    colormap(jet); colorbar;
    xlabel('Boundary (cm)'); ylabel('Seq Time (s)');
    title(titleText, 'Interpreter','none','FontSize',8);
    set(gca, 'YDir', 'normal');
    set(h, 'AlphaData', ~isnan(matrix));
end

% -------------------------------------------------------------------------
function plotAverageHeatmap(boundaries, seqTimes, matrix, nSessions, addHeadline, USE_CLIM, CLIM_RANGE)
    % plotAverageHeatmap - Plots averaged PS heatmap.
    %
    % Args:
    %   boundaries (double): boundary values.
    %   seqTimes (double): sequence times.
    %   matrix (double): averaged PS matrix.
    %   nSessions (int): number of sessions averaged.
    %   addHeadline (bool): true to add title.
    %   USE_CLIM (logical): true = fixed scale, false = auto.
    %   CLIM_RANGE (1×2 double): color scale limits.
    % -------------------------------------------------------------------------
    imagesc(boundaries, seqTimes, matrix);
    if USE_CLIM
        clim(CLIM_RANGE);
    end
    colormap(jet); colorbar;
    xlabel('Boundary (cm)'); ylabel('Seq Time (s)');
    if addHeadline
        title(sprintf('Average (%d sessions)', nSessions), 'FontSize', 9);
    end
    set(gca, 'YDir', 'normal');
end


% -------------------------------------------------------------------------
function figAvg = createAverageFigure(boundaries, seqTimes, matrix, ...
    nSessions, group, color, threshold, USE_CLIM, CLIM_RANGE)
    % createAverageFigure - Creates standalone average figure.
    %
    % Args:
    %   boundaries, seqTimes, matrix, nSessions, group, color, threshold
    %   USE_CLIM (logical): true = fixed scale, false = auto
    %   CLIM_RANGE (1x2 double): color scale limits
    %
    % Output:
    %   figAvg (figure): handle to the created figure.
    %
    % Saved Files:
    %   Saved automatically via SaveFolders.saveFile().
    %
    % How to Use:
    %   f = createAverageFigure(boundaries, seqTimes, avg, 5, '8th', 'blue', 0.2, true, [-0.7, 0.7]);
    % -------------------------------------------------------------------------
    figAvg = figure('Color','w','Name',sprintf('Average - %s_%s', group, color));
    plotAverageHeatmap(boundaries, seqTimes, matrix, nSessions, false, USE_CLIM, CLIM_RANGE);
    sgtitle(sprintf('%s, %s - Average Only (Outliers |value| > %.1f excluded)', ...
        group, color, 1-threshold), 'FontSize', 12, 'Interpreter', 'none');
end


% -------------------------------------------------------------------------
function psTable = createPSTable(matrix, seqTimes, boundaries)
    % createPSTable - Creates a sorted table of PS values.
    %
    % Description:
    %   Converts a PS matrix to a table with columns:
    %       PS, SeqTime, Boundary
    %   Sorted by descending PS value.
    %
    % Args:
    %   matrix (double): PS matrix.
    %   seqTimes (double): sequence times.
    %   boundaries (double): boundary values.
    %
    % Output:
    %   psTable (table): sorted table of PS results.
    % -------------------------------------------------------------------------
    [B, S] = meshgrid(boundaries, seqTimes);
    PS = matrix(:);
    SeqTime = S(:);
    Boundary = B(:);
    psTable = table(PS, SeqTime, Boundary);
    psTable = sortrows(psTable, 'PS', 'descend');
end
