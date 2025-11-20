function [X_all, y_all] = buildDataset(boundaryAllowance, seqTimeInSec, normalizeMode)
% buildDataset - Construct neuronal epoch-level dataset and compute mouse-level PS.
%
% Description:
%   Builds an epoch-level dataset for all mice and experiments for the given
%   boundary and sequence time. Aligns calcium and behavioral matrices,
%   detects epochs, computes average neuronal activity per epoch (24 zones),
%   and saves both per-experiment and per-mouse data, including a PS vector
%   and Excel summary.
%
% Args:
%   boundaryAllowance (double): Boundary distance in cm (e.g., 3.0)
%   seqTimeInSec (double): Sequence duration in seconds (e.g., 3.5)
%   normalizeMode (string): Normalization mode for alignFrames ('raw' or 'epoch')
%
% Output:
%   X_all (double): [N_epochs_total × 24] combined neuronal data.
%   y_all (double): [N_epochs_total × 1] binary labels (1=stranger, 0=empty).
%
% Saved Outputs:
%   data/processed/neuronal_epoch_data/seq<seqTime>/b<boundary>/
%       <group>_<color>/<date>/
%           X_epochs_<group>_<color>_<date>.mat
%           y_epochs_<group>_<color>_<date>.mat
%           mean_stranger_<group>_<color>_<date>.mat
%           mean_empty_<group>_<color>_<date>.mat
%       <group>_<color>/average/
%           mean_stranger_mouse_<group>_<color>.mat
%           mean_empty_mouse_<group>_<color>.mat
%           ps_mouse_<group>_<color>.mat
%           ps_mouse_<group>_<color>.xlsx  ← Excel summary (sorted by PS)
%
% Example:
%   [X, y] = buildDataset(3.0, 2.5, 'raw');
%
% -------------------------------------------------------------------------

cfg = config();
X_all = [];
y_all = [];

% === Define base paths ===
baseDirBool = fullfile("data", "processed", "bool_matrices", ...
    sprintf("seq%.1f", seqTimeInSec), sprintf("b%.1f", boundaryAllowance));

if ~exist(baseDirBool, "dir")
    error("Bool folder not found: %s", baseDirBool);
end

boolFiles = dir(fullfile(baseDirBool, "bool_*_stranger.mat"));
if isempty(boolFiles)
    error("No bool files found in %s", baseDirBool);
end

fprintf("Building dataset for Boundary=%.1f, Seq=%.1f\n", boundaryAllowance, seqTimeInSec);

% === Identify unique mice ===
allMice = unique(cellfun(@(n) extractMouseID(n), {boolFiles.name}, 'UniformOutput', false));

