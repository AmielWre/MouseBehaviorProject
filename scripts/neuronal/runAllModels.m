function runAllModels()
% runAllModels - Run all ML models for all (seq, boundary) pairs.
%
% Author: Amiel Wreschner

boundaries = 0 : 0.5 : 5;        % candidate boundaries (cm)
seqTimes   = 0 : 0.5 : 5;        % candidate sequence durations (s)
mlModels = {'SVM', 'Logistic', 'RandomForest', 'kNN'};
MODE  = 'per_mouse';    % 'per_mouse' or 'all_mice'

for m = 1:length(mlModels)
    mlModel = mlModels{m};
    for i = 1:length(seqTimes)
        for j = 1:length(boundaries)
            seqTime = seqTimes(i);
            boundary = boundaries(j);
            fprintf('\n>>> Running %s | seq %.1f | b %.1f <<<\n', mlModel, seqTime, boundary);
            if strcmpi(MODE, 'per_mouse')
                trainMouseModels(seqTime, boundary, mlModel);
            elseif strcmpi(MODE, 'all_mice')
                trainGlobalModels(seqTime, boundary, mlModel);
            end
        end
    end
end

fprintf('\nAll models and parameter combinations completed.\n');
end
