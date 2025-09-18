function plot_track_and_boundary(exp)
    % PLOT_TRACK_AND_BOUNDARY  Plot mouse trajectory with cage positions and boundary expansion
    %
    %   plot_track_and_boundary(exp) visualizes the XY trajectory of a mouse
    %   across all trials, overlays the positions of the stranger and empty cages,
    %   and expands the stranger cage by boundary allowances from 1 to 5 cm. 
    %   The function saves a high-resolution figure in PNG and FIG formats.
    %
    % INPUT:
    %   exp  - An ExperimentBehave object containing:
    %          • exp.XY_behave : 2 x T x N array of XY coordinates 
    %                            (2 coordinates, T trials, N frames per trial).
    %          • exp.cagePos   : struct with cage positions and scale factor:
    %              - cage_stranger.Position : [x, y, width, height] of stranger cage (px).
    %              - cage_empty.Position    : [x, y, width, height] of empty cage (px).
    %              - px2cm                  : conversion factor (px per cm).
    %          • exp.group    : string label of experimental group.
    %          • exp.color    : string label for group color.
    %          • exp.date     : string date identifier.
    %
    % DESCRIPTION:
    %   • Extracts XY coordinates from all trials and flattens them into a 
    %     single trajectory scatter plot.
    %   • Plots the stranger cage (green) and empty cage (red) as rectangles.
    %   • Expands the stranger cage by 1–5 cm in all directions and overlays
    %     dashed boundary rectangles (different colors).
    %   • Adds a legend with trajectory, cages, and boundary levels.
    %   • Saves the figure in:
    %       - PNG format (600 dpi, high resolution).
    %       - FIG format (editable in MATLAB).
    %
    % FILE SAVING:
    %   Figures are saved into:
    %       results/3chamber/boundary&sequence/mouse track and cage
    %   Filenames are based on:
    %       [group]_[color]_[date].png / .fig
    %
    % EXAMPLE:
    %   plot_track_and_boundary(exp);
    %
    %   % Produces a figure with:
    %   %   - Mouse trajectory (black scatter)
    %   %   - Stranger cage (green rectangle)
    %   %   - Empty cage (red rectangle)
    %   %   - Boundaries expanded 1–5 cm around the stranger cage
    %   % Saves high-res outputs to the results folder.
    %

    % Parameters
    MIN_X_CORD = 30;
    MAX_X_CORD = 700;
    baseDir = fullfile("results", "3chamber", "boundary&sequence", "mouse track and cage");
    
    % Extract all XY points
    x_all = squeeze(exp.XY_behave(1,:,:));   % 3 x 1200
    y_all = squeeze(exp.XY_behave(2,:,:));   % 3 x 1200
    x_all = x_all(:);
    y_all = y_all(:);
    
    % Stranger and empty cage rectangle
    strangerCagePos = exp.cagePos.cage_stranger.Position;
    emptyCagePos = exp.cagePos.cage_empty.Position;
    
    % Conversion factor
    px2cm = exp.cagePos.px2cm;
    
    % Mouse id
    group = exp.group;
    color = exp.color;
    date = exp.date;
    id = sprintf("%s %s %s", group, color, date);
    
    % Plot trajectory
    fig = figure;
    hTraj = scatter(x_all, y_all, 5, 'k', 'filled'); 
    hold on;
    title(sprintf('%s trajectory with stranger cage and boundary', id));
    xlabel('X (px)');
    ylabel('Y (px)');
    axis equal;
    
    % Plot original stranger cage in red
    rectangle('Position', strangerCagePos, 'EdgeColor', 'g', 'LineWidth', 2);
    rectangle('Position', emptyCagePos, 'EdgeColor', 'r', 'LineWidth', 2);
    
    % Make axes square (so X and Y use the same scale)
    axis equal;   
    
    % Adjust limits so all objects (points + rectangles) fit nicely
    xlim([min(min(x_all), MIN_X_CORD) max(max(x_all), MAX_X_CORD)]);
    ylim([min(y_all) max(y_all)]);
    
    % Expanded boundaries (1–5 cm)
    colors = lines(5);
    for b = 1:5
        expand_px = b * px2cm;
        newRect = [ ...
            strangerCagePos(1) - expand_px, ...
            strangerCagePos(2) - expand_px, ...
            strangerCagePos(3) + 2*expand_px, ...
            strangerCagePos(4) + 2*expand_px];
        
        rectangle('Position', newRect, 'EdgeColor', colors(b,:), ...
                  'LineStyle', '--', 'LineWidth', 1.5);
    end
    
    % --- LEGEND FIX ---
    % Add invisible dummy plots to represent rectangles in the legend
    strangerCageDummy   = plot(nan, nan, 'g-', 'LineWidth', 2);
    emptyCageDummy   = plot(nan, nan, 'r-', 'LineWidth', 2);
    hBoundsDummy = gobjects(1,5);
    for b = 1:5
        hBoundsDummy(b) = plot(nan, nan, '--', 'Color', colors(b,:), 'LineWidth', 1.5);
    end
    
    legend([hTraj, strangerCageDummy, emptyCageDummy, hBoundsDummy], ...
           {'Trajectory','Stranger cage', 'Empty cage', '1 cm','2 cm','3 cm','4 cm','5 cm'}, ...
           'Location', 'eastoutside');
    
    % ---- Save tracking figure directly in high resolution ----
    outDir = fullfile("results", "3chamber", "boundary&sequence", "mouse track and cage");
    if ~exist(outDir, "dir")
        mkdir(outDir);
    end
    
    % Set a larger figure size for export (this one only)
    set(fig, 'Units', 'inches', 'Position', [1, 1, 12, 8]);
    
    % File base name
    fileBase = fullfile(outDir, id);
    
    % Save as high-res PNG
    try
        exportgraphics(fig, fileBase + ".png", 'Resolution', 600);
    catch
        print(fig, fileBase, '-dpng', '-r600');
    end
    
    % Also save as MATLAB .fig for editing later
    savefig(fig, fileBase + ".fig");
        
    hold off;
end
