function [stStatistics, emStatistics] = stEmStatData(data, exp)
    % stEmStatData - Computes epoch statistics for stranger and empty trials.
    %
    % Syntax:
    %   [stStatistics, emStatistics] = stEmStatData(data, exp)
    %
    % Description:
    %   This function takes a BehaviorAnalysis object (`data`) and an 
    %   ExperimentBehave object (`exp`) and computes epoch statistics for
    %   each trial. It extracts the boolean matrices for stranger and empty
    %   regions of interest and applies the `Statistics.epochsStats` function
    %   to each trial's data.
    %
    % Inputs:
    %   data - A BehaviorAnalysis object containing the processed boolean matrices.
    %   exp  - An ExperimentBehave object containing experiment metadata,
    %          including the number of trials.
    %
    % Outputs:
    %   stStatistics - A struct array where each element contains the epoch
    %                  statistics for a single stranger trial.
    %   emStatistics - A struct array where each element contains the epoch
    %                  statistics for a single empty trial.
    %
    % Each struct in the output arrays contains the statistics (e.g., total
    % duration, number of epochs) as computed by the `Statistics.epochsStats`
    % function.
    %
    % Example:
    %   % Assuming 'myAnalysis' and 'myExp' objects exist
    %   [strangerStats, emptyStats] = stEmStatData(myAnalysis, myExp);
    
    stMat = data.getMatrix("stranger_out");
    emMat = data.getMatrix("empty_out");
    stim_trials = exp.getStimTrials();
    num_trials = length(stim_trials);
    
    % stStatistics, emStatistics: Two structures in the number of the trails.
    % in posision i there will be a struct with the statistics data that 
    % comes from epochsStats function
    for i = 1:num_trials
        trail = stim_trials(i);
        stTrailMat = squeeze(stMat(2, trail, :));
        emTrailMat = squeeze(emMat(2, trail, :));
    
        stStatistics(i) = Statistics.epochsStats(stTrailMat);
        emStatistics(i) = Statistics.epochsStats(emTrailMat);
    end
end
