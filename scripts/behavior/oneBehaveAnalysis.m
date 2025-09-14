function psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries)
    
    % Data for saving files
    group = exp.getGroup();
    color = exp.getColor();
    date  = exp.getDate();
    baseDir = fullfile('results', '3chamber', 'boundary&sequence', group, color);
    id = sprintf("%s_%s_%s", group, color, date);

    % Store PS across seqTimes and boundaries
    psMatrix = zeros(numel(seqTimes), numel(boundaries));
    for sIdx = 1:numel(seqTimes)
        seqTimeInSec = seqTimes(sIdx);
    
        % Initialize storage for trial-wise data per boundary
        numBoundaries = numel(boundaries);
        numTrials     = numel(exp.getStimTrials());
        strangerData  = zeros(numTrials, numBoundaries);
        emptyData     = zeros(numTrials, numBoundaries);
        psScores      = zeros(1, numBoundaries);
    
        for bIdx = 1:numBoundaries
            close all;
            % Run behavior analysis for given boundary and sequence time
            boundaryAllowance = boundaries(bIdx);
            analysis = BehaviorAnalysis(exp, boundaryAllowance, seqTimeInSec);
            analysis.run(); % *1 see below
    
            saveBollMats(analysis, exp);
    
            [stStatistics, emStatistics] = stEmStatData(analysis, exp);
            % stStatistics and emStatistics contain trial-wise epoch data
            % produced by Statistics.epochsStats function. Each struct element
            % corresponds to one trial. Data respects continuity defined by
            % seqTimeInSec. seqTimeInSec=0 ignores continuity.
    
            % Store total durations for each trial
            for t = 1:numTrials
                strangerData(t, bIdx) = stStatistics(t).totalDuration;
                emptyData(t, bIdx)    = emStatistics(t).totalDuration;
            end
    
            % Compute preference score for this boundary
            totalStranger = sum(strangerData(:, bIdx));
            totalEmpty    = sum(emptyData(:, bIdx));
            psScore = computePreferenceScore(totalStranger, totalEmpty);
            psScores(bIdx) = psScore;

            SaveFolders.saveCsvResults(stStatistics, emStatistics, psScore, exp, seqTimeInSec, boundaryAllowance);
            
            % Save the statistics data (stStatistics, emStatistics, psScore):
            % results\3chamber\boundary&sequence\matfiles\<group>_<color>_<date>\seq<seqTimeInSec>_b<boundaryAllowance>.mat
            data.stStatistics = stStatistics;
            data.emStatistics = emStatistics;
            data.psScore = psScore;
            basePath = fullfile("results", "3chamber", "boundary&sequence", "matfiles", id);
            fileName = sprintf("seq%.1f_b%.1f", seqTimeInSec, boundaryAllowance);
            SaveFolders.saveFile(data, [], basePath, fileName, {'mat'}, false);
        end
    
        % Save PS row into matrix
        psMatrix(sIdx, :) = psScores;
    
        % Plot results for this sequence time
        fig = plotStackedBars(seqTimeInSec, boundaries, strangerData, emptyData);

        % Save plot in pathToFolder\<group>\<color>\<date>_<sequence>second_sequence.png
        fileName = sprintf('%s_%.1fsecond_sequence', date, seqTimeInSec);
        SaveFolders.saveFile([], fig, baseDir, fileName, {'png'}, true);
    end

    % Plot heatmap of PS scores
    fig = plotPreferenceHeatmap(seqTimes, boundaries, psMatrix, exp);

    % Save plot in pathToFolder\<group>\<color>\<date>_<sequence>second_sequence.png
    fileName = sprintf('%s_preference_score', date);
    SaveFolders.saveFile([], fig, baseDir, fileName, {'png'}, true);
end

