% === Create brain map videos for each mouse and date/average folder ===
% Author: Amiel Wreschner
% --------------------------------------------
clc; clear;

baseDir = fullfile('results','3chamber','boundary&sequence', ...
                   'neuronal_analysis','per_mouse');
frameRate = 4;

mouseDirs = dir(baseDir);
mouseDirs = mouseDirs([mouseDirs.isdir] & ~startsWith({mouseDirs.name},'.'));

for m = 1:numel(mouseDirs)
    mouseName = mouseDirs(m).name;
    mousePath = fullfile(baseDir, mouseName);
    fprintf('\nProcessing mouse: %s\n', mouseName);

    % === Find all date or "average" folders ===
    subDirs = dir(mousePath);
    subDirs = subDirs([subDirs.isdir] & ~startsWith({subDirs.name},'.'));

    for s = 1:numel(subDirs)
        subName = subDirs(s).name;
        subPath = fullfile(mousePath, subName);
        brainMapPath = fullfile(subPath, 'brain_maps');

        if ~isfolder(brainMapPath)
            continue;
        end

        % === Collect all .png images ===
        files = dir(fullfile(brainMapPath, '*.png'));
        if isempty(files)
            fprintf('  No images found in %s\n', brainMapPath);
            continue;
        end

        imgPaths = sort(fullfile({files.folder}, {files.name}));

        % --- determine reference size from first frame
        I0 = imread(imgPaths{1});
        refSize = size(I0(:,:,1:3));

        % === Create output video name ===
        outputVideo = fullfile(subPath, sprintf('%s_%s_brainmaps_video.mp4', ...
                                                mouseName, subName));
        v = VideoWriter(outputVideo, 'MPEG-4');
        v.FrameRate = frameRate;
        open(v);

        for i = 1:numel(imgPaths)
            I = imread(imgPaths{i});
            if size(I,3)==1
                I = repmat(I,[1 1 3]);
            end
            if ~isequal(size(I,1),refSize(1)) || ~isequal(size(I,2),refSize(2))
                I = imresize(I,[refSize(1) refSize(2)]);
            end
            writeVideo(v, I);
        end
        close(v);

        fprintf('  → Video saved: %s\n', outputVideo);
    end
end

fprintf('\nAll videos created successfully!\n');
