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

% === Paths ===
dataDir = fullfile("data", "processed", "neuronal_epoch_data");
baseDirResults = fullfile("results", "3chamber", "boundary&sequence");
resultsDir = fullfile(baseDirResults, "neuronal_analysis");
if ~isfolder(resultsDir), mkdir(resultsDir); end

summaryFile = fullfile(resultsDir, "summaryData.mat");
logFile = fullfile(resultsDir, "analysisLog.mat");  % <-- NEW checkpoint file

% === Parameters ===
seqTimes = 0:0.5:5;
boundaries = 0:0.5:5;
regionNames = {'DI','Cl','Cpu','CpuA','AcbShv','AcbC','AcbSh','M1','IL','PrL', ...
               'PrL2','Cg1','BLA','CeL','CPu-GP','CpuP','S1BC','S1BC2','CA3', ...
               'Thl-VPM','Thl-VL','Thl-Po','CA1','DG'};

allPsPath = fullfile(baseDirResults, "allPsMatrices.mat");
load(allPsPath, 'allPsMatrices');

% === Collect all mouse IDs ===
allFields = fieldnames(allPsMatrices);
mouseIDs  = unique(cellfun(@(f) extractMouseID(f), allFields, 'UniformOutput', false));

% Initialize output dirs
perMouseDir = fullfile(resultsDir, 'per_mouse');
overallDir = fullfile(resultsDir, 'overall');
if ~isfolder(perMouseDir), mkdir(perMouseDir); end
if ~isfolder(overallDir), mkdir(overallDir); end

summaryData = struct();

% === Load checkpoint if it exists ===
if isfile(logFile)
    load(logFile, 'analysisLog');
    fprintf('✔ Loaded analysis log.\n');
else
    analysisLog = struct();
end

% --- Ensure correct structure even on first run ---
if ~isfield(analysisLog, 'mouse') || ~isstruct(analysisLog.mouse)
    analysisLog.mouse = struct('id', {}, 'datesDone', {}, 'completed', {});
end
if ~isfield(analysisLog, 'lastUpdated')
    analysisLog.lastUpdated = datetime.empty;
end

%% === Process each mouse ===
for m = 1:numel(mouseIDs)
    mouseID = mouseIDs{m};

    % Check if this mouse is already done
    mouseIdx = find(strcmp({analysisLog.mouse.id}, mouseID), 1);
    if ~isempty(mouseIdx) && isfield(analysisLog.mouse(mouseIdx), 'completed') && analysisLog.mouse(mouseIdx).completed
        fprintf('⏭ Skipping %s (already completed)\n', mouseID);
        continue;
    end

    fprintf('\nProcessing mouse %s...\n', mouseID);

    mouseDir = fullfile(perMouseDir, mouseID);
    mkdirs(fullfile(mouseDir, 'average'), {'region_distributions','ps_heatmaps','bars_seq_b','brain_maps'});

    mouseStranger = [];
    mouseEmpty = [];

    % --- Process each date ---
    mouseFields = allFields(contains(allFields, mouseID)); % all dates for this mouse
    if isempty(mouseFields)
        fprintf('\nNo matrices found for mouse %s \n', mouseID);
        continue;
    end

    nSessions = numel(mouseFields);
    completedDates = {};

    for i = 1:nSessions
        fieldName = mouseFields{i};
        parts = split(fieldName, '_');
        date = parts{3};
        dateDir = fullfile(mouseDir, date);

        % Check if date was processed already
        if ~isempty(mouseIdx) && ismember(date, analysisLog.mouse(mouseIdx).datesDone)
            fprintf('⏭ Skipping %s | %s (already done)\n', mouseID, date);
            continue;
        end

        mkdirs(fullfile(dateDir), {'region_distributions','ps_heatmaps','bars_seq_b','brain_maps'});

        try
            processDateLevel(mouseID, date, seqTimes, boundaries, regionNames, dateDir);
            completedDates{end+1} = date; %#ok<AGROW>
        catch ME
            warning('⚠ Error processing %s | %s: %s', mouseID, date, ME.message);
            continue;
        end

        % Update checkpoint after each date
        analysisLog = updateAnalysisLog(analysisLog, mouseID, completedDates, false);
        save(logFile, 'analysisLog');
    end

    % --- Mouse-level aggregation ---
    try
        [mouseStranger, mouseEmpty, psMatrix] = processMouseLevel(mouseID, seqTimes, boundaries, regionNames, mouseDir);

        safeMouseID = matlab.lang.makeValidName(mouseID);
        summaryData.(safeMouseID).stranger = mouseStranger;
        summaryData.(safeMouseID).empty = mouseEmpty;
        summaryData.(safeMouseID).psMatrix = psMatrix;

        % Save summary after each mouse
        save(summaryFile, 'summaryData', '-v7.3');
        fprintf('✔ Saved summaryData for %s\n', mouseID);

        % Update log that this mouse is fully done
        analysisLog = updateAnalysisLog(analysisLog, mouseID, completedDates, true);
        save(logFile, 'analysisLog');
    catch ME
        warning('⚠ Error in mouse-level processing for %s: %s', mouseID, ME.message);
    end
