function analyzeModelSummary()
% analyzeModelSummary
% -------------------------------------------------------------
% Master script to analyze all models and all mice.
% Calls analyzeMLPerformance() for each mouse,
% aggregates their data into an averaged table (per-mouse level),
% saves it under BASE_DIR, and generates figures.
%
% Author: Amiel Wreschner
% -------------------------------------------------------------

clc; clear;
warning('off','MATLAB:table:ModifiedAndSavedVarnames');

%% === Constants ===
BASE_DIR = 'results/3chamber/boundary&sequence/ml_models/';
MODEL_NAMES = {'SVM'};   % extend as needed
MIN_TEST_EPOCHS = 5;
EXCLUDE_NAN = true;
COLOR_LIMITS = [0.2 0.8];
IS_CONTROL = true;  % if true - analyze the control models (shufel models)

SEQ_VALUES = 0:0.5:5;
B_VALUES   = 0:0.5:5;

%% === Loop over models ===
for m = 1:numel(MODEL_NAMES)
    modelName = MODEL_NAMES{m};
    if IS_CONTROL
        modelPath = fullfile(BASE_DIR, modelName, 'control');
    else
        modelPath = fullfile(BASE_DIR, modelName);
    end

    if ~exist(modelPath, 'dir')
        fprintf('Model folder not found: %s\n', modelPath);
        continue;
    end

    fprintf('\n=== Processing model: %s ===\n', modelName);

    % % === Process only the "all_mice" folder === comment those lines if you
    % % want to analyze each mouse
    % mousePath = fullfile(modelPath, 'all_mice');
    % if ~exist(mousePath, 'dir')
    %     fprintf('  (No all_mice folder found in %s)\n', modelName);
    %     continue;
    % end
    % fprintf('  → Processing all_mice folder\n');
    % analyzeMLPerformance(mousePath, MIN_TEST_EPOCHS, EXCLUDE_NAN, COLOR_LIMITS);
    % continue;
    % =====================================================================

    % Get all mouse directories (ignore system and summary folders)
    mouseDirs = dir(modelPath);
    mouseDirs = mouseDirs([mouseDirs.isdir]);
    ignoreDirs = {'summary_overall','summary_overall_average','all_mice','summary_old','control','.','..'};
    mouseDirs = mouseDirs(~ismember({mouseDirs.name}, ignoreDirs));

    %% Prepare aggregation cubes
    nSeq = numel(SEQ_VALUES);
    nB   = numel(B_VALUES);
    nMice = numel(mouseDirs);
    AccCube = nan(nMice, nSeq, nB);
    AUCCube = nan(nMice, nSeq, nB);

    AllResults = struct();
    resultCount = 0;

    %% === Loop over each mouse ===
    for k = 1:nMice
        mouseName = mouseDirs(k).name;
        mousePath = fullfile(modelPath, mouseName);
        fprintf('  → %s\n', mouseName);

        try
            T = analyzeMLPerformance(mousePath, MIN_TEST_EPOCHS, EXCLUDE_NAN, COLOR_LIMITS);

            if isempty(T)
                fprintf('    (No valid data)\n');
                continue;
            end

            % Store result
            resultCount = resultCount + 1;
            AllResults(resultCount).Model = modelName;
            AllResults(resultCount).Mouse = mouseName;
            AllResults(resultCount).Table = T;

            % Fill accuracy/AUC cubes
            for i = 1:nSeq
                for j = 1:nB
                    idx = T.Seq == SEQ_VALUES(i) & T.Boundary == B_VALUES(j);
                    if any(idx)
                        nEp = T.TestEpochs(idx);
                        if nEp >= MIN_TEST_EPOCHS
                            AccCube(k,i,j) = mean(T.Accuracy(idx), 'omitnan');
                            AUCCube(k,i,j) = mean(T.AUC(idx), 'omitnan');
                        else
                            AccCube(k,i,j) = 0.5;
                            AUCCube(k,i,j) = 0.5;
                        end
                    else
                        AccCube(k,i,j) = 0.5;
                        AUCCube(k,i,j) = 0.5;
                    end
                end
            end

        catch ME
            fprintf('    Error processing %s: %s\n', mouseName, ME.message);
        end
    end

    %% === Compute per-cell average across mice ===
    avgAcc = squeeze(mean(AccCube, 1, 'omitnan'));
    avgAUC = squeeze(mean(AUCCube, 1, 'omitnan'));

    % Build table with averages
    [seqGrid, bGrid] = ndgrid(SEQ_VALUES, B_VALUES);
    avgTable = table(seqGrid(:), bGrid(:), avgAcc(:), avgAUC(:), ...
        'VariableNames', {'Seq','Boundary','Accuracy','AUC'});

    %% === Save average table ===
    summaryDir = fullfile(modelPath, 'summary_overall_average');
    if ~exist(summaryDir, 'dir')
        mkdir(summaryDir);
    end
    
    avgFile = fullfile(summaryDir, sprintf('performance_average_per_mouse_%s.xlsx', modelName));
    writetable(avgTable, avgFile);
    fprintf('  → Saved averaged table to: %s\n', fullfile(pwd, avgFile));
    
    %% === Generate Average Heatmaps ===
    fprintf('  → Creating average heatmaps (Accuracy, AUC)...\n');
    
    % Accuracy heatmap
    fig1 = figure('Name', sprintf('Average Accuracy Heatmap - %s', modelName), 'Color', 'w');
    imagesc(B_VALUES, SEQ_VALUES, avgAcc);
    set(gca, 'YDir', 'normal');
    xlabel('Boundary');
    ylabel('Sequence Time');
    title(sprintf('Average Accuracy Heatmap - %s', modelName), 'Interpreter', 'none');
    colormap(jet);
    colorbar;
    caxis(COLOR_LIMITS);
    
    saveas(fig1, fullfile(summaryDir, sprintf('avg_acc_heatmap_%s.fig', modelName)));
    saveas(fig1, fullfile(summaryDir, sprintf('avg_acc_heatmap_%s.png', modelName)));
    close(fig1);
    
    % AUC heatmap
    fig2 = figure('Name', sprintf('Average AUC Heatmap - %s', modelName), 'Color', 'w');
    imagesc(B_VALUES, SEQ_VALUES, avgAUC);
    set(gca, 'YDir', 'normal');
    xlabel('Boundary');
    ylabel('Sequence Time');
    title(sprintf('Average AUC Heatmap - %s', modelName), 'Interpreter', 'none');
    colormap(jet);
    colorbar;
    caxis(COLOR_LIMITS);
    
    saveas(fig2, fullfile(summaryDir, sprintf('avg_auc_heatmap_%s.fig', modelName)));
    saveas(fig2, fullfile(summaryDir, sprintf('avg_auc_heatmap_%s.png', modelName)));
    close(fig2);
    
    fprintf('  → Saved average heatmaps in %s\n', summaryDir);
    
    %% === Save struct for future reference ===
    save(fullfile(summaryDir, sprintf('AllResults_%s.mat', modelName)), 'AllResults');
    
    fprintf('=== Completed analysis for %s ===\n\n', modelName);
end

fprintf('=== All models analyzed ===\n');
end
