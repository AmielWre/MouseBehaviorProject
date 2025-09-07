% psAnalysis.m
% Script to analyze psMatrices (Preference Score) for all mice in allPsMatrices
%
% This script:
%   1. Aggregates all ps matrices per mouse (group+color)
%   2. Creates a raw sum matrix (no normalization)
%   3. Creates a normalized matrix (divide by #sessions)
%   4. Plots heatmaps styled like oneBehaveAnalysis
%   5. Creates a figure with subplots: one per session + aggregated average
%   6. Saves a separate figure for the average only
%   7. Creates and saves an overall average across all experiments
%
%   Special rule: values close to -1 or 1 are treated as 0 when aggregating.
%   Controlled by a threshold parameter (e.g., 0.2 → treat |value| > 0.8 as 0).
%   Outliers are displayed in black on the heatmap but not included in the average.

clc, clear, close all;

% Parameters
boundaries = 0 : 0.5 : 5;     % Boundary allowances in cm
seqTimes = 0 : 0.5 : 5;       % Sequence times in seconds (minimum stay in ROI)
threshold = 0.2;              % Tolerance around ±1 to treat as outlier
modePerExp = "normalize";       % Aggregation mode: 'none', 'normalize', or 'zscore'
modePerMouse = "normalize";

% -------- Collect matrices --------
path = "results\\3chamber\\boundary&sequence\\allPsMatrices.mat";
load(path, 'allPsMatrices');

% -------- Collect all fields --------
allFields = fieldnames(allPsMatrices);

% Extract unique mouse IDs (strip dates from field names)
mouseIDs = unique(cellfun(@(f) extractMouseID(f), allFields, 'UniformOutput', false));

% Overall aggregation storage (flexible pipeline)
allMatrices = {};

% Loop through each mouse
for m = 1:numel(mouseIDs)
    close all;
    mouseID = mouseIDs{m};
    % Erase prefix to group number (remove zv/x)
    mouseID = regexp(mouseID, '\d.*', 'match', 'once'); 

    % Filter fields belonging to this mouse
    mouseFields = allFields(contains(allFields, mouseID));
    if isempty(mouseFields)
        warning('No matrices found for mouse %s', mouseID);
        continue;
    end

    % Initialize aggregation
    sumMatrix = 0;
    nSessions = 0;

    % -------- Subplot figure for this mouse --------
    fig = figure('Color','w', 'Name', sprintf('Mouse %s - All Sessions', mouseID));
    nCols = ceil(sqrt(numel(mouseFields)+1));
    nRows = ceil((numel(mouseFields)+1) / nCols);

    % Loop through sessions for this mouse
    for i = 1:numel(mouseFields)
        rawMatrix = allPsMatrices.(mouseFields{i});

        % Apply normalization per matrix if needed
        psMatrix = preprocessMatrix(rawMatrix, threshold, modePerExp);
        sumMatrix = sumMatrix + psMatrix;
        nSessions = nSessions + 1;

        % Masked display matrix (for visualization only). if |value| >=
        % threshold it will be masked (white). The preprocessMatrix
        % function (above) makes sure that those values won't be account.
        displayMatrix = rawMatrix;
        mask = (rawMatrix >= (1 - threshold)) | (rawMatrix <= (-1 + threshold));
        displayMatrix(mask) = NaN;

        % Extract date from field name
        parts = split(mouseFields{i}, '_');
        sessionDate = parts{3};

        % Plot this session
        subplot(nRows, nCols, i);
        plotHeatmap(boundaries, seqTimes, displayMatrix, sessionDate);
    end

    % Avrage matrix (mouse average)
    avgMatrix = sumMatrix / nSessions;

    % Plot average in last subplot using helper function (with headline)
    subplot(nRows, nCols, numel(mouseFields)+1);
    plotAverageHeatmap(boundaries, seqTimes, avgMatrix, nSessions, true);

    % -------- Save figures --------
    parts = split(mouseID, '_');
    group = parts{1};
    color = parts{2};

    % Add super-title with padding to avoid overlap
    sgtitle(sprintf('%s, %s - Outliers (|value| > %.1f) shown in white, excluded from average', ...
        group, color, 1-threshold), 'FontSize', 10, 'Interpreter', 'none');
    set(findall(gcf,'Type','axes'),'TitleFontSizeMultiplier',0.9); % shrink subplot titles
    
    % Save in group/color folder (all sessions + average subplot)
    SaveFolders.saveMouseSummary(fig, group, color, 'all_days');
    % Save in summary_ps folder (all sessions + average subplot)
    SaveFolders.saveSummaryPs(fig, sprintf('%s_all_days', strcat(group, '_', color)));

    % -------- Save separate average-only figure --------
    figAvg = createAverageFigure(boundaries, seqTimes, avgMatrix, nSessions, group, color, threshold);
    SaveFolders.saveSummaryPsAverage(figAvg, group, color);
    SaveFolders.saveMouseSummary(figAvg, group, color, 'average');

    % -------- Collect matrices for overall analysis --------
    avgNormMatrix = preprocessMatrix(rawMatrix, threshold, modePerMouse);
    allMatrices{end+1} = avgNormMatrix;
end

% -------- Flexible aggregation across all experiments --------
allNormMatrix = aggregateMatrices(allMatrices);
figAll = createAverageFigure(boundaries, seqTimes, allNormMatrix, numel(allMatrices), 'All', 'Experiments', threshold);

% Save overall average
SaveFolders.saveSummaryPsAverage(figAll, 'all', 'experiments');
SaveFolders.saveMouseSummary(figAll, 'all', 'experiments', 'average');

% -------- Helper functions --------
function mouseID = extractMouseID(fieldName)
    % extractMouseID - Extracts group+color from field name
    %   Input:  fieldName like 'xl0th_blue_20240321'
    %   Output: mouseID like 'xl0th_blue'
    parts = split(fieldName, '_');
    mouseID = strjoin(parts(1:2), '_');
end

function psMatrix = preprocessMatrix(rawMatrix, threshold, mode)
    % preprocessMatrix - Applies preprocessing rules to a matrix
    %   rawMatrix: the raw preference score matrix
    %   threshold: values within threshold distance from ±1 are set to 0 so
    %   it won't count to the sum mat. 
    %   mode: aggregation mode ('none', 'normalize', 'zscore')
    %   Returns: processed matrix ready for aggregation

    % Mask extreme values
    mask = (rawMatrix >= (1 - threshold)) | (rawMatrix <= (-1 + threshold));
    psMatrix = rawMatrix;
    psMatrix(mask) = 0;

    switch mode
        case 'normalize'
            % Scale matrix to [-1, 1] based on min/max (if not constant)
            minVal = min(psMatrix(:));
            maxVal = max(psMatrix(:));
            if maxVal > minVal
                psMatrix = 2 * ((psMatrix - minVal) / (maxVal - minVal)) - 1;
            end
        case 'zscore'
            % Apply z-scoring (if not constant)
            mu = mean(psMatrix(:));
            sigma = std(psMatrix(:));
            if sigma > 0
                psMatrix = (psMatrix - mu) / sigma;
            end
        case 'none'
            % Leave unchanged
    end
end

function aggMatrix = aggregateMatrices(matrixList)
    % aggregateMatrices - Aggregates a list of matrices flexibly
    %   matrixList: cell array of matrices to aggregate
    %   Returns: element-wise average across matrices.
    if isempty(matrixList)
        aggMatrix = [];
        return;
    end
    n = numel(matrixList);
    aggMatrix = 0;
    for i = 1:n
        mat = matrixList{i};
        aggMatrix = aggMatrix + mat;
    end
    aggMatrix = aggMatrix / n;
end

function plotHeatmap(boundaries, seqTimes, displayMatrix, titleText)
    % plotHeatmap - Plots a single session heatmap with masked outliers
    %   boundaries: boundary allowances
    %   seqTimes: sequence times
    %   displayMatrix: matrix with NaN for outliers
    %   titleText: title string (e.g., session date)
    h = imagesc(boundaries, seqTimes, displayMatrix);
    colormap(jet);
    colorbar;
    xlabel('Boundary (cm)');
    ylabel('Seq Time (s)');
    title(titleText, 'Interpreter', 'none', 'FontSize', 8);
    set(gca, 'YDir', 'normal');
    set(h, 'AlphaData', ~isnan(displayMatrix)); % NaNs transparent
    colormap(gca, [0 0 0; jet(256)]); % prepend black for NaN
end

function plotAverageHeatmap(boundaries, seqTimes, normMatrix, nSessions, addHeadline)
    % plotAverageHeatmap - Plots the average preference score heatmap
    %   boundaries: boundary allowances
    %   seqTimes: sequence times
    %   normMatrix: normalized matrix (average over sessions)
    %   nSessions: number of sessions included
    %   addHeadline: if true, adds a title to the plot. For subplot usage this
    %                should be true, for standalone average figure this should be false.
    imagesc(boundaries, seqTimes, normMatrix);
    colormap(jet);
    colorbar;
    xlabel('Boundary (cm)');
    ylabel('Seq Time (s)');
    if addHeadline
        title(sprintf('Average (%d sessions)', nSessions), 'FontSize', 9);
    end
    set(gca, 'YDir', 'normal');
end

function figAvg = createAverageFigure(boundaries, seqTimes, normMatrix, nSessions, group, color, threshold)
    % createAverageFigure - Creates a standalone average-only figure
    %   boundaries: boundary allowances
    %   seqTimes: sequence times
    %   normMatrix: normalized matrix (average over sessions)
    %   nSessions: number of sessions included
    %   group, color: identifiers for mouse group and color
    %   threshold: outlier threshold used for exclusion
    %   Output: a figure handle containing the average heatmap
    %   Note: Calls plotAverageHeatmap with addHeadline=false to avoid subplot-style titles.
    figAvg = figure('Color','w', 'Name', sprintf('Average - %s_%s', group, color));
    plotAverageHeatmap(boundaries, seqTimes, normMatrix, nSessions, false);
    sgtitle(sprintf('%s, %s - Average Only (Outliers |value| > %.1f excluded)', ...
        group, color, 1-threshold), 'FontSize', 12, 'Interpreter', 'none');
end
