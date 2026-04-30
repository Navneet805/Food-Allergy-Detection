% Run this once to remove corrupted images
dataset_path = 'C:\Amrita Notes\MATLAB\SEM4\Project\output_dataset';

imds = imageDatastore(dataset_path, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

bad_files = {};
fprintf('Scanning %d images for corrupt files...\n', numel(imds.Files));

for i = 1:numel(imds.Files)
    try
        img = imread(imds.Files{i});
    catch
        bad_files{end+1} = imds.Files{i};
    end
end

fprintf('Found %d corrupt files. Deleting...\n', numel(bad_files));
for i = 1:numel(bad_files)
    fprintf('  Deleting: %s\n', bad_files{i});
    delete(bad_files{i});
end
fprintf('Done. Run main again.\n');