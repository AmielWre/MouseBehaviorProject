% === Test for plotPSHeatmap ===
clc; clear; close all;

% Simulate parameters
seqTimes   = 0:0.5:5;        % 11 sequence durations
boundaries = 0:0.5:5;        % 11 boundary values
saveDir    = fullfile(pwd, 'test_outputs');
if ~isfolder(saveDir), mkdir(saveDir); end

% === Create a synthetic PS matrix (Seq × Boundary) ===
% A simple pattern: PS increases with seq and decreases with boundary
[seqGrid, bndGrid] = ndgrid(seqTimes, boundaries);
psMatrix = 0.6 * tanh((seqGrid - bndGrid) / 5) + 0.1 * randn(size(seqGrid));

% === Clip to realistic range [-1, 1] ===
psMatrix(psMatrix > 1) = 1;
psMatrix(psMatrix < -1) = -1;

% === Test 1: Date level ===
plotPSHeatmap(psMatrix, seqTimes, boundaries, '10th_blue', '20240415', saveDir);

% === Test 2: Mouse level ===
plotPSHeatmap(psMatrix, seqTimes, boundaries, '10th_blue', 'average', saveDir);

% === Test 3: Overall level ===
plotPSHeatmap(psMatrix, seqTimes, boundaries, 'AllMice', 'overall', saveDir);

fprintf('✅ Test heatmaps saved to: %s\n', saveDir);



function plotPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, levelLabel, saveDir)
    % plotPSHeatmap - Generates a preference score (PS) heatmap.
    %
    % Description:
    %   Displays PS = (Stranger - Empty) / (Stranger + Empty) averaged across
    %   all brain regions, for either:
    %       - One session/date       → levelLabel = date string (e.g., '20240321')
    %       - One mouse (multi-date) → levelLabel = 'average'
    %       - Overall (all mice)     → levelLabel = 'overall'
    %
    % Inputs:
    %   psMatrix   (double) : [numel(seqTimes) × numel(boundaries)] PS matrix
    %   seqTimes   (vector) : Sequence durations (s)
    %   boundaries (vector) : Boundary distances (cm)
    %   mouseID    (char)   : Mouse name or 'AllMice'
    %   levelLabel (char)   : One of {date, 'average', 'overall'}
    %   saveDir    (char)   : Directory to save PNG output
    %
    % -------------------------------------------------------------------------

    if isempty(psMatrix) || all(isnan(psMatrix(:)))
        warning('Empty PS data — skipping heatmap for %s (%s)', mouseID, levelLabel);
        return;
    end

    if ~isfolder(saveDir), mkdir(saveDir); end

    % === Determine title and file name ===
    switch lower(levelLabel)
        case 'average'
            titleText = sprintf('%s | Mean across sessions', mouseID);
            fileSuffix = 'mean';
        case 'overall'
            titleText = 'All Mice | Overall Preference Score';
            fileSuffix = 'overall';
        otherwise
            titleText = sprintf('%s | Date: %s', mouseID, levelLabel);
            fileSuffix = levelLabel;
    end

    % === Plot heatmap ===
    fig = figure('Visible', 'off', 'Color', 'w');
    imagesc(boundaries, seqTimes, psMatrix);
    colormap(jet); colorbar;
    caxis([-1 1]);
    set(gca, 'YDir', 'normal');
    xlabel('Boundary (cm)');
    ylabel('Sequence time (s)');
    title(sprintf('%s | Preference Score Heatmap', titleText), ...
          'Interpreter', 'none', 'FontWeight', 'bold', 'FontSize', 12);
    set(gca, 'FontSize', 9, 'LineWidth', 0.8);
    grid on;

    % === Save ===
    saveName = sprintf('ps_heatmap_%s.png', fileSuffix);
    saveas(fig, fullfile(saveDir, saveName));
    close(fig);
end
