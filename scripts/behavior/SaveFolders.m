classdef SaveFolders
    %SAVEFOLDERS Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)

        
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



        function saveFile(data, figHandle, baseDir, fileName, formats, printFlag)
            % saveFile - Flexible file saver
            %
            % Inputs:
            %   data      - struct of variables to save (only used if 'mat' in formats)
            %   figHandle - handle to figure (only used if 'png' or 'fig' in formats)
            %   baseDir   - directory where files will be saved
            %   fileName  - file name without extension
            %   formats   - cell array of formats to save, e.g. {'png','fig','mat'}
            %   printFlag - if true - print path to what saved
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
