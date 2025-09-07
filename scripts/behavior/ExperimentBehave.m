classdef ExperimentBehave
    % ExperimentBehave
    % This class represents behavioral experiment metadata and data.
    %
    % Properties:
    %   path         - String: path to the XY_behave .mat file
    %   XY_behave    - 2x3xN matrix: coordinates of the mouse
    %   stim_trials  - Vector: which trials had stimulation [1,2,3]
    %   type         - String: experiment type (e.g., '3chamber')
    %   group        - Integer: mouse group number
    %   color        - String: color of the mouse group (e.g., 'blue')
    %   date         - String: experiment date (e.g., '20231203' means 03.12.2023)
    %   details      - String: trial layout description (e.g., 'em_R_st_L')
    %   cagePos      - Struct: contains rectangles and experiment metadata
    %
    % Constructor:
    %   obj = ExperimentBehave(path, cagePos)        % from path
    %   obj = ExperimentBehave(...all fields...)     % directly from values

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
            % Constructor
            if nargin == 2
                % Constructor from path and cagePos
                % Notes on `path` input (for automatic parsing):
                %   The function expects `path` to be a string containing 
                %   the filename of the XY_behave .mat file.
                %   The filename must follow the format:
                %
                %       'XY_behave_<group>th_<color>_<yyyymmdd>_<details>_<expType>.mat'
                %
                %   Example:
                %       'XY_behave_8th_blue_20231203_st_R_em_L_3chamber.mat'
                %
                %   From this name, the constructor will extract:
                %       group     → '8th'
                %       color     → 'blue'
                %       date      → '20231203'
                %       details   → 'st_R_em_L'
                %       expType   → '3chamber'
                %
                %   The file must also contain variables named `XY_behave` and `stim_trials`.
                path = string(varargin{1});
                cagePos = varargin{2};
                

                tokensPath = split(path, '\');
                obj.path = tokensPath{end};
                obj.cagePos = cagePos;

                % Parse filename (remove prefix and suffix)
                tokens = split(obj.path, '_');
                if startsWith(tokens{1}, 'XY')
                    tokens = tokens(3:end); % Skip 'XY' and 'behave'
                end

                % obj.group = str2double(extract(tokens{1}, digitsPattern));
                obj.group = tokens{1};
                obj.color = tokens{2};
                % rawDate = tokens{3};
                obj.date = tokens{3};
                obj.details = strjoin(tokens(4:7), '');
                obj.expType = erase(tokens{8}, '.mat');

                % Load XY_behave and stim_trials
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
                error('Invalid number of arguments to constructor.');
            end
        end


        % -------- Getters --------
        function val = getPath(obj), val = obj.path; end
        function val = getXYBehave(obj), val = obj.XY_behave; end
        function val = getStimTrials(obj), val = obj.stim_trials; end
        function val = getExpType(obj), val = obj.expType; end
        function val = getGroup(obj), val = obj.group; end
        function val = getColor(obj), val = obj.color; end
        function val = getDate(obj), val = obj.date; end
        function val = getDetails(obj), val = obj.details; end
        function val = getCagePos(obj), val = obj.cagePos; end
    end
end

% ---- Local helper function ----
function formatted = convertDate(rawDate)
    % Converts '20231203' → '03.12.2023'
    y = rawDate(1:4);
    m = rawDate(5:6);
    d = rawDate(7:8);
    formatted = y + "." + m + "." + d;
end
