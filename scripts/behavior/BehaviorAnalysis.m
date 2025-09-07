classdef BehaviorAnalysis < handle
    % BehaviorAnalysis - Analyzes 3-chamber behavioral experiment spatial activity
    %
    % This class is currently designed for 3-chamber sociability tests.
    % It assumes the existence of four specific cage ROIs:
    %   - cage_stranger
    %   - cage_empty
    %   - cage_stranger_out
    %   - cage_empty_out
    % and a 3-trial, 2-minute-per-trial structure in XY_behave.
    %
    % Constructor:
    %   obj = BehaviorAnalysis(exp, boundaryAllowance, seqTimeInSec)
    %
    % Public method:
    %   obj = run(obj)               % runs the full position and continuity analysis
    %   mat = getMatrix(obj, type)   % returns one of the four boolean matrices

    properties
        exp ExperimentBehave
        boundaryAllowance double
        seqTimeInSec double
        results struct  % will contain: stranger, empty, stranger_out, empty_out
    end

    methods
        function obj = BehaviorAnalysis(exp, boundaryAllowance, seqTimeInSec)
            obj.exp = exp;
            obj.boundaryAllowance = boundaryAllowance;
            obj.seqTimeInSec = seqTimeInSec;
            obj.results = struct();
        end

        function run(obj)
            % Generates four matrices, each with exactly the same structure as
            % XY_behave: 2*3*1200. For a matrix 'descriptionMat' (1,Z,K) there will be a
            % boolean value describing whether in frame number K, in trail number Z,
            % the mouse was within the boundaries of the description.
            % in (2,Z,K) there will be a boolean value describing whether frame number 
            % K, trail number Z is a part of time sequence of length.
            % the whole four will be saved in results field.
            XY_behave = obj.exp.XY_behave;
            trails = obj.exp.stim_trials;
            pxToExpand = obj.boundaryAllowance * obj.exp.cagePos.px2cm;
            minNanSeq = 15; % if there are more Nan in a row than this
            % value -all will be -1.

            % Expand ROI rectangles
            obj.exp.cagePos.cage_stranger_out.Position = posExpander(obj.exp.cagePos.cage_stranger.Position, pxToExpand);
            obj.exp.cagePos.cage_empty_out.Position    = posExpander(obj.exp.cagePos.cage_empty.Position, pxToExpand);

            % Initialize result matrices
            template = XY_behave + 0;
            mats = struct(...
                'stranger',      template,...
                'empty',         template,...
                'stranger_out',  template,...
                'empty_out',     template);

            for trail = trails
                coords = squeeze(XY_behave(:, trail, :));
                nFrames = size(coords, 2);
                inside = struct(...
                    'stranger',      false(1, nFrames),...
                    'empty',         false(1, nFrames),...
                    'stranger_out',  false(1, nFrames),...
                    'empty_out',     false(1, nFrames));

                for f = 1:nFrames
                    x = coords(1, f); y = coords(2, f);

                    % Handle with Nan values - replace with aberage values.
                    if isnan(x)
                        disp(f);
                        coords(1, :) = ...
                            handleNaNs(coords(1, :), f, minNanSeq, nFrames);
                        x = coords(1, f);
                    end
                
                    if isnan(y)
                        coords(2, :) = ...
                            handleNaNs(coords(2, :), f, minNanSeq, nFrames);
                        y = coords(2, f);
                    end

                    inside.stranger(f)     = inROI(obj.exp.cagePos.cage_stranger, x, y);
                    inside.empty(f)        = inROI(obj.exp.cagePos.cage_empty, x, y);
                    inside.stranger_out(f) = inROI(obj.exp.cagePos.cage_stranger_out, x, y);
                    inside.empty_out(f)    = inROI(obj.exp.cagePos.cage_empty_out, x, y);
                end

                mats.stranger(1, trail, :)     = inside.stranger;
                mats.empty(1, trail, :)        = inside.empty;
                mats.stranger_out(1, trail, :) = inside.stranger_out;
                mats.empty_out(1, trail, :)    = inside.empty_out;
            end

            % Apply continuity filtering
            framesPerTrial = size(XY_behave, 3);
            % in a trail there is numFrames frames and each trail is 2 minutes (120 secondes)
            framesPerMinute = round(framesPerTrial / 120);
            % seqLen will be the number of frames for continuity in case
            % seqTimeInSec is 0 seqLen will be 1 (that is why the max)
            seqLen = max(round(framesPerMinute * obj.seqTimeInSec), 1); 
            matNames = fieldnames(mats);
            for i = 1:numel(matNames)
                name = matNames{i};
                for t = trails
                    raw = squeeze(mats.(name)(1, t, :));
                    mats.(name)(2, t, :) = continuityChecker(raw, seqLen);
                end
            end

            obj.results = mats;
        end

        function mat = getMatrix(obj, name)
            % getMatrix("stranger") or "empty", "stranger_out", "empty_out"
            if isfield(obj.results, name)
                mat = obj.results.(name);
            else
                error('Invalid matrix name. Use: stranger, empty, stranger_out, empty_out');
            end
        end

        
    end
