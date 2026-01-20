function runAllModels()
% runAllModels - Run all ML models for all (seq, boundary) pairs.
%
% Author: Amiel Wreschner

boundaries = 0 : 0.5 : 5;        % candidate boundaries (cm)
seqTimes   = 0 : 0.5 : 5;      % candidate sequence durations (s)
MODE  = 'all_mice';             % 'per_mouse' or 'all_mice'
mlModels = {'SVM'};              % {'SVM', 'Logistic', 'RandomForest', 'kNN'}
isControl = true;               % if true - shuffle labels
isEqualClassification = true;
doTuneSVM = true;

baseResults = fullfile('results','3chamber','boundary&sequence','ml_models');

for m = 1:length(mlModels)
    mlModel = mlModels{m};
    modelDir = fullfile(baseResults, mlModel);
    if strcmp(MODE, 'all_mice')
        modelDir = fullfile(modelDir, 'all_mice');
    end
    if isControl
        modelDir = fullfile(modelDir, 'control');
    end
    if ~exist(modelDir, 'dir'), mkdir(modelDir); end

    % === Load or initialize trained pairs grid ===
    trainedPairsFile = fullfile(modelDir, 'trained_pairs.mat');
    if isfile(trainedPairsFile)
        load(trainedPairsFile, 'TrainedPairs');
        if ~exist('TrainedPairs','var') || ...
           ~isequal(size(TrainedPairs), [numel(seqTimes), numel(boundaries)])
            TrainedPairs = false(numel(seqTimes), numel(boundaries));
        end
    else
        TrainedPairs = false(numel(seqTimes), numel(boundaries));
    end

    fprintf('\n=== MODEL: %s ===\n', mlModel);

    for i = 1:length(seqTimes)
        for j = 1:length(boundaries)
            seqTime = seqTimes(i);
            boundary = boundaries(j);

            % === Skip if already trained ===
            if TrainedPairs(i, j)
                fprintf('Skipping %s | seq %.1f | b %.1f (already trained)\n', mlModel, seqTime, boundary);
                continue;
            end

            % === Run training ===
            fprintf('\n>>> Running %s | seq %.1f | b %.1f <<<\n', mlModel, seqTime, boundary);
            if strcmpi(MODE, 'per_mouse')
                trainMouseModels(seqTime, boundary, mlModel, isControl, isEqualClassification, doTuneSVM);
            elseif strcmpi(MODE, 'all_mice')
                trainGlobalModels(seqTime, boundary, mlModel, isControl);
            end

            % === Update grid and save ===

            % if seqTime == 0.5
            %     return

            TrainedPairs(i, j) = true;
            save(trainedPairsFile, 'TrainedPairs', 'seqTimes', 'boundaries');
        end
    end
end

fprintf('\nAll models and parameter combinations completed.\n');
end
