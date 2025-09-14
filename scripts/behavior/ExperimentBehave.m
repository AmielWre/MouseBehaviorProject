classdef ExperimentBehave
    % ExperimentBehave - Represents and processes behavioral experiment data.
    %
    % Description:
    %   This class is designed to encapsulate all the metadata and raw data
    %   for a single behavioral experiment. It handles the parsing of
    %   experiment details (like group, date, and color) directly from the
    %   filename and provides a convenient structure for storing and
    %   accessing the core data matrices.
    %
    % Properties:
    %   path         - String: Full path to the XY_behave .mat file.
    %   XY_behave    - 2x3xN matrix: Mouse coordinates (x, y) over time.
    %   stim_trials  - Vector: Trial numbers with stimulation applied.
    %   expType      - String: Experiment type (e.g., '3chamber').
    %   group        - String: Mouse group number (e.g., '10th').
    %   color        - String: Mouse group color (e.g., 'blue').
    %   date         - String: Experiment date in 'yyyymmdd' format.
    %   details      - String: Trial layout description (e.g., 'em_R_st_L').
    %   cagePos      - Struct: Contains rectangles and other experiment metadata.
    %
    % Constructor:
    %   There are two valid constructors for this class:
    %   1. obj = ExperimentBehave(path, cagePos)        % From path
    %   2. obj = ExperimentBehave(...all fields...)     % Directly from values
    %
    % See also:
    %   main_analysis
    properties
        path string
        XY_behave double
        stim_trials double
        expType string
        group string
        color string
        date string
        details string
        cagePos struct
    end
    methods
        function obj = ExperimentBehave(varargin)
            % ExperimentBehave - Creates an ExperimentBehave object.
            %
            % Syntax:
            %   obj = ExperimentBehave(path, cagePos)
            %   obj = ExperimentBehave(path, XY_behave, stim_trials, expType, group, color, date, details, cagePos)
            %
            % Description:
            %   The constructor supports two distinct calling syntaxes to
            %   create an instance of the class. The first syntax automatically
            %   parses experiment metadata from a filename, while the second
            %   allows direct initialization from pre-existing values.
            %
            % Inputs:
            %   path        - string: Full path to the .mat file. Expected
            %                   filename format: 'XY_behave_<group>th_<color>_<yyyymmdd>_...<expType>.mat'
            %   cagePos     - struct: Cage position data.
            %
            %   -OR-
            %   
            %   path        - string: Path to the experiment file.
            %   XY_behave   - double: 2x3xN matrix of XY coordinates.
            %   stim_trials - double: Vector of trial numbers with stimulation.
            %   expType     - string: Experiment type.
            %   group       - string: Mouse group.
            %   color       - string: Mouse color.
            %   date        - string: Experiment date.
            %   details     - string: Trial details.
            %   cagePos     - struct: Cage position data.
            %
            % Output:
            %   obj - An instance of the ExperimentBehave class.
            %
            % Example (Syntax 1):
            %   cageData = load('chamber_rois_positions/10th_yellow_20240321.mat');
            %   exp = ExperimentBehave('XY_behave_10th_yellow_20240321_em_R_st_L_3chamber.mat', cageData);
            %   From this name, the constructor will extract:
                %       group     '10th'
                %       color     'yellow'
                %       date      '20240321'
                %       details   'em_R_st_L'
                %       expType   '3chamber'
            %
            % Example (Syntax 2):
            %   % Assumes data variables are already in the workspace
            %   exp = ExperimentBehave('myFile.mat', XY_behave, stim_trials, '3chamber', '12th', 'green', '20240401', 'em_L_st_R', cageData);
            
            if nargin == 2
                % Constructor from path and cagePos
                path = string(varargin{1});
                cagePos = varargin{2};
                
                % Split path to get just the filename
                tokensPath = split(path, '\');
                obj.path = tokensPath{end};
                obj.cagePos = cagePos;

                % Parse filename (remove prefix and suffix)
                tokens = split(obj.path, '_');
                if startsWith(tokens{1}, 'XY')
                    % Skip 'XY' and 'behave' parts of the filename
                    tokens = tokens(3:end);
                end
                
                obj.group = tokens{1};
                obj.color = tokens{2};
                obj.date = tokens{3};
                % Join the details section, which may contain underscores
                obj.details = strjoin(tokens(4:7), '');
                % Remove the .mat extension from the last token
                obj.expType = erase(tokens{8}, '.mat');
                
                % Load XY_behave and stim_trials from the file specified by obj.path
                data = load(obj.path);
                obj.XY_behave = data.XY_behave;
                obj.stim_trials = data.stim_trials;
            elseif nargin == 9
                % Constructor from full fields
                obj.path = varargin{1};
                obj.XY_behave = varargin{2};
                obj.stim_trials = varargin{3};
                obj.expType = varargin{4};
                obj.group = varargin{5};
                obj.color = varargin{6};
                obj.date = varargin{7};
                obj.details = varargin{8};
                obj.cagePos = varargin{9};
            else
                % Throw an error for an invalid number of arguments
                error('Invalid number of arguments to constructor.');
            end
        end

        % -------- Getters --------
        
        function val = getPath(obj)
            val = obj.path;
        end
        
        function val = getXYBehave(obj)
            val = obj.XY_behave;
        end
        
        function val = getStimTrials(obj)
            val = obj.stim_trials;
        end
        
        function val = getExpType(obj)
            val = obj.expType;
        end
        
        function val = getGroup(obj)
            val = obj.group;
        end
        
        function val = getColor(obj)
            val = obj.color;
        end
        
        function val = getDate(obj)
            val = obj.date;
        end
        
        function val = getDetails(obj)
            val = obj.details;
        end
        
        function val = getCagePos(obj)
            val = obj.cagePos;
        end
    end
end
% ---- Local helper function ----
function formatted = convertDate(rawDate)
    % convertDate - Converts a date string from 'yyyymmdd' to 'dd.mm.yyyy'.
    %
    % Syntax:
    %   formatted = convertDate(rawDate)
    %
    % Inputs:
    %   rawDate - string: The raw date string in 'yyyymmdd' format.
    %
    % Output:
    %   formatted - string: The formatted date string in 'dd.mm.yyyy' format.
    %
    % Example:
    %   formattedDate = convertDate('20231203');
    y = rawDate(1:4);
    m = rawDate(5:6);
    d = rawDate(7:8);
    formatted = y + "." + m + "." + d;
end
