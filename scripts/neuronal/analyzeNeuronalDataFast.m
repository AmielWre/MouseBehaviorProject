%% === Main Data Structures Documentation ===
% summaryData: Structure holding aggregated neuronal data per mouse.
%   - summaryData.<mouseID>.stranger : [N_sessions x N_regions] matrix with mean ΔF/F during stranger epochs.
%   - summaryData.<mouseID>.empty    : [N_sessions x N_regions] matrix with mean ΔF/F during empty epochs.
%
% meanStranger, meanEmpty: Arrays holding per-session average neuronal activity for one mouse.
%   - Each is [N_sessions x N_regions] double.
%
% regionNames: Cell array of region short names (1x24 cell).
%
% seqTimes, boundaries: Numeric vectors defining analyzed sequence times and boundaries.
%
% allPsMatrices: Loaded struct from previous behavioral analysis containing per-session PS metrics.
%
% mouseIDs: Cell array of unique identifiers per mouse, extracted from field names.
%
% Folder outputs follow hierarchical structure:
%   results/3chamber/boundary&sequence/neuronal_analysis/
%     ├── per_mouse/<mouseID>/average/
%     │   ├── region_distributions/
%     │   ├── ps_heatmaps/
%     │   ├── bars_seq_b/
%     │   └── brain_maps/
%     ├── per_mouse/<mouseID>/date/
%     │   ├── region_distributions/
%     │   ├── ps_heatmaps/
%     │   ├── bars_seq_b/
%     │   └── brain_maps/
%     └── overall/
%         ├── region_distributions/
%         ├── ps_heatmaps/
%         ├── bars_seq_b/
%         └── brain_maps/
%
% Each folder holds .png visualizations corresponding to histograms, bar plots, heatmaps, or (later) brain maps.

clc; clear; close all;

% === Paths and parameters ===
baseDirResults = fullfile("results", "3chamber", "boundary&sequence");
resultsDir = fullfile(baseDirResults, "neuronal_analysis");
if ~isfolder(resultsDir), mkdir(resultsDir); end

allDataFile = fullfile(resultsDir, "allData.mat");

% === Load or build allData ===
if isfile(allDataFile)
    fprintf("Loading existing allData from disk...\n");
    load(allDataFile, "allData", "seqTimes", "boundaries");
else
    fprintf("No saved allData found. Building dataset...\n");
    [allData, seqTimes, boundaries] = buildAllData(resultsDir);
end

% === Continue with main analysis ===
regionNames = {'DI','Cl','Cpu','CpuA','AcbShv','AcbC','AcbSh','M1','IL','PrL', ...
               'PrL2','Cg1','BLA','CeL','CPu-GP','CpuP','S1BC','S1BC2','CA3', ...
               'Thl-VPM','Thl-VL','Thl-Po','CA1','DG'};

perMouseDir = fullfile(resultsDir, "per_mouse");
overallDir  = fullfile(resultsDir, "overall");
if ~isfolder(perMouseDir), mkdir(perMouseDir); end
if ~isfolder(overallDir), mkdir(overallDir); end

summaryData = struct();

mouseIDs = fieldnames(allData);

%% === Load Preprocessed Data ===
clc; clear; close all;

baseDirResults = fullfile("results", "3chamber", "boundary&sequence");
resultsDir = fullfile(baseDirResults, "neuronal_analysis");
load(fullfile(resultsDir, "allData.mat"), "allData", "seqTimes", "boundaries");

regionNames = {'DI','Cl','Cpu','CpuA','AcbShv','AcbC','AcbSh','M1','IL','PrL', ...
               'PrL2','Cg1','BLA','CeL','CPu-GP','CpuP','S1BC','S1BC2','CA3', ...
               'Thl-VPM','Thl-VL','Thl-Po','CA1','DG'};

perMouseDir = fullfile(resultsDir, "per_mouse");
overallDir  = fullfile(resultsDir, "overall");
if ~isfolder(perMouseDir), mkdir(perMouseDir); end
if ~isfolder(overallDir), mkdir(overallDir); end

summaryData = struct();

%% === Process Each Mouse ===
mouseIDs = fieldnames(allData);

for m = 1:numel(mouseIDs)
    safeMouseID = mouseIDs{m};
    mouseID = regexprep(safeMouseID, '_', ' '); % restore name if started with number

    fprintf('\nProcessing %s...\n', mouseID);
    mouseDir = fullfile(perMouseDir, mouseID);
    mkdirs(fullfile(mouseDir, 'average'), {'region_distributions','ps_heatmaps','bars_seq_b','brain_maps'});

    sessionNames = fieldnames(allData.(safeMouseID).sessions);

    for d = 1:numel(sessionNames)
        safeDate = sessionNames{d};
        date = regexprep(safeDate, '_', ' '); % restore name if started with number
        dateDir = fullfile(mouseDir, date);
        mkdirs(dateDir, {'region_distributions','ps_heatmaps','bars_seq_b','brain_maps'});

        processDateLevel(mouseID, date, seqTimes, boundaries, regionNames, dateDir, allData.(safeMouseID).sessions.(date));
    end

    [mouseStranger, mouseEmpty, psMatrix] = processMouseLevel(mouseID, seqTimes, boundaries, regionNames, mouseDir, allData.(safeMouseID));
    summaryData.(safeMouseID).stranger = mouseStranger;
    summaryData.(safeMouseID).empty = mouseEmpty;
    summaryData.(safeMouseID).psMatrix = psMatrix;
