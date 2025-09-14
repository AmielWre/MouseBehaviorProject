classdef BehaviorAnalysis < handle
    % BehaviorAnalysis - Analyzes 3-chamber behavioral experiment spatial activity
    %
    % This class is designed to process raw XY coordinate data from a 3-chamber
    % sociability test. It handles the identification of a mouse's position
    % relative to specific Regions of Interest (ROIs), applies continuity
    % filtering based on a minimum sequence time, and prepares boolean matrices
    % for further statistical analysis.
    %
    % It assumes the existence of four specific cage ROIs:
    %   - cage_stranger
    %   - cage_empty
    %   - cage_stranger_out
    %   - cage_empty_out
    % and a 3-trial, 2-minute-per-trial structure in the `XY_behave` data.
    %
    % Properties:
    %   exp               - An `ExperimentBehave` object containing experiment data.
    %   boundaryAllowance - A numeric value (cm) to expand the ROI boundaries.
    %   seqTimeInSec      - The minimum time in seconds a mouse must stay in an ROI
    %                       for the visit to be considered valid.
    %   results           - A struct containing the four processed boolean matrices.
    %
    % Public Methods:
    %   run()              - Executes the full position and continuity analysis.
    %   getMatrix(type)    - Returns one of the four processed boolean matrices.
    %
    % See also:
    %   ExperimentBehave, oneBehaveAnalysis
    
    properties
        exp ExperimentBehave
        boundaryAllowance double
        seqTimeInSec double
        results struct  % will contain: stranger, empty, stranger_out, empty_out
    end
    
    methods
        function obj = BehaviorAnalysis(exp, boundaryAllowance, seqTimeInSec)
            % BehaviorAnalysis - Constructs a BehaviorAnalysis object.
            %
            % Syntax:
            %   obj = BehaviorAnalysis(exp, boundaryAllowance, seqTimeInSec)
            %
            % Description:
            %   Initializes the analysis object with experiment data, a boundary
            %   allowance, and a sequence time for continuity filtering.
            %
            % Inputs:
            %   exp               - An `ExperimentBehave` object.
            %   boundaryAllowance - The boundary expansion in centimeters.
            %   seqTimeInSec      - The minimum stay time in seconds for continuity.
            %
            % Output:
            %   obj - A `BehaviorAnalysis` instance.
            
            obj.exp = exp;
            obj.boundaryAllowance = boundaryAllowance;
            obj.seqTimeInSec = seqTimeInSec;
            obj.results = struct();
        end
        
        function run(obj)
            % run - Executes the full position and continuity analysis.
            %
            % Description:
            %   This method performs the core analysis. It first handles NaN values
            %   in the raw coordinate data, then checks if the mouse's position is
            %   within each of the four ROIs for every frame. Finally, it applies
            %   a continuity filter based on `seqTimeInSec` to identify valid
            %   dwell times. The resulting boolean matrices are stored in the
            %   `results` property.
            %
            % Outputs:
            %   This method populates the `obj.results` property. The matrices
            %   are each of size 2x3xN (where N is the number of frames), and their
            %   structure is as follows:
            %   - `(1, Z, K)`: A boolean value indicating whether the mouse was in
            %     the ROI in trial `Z` at frame `K` (no continuity applied).
            %   - `(2, Z, K)`: A boolean value indicating if the mouse's presence
            %     at this frame is part of a continuous sequence that meets or
            %     exceeds the `seqTimeInSec` threshold.
            
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
            % getMatrix - Returns a processed boolean matrix by name.
            %
            % Syntax:
            %   mat = obj.getMatrix(name)
            %
            % Inputs:
            %   name - A string specifying the desired matrix, one of:
            %          'stranger', 'empty', 'stranger_out', 'empty_out'.
            %
            % Output:
            %   mat - The 2x3xN boolean matrix for the specified name.
            
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
    % posExpander - Expands a rectangular position vector by a given pixel amount.
    %
    % Syntax:
    %   newPos = posExpander(oldPos, px)
    %
    % Inputs:
    %   oldPos - A 4-element vector `[x, y, width, height]` defining a rectangle.
    %   px     - The number of pixels to expand the rectangle in all directions.
    %
    % Output:
    %   newPos - The new 4-element vector for the expanded rectangle.
    
    newPos = [oldPos(1)-px, oldPos(2)-px, oldPos(3)+2*px, oldPos(4)+2*px];
end

function vecCon = continuityChecker(vec, contN)
    % continuityChecker - Identifies continuous sequences of 1s meeting a minimum length.
    %
    % Syntax:
    %   vecCon = continuityChecker(vec, contN)
    %
    % Description:
    %   This function is useful for enforcing a minimum dwell time in behavioral
    %   experiments. It identifies segments of `true` values (or 1s) that are
    %   at least `contN` frames long.
    %
    % Inputs:
    %   vec    - A binary or logical vector (row or column). Example: `[0 1 1 0 1 1 1 0]`
    %   contN  - The minimum number of consecutive 1s required for a sequence.
    %
    % Output:
    %   vecCon - A logical vector of the same size as `vec`, where `true` marks
    %            the indices belonging to qualifying continuous sequences.
    %
    % Example:
    %   vec = [0 1 1 0 1 1 1 0 1 1];
    %   contN = 3;
    %   vecCon = continuityChecker(vec, contN);
    %   % vecCon = [0 0 0 0 1 1 1 0 0 0]
    
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
    % handleNaNs - Handles sequences of NaN values in a coordinate vector.
    %
    % Syntax:
    %   vOut = handleNaNs(vIn, f, minNanSeq, nFrames)
    %
    % Description:
    %   This function is called when a NaN value is encountered. It attempts to
    %   linearly interpolate over the NaN sequence using the preceding and
    %   subsequent non-NaN values. If a continuous sequence of NaNs is longer
    %   than `minNanSeq`, it marks the entire sequence with `-1`.
    %
    % Inputs:
    %   vIn       - A 1xN coordinate vector (X or Y).
    %   f         - The current frame index where the NaN was found.
    %   minNanSeq - The minimum sequence length to consider for replacement.
    %   nFrames   - The total number of frames.
    %
    % Output:
    %   vOut - The processed vector with NaNs handled.
    
    vOut = vIn;
    endIdx = min(f+minNanSeq-1, nFrames);
    seq = vOut(f:endIdx);
    nextValidRel = find(~isnan(seq),1,'first'); % relative index to f
    if isempty(nextValidRel)
        vOut(f:endIdx) = -1; % all remain NaN -> mark invalid
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