for m = 1:numel(allMice)
    mouseID = allMice{m};
    parts = split(mouseID, '_');
    group = parts{1};
    color = parts{2};

    fprintf("\nProcessing mouse %s_%s\n", group, color);

    % Initialize per-mouse storage
    mouseMeanStranger = [];
    mouseMeanEmpty = [];

    % --- Locate all experiments (dates) for this mouse ---
    filesMouse = dir(fullfile(baseDirBool, sprintf("bool_%s_%s_*_stranger.mat", group, color)));

    for f = 1:numel(filesMouse)
        [~, name, ~] = fileparts(filesMouse(f).name);
        parts = split(name, '_');
        date = parts{4};

        fprintf("  - %s\n", date);

        % === Load bools ===
        fileStranger = fullfile(baseDirBool, sprintf("bool_%s_%s_%s_stranger.mat", group, color, date));
        fileEmpty    = fullfile(baseDirBool, sprintf("bool_%s_%s_%s_empty.mat", group, color, date));

        if ~isfile(fileStranger) || ~isfile(fileEmpty)
            warning("Missing bool files for %s_%s_%s", group, color, date);
            continue;
        end

        dataSt = load(fileStranger); dataEm = load(fileEmpty);
        stFieldName = fieldnames(dataSt);
        emFieldName = fieldnames(dataEm);
        boolSt = dataSt.(stFieldName{1});
        boolEm = dataEm.(emFieldName{1});

        % === Load calcium ===
        caDir = fullfile("data", "processed", group, "ca_matrix");
        pattern = sprintf("Ca_trials_Matrix_%s_%s_%s_*_%s_*.mat", ...
            group, date, cfg.EXPERIMENT_TYPE, color);
        caFiles = dir(fullfile(caDir, pattern));

        if isempty(caFiles)
            warning("No CA file found for %s_%s_%s", group, color, date);
            continue;
        end

        caData = load(fullfile(caDir, caFiles(1).name));
        caMat = caData.ROICaData_stim(1:24,:,:); % keep 24 zones only

        % --- Validate dimensions for both types ---
        if ~validateDimensions(caMat, boolSt, group, color, date, 'stranger') || ...
           ~validateDimensions(caMat, boolEm, group, color, date, 'empty')
            continue;  % skip this experiment
        end

        % === Align and compute epochs ===
        [X_st_frames, y_st_frames] = alignFrames(caMat, boolSt, normalizeMode);
        [X_em_frames, y_em_frames] = alignFrames(caMat, boolEm, normalizeMode);

        [X_st_epochs, y_st_epochs] = computeEpochAverages(X_st_frames, y_st_frames, 1);
        [X_em_epochs, y_em_epochs] = computeEpochAverages(X_em_frames, y_em_frames, 0);

        X_epochs = [X_st_epochs; X_em_epochs];
        y_epochs = [y_st_epochs; y_em_epochs];

        mean_stranger = mean(X_st_epochs, 1, 'omitnan');
        mean_empty    = mean(X_em_epochs, 1, 'omitnan');

        % === Save per-experiment ===
        saveDir = fullfile("data", "processed", "neuronal_epoch_data", ...
            sprintf("seq%.1f", seqTimeInSec), sprintf("b%.1f", boundaryAllowance), ...
            sprintf("%s_%s", group, color), date);
        if ~isfolder(saveDir), mkdir(saveDir); end

        save(fullfile(saveDir, sprintf("X_epochs_%s_%s_%s.mat", group, color, date)), "X_epochs");
        save(fullfile(saveDir, sprintf("y_epochs_%s_%s_%s.mat", group, color, date)), "y_epochs");
        save(fullfile(saveDir, sprintf("mean_stranger_%s_%s_%s.mat", group, color, date)), "mean_stranger");
        save(fullfile(saveDir, sprintf("mean_empty_%s_%s_%s.mat", group, color, date)), "mean_empty");

        % Collect for mouse-level average
        mouseMeanStranger = [mouseMeanStranger; mean_stranger];
        mouseMeanEmpty = [mouseMeanEmpty; mean_empty];

        % Append to global dataset
        X_all = [X_all; X_epochs];
        y_all = [y_all; y_epochs];
    end

    %% === Mouse-level average and PS ===
    if isempty(mouseMeanStranger) || isempty(mouseMeanEmpty)
        continue;
    end

    meanStranger_mouse = mean(mouseMeanStranger, 1, 'omitnan');
    meanEmpty_mouse = mean(mouseMeanEmpty, 1, 'omitnan');
    ps_mouse = (meanStranger_mouse - meanEmpty_mouse) ./ ...
               (meanStranger_mouse + meanEmpty_mouse);

    avgDir = fullfile("data", "processed", "neuronal_epoch_data", ...
        sprintf("seq%.1f", seqTimeInSec), sprintf("b%.1f", boundaryAllowance), ...
        sprintf("%s_%s", group, color), "average");
    if ~isfolder(avgDir), mkdir(avgDir); end

    save(fullfile(avgDir, sprintf("mean_stranger_mouse_%s_%s.mat", group, color)), "meanStranger_mouse");
    save(fullfile(avgDir, sprintf("mean_empty_mouse_%s_%s.mat", group, color)), "meanEmpty_mouse");
    save(fullfile(avgDir, sprintf("ps_mouse_%s_%s.mat", group, color)), "ps_mouse");

    % === Create Excel summary ===
    Zone = (1:24)';
    PS = ps_mouse(:);
    MeanStranger = meanStranger_mouse(:);
    MeanEmpty = meanEmpty_mouse(:);

    psTable = table(Zone, MeanStranger, MeanEmpty, PS);
    psTable = sortrows(psTable, "PS", "descend");

    excelPath = fullfile(avgDir, sprintf("ps_mouse_%s_%s.xlsx", group, color));
    writetable(psTable, excelPath, 'FileType', 'spreadsheet');

    fprintf("  ✓ Mouse %s_%s average saved (PS range %.2f–%.2f)\n", ...
        group, color, min(ps_mouse), max(ps_mouse));
