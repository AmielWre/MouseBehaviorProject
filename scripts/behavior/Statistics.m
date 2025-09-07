classdef Statistics
    % Statistics - Static class for general behavioral/statistical calculations
    %
    % Usage:
    %   p = Statistics.percentTrue(vec)
    %   stats = Statistics.countEpochs(vec)
    %   total = Statistics.totalDuration(vec)

    methods (Static)

        function p = percentTrue(vec)
            % percentTrue - Calculate percentage of true values in a binary vector
            %
            % Input:
            %   vec - a logical or binary vector
            % Output:
            %   p   - percentage of true values (between 0 and 100)
            %
            % Example:
            %   Statistics.percentTrue([0 1 1 0 1])  --> 60
            p = 100 * nnz(vec) / numel(vec);
        end

        function stats = epochsStats(vec)
            % countEpochs - gives statistics about the epoches
            %
            % Input:
            %   vec - a logical or binary vector (any shape, will be flattened)
            % Output:
            %   stats - struct with fields:
            %       .count       - number of episodes
            %       .starts      - start indices of each episode
            %       .ends        - end indices of each episode
            %       .durations   - durations of episodes
            %       .avgDuration - average duration of episodes (0 if none)
            %       .totalDuration - total duration in ROI
            %
            % Example:
            %   stats = Statistics.countEpochs([0 1 1 0 1 0 1])
            %   stats.count --> 3
            %   stats.starts --> [2 5 7]
            %   stats.ends --> [3 5 7]
            %   stats.durations --> [2 1 1]
            %   stats.avgDuration --> 1.33
            %   stats.totalDuration --> 4

            vec = logical(vec(:)');
            starts = [false, vec(2:end) & ~vec(1:end-1)];
            if vec(1), starts(1) = true; end

            ends = [vec(1:end-1) & ~vec(2:end), false];
            if vec(end), ends(end) = true; end

            startIdx = find(starts);
            endIdx = find(ends);
            durations = endIdx - startIdx + 1;

            stats.count = numel(startIdx);
            stats.starts = startIdx;
            stats.ends = endIdx;
            stats.durations = durations;
            stats.totalDuration = nnz(vec);

            if isempty(durations)
                stats.avgDuration = 0;
            else
                stats.avgDuration = mean(durations);
            end
        end

    end
end
