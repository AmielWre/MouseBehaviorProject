function psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries)
    % oneBehaveAnalysis - Computes the preference score matrix for a single experiment.
    %
    % Syntax:
    %   psMatrix = oneBehaveAnalysis(exp, seqTimes, boundaries)
    %
    % Description:
    %   This function performs a detailed behavior analysis for a single experiment
    %   (`exp`) across a range of sequence times (`seqTimes`) and boundary
    %   allowances (`boundaries`). It calculates the preference score for each
    %   combination, saves intermediate and final results, and generates
    %   stacked bar plots and a preference score heatmap.
    %
    % Calculate PS - Preference Score, (a-b)/(a+b)
    %        where a=strangerTime, b=emptyTime.
    %        Returns NaN if a+b=0.
    % If you want to change this logic - just change computePreferenceScore
    % function.
    %
    % Inputs:
    %   exp       - An ExperimentBehave object containing the experiment's data.
    %   seqTimes  - Array of minimum stay times in ROI (numeric vector).
    %   boundaries - Array of boundary allowance values (numeric vector).
    %
    % Output:
    %   psMatrix  - A matrix of preference scores (numSeqTimes x numBoundaries).
    %
    % Example:
    %   exp = ExperimentBehave('my_exp_file.mat', cage_pos_data);
    %   ps = oneBehaveAnalysis(exp, 0:0.5:5, 0:1:5);
    %
    % Processing Flow & Outputs:
    %   The core analysis runs in a nested loop. The `analysis` object is created
    %   and its `run` method is called once for every combination of
    %   `seqTimes` and `boundaries`. The total number of analysis runs is
    %   numel(seqTimes) * numel(boundaries).
    %
    %   At each step, the script saves several types of data:
    %   - **Boolean Matrices**: Saved inside the inner loop for each `seqTime` and
    %     `boundary` combination.
    %     - **Path**: `data/processed/bool_matrices/seq<seq>/b<boundary>/`
    %     - **Files**: `bool_<group>_<color>_<date>_stranger.mat` and `bool_<group>_<color>_<date>_empty.mat`
    %
    %   - **Trial Statistics**: Saved inside the inner loop for each `seqTime` and
    %     `boundary` combination.
    %     - **Path**: `results/3chamber/boundary&sequence/matfiles/<group>_<color>_<date>/`
    %     - **Files**: `seq<seqTimeInSec>_b<boundaryAllowance>.mat` and a CSV file.
    %
    %   - **Plots**: Generated and saved after each `seqTime` iteration, and a final
    %     heatmap is saved at the end of the script.
    %     - **Paths**: `results/3chamber/boundary&sequence/<group>/<color>/`
    %     - **Files**: `<date>_<sequence>second_sequence.png` (stacked bar chart)
    %       and `<date>_preference_score.png` (heatmap)
    
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
            analysis.run();
    
            % The BehaviorAnalysis class computes boolean matrices for different
            % types of time-series data. The 'stranger_out' and 'empty_out'
            % To get the desire mat you write - mat = analysis.getMatrix(<mat_description>)
            % mat_description can be one of: "stranger", "empty",
            % "stranger_out", "empty_out".
            % matrices are each a 2x3x1200 double.
            % The data is structured as follows:
            %  - Row 1: The boolean vector without continuity applied.
            %  - Row 2: The boolean vector with continuity applied based on `seqTimeInSec`.
            %  - Columns 1-3: Data for each of the three trials.
            %  - Slices: The full time series (frames).
            %
            % To get the boolean vector with continuity for the first trial, you
            % would use: `with_seq = squeeze(mat(:, 1, :))(2, :)`.
            % You can then use the `Statistics.epochsStats(with_seq)` to get
            % epoch statistics for that vector.
            
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
        SaveFolders.saveFile([], fig, baseDir, fileName, {'png', 'fig'}, true);
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
    %   fig = plotStackedBars(seqTimeInSec, boundaries, strangerData, emptyData)
    %
    % Inputs:
    %   seqTimeInSec  - Sequence time in seconds (numeric scalar)
    %   boundaries    - Array of boundary allowance values (numeric vector)
    %   strangerData  - Matrix of Stranger ROI durations (numTrials x numBoundaries)
    %   emptyData     - Matrix of Empty ROI durations (numTrials x numBoundaries)
    %
    % Output:
    %   fig - A figure handle to the generated stacked bar plot. The plot displays:
    %       - Green shades for Stranger trials
    %       - Red shades for Empty trials
    %       - Darker shades for earlier trials, lighter for later trials
    %
    % Example:
    %   fig = plotStackedBars(0.5, 0:0.5:5, strangerData, emptyData);
    
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
    % plotPreferenceHeatmap - Shows a heatmap of preference scores across parameters
    %
    % Syntax:
    %   fig = plotPreferenceHeatmap(seqTimes, boundaries, psMatrix, exp)
    %
    % Inputs:
    %   seqTimes   - Array of sequence times (numeric vector)
    %   boundaries - Array of boundary allowance values (numeric vector)
    %   psMatrix   - Matrix of preference scores (numSeqTimes x numBoundaries)
    %   exp        - ExperimentBehave object
    %
    % Output:
    %   fig - A figure handle to the generated heatmap, colored by preference score values.
    
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
    % saveBollMats - Saves boolean matrices (stranger_out, empty_out) to file.
    %
    % Syntax:
    %   saveBollMats(analysis, exp)
    %
    % Description:
    %   This function extracts the boolean matrices for stranger and empty ROIs
    %   from the analysis object and saves them as .mat files.
    %
    % Inputs:
    %   analysis - A BehaviorAnalysis object.
    %   exp      - An ExperimentBehave object.
    %
    % Example:
    %   % Assuming 'myAnalysis' and 'myExp' objects exist
    %   saveBollMats(myAnalysis, myExp);
    %
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
    if isvector(stMat)  % If only one trail was, it will become a vector
        stMat = stMat(:)';  % ensure it’s a row
    end
    if isvector(emMat)  % Same to empty
        emMat = emMat(:)';  % ensure it’s a row
    end
    
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
