function runAllModels()
% runAllModels - Run all ML models for all (seq, boundary) pairs.
%
% Runs all combinations of:
%   - MODE: {'per_mouse','all_mice'}
%   - Control: {false,true}
%
% Author: Amiel Wreschner

boundaries = 0 : 0.5 : 5;        % candidate boundaries (cm)
seqTimes   = 0 : 0.5 : 5;        % candidate sequence durations (s)
MODE_LIST  = {'per_mouse'};
mlModels   = {'SVM'};            % {'SVM', 'Logistic', 'RandomForest', 'kNN'}
isControlList = [false, true];   % run both real and control
isEqualClassification = true;
doTuneSVM = true;

baseResults = fullfile('results','3chamber','boundary&sequence','ml_models');

for m = 1:length(mlModels)
    mlModel = mlModels{m};

    for modeIdx = 1:length(MODE_LIST)
        MODE = MODE_LIST{modeIdx};

        for ctrlIdx = 1:length(isControlList)
            isControl = isControlList(ctrlIdx);

            fprintf('\n=== MODEL: %s | MODE: %s | CONTROL: %d ===\n', ...
                mlModel, MODE, isControl);

            % === Define model directory ===
            modelDir = fullfile(baseResults, mlModel);
            if strcmpi(MODE, 'all_mice')
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

            % === Iterate through seq/b pairs ===
            for i = 1:length(seqTimes)
                for j = 1:length(boundaries)
                    seqTime = seqTimes(i);
                    boundary = boundaries(j);

                    % === Skip if already trained ===
                    if TrainedPairs(i, j)
                        fprintf('Skipping %s | %s | seq %.1f | b %.1f (already trained)\n', ...
                            mlModel, MODE, seqTime, boundary);
                        continue;
                    end

                    fprintf('\n>>> Running %s | %s | seq %.1f | b %.1f | control=%d <<<\n', ...
                        mlModel, MODE, seqTime, boundary, isControl);

                    % === Run training ===
                    try
                        if strcmpi(MODE, 'per_mouse')
                            trainMouseModels(seqTime, boundary, mlModel, isControl, isEqualClassification, doTuneSVM);
                        elseif strcmpi(MODE, 'all_mice')
                            trainGlobalModels(seqTime, boundary, mlModel, isControl);
                        end
                    catch ME
                        fprintf('  ERROR: %s\n', ME.message);
                    end

                    % === Update grid and save progress ===
                    TrainedPairs(i, j) = true;
                    save(trainedPairsFile, 'TrainedPairs', 'seqTimes', 'boundaries');
                end
            end
        end
    end
end

fprintf('\nAll models and parameter combinations completed for all modes.\n');
end