end

fprintf("\nDataset built successfully. Total epochs: %d\n", size(X_all,1));
end

% ---------------------------------------------------------
% Helpers
% ---------------------------------------------------------

% ------------------------------------------------------------------------
function mouseID = extractMouseID(filename)
% extractMouseID - Extracts "group_color" mouse ID from filename.
    parts = split(filename, '_');
    mouseID = strjoin(parts(2:3), '_');
end

% ------------------------------------------------------------------------
function [X_epochs, y_epochs] = computeEpochAverages(X_frames, y_frames, label)
% computeEpochAverages - Averages neuronal data per behavioral epoch.
%
% Args:
%   X_frames (double): [N_frames × 24] calcium data.
%   y_frames (double): [N_frames × 1] binary vector (1=active).
%   label (int): 1 for stranger, 0 for empty.
%
% Output:
%   X_epochs (double): [N_epochs × 24]
%   y_epochs (double): [N_epochs × 1]
% -------------------------------------------------------------------------
    if isempty(X_frames)
        X_epochs = [];
        y_epochs = [];
        return;
    end

    diff_y = diff([0; y_frames; 0]);
    starts = find(diff_y == 1);
    ends   = find(diff_y == -1) - 1;

    nEpochs = numel(starts);
    X_epochs = zeros(nEpochs, size(X_frames, 2));
    y_epochs = label * ones(nEpochs, 1);

    for e = 1:nEpochs
        idx = starts(e):ends(e);
        X_epochs(e, :) = mean(X_frames(idx, :), 1, 'omitnan');
    end
end


function isValid = validateDimensions(caMat, boolMat, group, color, date, typeLabel)
% validateDimensions  Ensure CA and bool matrices are aligned.
%
% Args:
%   caMat (double): calcium matrix [nNeurons × T × F]
%   boolMat (double): boolean matrix [T × F]
%   group, color, date (char): identifiers for the experiment
%   typeLabel (char): 'stranger' or 'empty'
%
% Output:
%   isValid (logical): true if dimensions match, false otherwise
%
% How it works:
%   - Checks that both matrices have matching trial (T) and frame (F) sizes.
%   - Prints a detailed warning if mismatch is found.
% -------------------------------------------------------------------------
    [nNeurons, T_ca, F_ca] = size(caMat);
    [T_bool, F_bool] = size(boolMat);

    if T_ca ~= T_bool || F_ca ~= F_bool
        warning("Dimension mismatch for %s (%s_%s_%s):\n  CA: " + ...
            "[%d × %d × %d]\n  Bool: [%d × %d]\n  --> Skipping.\n", ...
            upper(typeLabel), group, color, date, nNeurons, T_ca, F_ca, T_bool, F_bool);
        isValid = false;
    else
        isValid = true;
    end
end



function [X_exp, y_exp] = alignFrames(caMat, boolMat, normalizeMode)
% alignFrames  Convert trial × frame matrices into frame-level dataset
%
%   Inputs:
%       caMat   - [48 × T × F]
%       boolMat - [T × F]
%       normalizeMode - 'raw' or 'epoch'
%
%   Outputs:
%       X_exp - [(T*F) × 48]
%       y_exp - [(T*F) × 1]

    [nNeurons, T, F] = size(caMat);

    % Reshape CA: we want frames to go first within each trial
    X_exp = permute(caMat, [3 2 1]);      % F × T × 48
    X_exp = reshape(X_exp, F*T, nNeurons);

    % Reshape bool the same way
    y_exp = permute(boolMat, [2 1]);      % F × T
    y_exp = reshape(y_exp, F*T, 1);

    % --- Create mask: 1 if the row has at least one non-NaN value
    % ---              0 if all values are NaN
    mask = ~all(isnan(X_exp), 2);

    % --- Apply mask to both X_exp and y_exp
    X_exp = X_exp(mask, :);
    y_exp = y_exp(mask, :);

    % Apply normalization if requested
    switch normalizeMode
        case 'raw'
            % do nothing
        case 'epoch'
            % TODO: implement epoch normalization later
            warning("Epoch normalization not implemented. Returning raw.");
        otherwise
            error("Unknown normalizeMode: %s", normalizeMode);
    end
end
