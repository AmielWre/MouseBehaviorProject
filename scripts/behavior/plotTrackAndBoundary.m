function plotTrackAndBoundary(exp, seqTimes, boundaries)
% plotTrackAndBoundary - Generate trajectory and ROI visualizations for one experiment.
%
% DESCRIPTION:
%   Creates three trajectory-based visualizations:
%     (1) Base trajectory (no cages or boundaries)
%     (2) Trajectory with stranger/empty cages and 1–5 cm boundaries
%     (3) Epoch overlays per (integer boundary, integer sequence)
%
% INPUTS:
%   exp        - ExperimentBehave object containing:
%                  • XY_behave (2 × T × F): XY coordinates
%                  • cagePos struct with:
%                       - cage_stranger.Position [x,y,w,h]
%                       - cage_empty.Position    [x,y,w,h]
%                       - px2cm : pixels-per-cm conversion factor
%                  • group, color, date: identifying strings
%   seqTimes   - Vector of tested sequence durations (s)
%   boundaries - Vector of tested boundary distances (cm)
%
% OUTPUTS:
%   Saves PNG figures in:
%     results/3chamber/boundary&sequence/mouse track and cage/
%         ├── <group>_<color>_<date>_base.png
%         ├── <group>_<color>_<date>_boundaries.png
%         └── <group>_<color>_<date>_epochs/
%                 ├── b<boundary>_seq<seq>.png
%
% -------------------------------------------------------------------------

%% === Setup ===
outDir = fullfile("results", "3chamber", "boundary&sequence", "mouse track and cage");
if ~exist(outDir, "dir"), mkdir(outDir); end

group = exp.group;
color = exp.color;
date  = exp.date;
id = sprintf("%s_%s_%s", group, color, date);

x_all = squeeze(exp.XY_behave(1,:,:)); 
y_all = squeeze(exp.XY_behave(2,:,:));
x_all = x_all(:);
y_all = y_all(:);

strangerCage = exp.cagePos.cage_stranger.Position;
emptyCage    = exp.cagePos.cage_empty.Position;
px2cm        = exp.cagePos.px2cm;

fprintf('\n=== Generating trajectory plots for %s ===\n', id);

%% === 1. Base trajectory plot ===
fig = figure('Visible','off');
scatter(x_all, y_all, 1.5, 'k', 'filled'); % smaller dots
axis equal tight;
xlabel('X (px)', 'FontSize',8);
ylabel('Y (px)', 'FontSize',8);
title(sprintf('%s | Base Trajectory', id), 'Interpreter','none', 'FontSize',9);
set(gca, 'FontSize',8);
exportgraphics(fig, fullfile(outDir, sprintf('%s_base.png', id)), 'Resolution',600);
close(fig);

%% === 2. Cages + Boundaries plot ===
fig = figure('Visible','off'); hold on;
hTraj = scatter(x_all, y_all, 1.5, [0.1 0.1 0.1], 'filled');

% Plot cages
rectangle('Position', strangerCage, 'EdgeColor', [0 0.8 0], 'LineWidth', 1.2);
rectangle('Position', emptyCage,    'EdgeColor', [1 0 0], 'LineWidth', 1.2);

% Generate 1–5 cm boundaries
for cm = 1:5
    factor = 0.12 * (cm - 1);
    greenShade = [0, min(0.6 + factor, 1), 0];
    redShade   = [min(0.9 + factor, 1), factor, factor];
    expand_px = cm * px2cm;

    rectS = [strangerCage(1)-expand_px, strangerCage(2)-expand_px, ...
             strangerCage(3)+2*expand_px, strangerCage(4)+2*expand_px];
    rectangle('Position', rectS, 'EdgeColor', greenShade, 'LineStyle','--', 'LineWidth',0.7);

    rectE = [emptyCage(1)-expand_px, emptyCage(2)-expand_px, ...
             emptyCage(3)+2*expand_px, emptyCage(4)+2*expand_px];
    rectangle('Position', rectE, 'EdgeColor', redShade, 'LineStyle','--', 'LineWidth',0.7);
end

axis equal tight;
xlabel('X (px)', 'FontSize',8);
ylabel('Y (px)', 'FontSize',8);
title(sprintf('%s | Cages and Boundaries', id), ...
    'Interpreter','none','FontSize',9,'FontWeight','bold');
set(gca, 'FontSize',8);

% Create legend with note included
hStranger = plot(nan,nan,'-','Color',[0 0.8 0],'LineWidth',1.2);
hEmpty = plot(nan,nan,'-','Color',[1 0 0],'LineWidth',1.2);
hNote = plot(nan,nan,'w','LineStyle','none');  % invisible placeholder

