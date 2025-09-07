% test_handleNaNs.m
% Script to test the handleNaNs function with synthetic data and edge cases
clc, clear, close all;

% Parameters
nFrames   = 50;
minNanSeq = 8;

% Base vector (linearly increasing, easy to see changes)
v = linspace(1, 100, nFrames);

% --- Test cases ---
tests = struct();

% 1. Single NaN in the middle
t1       = v;
t1(20)   = NaN;
tests(1).name = "Single NaN in middle";
tests(1).vec  = t1;

% 2. Short NaN run (< minNanSeq) → should interpolate
t2       = v;
t2(10:12)= NaN;
tests(2).name = "Short NaN run (3)";
tests(2).vec  = t2;

% 3. Long NaN run (>= minNanSeq) → should set to -1
t3       = v;
t3(30:40)= NaN;
tests(3).name = "Long NaN run (11)";
tests(3).vec  = t3;

% 4. NaNs at the very start
t4       = v;
t4(1:6)  = NaN;
tests(4).name = "NaNs at start";
tests(4).vec  = t4;

% 5. NaNs at the very end
t5       = v;
t5(45:50)= NaN;
tests(5).name = "NaNs at end";
tests(5).vec  = t5;

% 6. Multiple scattered NaN bursts
t6       = v;
t6([5 6 15 16 25 26 35:37 41:49]) = NaN;
tests(6).name = "Scattered NaN bursts";
tests(6).vec  = t6;

% --- Run tests ---
for k = 1:numel(tests)
    fprintf("\n=== %s ===\n", tests(k).name);
    vIn = tests(k).vec;
    vOut = vIn;
    for f = 1:nFrames
        if isnan(vOut(f))
            vOut = handleNaNs(vOut, f, minNanSeq, nFrames);
        end
    end
    % Show results (before vs after)
    disp([ (1:nFrames)' vIn' vOut' ]);
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

