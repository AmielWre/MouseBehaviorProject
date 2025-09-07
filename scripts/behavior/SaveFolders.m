classdef SaveFolders
    %SAVEFOLDERS Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)

        function saveBoundaryPlot(obj, figHandle, sequence)
            % savePlot - Save boundary/sequence plots with standardized naming
            %
            % Inputs:
            %   figHandle    - Handle to the current figure
            %   sequence - String identifier of the sequence
            %   obj - ExperimentBehave object
            %
            % The plot is saved into:
            %   results/figures/3chamber/boundry&sequence/group
            % The filename includes the experiment date and sequenceName.
            
                % Extract metadata from experiment
                date = obj.getDate;  % assuming exp has a 'date' property
                group   = obj.getGroup; % assuming exp has a 'group' property
                color = obj.getColor;
            
                % Build folder path
                baseDir = fullfile('results','3chamber','boundary&sequence', group, color);
            
                % Ensure folder exists
                if ~exist(baseDir, 'dir')
                    mkdir(baseDir);
                end
            
                % Build filename: YYYYMMDD_sequenceName.png
                fname = sprintf('%s_%.1fsecond_sequence.png', date, sequence);
            
                % Full path
                fpath = fullfile(baseDir, fname);
            
                % Save figure
                saveas(figHandle, fpath);
            
                fprintf('Figure saved: %s\n', fpath);
        end

        function savePsHeatMap(obj, figHandle)
            % Extract metadata from experiment
            date = obj.getDate;  % assuming exp has a 'date' property
            group = obj.getGroup; % assuming exp has a 'group' property
            color = obj.getColor;

            baseDir = fullfile('results','3chamber','boundary&sequence', group, color);

             % Ensure folder exists
            if ~exist(baseDir, 'dir')
                mkdir(baseDir);
            end

            fname = sprintf('%s_preference_score.png', date);

            % Full path
            fpath = fullfile(baseDir, fname);

            % Save figure
            saveas(figHandle, fpath);
        
            fprintf('Figure saved: %s\n', fpath);
        end

        function saveBollMats(stMat, emMat, exp, seqTimeInSec, boundaryAllowance)
            % saveBollMats - Save boolean matrices (stranger_out, empty_out)
            %
            % Inputs:
            %   stMat             - Boolean matrix for stranger ROI (trials x frames)
            %   emMat             - Boolean matrix for empty ROI (trials x frames)
            %   exp               - ExperimentBehave object
            %   seqTimeInSec      - Sequence requirement (numeric scalar)
            %   boundaryAllowance - Boundary allowance (numeric scalar)
            %
            % Files will be saved under:
            %   data/processed/bool_matrices/seq<seq>/b<boundary>/
            %   with filenames:
            %     <group>_<color>_<date>_stranger.mat
            %     <group>_<color>_<date>_empty.mat
    
            % Extract metadata from experiment
            group = exp.getGroup();
            color = exp.getColor();
            date  = exp.getDate();
    
            % Build folder path
            seqFolder = sprintf("seq%.1f", seqTimeInSec);
            bFolder   = sprintf("b%.1f", boundaryAllowance);
            baseDir   = fullfile("data","processed","bool_matrices",seqFolder,bFolder);
    
            % Ensure folder exists
            if ~exist(baseDir,"dir")
                mkdir(baseDir);
            end
    
            % Stranger file
            fnameSt = sprintf("bool_%s_%s_%s_stranger.mat", group, color, date);
            fpathSt = fullfile(baseDir, fnameSt);
            stranger = stMat; %#ok<NASGU> keep clean var name in .mat
            save(fpathSt, "stranger");
    
            % Empty file
            fnameEm = sprintf("bool_%s_%s_%s_empty.mat", group, color, date);
            fpathEm = fullfile(baseDir, fnameEm);
            empty = emMat; %#ok<NASGU>
            save(fpathEm, "empty");
    
            % fprintf("Saved: %s\n", fpathSt);
            % fprintf("Saved: %s\n", fpathEm);
        end

        function saveMatResults(stStatistics, emStatistics, ps, exp, seq, boundary)
            % Extract identifiers
            group  = exp.group;
            color  = exp.color;
            date   = exp.date;
    
            % Ensure folder exists: one folder per mouse+date
            outDir = fullfile("results", "3chamber", "boundary&sequence", "matfiles", ...
                              sprintf("%s_%s_%s", group, color, date));
            if ~exist(outDir, "dir")
                mkdir(outDir);
            end
    
            % File name for this seq × boundary
            fileName = fullfile(outDir, ...
                       sprintf("seq%.1f_b%.1f.mat", seq, boundary));
    
            % Save variables
            save(fileName, "stStatistics", "emStatistics", "ps");
        end

        function saveCsvResults(stStatistics, emStatistics, ps, exp, seq, boundary)
            % Extract identifiers
            group  = exp.group;
            color  = exp.color;
            date   = exp.date;
    
            % Aggregate stats across all trials
            numEmptyEpochs     = sum([emStatistics.count]);
            numStrangerEpochs  = sum([stStatistics.count]);
            totalDurationEmpty = sum([emStatistics.totalDuration]);
            totalDurationStranger = sum([stStatistics.totalDuration]);
    
            % Build row
            row = {date, seq, boundary, ps, ...
                   numEmptyEpochs, numStrangerEpochs, ...
                   totalDurationEmpty, totalDurationStranger};
    
            % Ensure folder exists
            outDir = fullfile("results", "3chamber", "boundary&sequence", "csv_data");
            if ~exist(outDir, "dir")
                mkdir(outDir);
            end
    
            % File per mouse
            fileName = fullfile(outDir, sprintf("%s_%s.csv", group, color));
    
            % If file doesn't exist, write header first
            if ~isfile(fileName)
                header = {'date','seq','boundary','ps', ...
                          'numEmptyEpochs','numStrangerEpochs', ...
                          'totalDurationEmpty','totalDurationStranger'};
                writecell([header; row], fileName);
            else
                writecell(row, fileName, 'WriteMode','append');
            end
        end

        function saveMouseSummary(fig, group, color, filename)
            % Save figure in results\3chamber\boundary&sequence\<group>\<color>
            folderPath = fullfile("results", "3chamber", "boundary&sequence", group, color);
            if ~exist(folderPath, 'dir')
                mkdir(folderPath);
            end
            saveas(fig, fullfile(folderPath, filename + ".png"));
            savefig(fig, fullfile(folderPath, filename + ".fig"));
        end

        function saveSummaryPs(fig, filename)
            % Save figure in results\3chamber\boundary&sequence\summary_ps
            folderPath = fullfile("results", "3chamber", "boundary&sequence", "summary_ps", "all_days");
            if ~exist(folderPath, 'dir')
                mkdir(folderPath);
            end
            saveas(fig, fullfile(folderPath, filename + ".png"));
            savefig(fig, fullfile(folderPath, filename + ".fig"));
        end

        function saveSummaryPsAverage(fig, group, color)
            % Save in summary_ps/per_mouse/average with name group_color
            outDir = fullfile('results', '3chamber', 'boundary&sequence', ...
                              'summary_ps', 'per_mouse', 'average');
            if ~exist(outDir, 'dir')
                mkdir(outDir);
            end
            fileName = sprintf('%s_%s.png', group, color);
            saveas(fig, fullfile(outDir, fileName));
        end


        




    end

end