legend([hTraj hStranger hEmpty hNote], ...
    {'Trajectory','Stranger cage','Empty cage','Dashed lines = 1 cm'}, ...
    'Location','northeastoutside', 'FontSize',7, 'Box','off');

exportgraphics(fig, fullfile(outDir, sprintf('%s_boundaries.png', id)), 'Resolution',600);
close(fig);

%% === 3. Epoch overlay plots ===
epochDir = fullfile(outDir, sprintf('%s_epochs', id));
if ~exist(epochDir, "dir"), mkdir(epochDir); end

dataBase = fullfile("data", "processed", "bool_matrices");

% Keep only integer seqTimes and boundaries
seqTimes = seqTimes(mod(seqTimes,1)==0);
boundaries = boundaries(mod(boundaries,1)==0);

for bIdx = 1:numel(boundaries)
    b = boundaries(bIdx);
    bDir = sprintf("b%.1f", b);

    for sIdx = 1:numel(seqTimes)
        seq = seqTimes(sIdx);
        seqDir = sprintf("seq%.1f", seq);

        basePath = fullfile(dataBase, seqDir, bDir);
        fStranger = fullfile(basePath, sprintf("bool_%s_%s_%s_stranger.mat", group, color, date));
        fEmpty    = fullfile(basePath, sprintf("bool_%s_%s_%s_empty.mat", group, color, date));

        if ~isfile(fStranger) || ~isfile(fEmpty)
            continue;
        end

        % Load boolean vectors
        dS = load(fStranger); fnS = fieldnames(dS); boolS = dS.(fnS{1});
        dE = load(fEmpty); fnE = fieldnames(dE); boolE = dE.(fnE{1});
        boolS = boolS(:) > 0;
        boolE = boolE(:) > 0;

        if numel(boolS) ~= numel(x_all) || numel(boolE) ~= numel(x_all)
            continue;
        end

        % --- Plot epochs ---
        fig = figure('Visible','off'); hold on;
        scatter(x_all, y_all, 1, [0.85 0.85 0.85], 'filled'); % background
        scatter(x_all(boolS), y_all(boolS), 2, [0 0.8 0], 'filled', 'MarkerFaceAlpha', 0.8);
        scatter(x_all(boolE), y_all(boolE), 2, [1 0 0], 'filled', 'MarkerFaceAlpha', 0.8);

        % Draw cages and boundaries
        rectangle('Position', strangerCage, 'EdgeColor', [0 0.8 0], 'LineWidth', 1);
        rectangle('Position', emptyCage, 'EdgeColor', [1 0 0], 'LineWidth', 1);
        for cm = 1:5
            factor = 0.12 * (cm - 1);
            greenShade = [0, min(0.6 + factor, 1), 0];
            redShade   = [min(0.9 + factor, 1), factor, factor];
            expand_px = cm * px2cm;

            rectS = [strangerCage(1)-expand_px, strangerCage(2)-expand_px, ...
                     strangerCage(3)+2*expand_px, strangerCage(4)+2*expand_px];
            rectangle('Position', rectS, 'EdgeColor', greenShade, 'LineStyle','--', 'LineWidth',0.7);

            rectE = [emptyCage(1)-expand_px, emptyCage(2)-expand_px, ...
                     emptyCage(3)+2*expand_px, emptyCage(4)+2*expand_px];
            rectangle('Position', rectE, 'EdgeColor', redShade, 'LineStyle','--', 'LineWidth',0.7);
        end

        axis equal tight;
        xlabel('X (px)', 'FontSize',8);
        ylabel('Y (px)', 'FontSize',8);
        title(sprintf('%s | B%.1f | Seq%.1f | Epochs', id, b, seq), ...
            'Interpreter','none','FontSize',9);
        set(gca, 'FontSize',8);

        % Legend (compact)
        hAll = plot(nan,nan,'o','MarkerFaceColor',[0.8 0.8 0.8],'MarkerEdgeColor','none');
        hStr = plot(nan,nan,'o','MarkerFaceColor',[0 0.8 0],'MarkerEdgeColor','none');
        hEmp = plot(nan,nan,'o','MarkerFaceColor',[1 0 0],'MarkerEdgeColor','none');
        hNote = plot(nan,nan,'w','LineStyle','none');

        legend([hAll hStr hEmp hNote], ...
            {'All frames','Stranger epochs','Empty epochs','Dashed lines = 1 cm'}, ...
            'Location','northeastoutside','FontSize',7,'Box','off');

        outFile = fullfile(epochDir, sprintf('b%.1f_seq%.1f.png', b, seq));
        exportgraphics(fig, outFile, 'Resolution', 600);
        close(fig);
    end
end

fprintf('✔ Finished generating trajectory plots for %s\n', id);
end