end

% === Helper Functions (local) ===
function newPos = posExpander(oldPos, px)
    newPos = [oldPos(1)-px, oldPos(2)-px, oldPos(3)+2*px, oldPos(4)+2*px];
end

function vecCon = continuityChecker(vec, contN)
% continuityChecker - Identify continuous sequences of 1s meeting a minimum length
%
% Inputs:
%   vec   - A binary or logical vector (row or column).  
%           Example: [0 1 1 0 1 1 1 0]
%   contN - Minimum number of consecutive 1s required for a sequence to be
%           considered valid.
%
% Output:
%   vecCon - Logical vector of the same size as `vec`, where `true` marks
%            the indices belonging to qualifying continuous sequences.
%
% Example:
%   vec = [0 1 1 0 1 1 1 0 1 1];
%   contN = 3;
%   vecCon = continuityChecker(vec, contN);
%   % vecCon = [0 0 0 0 1 1 1 0 0 0]
%
% Notes:
%   - The function first reshapes the input vector to a row vector internally.
%   - Works with numeric binary (0/1) or logical arrays.
%   - This function is useful for enforcing a minimum dwell time in behavioral
%     experiments, e.g., when determining if an animal stayed in a Region of
%     Interest (ROI) for at least `contN` consecutive frames or seconds.

    vec = vec(:)'; vecCon = false(size(vec));
    curCon = 0; startIdx = 1;
    for i = 1:length(vec)
        if vec(i)
            if curCon == 0, startIdx = i; end
            curCon = curCon + 1;
        else
            if curCon >= contN
                vecCon(startIdx:i-1) = true;
            end
            curCon = 0;
        end
    end
    if curCon >= contN
        vecCon(startIdx:end) = true;
    end
end

function vOut = handleNaNs(vIn, f, minNanSeq, nFrames)
% handleNaNs - Handle NaN sequences dynamically around index f.
%
% Inputs:
%   vIn       - 1 x N vector (X or Y coordinates)
%   f         - current frame index
%   minNanSeq - minimum sequence length to consider replacement
%   nFrames   - total number of frames
%
% Output:
%   vOut - processed vector with NaNs handled
%
% Notes:
%   - This function is always called when vIn(f) is NaN, so vIn(f-1) cannot be NaN.
%   - If no valid value is found within the next minNanSeq frames, the block is marked as -1.
%   - If f == 1 or the previous value was -1, the replacement uses the next valid value only.

    vOut = vIn;
    endIdx = min(f+minNanSeq-1, nFrames);
    seq = vOut(f:endIdx);

    nextValidRel = find(~isnan(seq),1,'first'); % relative index to f
    if isempty(nextValidRel)
        vOut(f:endIdx) = -1; % all remain NaN → mark invalid
        return
    end

    if f == 1 || vIn(f-1) == -1
        % If we start with NaN or the previous value was also changed to -1
        % [probably in this function], fill only until the first valid
        vOut(f: f+nextValidRel-1) = seq(nextValidRel);
    else
        prevVal = vIn(f-1);
        nextVal = seq(nextValidRel);
        lins = linspace(prevVal, nextVal, nextValidRel + 1);
        vOut(f:f+nextValidRel-1) = lins(2:end);
    end
end

