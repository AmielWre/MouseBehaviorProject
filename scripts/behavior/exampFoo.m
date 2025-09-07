clc, clear, close all;

path = "data\processed\10th\XY_behave_10th_red_20240512_st_R_em_L_3chamber.mat";


% CODE FOR CHANGING SOME COORDS TO NaN. NEED TO SAVE AT THE END
% XY_behave_for_test = load(path);
% cords = XY_behave_for_test.XY_behave;
% cords_trail1 = squeeze(cords(:,1,:));
% cords_trail1(1, 1:5) = NaN;
% cords_trail1(1, 20:28) = NaN;
% cords_trail1(1, 50:200) = NaN;
% cords(:, 1, :) = cords_trail1;
% XY_behave_for_test.XY_behave = cords;

roiPath = "chamber_rois_positions\10th_red_20240512";
roisPos = load(roiPath);

exp = ExperimentBehave(path, roisPos);
analysis = BehaviorAnalysis(exp, 0, 0);
analysis.run();