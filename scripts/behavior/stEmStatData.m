
function [stStatistics, emStatistics] = stEmStatData(data, exp)
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