end

fprintf('✔ summaryData saved to %s\n', summaryFile);
processOverall(summaryData, seqTimes, boundaries, regionNames, overallDir);

% === Helpers =====
function log = updateAnalysisLog(log, mouseID, completedDates, isComplete)
    if ~isfield(log, 'mouse')
        log.mouse = struct('id', {}, 'datesDone', {}, 'completed', {});
    end
    idx = find(strcmp({log.mouse.id}, mouseID), 1);
    if isempty(idx)
        idx = numel(log.mouse) + 1;
        log.mouse(idx).id = mouseID;
    end
    if ~isfield(log.mouse(idx), 'datesDone') || isempty(log.mouse(idx).datesDone)
        log.mouse(idx).datesDone = {};
    end
    log.mouse(idx).datesDone = unique([log.mouse(idx).datesDone, completedDates]);
    log.mouse(idx).completed = isComplete;
    log.lastUpdated = datetime('now');
end

function mouseID = extractMouseID(fieldName)
    parts = split(fieldName, '_'); mouseID = strjoin(parts(1:2), '_');
    mouseID = regexp(mouseID, '\d.*', 'match', 'once');
end

function mkdirs(base, subs)
    for i = 1:numel(subs)
        d = fullfile(base, subs{i}); if ~isfolder(d), mkdir(d); end
    end
end


