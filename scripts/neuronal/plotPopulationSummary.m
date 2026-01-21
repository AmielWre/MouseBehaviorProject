% plotPopulationSummary.m
% -------------------------------------------------------------------------
% Create population-level summary plots (real vs control)
% based on per-mouse accuracy/AUC performance tables.
%
% INPUT FILES (expected):
%   results/.../ml_models/SVM/<mouse>/performance_<mouse>_SVM.xlsx
%   results/.../ml_models/SVM/control/<mouse>/performance_<mouse>_SVM.xlsx
%
% Author: Amiel Wreschner
% -------------------------------------------------------------------------

clear; clc; close all;

%% === USER INPUTS ===
baseDir = 'results\3chamber\boundary&sequence\ml_models\SVM';
metric = 'Accuracy';   % 'Accuracy' or 'AUC'
outputDir = fullfile(baseDir, 'summary_overall_average');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

MIN_TEST_EPOCHS = 5;   % skip small datasets

%% === Load per-mouse data ===
mouseDirs = dir(baseDir);
mouseDirs = mouseDirs([mouseDirs.isdir]);
mouseDirs = mouseDirs(~ismember({mouseDirs.name}, {'.','..','control','summary_overall_average'}));

dataReal = [];
dataControl = [];
mouseList = {};

for m = 1:numel(mouseDirs)
    mouseName = mouseDirs(m).name;
    if strcmp (mouseName, 'all_mice')
        continue
    end

    % --- real model
    realFile = fullfile(baseDir, mouseName, sprintf('performance_%s_SVM.xlsx', mouseName));
    ctrlFile = fullfile(baseDir, 'control', mouseName, sprintf('performance_%s_SVM.xlsx', mouseName));

    % Real
    if isfile(realFile)
        Treal = readtable(realFile);
        if ismember(metric, Treal.Properties.VariableNames)
            val = mean(Treal.(metric)(Treal.TestEpochs >= MIN_TEST_EPOCHS), 'omitnan');
            dataReal(end+1) = val;
        else
            dataReal(end+1) = NaN;
        end
    else
        dataReal(end+1) = NaN;
    end

    % Control
    if isfile(ctrlFile)
        Tctrl = readtable(ctrlFile);
        if ismember(metric, Tctrl.Properties.VariableNames)
            val = mean(Tctrl.(metric)(Tctrl.TestEpochs >= MIN_TEST_EPOCHS), 'omitnan');
            dataControl(end+1) = val;
        else
            dataControl(end+1) = NaN;
        end
    else
        dataControl(end+1) = NaN;
    end

    mouseList{end+1} = mouseName;
end

%% === Remove mice with no valid data ===
validIdx = ~isnan(dataReal) & ~isnan(dataControl);
dataReal = dataReal(validIdx);
dataControl = dataControl(validIdx);
mouseList = mouseList(validIdx);

fprintf('Loaded %d valid mice for comparison (%s)\n', numel(mouseList), metric);

%% === POPULATION BAR PLOT ===
meanReal = mean(dataReal, 'omitnan');
meanCtrl = mean(dataControl, 'omitnan');
semReal  = std(dataReal, 'omitnan') / sqrt(numel(dataReal));
semCtrl  = std(dataControl, 'omitnan') / sqrt(numel(dataControl));

fig1 = figure('Color','w');
barData = [meanReal, meanCtrl];
barErr  = [semReal, semCtrl];

b = bar(barData, 'FaceColor','flat');
b.CData = [0 0.45 0.74; 0.85 0.33 0.10];  % blue (real) / orange (control)
hold on;
errorbar(1:2, barData, barErr, 'k', 'linestyle', 'none', 'LineWidth', 1.2);
hold off;

set(gca,'XTickLabel',{'Real','Control'},'FontSize',12);
ylabel(sprintf('Mean %s', metric));
title(sprintf('Population Average %s Across Mice', metric));
ylim([0 1]);
grid on;

saveas(fig1, fullfile(outputDir, sprintf('population_bar_%s.png', metric)));
close(fig1);

%% === SCATTER COMPARISON (REAL vs CONTROL) ===
fig2 = figure('Color','w');
scatter(dataControl, dataReal, 100, 'filled', ...
    'MarkerFaceColor', [0.3 0.6 0.9], 'MarkerEdgeColor','k', 'MarkerFaceAlpha', 0.7);
hold on;
plot([0 1],[0 1],'k--','LineWidth',1.2);

xlabel(sprintf('Control %s', metric));
ylabel(sprintf('Real %s', metric));
title(sprintf('Per-Mouse Comparison (%s)', metric));
axis equal;

% Zoomed-in region of interest
xlim([0.4 0.7]);
ylim([0.4 0.7]);
grid on;

% Annotate mouse names (slightly offset)
for i = 1:numel(mouseList)
    text(dataControl(i)+0.005, dataReal(i), mouseList{i}, ...
        'FontSize',8, 'HorizontalAlignment','left', ...
        'Interpreter','none');   % <---- this line fixes the subscript issue
end


exportgraphics(fig2, fullfile(outputDir, sprintf('scatter_real_vs_control_%s_zoom.png', metric)), ...
    'Resolution', 1200);

close(fig2);

fprintf('\n✅ Population summary plots saved to: %s\n', outputDir);