end

save(fullfile(resultsDir, "summaryData.mat"), "summaryData", "-v7.3");
processOverall(summaryData, seqTimes, boundaries, regionNames, overallDir);



function [allData, seqTimes, boundaries] = buildAllData(resultsDir)
% buildAllData - Traverse neuronal_epoch_data and aggregate all mice, sessions, and parameters.
%
% Description:
%   Scans the hierarchical directory structure under:
%       data/processed/neuronal_epoch_data/
%   and builds a unified structure `allData` containing, for each mouse:
%       • Date-level (session) data — X, y, mean_stranger, mean_empty per seq×boundary
%       • Average-level data — mean_stranger_mouse, mean_empty_mouse per seq×boundary
%
%   The function runs only once; subsequent runs should reuse the saved file:
%       results/3chamber/boundary&sequence/neuronal_analysis/allData.mat
%
% Outputs:
%   allData    (struct): Nested data structure organized as
%       allData.<mouse>.sessions.<date>.seq(sIdx).b(bIdx).X / y / meanS / meanE
%       allData.<mouse>.average.seq(sIdx).b(bIdx).meanS / meanE
%
%   seqTimes   (numeric vector): Tested sequence durations
%   boundaries (numeric vector): Tested boundary values
%
% Saved File:
%   fullfile(resultsDir, "allData.mat")
%
% Notes:
%   - Uses safe field names for mice/dates starting with digits.
%   - Skips missing or empty files gracefully.
%   - Heavy operation — expected to run once, then cached.
%
% -------------------------------------------------------------------------

% === Parameters ===
    dataDir = fullfile("data", "processed", "neuronal_epoch_data");
    seqTimes = 0:0.5:5;
    boundaries = 0:0.5:5;
    
    allData = struct();
    
    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx);
        seqDir = sprintf('seq%.1f', seq);
    
        for bIdx = 1:numel(boundaries)
            b = boundaries(bIdx);
            bDir = sprintf('b%.1f', b);
            seqBPath = fullfile(dataDir, seqDir, bDir);
            if ~isfolder(seqBPath), continue; end
    
            mouseDirs = dir(fullfile(seqBPath, '*_*'));
            mouseDirs = mouseDirs([mouseDirs.isdir]);
    
            for m = 1:numel(mouseDirs)
                mouseID = mouseDirs(m).name;
                safeMouseID = matlab.lang.makeValidName(mouseID); % for struct fieldnames
    
                % assign to mouse level
                mousePath = fullfile(seqBPath, mouseID);
                fS = fullfile(mousePath, 'average', sprintf('mean_stranger_mouse_%s.mat', mouseID));
                fE = fullfile(mousePath, 'average', sprintf('mean_empty_mouse_%s.mat', mouseID));
                meanS = []; meanE = [];
                if isfile(fS)
                    dS = load(fS); fnS = fieldnames(dS); meanS = dS.(fnS{1});
                end
                if isfile(fE)
                    dE = load(fE); fnE = fieldnames(dE); meanE = dE.(fnE{1});
                end
                allData.(safeMouseID).average.seq(sIdx).b(bIdx).meanS = meanS;
                allData.(safeMouseID).average.seq(sIdx).b(bIdx).meanE = meanE;
    
    
                dateDirs = dir(fullfile(seqBPath, mouseID, '20*'));
                dateDirs = dateDirs([dateDirs.isdir]);
    
                for d = 1:numel(dateDirs)
                    dateName = dateDirs(d).name;
                    fprintf('Seq %.1f, B %.1f | %s | %s\n', seq, b, mouseID, dateName);
                    safeDate = matlab.lang.makeValidName(dateName); % for struct fieldnames
    
                    % build paths
                    datePath = fullfile(seqBPath, mouseID, dateName);
                    fX = fullfile(datePath, sprintf('X_epochs_%s_%s.mat', mouseID, dateName));
                    fY = fullfile(datePath, sprintf('y_epochs_%s_%s.mat', mouseID, dateName));
                    fS = fullfile(datePath, sprintf('mean_stranger_%s_%s.mat', mouseID, dateName));
                    fE = fullfile(datePath, sprintf('mean_empty_%s_%s.mat', mouseID, dateName));
    
                    if ~isfile(fX) || ~isfile(fY), continue; end
    
                    % load
                    Xd = load(fX); fnX = fieldnames(Xd); X = Xd.(fnX{1});
                    Yd = load(fY); fnY = fieldnames(Yd); y = Yd.(fnY{1});
    
                    meanS = []; meanE = [];
                    if isfile(fS)
                        dS = load(fS); fnS = fieldnames(dS); meanS = dS.(fnS{1});
                    end
                    if isfile(fE)
                        dE = load(fE); fnE = fieldnames(dE); meanE = dE.(fnE{1});
                    end
    
                    % assign to date level
                    allData.(safeMouseID).sessions.(safeDate).seq(sIdx).b(bIdx).X = X;
                    allData.(safeMouseID).sessions.(safeDate).seq(sIdx).b(bIdx).y = y;
                    allData.(safeMouseID).sessions.(safeDate).seq(sIdx).b(bIdx).meanS = meanS;
                    allData.(safeMouseID).sessions.(safeDate).seq(sIdx).b(bIdx).meanE = meanE;
                end            
    
            end
        end
    end
    
    % === Save master dataset ===
    save(fullfile(resultsDir, "allData.mat"), "allData", "seqTimes", "boundaries", "-v7.3");
    fprintf("✔ allData saved to %s\n", fullfile(resultsDir, "allData.mat"));
    % === Save results ===
    save(fullfile(resultsDir, "allData.mat"), "allData", "seqTimes", "boundaries", "-v7.3");
    fprintf("✔ allData saved to %s\n", fullfile(resultsDir, "allData.mat"));
