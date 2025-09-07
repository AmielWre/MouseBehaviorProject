

function [strangerMat, emptyMat, strangerOutMat, emptyOutMat] = ...
    analysisOld(boundaryAllowance, seqTimeInSec)
% Generates four matrices, each with exactly the same structure as
% XY_behave: 2*3*1200. For a matrix 'descriptionMat' (1,Z,K) there will be a
% boolean value describing whether in frame number K, in trail number Z,
% the mouse was within the boundaries of the description.
% in (2,Z,K) there will be a boolean value describing whether frame number 
% K, trail number Z is a part of time sequence of length 
% Inputs:
%   - boundaryAllowance: How many cm to expand the borders of the rectangle
%     (on each side) for out
%   - seqTimeInSec: Represents the total time duration in seconds of a valid
%     sequence within an area.
    XY_path = 'XY_behave.mat';
    mouseBehave = load(XY_path);
    XY_behave = mouseBehave.XY_behave;
    trails = mouseBehave.stim_trials;
    [strangerMat, emptyMat, strangerOutMat, emptyOutMat] =...
        checkPos(XY_behave, boundaryAllowance, trails);
    numFrames = size(XY_behave, 3);
    frameToSec = numFrames / 120; % in a trail there is numFrames frames and each trail is 2 minutes (120 secondes)
    seqNum = round(frameToSec * seqTimeInSec);
    matrices = {strangerMat, emptyMat, strangerOutMat, emptyOutMat};

    for i = 1:length(matrices)
        mat = matrices{i};
        for trail = trails
            mat(2, trail, :) = continuityChecker(mat(1, trail, :), seqNum);
        end
        % Store the updated matrix back
        matrices{i} = mat;
    end

    % Extract the updated matrices
    strangerMat = matrices{1};
    emptyMat = matrices{2};
    strangerOutMat = matrices{3};
    emptyOutMat = matrices{4};
end


function [strangerMat, emptyMat, strangerOutMat, emptyOutMat]...
                        = checkPos(XY_behave, boundaryAllowance, trails)
% See the documentation for the analysis function. checkPos generates the
% matrices and the first coordinate for the first position (1,Z,K).
% The second coordinate (2,Z,K) is left as the value in XY_behave
% (it has no meaning).
    strangerMat = XY_behave + 0;
    emptyMat = XY_behave + 0;
    strangerOutMat = XY_behave + 0;
    emptyOutMat = XY_behave + 0;
    filePath = "chamber_rois_positions\8th_blue_20231121.mat";
    cagePos = load(filePath);
    
    pxToExpand = boundaryAllowance * cagePos.px2cm;
    stranger_out_pos = posExpander(cagePos.cage_stranger.Position, pxToExpand);
    empty_out_pos = posExpander(cagePos.cage_empty.Position, pxToExpand);
    cagePos.cage_stranger_out.Position = stranger_out_pos;
    cagePos.cage_empty_out.Position = empty_out_pos;
    save(filePath, '-struct', 'cagePos');

    for trail = trails
        XY_1 = squeeze(XY_behave(:,trail,:)); % [X; Y]
        
        % Number of frames
        num_frames = size(XY_1,2);
        
        % Initialize logical vectors to store if the mouse is in each cage
        is_in_cage_stranger      = false(1, num_frames);
        is_in_cage_empty         = false(1, num_frames);
        is_in_cage_stranger_out  = false(1, num_frames);
        is_in_cage_empty_out     = false(1, num_frames);

        % For each frame, check if the location is in each ROI
        for frame = 1:num_frames
            x = XY_1(1, frame);
            y = XY_1(2, frame);
        
            % Check each ROI:
            is_in_cage_stranger(frame)     = inROI(cagePos.cage_stranger, x, y);
            is_in_cage_empty(frame)        = inROI(cagePos.cage_empty, x, y);
            is_in_cage_stranger_out(frame) = inROI(cagePos.cage_stranger_out, x, y);
            is_in_cage_empty_out(frame)    = inROI(cagePos.cage_empty_out, x, y);
        end
        strangerMat(1, trail, :) = is_in_cage_stranger;
        emptyMat(1, trail, :) = is_in_cage_empty;
        strangerOutMat(1, trail, :) = is_in_cage_stranger_out;
        emptyOutMat(1, trail, :) = is_in_cage_empty_out;
    end
end


function rectangle = createRect(videoPath, frameNumber)
% CREATE RECT - Extract a frame from a video and draw a rectangular ROI.
%   rectangle = createRect(videoPath, frameNumber)
%   Inputs:
%     videoPath   - Path to the video file.
%     frameNumber - Frame number to extract.
%   Output:
%     rectangle - Rectangle ROI object. The position is saved in 'roi_rectangle.mat'.
    v = VideoReader(videoPath);
    frame = read(v, frameNumber);
    imshow(frame);
    
    rectangle = drawrectangle('Color','r');
    roiPosition = rectangle.Position;
    
    save('roi_rectangle.mat','roiPosition');
end


function newPos = posExpander(oldPos, pxToExpand)
% posExpander - Expand the Rectangle Position
% Adjusts the size of a rectangle by expanding it symmetrically.
% Inputs:
%   - oldPos: Original position as [x, y, width, height].
%   - pxToExpand: Pixels to expand in each direction.
% Output:
%   - newPos: Adjusted position with the expanded boundaries.
    newPos = zeros(1, 4);
    newPos(1) = oldPos(1) - pxToExpand;
    newPos(2) = oldPos(2) - pxToExpand;
    newPos(3) = oldPos(3) + pxToExpand * 2;
    newPos(4) = oldPos(4) + pxToExpand * 2;
end


function vecCon = continuityChecker(vec, contNumber)
    % Checks continuity of a vector and returns a vector accordingly
    %   Inputs:
    %     vec - vector to check
    %     contNumber - The number of sequences of true needed
    %   Output:
    %     vecCon - vector with continuity
    % example: for vec = [1, 0, 1, 1, 1, 0, 0, 1, 1, 0], contNumber = 3 the
    % output will be     [0, 0, 1, 1, 1, 0, 0, 0, 0, 0]
    vecCon = false(1, length(vec));
    curCon = 0;  % Current continuity count
    startIdx = 1; % Start index of current sequence
    vecLength = length(vec);

    for i = 1:vecLength
        if vec(i)
            % Increment continuity counter
            if curCon == 0
                startIdx = i; % Mark the start of a new sequence
            end
            curCon = curCon + 1;
        else
            % Check and mark the sequence if it meets the required length
            if curCon >= contNumber
                vecCon(startIdx:i - 1) = true;
            end
            curCon = 0; % Reset counter
        end
    end

    % Handle the final sequence
    if curCon >= contNumber
        vecCon(startIdx:vecLength) = true;
    end
end  