function processDateLevel(mouseID, dateName, seqTimes, boundaries, regionNames, dateDir)
% processDateLevel - Process neuronal epoch data for one mouse and date.
%
% Description:
%   Iterates over all sequence × boundary combinations for the given date.
%   For each (seq,b) pair:
%       • Loads epoch-level ΔF/F activity and labels
%       • Separates stranger vs. empty epochs
%       • Computes per-region PS = (S - E) / (S + E)
%       • Plots:
%           - Region-wise distribution plots (CV, MAD, K–S)
%           - Per (seq,b) bar plots (stranger vs empty)
%   After looping, it generates PS heatmaps for each region.
%
% Outputs:
%   Saves under:
%       <dateDir>/region_distributions/<region>/
%       <dateDir>/bars_seq_b/
%       <dateDir>/ps_heatmaps/<region>.png
%
% -------------------------------------------------------------------------

    fprintf('\n- %s\n', dateName);
    
    % === Output directories ===
    distDir    = fullfile(dateDir, 'region_distributions');
    heatmapDir = fullfile(dateDir, 'ps_heatmaps');
    barsDir    = fullfile(dateDir, 'bars_seq_b');
    brainDir   = fullfile(dateDir, 'brain_maps');
    for d = {distDir, heatmapDir, barsDir, brainDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end
    
    % === Base data directory ===
    dataBase = fullfile("data", "processed", "neuronal_epoch_data");
    
    % === Initialize PS struct (one matrix per region) ===
    psMatrix = struct();
    regionMap = containers.Map(); % maps safe names -> original names
    for r = 1:numel(regionNames)
        safeRegion = matlab.lang.makeValidName(regionNames{r});
        psMatrix.(safeRegion) = nan(numel(seqTimes), numel(boundaries));
        regionMap(safeRegion) = regionNames{r};
    end
    
    % === Iterate over all sequence × boundary combinations ===
    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx);
        seqDir = sprintf('seq%.1f', seq);
    
        for bIdx = 1:numel(boundaries)
            b = boundaries(bIdx);
            bDir = sprintf('b%.1f', b);
            sessionPath = fullfile(dataBase, seqDir, bDir, mouseID, dateName);
    
            if ~isfolder(sessionPath)
                fprintf('\nMissing folder for %s | %s | Seq%.1f B%.1f \n', mouseID, dateName, seq, b);
                continue;
            end
    
            % Load epoch-level data
            fX = fullfile(sessionPath, sprintf('X_epochs_%s_%s.mat', mouseID, dateName));
            fY = fullfile(sessionPath, sprintf('y_epochs_%s_%s.mat', mouseID, dateName));
            if ~isfile(fX) || ~isfile(fY)
                fprintf('\nMissing X/y files for %s | %s | Seq%.1f B%.1f \n', mouseID, dateName, seq, b);
                continue;
            end
    
            Xd = load(fX); fnX = fieldnames(Xd); X = Xd.(fnX{1});
            Yd = load(fY); fnY = fieldnames(Yd); y = Yd.(fnY{1});
            if isempty(X) || isempty(y) || numel(y) ~= size(X,1)
                fprintf('\nNo epochs or size of y ~= size of X for %s | %s | Seq%.1f B%.1f \n', mouseID, dateName, seq, b);
                continue;
            end
    
            strangerVals = X(y == 1, :);
            emptyVals    = X(y == 0, :);
    
            if isempty(strangerVals) && isempty(emptyVals)
                fprintf('\nNo epochs found for %s | %s | Seq%.1f B%.1f \n', mouseID, dateName, seq, b);
                continue;
            end
    
            % === Region-level analysis ===
            for r = 1:numel(regionNames)
                region = regionNames{r};
                safeRegion = matlab.lang.makeValidName(region);
                regionDir = fullfile(distDir, region);
                if ~isfolder(regionDir), mkdir(regionDir); end
    
                valsS = strangerVals(:, r);
                valsE = emptyVals(:, r);
    
                if all(isnan(valsS)) && all(isnan(valsE))
                    fprintf('\nAll values for %s | %s | Seq%.1f B%.1f | %s are nan. Skipping', mouseID, dateName, seq, b, region);
                    continue; 
                end
    
                % Plot per-region distribution
                plotDistributionWithStats(valsS, valsE, mouseID, region, seq, b, regionDir, dateName);
    
                % Compute mean PS for this region and (seq,b)
                meanS = mean(valsS, "omitnan");
                meanE = mean(valsE, "omitnan");
                
                if ~isnan(meanS) && ~isnan(meanE)
                    % NEW PS definition (raw difference)
                    psMatrix.(safeRegion)(sIdx, bIdx) = meanS - meanE;
                else
                    psMatrix.(safeRegion)(sIdx, bIdx) = NaN;
                end
            end
    
            % === Summary bar across all regions ===
            pVals = processBars(strangerVals, emptyVals, mouseID, seq, b, regionNames, barsDir, dateName);

            % === Plot brain map for this (seq,b) ===
            psVector = zeros(numel(regionNames), 1);
            for r = 1:numel(regionNames)
                safeRegion = matlab.lang.makeValidName(regionNames{r});
                psVector(r) = psMatrix.(safeRegion)(sIdx, bIdx);
            end
            
            brainMapDir = fullfile(dateDir, 'brain_maps');
            if ~isfolder(brainMapDir), mkdir(brainMapDir); end
            
            figTitle = sprintf('%s | %s | Seq %.1f | B %.1f', ...
                                mouseID, dateName, seq, b);
            
            plotBrainMap(pVals, psVector, mouseID, seq, b, brainDir, dateName);
        end
    end
    
    % === Plot PS heatmaps for each region ===
    plotRegionPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, dateName, heatmapDir, regionMap);
    
end