end


%% === Helper Functions ===
function mouseID = extractMouseID(fieldName)
    parts = split(fieldName, '_'); mouseID = strjoin(parts(1:2), '_');
    mouseID = regexp(mouseID, '\d.*', 'match', 'once');
end

function mkdirs(base, subs)
    for i = 1:numel(subs)
        d = fullfile(base, subs{i}); if ~isfolder(d), mkdir(d); end
    end
end

function [strangerMeans, emptyMeans] = collectSessionMeans(mouseFolderPath, mouseID)
    % collectSessionMeans - Loads and aggregates mean neuronal activity across sessions.
    %
    % Description:
    %   This function scans all session folders within a given mouse directory
    %   (identified by date format, e.g. '20240321') and loads the corresponding
    %   precomputed mean neuronal activity for both "stranger" and "empty" epochs.
    %   It returns matrices where each row corresponds to one session, and
    %   each column corresponds to one brain region (e.g., 24 regions total).
    %
    % Inputs:
    %   mouseFolderPath (char or string)
    %       Path to the specific mouse folder under neuronal_epoch_data
    %       (e.g., 'data/processed/neuronal_epoch_data/seq0.0/b0.5/10th_blue')
    %
    %   mouseID (char or string)
    %       Identifier of the mouse (e.g., '10th_blue')
    %
    % Outputs:
    %   strangerMeans (double matrix)
    %       [N_sessions × N_regions] matrix, each row representing the
    %       mean neuronal activity during stranger epochs per session.
    %
    %   emptyMeans (double matrix)
    %       [N_sessions × N_regions] matrix, each row representing the
    %       mean neuronal activity during empty epochs per session.
    %
    % Example:
    %   [strangerMeans, emptyMeans] = collectSessionMeans( ...
    %       'data/processed/neuronal_epoch_data/seq0.0/b0.5/10th_blue', ...
    %       '10th_blue');
    %
    % Notes:
    %   - Only folders beginning with '20' (e.g., dates) are processed.
    %   - Each .mat file is expected to contain a single variable with
    %     region-wise mean activity values.
    %   - Sessions missing either 'mean_stranger' or 'mean_empty' files are skipped.
    %
    % -------------------------------------------------------------------------
    
    sessionFolders = dir(fullfile(mouseFolderPath, '20*'));
    strangerMeans = [];
    emptyMeans = [];
    
    for iSession = 1:numel(sessionFolders)
        sessionDate = sessionFolders(iSession).name;
        
        % Build expected filenames for mean activity data
        fileStranger = fullfile(mouseFolderPath, sessionDate, ...
            sprintf('mean_stranger_%s_%s.mat', mouseID, sessionDate));
        fileEmpty = fullfile(mouseFolderPath, sessionDate, ...
            sprintf('mean_empty_%s_%s.mat', mouseID, sessionDate));
        
        % Skip session if files are missing
        if ~isfile(fileStranger) || ~isfile(fileEmpty)
            warning('Missing files for %s (%s) — skipped.', mouseID, sessionDate);
            continue;
        end
        
        % Load data from files
        dataStranger = load(fileStranger);
        dataEmpty = load(fileEmpty);
        
        % Extract numeric content (handle arbitrary field names)
        fnStranger = fieldnames(dataStranger);
        fnEmpty = fieldnames(dataEmpty);
        valsStranger = dataStranger.(fnStranger{1});
        valsEmpty = dataEmpty.(fnEmpty{1});
        
        % Ensure row vector and append to results
        strangerMeans = [strangerMeans; valsStranger(:)'];
        emptyMeans = [emptyMeans; valsEmpty(:)'];
    end
end


function processDateLevel(mouseID, dateName, seqTimes, boundaries, regionNames, dateDir, dateData)
    % processDateLevel - Analyze neuronal data for one mouse and one session (date)
    %
    % Description:
    %   Processes the preloaded session data (from allData) for one mouse and date.
    %   For each combination of sequence time (seq) and boundary (b), it:
    %       • Retrieves preloaded ΔF/F matrices and labels (X, y)
    %       • Separates "stranger" and "empty" epochs
    %       • Computes mean ΔF/F per region
    %       • Plots:
    %           - Region-wise distribution plots (boxplots + stats)
    %           - Per (seq,b) bar plots (stranger vs empty)
    %   After all combinations, it also builds a behavioral-style
    %   Preference Score (PS) heatmap for the full session.
    %
    % Inputs:
    %   mouseID     (char)   : Mouse identifier (e.g., '10th_blue')
    %   dateName    (char)   : Session date (e.g., '20240321')
    %   seqTimes    (numeric): Sequence durations (s)
    %   boundaries  (numeric): Boundary distances (cm)
    %   regionNames (cellstr): Brain region short names (1x24 cell)
    %   dateDir     (char)   : Output directory for this specific date
    %   dateData    (struct) : Data subset from allData.(safeMouseID).sessions.(safeDate)
    %
    % Outputs:
    %   Saves plots under:
    %       <dateDir>/region_distributions/<region>/
    %       <dateDir>/bars_seq_b/
    %       <dateDir>/ps_heatmaps/
    %
    % Dependencies:
    %   Requires helper functions:
    %       plotDistributionWithStats()
    %       processBars()
    %       plotPSHeatmap()
    %
    % -------------------------------------------------------------------------
    
    fprintf('\n-%s \n', dateName);
    
    % === Initialize output directories ===
    distDir    = fullfile(dateDir, 'region_distributions');
    barsDir    = fullfile(dateDir, 'bars_seq_b');
    heatmapDir = fullfile(dateDir, 'ps_heatmaps');
    for d = {distDir, barsDir, heatmapDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end
    
    % === Initialize PS matrix (Seq × Boundary) ===
    psMatrix = nan(numel(seqTimes), numel(boundaries));
    
    % === Iterate through seq × boundary combinations ===
    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx);
        for bIdx = 1:numel(boundaries)
            b = boundaries(bIdx);
    
            % Validate field existence
            if numel(dateData.seq) < sIdx || isempty(dateData.seq(sIdx).b) ...
                    || numel(dateData.seq(sIdx).b) < bIdx
                continue;
            end
    
            entry = dateData.seq(sIdx).b(bIdx);
    
            if ~isfield(entry, 'X') || isempty(entry.X) || ...
               ~isfield(entry, 'y') || isempty(entry.y)
                warning('No data for %s | %s | Seq%.1f B%.1f', mouseID, dateName, seq, b);
                continue;
            end
    
            X = entry.X;
            y = entry.y;
    
            % Separate stranger / empty epochs
            strangerIdx = (y == 1);
            emptyIdx    = (y == 0);
    
            strangerVals = X(strangerIdx, :);
            emptyVals    = X(emptyIdx, :);
    
            % Skip invalid data
            if isempty(strangerVals) && isempty(emptyVals)
                warning('Empty X for %s | %s | Seq%.1f B%.1f', mouseID, dateName, seq, b);
                continue;
            end
    
            % === Region-level plots ===
            for r = 1:numel(regionNames)
                regionDir = fullfile(distDir, regionNames{r});
                if ~isfolder(regionDir), mkdir(regionDir); end
                valsS = strangerVals(:, r);
                valsE = emptyVals(:, r);
    
                if all(isnan(valsS)) && all(isnan(valsE))
                    continue;
                end
    
                plotDistributionWithStats(valsE, valsS, ...
                    mouseID, regionNames{r}, seq, b, regionDir, dateName);
            end
    
            % === Bar plot ===
            processBars(strangerVals, emptyVals, mouseID, seq, b, regionNames, barsDir);
    
            % === Compute overall PS ===
            meanStranger = mean(strangerVals, "all", "omitnan");
            meanEmpty    = mean(emptyVals, "all", "omitnan");
            psMatrix(sIdx, bIdx) = (meanStranger - meanEmpty) / (meanStranger + meanEmpty + eps);
        end
    end
    
    % === Plot PS heatmap ===
    plotPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, dateName, heatmapDir);
    
    fprintf('✔ Done: %s | %s\n', mouseID, dateName);
end


function [mouseStranger, mouseEmpty, psMatrix] = processMouseLevel(mouseID, seqTimes, boundaries, regionNames, mouseDir)
    % processMouseLevel - Aggregate neuronal data across all sessions of one mouse.
    %
    % Description:
    %   Combines per-session (date-level) data for one mouse across all
    %   sequence × boundary conditions. For each (seq,b) pair, it loads
    %   per-session mean activity, computes averaged stranger vs. empty
    %   values per region, and generates:
    %       - Region-wise aggregated distribution plots
    %       - Summary bar plots
    %       - Behavioral-style PS heatmap (Seq × Boundary)
    %
    % Inputs:
    %   mouseID (char): Mouse identifier, e.g. '10th_blue'
    %   seqTimes (vector): Tested sequence durations (s)
    %   boundaries (vector): Tested boundary distances (cm)
    %   regionNames (cellstr): List of brain region short names
    %   mouseDir (char): Output folder for this mouse (contains all dates)
    %
    % Outputs:
    %   Saves results under:
    %       <mouseDir>/average/region_distributions/<region>/
    %       <mouseDir>/average/bars_seq_b/
    %       <mouseDir>/average/ps_heatmaps/
    %
    % -------------------------------------------------------------------------

    fprintf('\n=== Aggregating data for mouse %s ===\n', mouseID);

    % --- Setup output directories ---
    avgDir = fullfile(mouseDir, 'average');
    distDir = fullfile(avgDir, 'region_distributions');
    barsDir = fullfile(avgDir, 'bars_seq_b');
    heatmapDir = fullfile(avgDir, 'ps_heatmaps');
    for d = {distDir, barsDir, heatmapDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end

    % --- Base data directory ---
    dataBase = fullfile("data", "processed", "neuronal_epoch_data");

    % --- Initialize containers ---
    psMatrix = nan(numel(seqTimes), numel(boundaries));     % mean PS per (seq,b)
    allStranger = []; allEmpty = [];                        % for overall region plots

    % --- Loop through all combinations ---
    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx); seqDir = sprintf('seq%.1f', seq);

        for bIdx = 1:numel(boundaries)
            b = boundaries(bIdx); bDir = sprintf('b%.1f', b);

            % locate all session folders for this mouse
            seqBPath = fullfile(dataBase, seqDir, bDir, mouseID);
            if ~isfolder(seqBPath)
                warning('Missing seq/b folder for %s | Seq%.1f B%.1f', mouseID, seq, b);
                continue;
            end

            % get all session (date) subfolders
            dateFolders = dir(fullfile(seqBPath, '20*'));
            if isempty(dateFolders)
                warning('No date folders found for %s | Seq%.1f B%.1f', mouseID, seq, b);
                continue;
            end

            % accumulate means across dates
            dateMeansStranger = [];
            dateMeansEmpty = [];

            for d = 1:numel(dateFolders)
                dateName = dateFolders(d).name;
                meanSPath = fullfile(seqBPath, dateName, sprintf('mean_stranger_%s_%s.mat', mouseID, dateName));
                meanEPath = fullfile(seqBPath, dateName, sprintf('mean_empty_%s_%s.mat', mouseID, dateName));
                if ~isfile(meanSPath) || ~isfile(meanEPath)
                    continue;
                end

                dS = load(meanSPath); fnS = fieldnames(dS); valsS = dS.(fnS{1});
                dE = load(meanEPath); fnE = fieldnames(dE); valsE = dE.(fnE{1});

                if isempty(valsS) || isempty(valsE)
                    continue;
                end

                dateMeansStranger = [dateMeansStranger; valsS(:)'];
                dateMeansEmpty = [dateMeansEmpty; valsE(:)'];
            end

            if isempty(dateMeansStranger) || isempty(dateMeansEmpty)
                warning('No valid mean data for %s | Seq%.1f B%.1f', mouseID, seq, b);
                continue;
            end

            % --- Store for overall plots ---
            allStranger = [allStranger; dateMeansStranger];
            allEmpty = [allEmpty; dateMeansEmpty];

            % --- Region-wise plots ---
            for r = 1:numel(regionNames)
                regDir = fullfile(distDir, regionNames{r});
                if ~isfolder(regDir), mkdir(regDir); end
                valsS = dateMeansStranger(:, r);
                valsE = dateMeansEmpty(:, r);
                if all(isnan(valsS)) && all(isnan(valsE)), continue; end

                plotDistributionWithStats(valsE, valsS, mouseID, regionNames{r}, seq, b, regDir, 'average');
            end

            % --- Bar plot per (seq,b) ---
            processBars(dateMeansStranger, dateMeansEmpty, mouseID, seq, b, regionNames, barsDir);

            % --- Compute PS value ---
            meanS = mean(dateMeansStranger, "all", "omitnan");
            meanE = mean(dateMeansEmpty, "all", "omitnan");
            psMatrix(sIdx, bIdx) = (meanS - meanE) / (meanS + meanE + eps);
        end
    end

    % --- Generate PS heatmap (aggregated across sessions) ---
    plotPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, 'average', heatmapDir);

    fprintf('✔ Done: Mouse-level analysis complete for %s\n', mouseID);

    % --- Store mean activity across all seq×b combinations ---
    mouseStranger = allStranger;
    mouseEmpty = allEmpty;
end


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


function processBars(strangerVals, emptyVals, mouseID, seqTime, boundary, regionNames, saveDir)
    % processBars - Generates grouped bar plots comparing stranger vs empty activity.
    %
    % Description:
    %   Creates a simple grouped bar chart comparing mean neuronal activity
    %   between stranger and empty epochs for all regions.
    %
    % -------------------------------------------------------------------------
    fig = figure('Visible', 'off', 'Color', 'w'); hold on;
    x = 1:numel(regionNames);
    bar(x - 0.15, mean(emptyVals, 1), 0.3, 'FaceColor', [0.6 0.6 0.6]);
    bar(x + 0.15, mean(strangerVals, 1), 0.3, 'FaceColor', [1 0 0]);
    title(sprintf('%s | Seq%.1f B%.1f', mouseID, seqTime, boundary), 'Interpreter', 'none');
    set(gca, 'XTick', 1:numel(regionNames), 'XTickLabel', regionNames, 'XTickLabelRotation', 45);
    ylabel('Mean ΔF/F'); legend({'Empty', 'Stranger'}, 'Location', 'best'); box off;
    if ~isfolder(saveDir), mkdir(saveDir); end
    saveas(fig, fullfile(saveDir, sprintf('bar_seq%.1f_b%.1f.png', seqTime, boundary)));
    close(fig);
end


function plotDistributionWithStats(emptyVals, strangerVals, mouseID, regionName, seqTime, boundary, saveDir, label)
    % plotDistributionWithStats - Compare Empty vs Stranger distributions and show statistics.
    %
    % Description:
    %   Creates transparent boxplots with jittered points for both conditions,
    %   computes consistency and comparison metrics, and annotates results.
    %   Displays all information in a two-line title (main + summary) for clarity.
    %   Outliers are automatically labeled with mouse and session info.
    %
    % Inputs:
    %   emptyVals, strangerVals (double arrays): ΔF/F values per epoch
    %   mouseID (char): current mouse ID (e.g. '10th_blue')
    %   regionName (char): brain region short name (e.g. 'DI')
    %   seqTime (double): sequence duration in seconds
    %   boundary (double): boundary threshold (cm)
    %   saveDir (char): directory to save figure
    %   label (char): session/date label or "sessions"/"mice"
    %
    % -------------------------------------------------------------------------
    
    fig = figure('Visible', 'off', 'Color', 'w');
    hold on;

    % === Handle missing or invalid data early ===
    if isempty(emptyVals) || all(isnan(emptyVals))
        warning('No valid EMPTY data for %s | %s | Seq%.1f B%.1f | %s', ...
            mouseID, regionName, seqTime, boundary, label);
        emptyVals = NaN;  % keep placeholder so plotting works
    end
    
    if isempty(strangerVals) || all(isnan(strangerVals))
        warning('No valid STRANGER data for %s | %s | Seq%.1f B%.1f | %s', ...
            mouseID, regionName, seqTime, boundary, label);
        strangerVals = NaN;
    end

    % === Compute descriptive stats ===
    emptyStats    = computeConsistencyStats(emptyVals);
    strangerStats = computeConsistencyStats(strangerVals);
    if numel(emptyVals) > 2 && numel(strangerVals) > 2
        [~, pKS] = kstest2(emptyVals, strangerVals);
    else
        pKS = NaN;
    end

    % === Plot transparent boxplots with missing-data handling ===
    positions = [1 2];
    
    % --- Handle missing / NaN data early ---
    if isempty(emptyVals) || all(isnan(emptyVals))
        warning('No valid EMPTY data for %s | %s | Seq%.1f B%.1f | %s', ...
            mouseID, regionName, seqTime, boundary, label);
        emptyVals = NaN;  % placeholder for plotting
    end
    if isempty(strangerVals) || all(isnan(strangerVals))
        warning('No valid STRANGER data for %s | %s | Seq%.1f B%.1f | %s', ...
            mouseID, regionName, seqTime, boundary, label);
        strangerVals = NaN;
    end
    
    % --- Draw boxplots (NaN-safe) ---
    boxchart(ones(size(emptyVals))*positions(1), emptyVals, ...
        'BoxFaceColor', [0.6 0.6 0.6], 'BoxFaceAlpha', 0.25, ...
        'MarkerStyle', 'none', 'WhiskerLineColor', [0.4 0.4 0.4], 'LineWidth', 0.8);
    boxchart(ones(size(strangerVals))*positions(2), strangerVals, ...
        'BoxFaceColor', [1 0 0], 'BoxFaceAlpha', 0.25, ...
        'MarkerStyle', 'none', 'WhiskerLineColor', [0.6 0 0], 'LineWidth', 0.8);
    
    % --- Overlay jittered points (only for valid data) ---
    if ~all(isnan(emptyVals))
        scatter(repmat(positions(1), numel(emptyVals), 1) + 0.05*randn(numel(emptyVals), 1), ...
            emptyVals, 25, [0.3 0.3 0.3], 'filled', 'MarkerFaceAlpha', 0.7);
    else
        text(positions(1), 0, 'No data', 'HorizontalAlignment', 'center', ...
            'Color', [0.4 0.4 0.4], 'FontAngle', 'italic', 'FontSize', 8);
    end
    
    if ~all(isnan(strangerVals))
        scatter(repmat(positions(2), numel(strangerVals), 1) + 0.05*randn(numel(strangerVals), 1), ...
            strangerVals, 25, [1 0 0], 'filled', 'MarkerFaceAlpha', 0.7);
    else
        text(positions(2), 0, 'No data', 'HorizontalAlignment', 'center', ...
            'Color', [0.7 0.1 0.1], 'FontAngle', 'italic', 'FontSize', 8);
    end


    % === Axis formatting ===
    xlim([0.5 2.5]);
    xticks(positions);
    xticklabels({'Empty', 'Stranger'});
    ylabel('ΔF/F', 'FontSize', 10);
    set(gca, 'FontSize', 9, 'Box', 'off');

    % === Main and secondary title ===
    mainTitle = sprintf('%s | %s | Seq%.1f B%.1f | %s', mouseID, regionName, seqTime, boundary, label);
    statsLine = sprintf('Empty: n=%d, CV=%.2f, MAD=%.3f \n Stranger: n=%d, CV=%.2f, MAD=%.3f | K–S p=%.3f', ...
        numel(emptyVals), emptyStats.cv, emptyStats.mad, ...
        numel(strangerVals), strangerStats.cv, strangerStats.mad, pKS);
    title(mainTitle, 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    subtitle(statsLine, 'Interpreter', 'none', 'FontSize', 9, 'FontWeight', 'normal');

    % === Annotate outliers with contextual labels ===
    % outlierIdxEmpty = isoutlier(emptyVals);
    % outlierIdxStranger = isoutlier(strangerVals);
    % 
    % for i = find(outlierIdxEmpty)'
    %     txtLabel = getOutlierLabel(label, i, mouseID, 'Empty');
    %     text(positions(1) - 0.1, emptyVals(i), txtLabel, ...
    %         'FontSize', 7, 'Color', [0.3 0.3 0.3], 'Rotation', 20, ...
    %         'HorizontalAlignment','right','Interpreter', 'none');
    % end
    % for i = find(outlierIdxStranger)'
    %     txtLabel = getOutlierLabel(label, i, mouseID, 'Stranger');
    %     text(positions(2) + 0.1, strangerVals(i), txtLabel, ...
    %         'FontSize', 7, 'Color', [0.8 0 0], 'Rotation', 20, ...
    %         'HorizontalAlignment','left','Interpreter', 'none');
    % end

    % === Save figure ===
    if ~isfolder(saveDir), mkdir(saveDir); end
    saveas(fig, fullfile(saveDir, sprintf('seq%.1f_b%.1f_%s.png', seqTime, boundary, label)));
    close(fig);
end


function processOverall(summaryData, seqTimes, boundaries, regionNames, overallDir)
    % processOverall - Aggregate and visualize neuronal data across all mice.
    %
    % Description:
    %   Combines per-mouse averaged neuronal data to generate:
    %       - Region-wise distributions across mice
    %       - Group-level bar plots (Stranger vs Empty)
    %       - Overall PS heatmap (Seq × Boundary) averaged across all mice
    %
    % Inputs:
    %   summaryData (struct): Contains .<mouseID>.stranger and .empty matrices
    %   seqTimes (numeric): Tested sequence durations (s)
    %   boundaries (numeric): Tested boundary distances (cm)
    %   regionNames (cellstr): List of brain region short names
    %   overallDir (char): Output folder for overall-level analysis
    %
    % Output:
    %   Saves results under:
    %       <overallDir>/region_distributions/<region>/
    %       <overallDir>/bars_seq_b/
    %       <overallDir>/ps_heatmaps/
    %
    % -------------------------------------------------------------------------

    fprintf('\n=== Building Overall Summary Across All Mice ===\n');

    % --- Setup output directories ---
    distDir = fullfile(overallDir, 'region_distributions');
    barsDir = fullfile(overallDir, 'bars_seq_b');
    heatmapDir = fullfile(overallDir, 'ps_heatmaps');
    for d = {distDir, barsDir, heatmapDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end

    % --- Initialize containers ---
    allStranger = []; 
    allEmpty = [];
    psMatrixAll = nan(numel(seqTimes), numel(boundaries)); % aggregated PS matrix

    % --- Extract data from all mice ---
    mouseIDs = fieldnames(summaryData);
    if isempty(mouseIDs)
        warning('No mouse data found in summaryData.');
        return;
    end

    for m = 1:numel(mouseIDs)
        mouseID = mouseIDs{m};
        data = summaryData.(mouseID);

        if ~isfield(data, 'stranger') || ~isfield(data, 'empty')
            warning('Skipping %s (missing data fields)', mouseID);
            continue;
        end
        if isempty(data.stranger) || isempty(data.empty)
            warning('Skipping %s (empty data matrices)', mouseID);
            continue;
        end

        % store for global region-level plots
        allStranger = [allStranger; data.stranger];
        allEmpty = [allEmpty; data.empty];
    end

    % --- Validate collected data ---
    if isempty(allStranger) || isempty(allEmpty)
        warning('No aggregated data available for overall-level plotting.');
        return;
    end

    % --- Region-wise distributions across mice ---
    for r = 1:numel(regionNames)
        regDir = fullfile(distDir, regionNames{r});
        if ~isfolder(regDir), mkdir(regDir); end
        valsS = allStranger(:, r);
        valsE = allEmpty(:, r);
        if all(isnan(valsS)) && all(isnan(valsE)), continue; end

        plotDistributionWithStats(valsE, valsS, 'AllMice', regionNames{r}, 0, 0, regDir, 'overall');
    end

    % --- Mean across all regions for bar plot ---
    processBars(allStranger, allEmpty, 'AllMice', 0, 0, regionNames, barsDir);

    % --- Compute overall PS matrix (average across all mice) ---
    % For this, we expect each mouse’s per-seq,b averages to be already summarized.
    % Here we build a synthetic version if not stored explicitly.

    % Try to estimate per-seq,b PS matrix if available:
    % If not available, compute global average difference
    meanS = mean(allStranger, 'all', 'omitnan');
    meanE = mean(allEmpty, 'all', 'omitnan');
    psMatrixAll(:) = (meanS - meanE) ./ (meanS + meanE + eps);

    % --- Generate PS heatmap (aggregated across all mice) ---
    plotPSHeatmap(psMatrixAll, seqTimes, boundaries, 'AllMice', 'overall', heatmapDir);

    fprintf('✔ Done: Overall summary complete.\n');
end


function stats = computeConsistencyStats(data)
% computeConsistencyStats - Compute dispersion and shape metrics for a vector.
%
% Inputs:
%   data (numeric vector) - signal values (e.g. ΔF/F for a region)
%
% Output:
%   stats (struct) with fields:
%       n        - number of values
%       mean     - mean
%       std      - standard deviation
%       cv       - coefficient of variation (std/mean)
%       mad      - median absolute deviation
%       skew     - skewness
%       kurt     - kurtosis
%       range    - range of values
%
% Example:
%   s = computeConsistencyStats(strangerVals(:,r));

    stats.n = numel(data);
    stats.mean = mean(data);
    stats.std = std(data);
    stats.cv = stats.std / (abs(stats.mean) + eps);
    stats.mad = mad(data, 1);
    stats.skew = skewness(data);
    stats.kurt = kurtosis(data);
    stats.range = range(data);

    if abs(stats.mean) < 1e-3
        stats.cv = NaN; % Avoid unstable division near zero
    else
        stats.cv = stats.std / abs(stats.mean);
    end
end


function outlierIdx = detectOutliers(values)
    % detectOutliers - robust detection (works for small samples)
    if numel(values) < 5
        outlierIdx = abs(values - mean(values)) > 2*std(values);
    else
        outlierIdx = isoutlier(values);
    end
end


function txtLabel = getOutlierLabel(label, idx, mouseID, condition)
    % getOutlierLabel - Contextual outlier labeling by analysis level
    %
    % For 'mice' level  → show which mouse (e.g., '10th_blue')
    % For 'sessions' level → show the exact date (parsed from label if possible)
    % For 'date' level  → show epoch index (e.g., 'ep#4')

    % Try to detect a date-like string (e.g., '20240321')
    isDate = ~isempty(regexp(label, '20\d{6}', 'once'));

    if strcmpi(label, 'mice')
        txtLabel = sprintf('%s', mouseID);              % overall level
    elseif strcmpi(label, 'sessions') || isDate
        % If label looks like a date or we’re in sessions level
        txtLabel = sprintf('%s', label);                % show date directly
    else
        txtLabel = sprintf('ep#%d', idx);               % epoch index
    end
end


