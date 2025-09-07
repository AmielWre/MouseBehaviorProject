classdef BehaviorPlotter
    % BehaviorPlotter - Static utilities for visualizing 3-chamber behavior.
    %
    % Usage
    %   BehaviorPlotter.plotAllTrails(exp)
    %
    % Input
    %   exp : ExperimentBehave object (must provide getters used below)
    %
    % Output
    %   Saves one PNG per trail in: results/figures/<expType>/<group>/

    methods (Static)
        function plotAllTrails(exp)
            % --- Pull data from the experiment object ---
            XY_all     = exp.getXYBehave();     % 2 x Z x K
            stimTrials = exp.getStimTrials();   % e.g., [1 2 3]
            nTrials    = numel(stimTrials);
            cp         = exp.getCagePos();      % struct with .cage_stranger, .cage_stranger_out

            % Ensure we have Position rectangles (works for ROI objects or structs)
            cagePos    = cp.cage_stranger.Position;
            cageOutPos = cp.cage_stranger_out.Position;

            % Parse layout from details string (e.g., 'stRemL' -> Stranger=R, Empty=L)
            % details need to be stRemL or stLemR
            [strSide, emSide] = BehaviorPlotter.i_parseLayout(exp.getDetails());

            % Prepare output folder
            expType  = string(exp.getExpType());
            groupStr = string(exp.getGroup());
            description = 'tracking';
            outDir   = fullfile('results','figures',expType,description,groupStr);
            if ~exist(outDir,'dir'), mkdir(outDir); end

            % --- Plot each trail ---
            for i = 1:nTrials
                tr = stimTrials(i);
                XY = squeeze(XY_all(:, tr, :));   % 2 x K

                % Figure with compact spacing
                f  = figure('Color','w');
                tl = tiledlayout(f,1,1,'Padding','compact','TileSpacing','compact');
                ax = nexttile(tl); hold(ax,'on');

                % Path and ROIs
                plot(ax, XY(1,:), XY(2,:), 'k.', 'MarkerSize', 6);
                rectangle(ax,'Position',cagePos,    'EdgeColor','r','LineWidth',2); % stranger
                rectangle(ax,'Position',cageOutPos, 'EdgeColor','g','LineWidth',2); % stranger_out
                xlabel(ax,'X Position (px)');
                ylabel(ax,'Y Position (px)');
                box(ax,'on'); axis(ax,'tight');

                % Add a little headroom so the title never touches the data
                yl = ylim(ax);
                ylim(ax, [yl(1), yl(2) + 0.08*diff(yl)]);

                % One clean headline (above axes, not inside plot)
                meta = sprintf( ...
                    'Group: %s  |  Color: %s  |  Date: %s  |  Exp: %s  |  Layout: Stranger-%s, Empty-%s  |  Trail: %d', ...
                    groupStr, string(exp.getColor()), string(exp.getDate()), expType, strSide, emSide, tr);
                sgtitle(tl, meta, 'Interpreter','none', 'FontSize',8, 'FontWeight','normal');

                % Save figure
                fname = sprintf('XY_behave_%s_%s_trail_%d.png', string(exp.getColor()), string(exp.getDate()), tr);
                exportgraphics(f, fullfile(outDir, fname), 'Resolution', 200);
                close(f);
            end
        end
    end

    % ======== helpers ========
    methods (Static, Access = private)
        function pos = i_getPosition(roiOrStruct)
            % Accepts images.roi.Rectangle or a struct with .Position
            if isobject(roiOrStruct) && isprop(roiOrStruct,'Position')
                pos = roiOrStruct.Position;
            elseif isstruct(roiOrStruct) && isfield(roiOrStruct,'Position')
                pos = roiOrStruct.Position;
            elseif isnumeric(roiOrStruct) && numel(roiOrStruct)==4
                % Already a [x y w h]
                pos = roiOrStruct(:).';
            else
                error('BehaviorPlotter:InvalidROI', ...
                    'ROI must be a rectangle object/struct with Position, or a 1x4 numeric [x y w h].');
            end
        end

        function [strSide, emSide] = i_parseLayout(det)
            % Parse something like 'stRemL' / 'emRstL' into sides (R/L).
            if contains(det, 'stR', 'IgnoreCase',true), strSide = 'R'; end
            if contains(det, 'stL', 'IgnoreCase',true), strSide = 'L'; end
            if contains(det, 'emR', 'IgnoreCase',true), emSide  = 'R'; end
            if contains(det, 'emL', 'IgnoreCase',true), emSide  = 'L'; end
        end
    end
end