function [mouseStranger, mouseEmpty, psMatrix] = processMouseLevel(mouseID, seqTimes, boundaries, regionNames, mouseDir)
% Mouse-level aggregation (updated to match date-level behavior)

    fprintf('\n=== Aggregating average data for mouse %s ===\n', mouseID);

    % --- Setup output directories ---
    avgDir       = fullfile(mouseDir, 'average');
    distDir      = fullfile(avgDir, 'region_distributions');
    barsDir      = fullfile(avgDir, 'bars_seq_b');
    heatmapDir   = fullfile(avgDir, 'ps_heatmaps');
    brainMapDir  = fullfile(avgDir, 'brain_maps');

    for d = {distDir, barsDir, heatmapDir, brainMapDir}
        if ~isfolder(d{1}), mkdir(d{1}); end
    end

    % Data base
    dataBase = fullfile("data","processed","neuronal_epoch_data");

    % Initialize psMatrix
    psMatrix = struct();
    regionMap = containers.Map();

    for r = 1:numel(regionNames)
        safeRegion = matlab.lang.makeValidName(regionNames{r});
        psMatrix.(safeRegion) = nan(numel(seqTimes), numel(boundaries));
        regionMap(safeRegion) = regionNames{r};
    end

    allStranger = []; 
    allEmpty    = [];

    % Loop over seq × boundary
    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx); 
        seqDir = sprintf('seq%.1f', seq);

        for bIdx = 1:numel(boundaries)
            b = boundaries(bIdx);
            bDir = sprintf('b%.1f', b);

            seqBPath = fullfile(dataBase, seqDir, bDir, mouseID);
            if ~isfolder(seqBPath)
                fprintf('\nMissing seq/b folder for %s | Seq%.1f B%.1f\n', mouseID, seq, b);
                continue;
            end

            dateFolders = dir(fullfile(seqBPath,'20*'));
            if isempty(dateFolders)
                fprintf('\nNo date folders for %s | Seq%.1f B%.1f\n', mouseID, seq, b);
                continue;
            end

            % Collect means across dates
            dateMeansStranger = [];
            dateMeansEmpty    = [];

            for d = 1:numel(dateFolders)
                dateName = dateFolders(d).name;

                fS = fullfile(seqBPath, dateName, sprintf('mean_stranger_%s_%s.mat', mouseID, dateName));
                fE = fullfile(seqBPath, dateName, sprintf('mean_empty_%s_%s.mat', mouseID, dateName));

                if ~isfile(fS) || ~isfile(fE)
                    continue;
                end

                dS = load(fS); fnS = fieldnames(dS); valsS = dS.(fnS{1});
                dE = load(fE); fnE = fieldnames(dE); valsE = dE.(fnE{1});

                if isempty(valsS) || isempty(valsE), continue; end

                dateMeansStranger(end+1,:) = valsS(:)';
                dateMeansEmpty(end+1,:)    = valsE(:)';
            end

            if isempty(dateMeansStranger) || isempty(dateMeansEmpty)
                fprintf('\nNo valid mean data for %s | Seq%.1f B%.1f\n', mouseID, seq, b);
                continue;
            end

            % Store for overall
            allStranger = [allStranger; dateMeansStranger];
            allEmpty    = [allEmpty; dateMeansEmpty];

            % --- Region-wise aggregation plots ---
            for r = 1:numel(regionNames)
                reg = regionNames{r};
                safeReg = matlab.lang.makeValidName(reg);
                regDir = fullfile(distDir, reg);

                if ~isfolder(regDir), mkdir(regDir); end

                valsS = dateMeansStranger(:,r);
                valsE = dateMeansEmpty(:,r);

                if all(isnan(valsS)) && all(isnan(valsE)), continue; end

                plotDistributionWithStats(valsS, valsE, mouseID, reg, seq, b, regDir, 'average');
            end

            % --- Bars ---
            pVals = processBars(dateMeansStranger, dateMeansEmpty, mouseID, seq, b, regionNames, barsDir, 'average');

            % --- Compute PS (raw difference) ---
            psVector = zeros(numel(regionNames),1);
            for r = 1:numel(regionNames)
                safeReg = matlab.lang.makeValidName(regionNames{r});
                meanS = mean(dateMeansStranger(:,r),'omitnan');
                meanE = mean(dateMeansEmpty(:,r),'omitnan');

                if ~isnan(meanS) && ~isnan(meanE)
                    psVal = meanS - meanE;
                    psMatrix.(safeReg)(sIdx,bIdx) = psVal;
                    psVector(r)                  = psVal;
                else
                    psMatrix.(safeReg)(sIdx,bIdx) = NaN;
                    psVector(r) = NaN;
                end
            end

            % --- Brain map (mouse-level) ---
            plotBrainMap(pVals, psVector, mouseID, seq, b, brainMapDir, 'average');

        end
    end

    % --- Heatmaps ---
    plotRegionPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, 'average', heatmapDir, regionMap);

    fprintf('✔ Done: Mouse-level complete for %s\n', mouseID);

    % Return aggregated arrays
    mouseStranger = allStranger;
    mouseEmpty    = allEmpty;