function fig = plotStackedBars(seqTimeInSec, boundaries, strangerData, emptyData)
% plotStackedBars - Creates a stacked bar chart comparing Stranger and Empty ROI durations.
%
% Syntax:
%   plotStackedBars(seqTimeInSec, boundaries, strangerData, emptyData, exp)
%
% Inputs:
%   seqTimeInSec  - Sequence time in seconds (numeric scalar)
%   boundaries    - Array of boundary allowance values (numeric vector)
%   strangerData  - Matrix of Stranger ROI durations (numTrials x numBoundaries)
%   emptyData     - Matrix of Empty ROI durations (numTrials x numBoundaries)
%
% Output:
%   A figure displaying stacked bar plots, with:
%       - Green shades for Stranger trials
%       - Red shades for Empty trials
%       - Darker shades for earlier trials, lighter for later trials
%
% Example:
%   plotStackedBars(0.5, 0:0.5:5, strangerData, emptyData, exp)

    fig = figure('Color','w'); hold on;
    title(sprintf("Sequence Time = %.1f sec", seqTimeInSec));

    xPositions = 1:numel(boundaries);
    numTrials = size(strangerData,1);

    % Define color shades (darker = earlier trials)
    greenShades = linspace(0.3, 0.8, numTrials)';
    redShades   = linspace(0.3, 0.8, numTrials)';

    % Stranger bars
    b1 = bar(xPositions - 0.2, strangerData', 0.4, 'stacked');
    for k = 1:numTrials
        b1(k).FaceColor = [0, greenShades(k), 0];
        b1(k).EdgeColor = 'none';
    end

    % Empty bars
    b2 = bar(xPositions + 0.2, emptyData', 0.4, 'stacked');
    for k = 1:numTrials
        b2(k).FaceColor = [redShades(k), 0, 0];
        b2(k).EdgeColor = 'none';
    end

    % Axis and labels
    xticks(xPositions);
    xticklabels(string(boundaries));
    xlabel('Boundary Allowance (cm)');
    ylabel('Total Duration (frames)');

    % Legend
    legendEntries = cell(1, numTrials * 2);
    for k = 1:numTrials
        legendEntries{k} = sprintf('Stranger - Trial %d', k);
        legendEntries{numTrials + k} = sprintf('Empty - Trial %d', k);
    end
    legend([b1, b2], legendEntries, 'Location', 'northwest');

    box on;
    % drawnow;
end

function ps = computePreferenceScore(strangerTime, emptyTime)
% computePreferenceScore - Compute preference score from ROI times
%
% Syntax:
%   ps = computePreferenceScore(strangerTime, emptyTime)
%
% Inputs:
%   strangerTime - Total duration in Stranger ROI (numeric)
%   emptyTime    - Total duration in Empty ROI (numeric)
%
% Output:
%   ps - Preference score, (a-b)/(a+b)
%        where a=strangerTime, b=emptyTime.
%        Returns NaN if denominator=0.

    denom = strangerTime + emptyTime;
    if denom == 0
        ps = NaN; % undefined if no time spent in either ROI
    else
        ps = (strangerTime - emptyTime) / denom;
    end
end

function fig = plotPreferenceHeatmap(seqTimes, boundaries, psMatrix, exp)
% plotPreferenceHeatmap - Show heatmap of preference scores across parameters
%
% Syntax:
%   plotPreferenceHeatmap(seqTimes, boundaries, psMatrix)
%
% Inputs:
%   seqTimes   - Array of sequence times (numeric vector)
%   boundaries - Array of boundary allowance values (numeric vector)
%   psMatrix   - Matrix of preference scores (numSeqTimes x numBoundaries)
%   exp        - ExperimentBehave object
%
% Output:
%   A heatmap figure, colored by preference score values.

    fig = figure('Color','w');
    imagesc(boundaries, seqTimes, psMatrix);
    colormap(jet);
    colorbar;
    xlabel('Boundary Allowance (cm)');
    ylabel('Sequence Time (second)');
    title('Preference Score Heatmap');
    set(gca, 'YDir', 'normal'); % so seqTimes increase upward

end

function saveBollMats(analysis, exp)
    % saveBollMats - Save boolean matrices (stranger_out, empty_out)
    % Files will be saved under:
    %   data/processed/bool_matrices/seq<seq>/b<boundary>/
    %   with filenames:
    %     bool_<group>_<color>_<date>_stranger.mat
    %     bool_<group>_<color>_<date>_empty.mat

    formats = "mat";

    stMat = analysis.getMatrix("stranger_out");
    emMat = analysis.getMatrix("empty_out");

    stMat = squeeze(stMat(2, :, :)); % So it will contain only the mat with continuity (according to seqTimeInSec)
    emMat = squeeze(emMat(2, :, :)); % -- " --
    
    % Build folder path
    seqFolder = sprintf("seq%.1f", analysis.seqTimeInSec);
    bFolder   = sprintf("b%.1f", analysis.boundaryAllowance);
    baseDir   = fullfile("data","processed","bool_matrices",seqFolder,bFolder);

    
    % Extract metadata from experiment
    group = exp.getGroup();
    color = exp.getColor();
    date  = exp.getDate();

    id = sprintf("%s_%s_%s", group, color, date);
    fpathSt = sprintf("bool_%s_stranger", id);
    fpathEm = sprintf("bool_%s_empty", id);
    
    SaveFolders.saveFile(stMat, [], baseDir, fpathSt, formats, false);
    SaveFolders.saveFile(emMat, [], baseDir, fpathEm, formats, false);

end

% *1
% Now you can get matrix <mat_description> by doing
% mat = analysis.getMatrix("mat_description"). now mat is in the size of
% 2*stim_trails_num*frames_num. stim_trrails usually will be 3, frames_num
% 1200. mat1 = squeeze(mat(:, 1, :)) will give you the data of the first
% trail. no_seq = mat1(1,:) will give you 1x1200 boolean mat without
% continuity and with_seq = mat1(2, :) 1x1200 boolean mat with continuity.
% stat_seq_1 = Statistics.epochsStats(with_seq) will give you epochs
% statistics about this vector (see Statistics class).