function [X, y] = buildDataset(boundary, seqTime, normalizeMode)
% buildDataset  Construct frame-level dataset from bool (labels) 
%               and calcium (neuronal activity) matrices.
%
%   [X, y] = buildDataset(boundary, seqTime, normalizeMode)
%
%   Inputs:
%       boundary      - numeric, current boundary value (e.g., 3.0)
%       seqTime       - numeric, current sequence duration (e.g., 3.5)
%       normalizeMode - string, how to represent neuronal activity:
%                           'raw'   : keep calcium values as-is
%                           'epoch' : normalize per social interaction epoch
%
%   Outputs:
%       X - [N_frames_total × N_neurons] feature matrix
%       y - [N_frames_total × 1] binary labels (0/1 for interaction)
%
%   Notes:
%       - Bool matrices (y) are T × F per experiment
%       - CA matrices (X) are 48 × T × F per experiment
%       - Frame alignment is guaranteed by trial × frame indexing
%       - Currently only 'raw' is implemented; 'epoch' is left as future option

    % --- Locate folders ---
    baseDirBool = fullfile("data", "processed", "bool_matrices", ...
                           sprintf("seq%.1f", seqTime), ...
                           sprintf("b%.1f", boundary));
                       
    if ~exist(baseDirBool, "dir")
        error("Bool folder not found: %s", baseDirBool);
    end

    % --- Gather files ---
    boolFiles = dir(fullfile(baseDirBool, "*_stranger.mat")); % use stranger only for now
    if isempty(boolFiles)
        error("No bool files found in %s", baseDirBool);
    end
    
    % --- Initialize storage ---
    X_all = [];
    y_all = [];

    % --- Loop over experiments ---
    for f = 1:numel(boolFiles)
        % Get experiment ID from filename (to match CA file)
        [~, name, ~] = fileparts(boolFiles(f).name);
        [group, color, date] = extractExpID(name); % helper to strip "_stranger"
        fprintf("\nProcessing %s %s %s", group, color, date);
        
        % Load bool
        boolData = load(fullfile(baseDirBool, boolFiles(f).name));
        fieldName = fieldnames(boolData);
        boolMat = boolData.(fieldName{1});  % T × F
        
        % Load corresponding CA
        % Ca_trials_Matrix_12th_20241209_3chamber_1A2P_1_blue_st_R_em_L
        caDir = fullfile("data", "processed", group, "ca_matrix");

        % Build search pattern with wildcards
        pattern = sprintf("Ca_trials_Matrix_%s_%s_*_%s_*.mat", group, date, color);
        
        % Find matching file(s)
        caFiles = dir(fullfile(caDir, pattern));
        
        if isempty(caFiles)
            warning("No CA file found for %s %s %s\n", group, date, color);
            continue;
        end

        caFile = fullfile(caDir, caFiles(1).name);

        caData = load(caFile);
        caMat  = caData.ROICaData_stim;      % 48 × T × F

        % --- Check dimension consistency ---
        [nNeurons, T_ca, F_ca] = size(caMat);
        [T_bool, F_bool] = size(boolMat);
        
        if T_ca ~= T_bool || F_ca ~= F_bool
            warning("Dimension mismatch for %s %s %s:\n  CA matrix:  " + ...
                "[%d × %d (Trials) × %d (Frames)]\n  Bool matrix: [%d (Trials) × %d (Frames)]\n  " + ...
                "--> Skipping this experiment.\n", ...
                    group, color, date, nNeurons, T_ca, F_ca, T_bool, F_bool);
            continue;
        end
        
        % --- Convert to frame-level dataset ---
        [X_exp, y_exp] = alignFrames(caMat, boolMat, normalizeMode);
        
        % Append
        X_all = [X_all; X_exp];
        y_all = [y_all; y_exp];
    end
    
    % --- Final outputs ---
    X = X_all;
    y = y_all;
end


% ---------------------------------------------------------
% Helpers
% ---------------------------------------------------------

function [group, color, date] = extractExpID(fname)
    parts = split(fname, "_");
    group = parts{2};
    color = parts{3};
    date  = parts{4};
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

    % Remove first 21 frames (if needed)
    X_exp = X_exp(21:end, :);
    y_exp = y_exp(21:end);

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