end


function plotRegionPSHeatmap(psMatrix, seqTimes, boundaries, mouseID, label, saveDir, regionMap)
    % ... (function documentation remains the same)
    
    if ~isfolder(saveDir), mkdir(saveDir); end
    regionFields = fieldnames(psMatrix);
    
    % === 1. Calculate Global Color Limits ===
    allPSValues = [];
    for r = 1:numel(regionFields)
        psVals = psMatrix.(regionFields{r});
        allPSValues = [allPSValues; psVals(:)]; %#ok<AGROW>
    end
    
    % Find the maximum absolute value among all non-NaN PS values
    nonNanValues = allPSValues(~isnan(allPSValues));
    if isempty(nonNanValues)
        fprintf('\nNo valid PS values found across all regions for %s | %s. Skipping heatmaps.\n', mouseID, label);
        return;
    end
    
    maxAbsPS = max(abs(nonNanValues));
    % Set limits symmetrically around zero
    CLim = [-maxAbsPS, maxAbsPS]; 
    if all(CLim == 0), CLim = [-0.01, 0.01]; end % Handle case where all values are 0
    
    % === 2. Define a Colormap with NaN handling ===
    % We will use a standard blue-to-red map for data, and white for NaN
    % N is the number of colors in the colormap (e.g., 256)
    N = 256;
    baseMap = jet(N); 
    nanColor = [1 1 1]; % White for NaN
    newMap = [nanColor; baseMap]; % Add white to the bottom (index 1)
    
    for r = 1:numel(regionFields)
        safeRegion = regionFields{r};
        psVals = psMatrix.(safeRegion);
    
        if all(isnan(psVals), 'all')
            fprintf('\nNo valid PS values for %s | %s | Region %s \n', mouseID, label, safeRegion);
            continue;
        end
    
        % Restore original region name for display
        regionName = regionMap(safeRegion);
    
        fig = figure('Visible', 'off', 'Color', 'w');
        
        % Use pcolor instead of imagesc for better NaN handling
        h = pcolor(boundaries, seqTimes, psVals);
        set(h, 'EdgeColor', 'none'); % Remove grid lines
        
        % Set the new colormap and limits
        colormap(newMap); 
        caxis(CLim);
        
        % Map NaN values to the first color (white) in the new map
        set(h, 'FaceColor', 'flat');
        h.CData(isnan(h.CData)) = 1; % CData index 1 corresponds to white in newMap
        
        % Create and adjust the color bar
        cb = colorbar;
        set(cb, 'YTick', linspace(CLim(1), CLim(2), 5)); % Set clear tick marks
        
        set(gca, 'YDir', 'normal');
        xlabel('Boundary (cm)');
        ylabel('Sequence (s)');
        title(sprintf('%s | %s | %s', mouseID, regionName, label), ...
            'Interpreter', 'none', 'FontSize', 11);
        set(gca, 'FontSize', 9);
    
        exportgraphics(fig, fullfile(saveDir, sprintf('%s_seq_b_%s.png', regionName, label)), ...
            'Resolution', 150);
        close(fig);
    end
end

