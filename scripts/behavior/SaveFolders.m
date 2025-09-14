classdef SaveFolders
    % SAVEFOLDERS - A static class for saving various types of data and figures.
    %
    % Description:
    %   This class provides a set of static methods to handle the saving of
    %   experiment data, plots, and CSV results. It ensures that the target
    %   directories exist and handles different file formats.
    
    methods (Static)
        
        function saveCsvResults(stStatistics, emStatistics, ps, exp, seq, boundary)
            % saveCsvResults - Appends a single row of analysis results to a CSV file.
            %
            % Syntax:
            %   saveCsvResults(stStatistics, emStatistics, ps, exp, seq, boundary)
            %
            % Description:
            %   This method aggregates statistics for a single experiment and appends
            %   them as a new row to a CSV file. If the file does not exist, it
            %   creates it and adds a header row.
            %
            % Inputs:
            %   stStatistics   - Struct array of stranger trial statistics.
            %   emStatistics   - Struct array of empty trial statistics.
            %   ps             - The preference score for the trial.
            %   exp            - An `ExperimentBehave` object.
            %   seq            - The sequence time in seconds.
            %   boundary       - The boundary allowance in cm.
            
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
        
        function saveFile(data, figHandle, baseDir, fileName, formats, printFlag)
            % saveFile - A flexible utility for saving various file types.
            %
            % Syntax:
            %   saveFile(data, figHandle, baseDir, fileName, formats, printFlag)
            %
            % Description:
            %   This method saves data or a figure to a specified directory
            %   in one or more formats. It supports PNG, FIG, MAT, and CSV.
            %   The function checks if the directory exists and creates it
            %   if necessary.
            %
            % Inputs:
            %   data      - Data to save (struct, cell, or table). Required for 'mat' and 'csv'.
            %   figHandle - Handle to the figure to save. Required for 'png' and 'fig'.
            %   baseDir   - The base directory path.
            %   fileName  - The name of the file (without extension).
            %   formats   - A cell array of file extensions to save (e.g., {'png','mat'}).
            %   printFlag - A logical flag to print the save path to the console.
            % Examples:
            %   saveFile([], gcf, "results", "test_plot", {'png','fig'});
            %   saveFile(myStruct, [], "results", "trial_data", {'mat'});
            
            if ~exist(baseDir, 'dir')
                mkdir(baseDir);
            end
            
            for i = 1:numel(formats)
                fmt = lower(formats{i});
                fpath = fullfile(baseDir, fileName + "." + fmt);
                
                switch fmt
                    case 'png'
                        if isempty(figHandle), error('Figure handle required for PNG'); end
                        saveas(figHandle, fpath);
                        
                    case 'fig'
                        if isempty(figHandle), error('Figure handle required for FIG'); end
                        savefig(figHandle, fpath);
                        
                    case 'mat'
                        if isempty(data)
                            error('Data required for MAT');
                        end
                        
                        varName = matlab.lang.makeValidName(fileName); % safe variable name
                        
                        if isstruct(data)
                            fields = fieldnames(data);
                            if numel(fields) == 1
                                % Single-field struct: rename to fileName
                                tmp.(varName) = data.(fields{1});
                                save(fpath, '-struct', 'tmp');
                            else
                                % Multi-field struct: save all fields
                                save(fpath, '-struct', 'data');
                            end
                        else
                            % Plain matrix/vector/array
                            tmp.(varName) = data;
                            save(fpath, '-struct', 'tmp');
                        end
                        
                    case 'csv'
                        if isempty(data), error('Data cell/struct required for CSV'); end
                        if iscell(data)
                            writecell(data, fpath);
                        elseif istable(data)
                            writetable(data, fpath);
                        else
                            error('CSV requires cell or table input');
                        end
                        
                    otherwise
                        warning('Unknown format: %s (skipped)', fmt);
                end
                if printFlag
                    fprintf('Saved: %s\n', fpath);
                end
            end
        end
    end
end
