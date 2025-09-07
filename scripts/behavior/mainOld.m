% clc, clear;


% boundaryAllowance: How many cm of margin of error do I give the mouse? That
% is,boundaryAllowance = 0 I will only count the frames that were right next
% to the stranger. 
% In any case, we will always check the exact limits, and this value is
% for what we will keep as out.
boundaryAllowance = 4; % in cm. 

% seqTime: Represents the total time duration in seconds of a valid
% sequence within an area.
seqTimeInSec = 0.5;

% vecExp = exampFoo([1, 0, 1, 1, 1, 0, 0, 1, 1, 0], 2);

[strangerMat, emptyMat, strangerOutMat, emptyOutMat] = ...
    analysisOld(boundaryAllowance, seqTimeInSec);

XY_path = 'XY_behave.mat';
mouseBehave = load(XY_path).XY_behave;
XY_behave1 = squeeze(mouseBehave(:,1,:));
cagePos = load("chamber_rois_positions\8th_blue_20231121.mat");
strangeMat1 = squeeze(strangerMat(:, 1, :));
strangeOutMat1 = squeeze(strangerOutMat(:, 1, :));

figure;
scatter(XY_behave1(1,:), XY_behave1(2,:))
hold on;
rectangle('pos',cagePos.cage_stranger_out.Position,'edgecolor', 'r')
rectangle('pos',cagePos.cage_stranger.Position)