function pVals = processBars(strangerVals, emptyVals, mouseID, seqTime, boundary, regionNames, saveDir, label)
% processBars - Generates a grouped bar plot with error bars and significance stars.
%
% Description:
%   Compares Stranger vs Empty mean ΔF/F for each brain region using bars,
%   SEM error bars, Wilcoxon rank-sum p-values, and significance stars.
%
%   p-value interpretation:
%       p < 0.05  → *
%       p < 0.01  → **
%       p < 0.001 → ***
%
% Inputs:
%   strangerVals  - [nEpochs × nRegions] ΔF/F for Stranger epochs
%   emptyVals     - [nEpochs × nRegions] ΔF/F for Empty epochs
%   mouseID       - Mouse ID string
%   seqTime       - Sequence time
%   boundary      - Boundary value
%   regionNames   - 1×n cell array of region names
%   saveDir       - Directory to save figure
%   label         - Additional label (e.g. date / 'average' / 'overall')
%
% -------------------------------------------------------------------------

    % Compute means
    meanEmpty    = mean(emptyVals, 1);
    meanStranger = mean(strangerVals, 1);

    % SEM (standard error of mean)
    semEmpty    = std(emptyVals, [], 1) ./ sqrt(size(emptyVals,1));
    semStranger = std(strangerVals,[], 1) ./ sqrt(size(strangerVals,1));

    % Sample sizes
    nEmpty    = size(emptyVals, 1);
    nStranger = size(strangerVals, 1);

    % Create figure
    fig = figure('Visible', 'off', 'Color', 'w'); hold on;
    x = 1:numel(regionNames);

    % Colors
    emptyColor    = [0.55, 0.55, 0.55];
    strangerColor = [0.90, 0.20, 0.20];

    % --- Bar Plot ---
    b1 = bar(x - 0.17, meanEmpty,    0.34, 'FaceColor', emptyColor,    'EdgeColor', 'none');
    b2 = bar(x + 0.17, meanStranger, 0.34, 'FaceColor', strangerColor, 'EdgeColor', 'none');

    % --- Error Bars (SEM) ---
    errorbar(x - 0.17, meanEmpty,    semEmpty,    'k', 'LineStyle','none', 'LineWidth',1);
    errorbar(x + 0.17, meanStranger, semStranger, 'k', 'LineStyle','none', 'LineWidth',1);

    % --- Statistical tests (Wilcoxon rank-sum per region) ---
    pVals = nan(1, numel(x));
    for r = 1:numel(x)
        try
            pVals(r) = ranksum(emptyVals(:,r), strangerVals(:,r)); % unpaired test
        catch
            pVals(r) = NaN;
        end
    end

    % --- Plot significance stars above bars ---
    yMax = max([meanEmpty + semEmpty, meanStranger + semStranger], [], 'all', 'omitnan');
    yMin = min([meanEmpty - semEmpty, meanStranger - semStranger], [], 'all', 'omitnan');
    
    % Handle NaN or identical limits
    if isnan(yMax) || isnan(yMin)
        yMax = 0.01; 
        yMin = -0.01;
    end
    if yMax == yMin
        yMax = yMax + 0.001;
        yMin = yMin - 0.001;
    end
    
    yRange = yMax - yMin;
    ylim([yMin - 0.1*yRange, yMax + 0.3*yRange]); % Add extra space above bars
    
    % New position for stars (relative to current ylim)
    yl = ylim;
    yTop = yl(2) - 0.05 * yRange;  % 5% below top axis limit
        
    for r = 1:numel(x)
        if isnan(pVals(r)), continue; end
        if     pVals(r) < 0.001, star = '***';
        elseif pVals(r) < 0.01,  star = '**';
        elseif pVals(r) < 0.05,  star = '*';
        else,                    star = ''; 
        end
    
        if ~isempty(star)
            text(x(r), yTop, star, 'HorizontalAlignment','center', ...
                 'FontSize',14, 'Color','k');
        end
    end


    % --- Titles ---
    mainTitle = sprintf('%s | Seq %.1f  |  B %.1f  |  %s', mouseID, seqTime, boundary, label);
    title(mainTitle, 'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');

    % Subtitle depends on label type
    if strcmpi(label, 'average')
        subtitle(sprintf('n = %d experiments', nStranger));
    elseif strcmpi(label, 'overall')
        subtitle(sprintf('n = %d mice', nStranger));
    else
        subtitle(sprintf('n = %d empty-epochs,  %d stranger-epochs', nEmpty, nStranger));
    end

    % Axis formatting
    ylabel('Mean ΔF/F', 'FontSize', 12, 'FontWeight', 'bold');
    set(gca, 'XTick', x, 'XTickLabel', regionNames, ...
             'XTickLabelRotation', 45, 'FontSize', 11);

    legend({'Empty','Stranger'}, 'Location','southwest');
    box off; grid on; grid minor;
    set(gca, 'GridAlpha', 0.15, 'LineWidth', 1.2);

    % Save
    if ~exist(saveDir,'dir'), mkdir(saveDir); end
    outName = sprintf('bar_seq%.1f_b%.1f_%s.png', seqTime, boundary, label);
    exportgraphics(fig, fullfile(saveDir, outName), 'Resolution', 300);

    close(fig);
end


function plotDistributionWithStats(strangerVals, emptyVals, mouseID, regionName, seqTime, boundary, saveDir, label)
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
        fprintf('\nNo valid EMPTY data for %s | %s | Seq%.1f B%.1f | %s \n', ...
            mouseID, regionName, seqTime, boundary, label);
        emptyVals = NaN;  % keep placeholder so plotting works
    end
    
    if isempty(strangerVals) || all(isnan(strangerVals))
        fprintf('\nNo valid STRANGER data for %s | %s | Seq%.1f B%.1f | %s \n', ...
            mouseID, regionName, seqTime, boundary, label);
        strangerVals = NaN;
    end
    
    % === Compute stats ===
    emptyStats = computeConsistencyStats(emptyVals);
    strangerStats = computeConsistencyStats(strangerVals);

    % === Choose test based on data level ===
    % K–S test for epoch-level (date), ranksum for mouse average or overall.
    if contains(lower(label), {'average', 'overall'})
        if numel(emptyVals) > 2 && numel(strangerVals) > 2
            try
                pValue = ranksum(strangerVals, emptyVals);
                testName = 'ranksum';
            catch
                pValue = NaN;
                testName = 'ranksum (error)';
            end
        else
            if strcmpi(label, 'average')
                testName = 'not enough experiment data';
            else
                testName = 'not enough mouse data';
            end
            pValue = NaN;
        end
    else
        if numel(emptyVals) > 2 && numel(strangerVals) > 2
            try
                [~, pValue] = kstest2(emptyVals, strangerVals);
                testName = 'K–S';
            catch
                pValue = NaN;
                testName = 'K–S (error)';
            end
        else
            testName = 'not enough epoch data';
            pValue = NaN;
        end
    end



    % === Plot transparent boxplots with missing-data handling ===
    positions = [1 2];
    
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
    if strcmpi(label, 'average')
        dataType = '(experiments)';
    elseif strcmpi(label, 'overall')
        dataType = '(mice)';
    else
        dataType = '(epochs)';
    end
    mainTitle = sprintf('%s | %s | Seq%.1f B%.1f | %s', mouseID, regionName, seqTime, boundary, label);
    statsLine = sprintf(['Empty: n=%d %s, Mean: %.4f, CV=%.2f, MAD=%.3f \n' ...
        'Stranger: n=%d %s, Mean: %.4f, CV=%.2f, MAD=%.3f \n%s p=%.3f'], ...
        numel(emptyVals), dataType, emptyStats.mean, emptyStats.cv, emptyStats.mad, ...
        numel(strangerVals), dataType, strangerStats.mean, strangerStats.cv, strangerStats.mad, ...
        testName, pValue);
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


function plotBrainMap(pVals, PS, mouseID, seqTime, boundary, saveDir, label)
% FINAL version: identical to Shlomo’s plotting logic, with your data.

    % --- Load coordinates + template ---
    dataDir = ('results/3chamber/boundary&sequence/neuronal_analysis');
    D = load(fullfile(dataDir,'Coors_and_IDs_2ILs.mat'));
    IDS = D.IDS;
    IDS_coor = D.IDS_coor;
    brainTemplate = D.multifiber_template;

    xloc = cell2mat(IDS_coor(2,1:24));
    yloc = cell2mat(IDS_coor(3,1:24));
    regionNames = IDS(1:24);

    % --- Create figure ---
    fig = figure('Visible','off','Color','w');
    set(fig,'Position',[200 100 900 900]);
    hold on;

    % === BRAIN OUTLINE (original code) ===
    imagesc(flipud(brainTemplate));
    set(gca,'YDir','normal');
    alpha(0.15);
    axis equal;
    axis off;
    hold on;

    % --- Colors: red/blue ---
    colors = zeros(24,3);
    for i = 1:24
        if PS(i) > 0
            colors(i,:) = [0.9 0.2 0.2];  % red
        else
            colors(i,:) = [0.25 0.45 1];  % blue
        end
    end

    % --- Dot size ---
    absPS = abs(PS);
    ranks = tiedrank(absPS);
    ranks = ranks ./ max(ranks);
    dotSize = 150 + ranks * 900;

    % --- Significance (circles) ---
    ringSize = dotSize + 90;

    for i = 1:24
        if isnan(pVals(i)), continue; end

        if pVals(i) < 0.01
            lw = 2;
        elseif pVals(i) < 0.05
            lw = 1.2;
        else
            lw = 0;
        end

        if lw > 0
            scatter(xloc(i), yloc(i), ringSize(i), 'o', ...
                'MarkerEdgeColor','k','LineWidth',lw);
        end
    end

    % --- Main dots (original Shlomo style) ---
    scatter(xloc, yloc, dotSize, colors, 'filled');

    % --- Labels ---
    for i = 1:24
        text(xloc(i), yloc(i), regionNames{i}, ...
            'HorizontalAlignment','center', ...
            'FontSize',9,'FontWeight','bold');
    end

    % --- Title ---
    ttl = sprintf('%s | Seq %.1f | B %.1f | %s', ...
                  mouseID, seqTime, boundary, label);
    title(ttl,'Interpreter','none','FontSize',15);

    subtitle('  Mean(Stranger) - Mean(Empty)', ...
         'FontSize', 13, 'FontWeight','normal');

    % === LEGEND (based on your example) ===
    lx = size(brainTemplate,2) - 180;   % about 789 - 180 = 609
    ly = size(brainTemplate,1) - 80;    % about 910 - 80 = 830
    dy = 55;

    scatter(lx, ly,       200, [0.9 0.2 0.2],'filled');
    text(lx+40, ly,       '>0 difference','FontSize',10);

    scatter(lx, ly-dy,    200, [0.25 0.45 1],'filled');
    text(lx+40, ly-dy,    '<0 difference','FontSize',10);

    scatter(lx, ly-2*dy,  230, 'o','MarkerEdgeColor','k','LineWidth',1.2);
    text(lx+40, ly-2*dy,  'p < 0.05','FontSize',10);

    scatter(lx, ly-3*dy,  230, 'o','MarkerEdgeColor','k','LineWidth',2);
    text(lx+40, ly-3*dy,  'p < 0.01','FontSize',10);

    % === Example size legend ===
    examplePS = [0.05, 0.10, 0.20];
    absPS_e = abs(examplePS);
    ranks_e = tiedrank(absPS_e);
    ranks_e = ranks_e ./ max(ranks_e);
    dotSize_e = 180 + ranks_e * 900;
    
    % Anchor under existing legend
    ly2 = ly - 4*dy - 20;
    
    % Small
    scatter(lx, ly2, dotSize_e(1), [0.5 0.5 0.5], 'filled');
    text(lx+45, ly2, sprintf('Example size: %.2f', examplePS(1)), 'FontSize',8);
    
    % Medium
    scatter(lx, ly2 - dy, dotSize_e(2), [0.5 0.5 0.5], 'filled');
    text(lx+45, ly2 - dy, sprintf('Example size: %.2f', examplePS(2)), 'FontSize',8);
    
    % Large
    scatter(lx, ly2 - 2*dy, dotSize_e(3), [0.5 0.5 0.5], 'filled');
    text(lx+45, ly2 - 2*dy, sprintf('Example size: %.2f', examplePS(3)), 'FontSize',8);

    % --- Save ---
    if ~exist(saveDir,'dir'), mkdir(saveDir); end
    outName = sprintf('brainmap_seq%.1f_b%.1f_%s.png', seqTime, boundary, label);
    exportgraphics(fig, fullfile(saveDir,outName), 'Resolution',300);

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
        fprintf('\nNo mouse data found in summaryData. \n');
        return;
    end

    for m = 1:numel(mouseIDs)
        mouseID = mouseIDs{m};
        data = summaryData.(mouseID);

        if ~isfield(data, 'stranger') || ~isfield(data, 'empty')
            fprintf('\nSkipping %s (missing data fields) \n', mouseID);
            continue;
        end
        if isempty(data.stranger) || isempty(data.empty)
            fprintf('\nSkipping %s (empty data matrices) \n', mouseID);
            continue;
        end

        % store for global region-level plots
        allStranger = [allStranger; data.stranger];
        allEmpty = [allEmpty; data.empty];
    end

    % --- Validate collected data ---
    if isempty(allStranger) || isempty(allEmpty)
        fprintf('\nNo aggregated data available for overall-level plotting. \n');
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


