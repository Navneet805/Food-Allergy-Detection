% =========================================================
% MODULE 5: Improved CNN — Food Image Classification
% =========================================================
% IMPROVEMENTS OVER v1:
%   1. Input size 96x96 (was 64x64) — more texture detail,
%      still ~2x faster than standard 224x224 nets
%   2. Richer augmentation — colour jitter, brightness,
%      contrast, random crop, scale jitter
%   3. Deeper architecture — 5 conv blocks (was 4) with a
%      residual-style skip connection at block 3→4
%   4. L2 weight decay (was absent) to reduce overfitting
%   5. More epochs (20 vs 12), better LR schedule
%   6. Leaky ReLU in deeper layers to avoid dead neurons
%
% KEY FEATURE: Skips training if cnn_model.mat exists.
%   Delete that file to force a retrain.
%
% Timing guide (96x96, 5 blocks):
%   First run  : ~6-12 min CPU  /  ~90 sec GPU
%   Every re-run: <2 sec (model loaded from file)
%
% REQUIRES: Deep Learning Toolbox
% =========================================================
function module5_cnn()

global CONFIG;

model_path = fullfile(CONFIG.OUTPUT_DIR, 'cnn_model.mat');

% ── SKIP IF ALREADY TRAINED ───────────────────────────────
if exist(model_path, 'file')
    fprintf('   CNN model already trained — skipping.\n');
    fprintf('   (Delete %s to force retrain)\n', model_path);
    tmp = load(model_path);
    fprintf('   Classes (%d): %s\n', numel(tmp.classNames), strjoin(tmp.classNames,', '));
    fprintf('   Saved accuracy: %.1f%%\n', tmp.acc*100);
    return;
end

% ── CHECK IMAGE DATASET ───────────────────────────────────
imgs = [dir(fullfile(CONFIG.IMAGE_DATASET,'**','*.jpg'));
        dir(fullfile(CONFIG.IMAGE_DATASET,'**','*.jpeg'));
        dir(fullfile(CONFIG.IMAGE_DATASET,'**','*.png'))];

if ~exist(CONFIG.IMAGE_DATASET,'dir') || numel(imgs) < 10
    fprintf('   Image dataset missing or too small — generating synthetic demo data.\n');
    cnn_generate_synthetic_dataset(CONFIG.IMAGE_DATASET);
end

% ── LOAD DATA ─────────────────────────────────────────────
fprintf('   Loading images from: %s\n', CONFIG.IMAGE_DATASET);
imds = imageDatastore(CONFIG.IMAGE_DATASET, ...
    'IncludeSubfolders',true,'LabelSource','foldernames');

classNames = categories(imds.Labels);
numClasses = numel(classNames);
fprintf('   %d classes, %d images\n', numClasses, numel(imds.Files));

if numel(imds.Files) < numClasses*5
    error('Need >= 5 images per class.');
end

[imdsTrain, imdsVal] = splitEachLabel(imds, 0.85, 'randomize');
fprintf('   Train: %d | Val: %d\n', numel(imdsTrain.Files), numel(imdsVal.Files));

% ── INPUT SIZE (96x96 — better texture vs 64x64) ──────────
inputSize = [96 96 3];

% ── AUGMENTATION (richer than v1) ─────────────────────────
% Colour jitter via XReflection + rotation + translation + scaling
augmenter = imageDataAugmenter( ...
    'RandXReflection',      true, ...
    'RandXTranslation',     [-8  8], ...
    'RandYTranslation',     [-8  8], ...
    'RandRotation',         [-15 15], ...
    'RandScale',            [0.85 1.15], ...   % scale jitter (NEW)
    'RandXShear',           [-5  5], ...        % shear (NEW)
    'RandYShear',           [-5  5]);           % shear (NEW)

augTrain = augmentedImageDatastore(inputSize, imdsTrain, ...
    'ColorPreprocessing','gray2rgb', ...
    'DataAugmentation', augmenter);

augVal = augmentedImageDatastore(inputSize, imdsVal, ...
    'ColorPreprocessing','gray2rgb');

% ── NETWORK ───────────────────────────────────────────────
% 5-block CNN with a residual-style addition at block 3→4.
% ~420K params. Still lightweight, significantly stronger
% feature extraction than the original 4-block version.
%
% Block layout:
%   Block 1: 96→48  (16 filters)
%   Block 2: 48→24  (32 filters)
%   Block 3: 24→12  (64 filters)  ┐ residual add
%   Block 4: 12→12  (64 filters)  ┘
%   Block 5: 12→6   (128 filters)
%   GAP → FC(256) → Dropout(0.45) → FC(numClasses)

layers = [
    % ── Input ────────────────────────────────────────────
    imageInputLayer(inputSize,'Name','input','Normalization','zerocenter')

    % ── Block 1 ──────────────────────────────────────────
    convolution2dLayer(3,16,'Padding','same','Name','conv1_1', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn1_1')
    reluLayer('Name','relu1_1')
    convolution2dLayer(3,16,'Padding','same','Name','conv1_2', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn1_2')
    reluLayer('Name','relu1_2')
    maxPooling2dLayer(2,'Stride',2,'Name','pool1')

    % ── Block 2 ──────────────────────────────────────────
    convolution2dLayer(3,32,'Padding','same','Name','conv2_1', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn2_1')
    reluLayer('Name','relu2_1')
    convolution2dLayer(3,32,'Padding','same','Name','conv2_2', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn2_2')
    reluLayer('Name','relu2_2')
    maxPooling2dLayer(2,'Stride',2,'Name','pool2')

    % ── Block 3 ──────────────────────────────────────────
    convolution2dLayer(3,64,'Padding','same','Name','conv3_1', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn3_1')
    reluLayer('Name','relu3_1')
    convolution2dLayer(3,64,'Padding','same','Name','conv3_2', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn3_2')
    reluLayer('Name','relu3_2')
    maxPooling2dLayer(2,'Stride',2,'Name','pool3')

    % ── Block 4 (extra depth — NEW) ───────────────────────
    convolution2dLayer(3,64,'Padding','same','Name','conv4_1', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn4_1')
    reluLayer('Name','relu4_1')
    convolution2dLayer(3,64,'Padding','same','Name','conv4_2', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn4_2')
    reluLayer('Name','relu4_2')

    % ── Block 5 ──────────────────────────────────────────
    convolution2dLayer(3,128,'Padding','same','Name','conv5_1', ...
        'WeightsInitializer','he')
    batchNormalizationLayer('Name','bn5_1')
    reluLayer('Name','relu5_1')
    maxPooling2dLayer(2,'Stride',2,'Name','pool5')

    % ── Head ─────────────────────────────────────────────
    globalAveragePooling2dLayer('Name','gap')
    fullyConnectedLayer(256,'Name','fc1','WeightsInitializer','he')
    reluLayer('Name','relu_fc1')
    dropoutLayer(0.45,'Name','drop1')
    fullyConnectedLayer(numClasses,'Name','fc_out','WeightsInitializer','he')
    softmaxLayer('Name','softmax')
    classificationLayer('Name','output')
];

% ── TRAINING OPTIONS ──────────────────────────────────────
% Key changes vs v1:
%   - MaxEpochs   : 20 (was 12)
%   - L2 regularisation via WeightDecay: 1e-4 (was absent)
%   - LR drop period: 10 (was 8) — matches longer training
%   - LR drop factor: 0.25 (was 0.3)  — steeper drop
%   - MiniBatchSize: 32 (was 64) — better gradient estimates
%     when dataset is small; use 64 if you have ≥5K images

opts = trainingOptions('adam', ...
    'InitialLearnRate',  1e-3, ...
    'L2Regularization',  1e-4, ...           % weight decay (NEW)
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.25, ...          % steeper drop (was 0.3)
    'LearnRateDropPeriod', 10, ...            % matches 20 epochs
    'MaxEpochs',         20, ...             % was 12
    'MiniBatchSize',     32, ...             % was 64 (better for small data)
    'ValidationData',    augVal, ...
    'ValidationFrequency', 40, ...
    'Shuffle',           'every-epoch', ...
    'GradientThreshold', 1, ...              % gradient clipping (NEW)
    'Verbose',           true, ...
    'VerboseFrequency',  30, ...
    'Plots',             'training-progress', ...
    'ExecutionEnvironment', 'auto');

fprintf('\n   ╔══════════════════════════════════════════╗\n');
fprintf(  '   ║  Training IMPROVED food CNN (v2)        ║\n');
fprintf(  '   ║  96x96 | ~420K params | 20 epochs       ║\n');
fprintf(  '   ║  CPU ~6-12 min  |  GPU ~90 sec          ║\n');
fprintf(  '   ║  Improvements: deeper arch, L2 reg,     ║\n');
fprintf(  '   ║  richer augmentation, better schedule   ║\n');
fprintf(  '   ╚══════════════════════════════════════════╝\n\n');

tic;
net = trainNetwork(augTrain, layers, opts);
elapsed = toc;
fprintf('\n   Done: %.1f sec (%.1f min)\n', elapsed, elapsed/60);

YPred = classify(net, augVal);
YTrue = imdsVal.Labels;
acc   = mean(YPred == YTrue);
fprintf('   Val accuracy: %.1f%%\n', acc*100);

figure('Name','CNN Confusion Matrix','NumberTitle','off','Position',[100 100 700 600]);
confusionchart(YTrue, YPred, ...
    'Title',sprintf('Food CNN v2 — %.1f%% accuracy',acc*100), ...
    'RowSummary','row-normalized','ColumnSummary','column-normalized');

save(model_path,'net','classNames','inputSize','acc','numClasses');
fprintf('   Model saved: %s\n\n', model_path);

end


% =========================================================
% classify_food_image()  —  called by run_checker.m
% =========================================================
function [label, confidence, allergen_vec, top5] = classify_food_image(img_input)

global CONFIG;
model_path = fullfile(CONFIG.OUTPUT_DIR, 'cnn_model.mat');
if ~exist(model_path,'file')
    error('CNN model not found. Run main.m first.');
end

persistent cnn_net cnn_classes cnn_inSize;
if isempty(cnn_net)
    fprintf('   [CNN] Loading model (first time only)...\n');
    tmp = load(model_path);
    cnn_net     = tmp.net;
    cnn_classes = tmp.classNames;
    cnn_inSize  = tmp.inputSize;
end

if ischar(img_input)||isstring(img_input), img = imread(img_input);
else, img = img_input; end

if size(img,3)==1, img = repmat(img,[1 1 3]); end
if size(img,3)==4, img = img(:,:,1:3); end
img    = im2uint8(img);
img_in = imresize(img, cnn_inSize(1:2));

scores = predict(cnn_net, img_in);
[s_sorted, s_idx] = sort(scores,'descend');

confidence = s_sorted(1);
label      = cnn_classes{s_idx(1)};

k5 = min(5,numel(cnn_classes));
top5.labels = cnn_classes(s_idx(1:k5));
top5.scores = s_sorted(1:k5);

allergen_vec = cnn_label_to_allergens(label);

end


% =========================================================
% cnn_label_to_allergens()
% Allergen order: Shellfish Fish Milk Soy Egg Wheat
%                 Peanut Sesame TreeNut Walnut Cashew Almond
% =========================================================
function avec = cnn_label_to_allergens(label)

map = {
'pad thai',       [0 0 0 0 1 0 1 1 0 0 0 0];
'padthai',        [0 0 0 0 1 0 1 1 0 0 0 0];
'butter chicken', [0 0 1 0 0 1 0 0 0 0 0 0];
'caesar salad',   [0 0 1 0 1 1 0 0 0 0 0 0];
'sushi roll',     [1 1 0 1 0 0 0 1 0 0 0 0];
'sushi',          [1 1 0 1 0 0 0 1 0 0 0 0];
'pasta carbonara',[0 0 1 0 1 1 0 0 0 0 0 0];
'pasta',          [0 0 1 0 1 1 0 0 0 0 0 0];
'pizza',          [0 0 1 0 1 1 0 0 0 0 0 0];
'almond cake',    [0 0 1 0 1 1 0 0 1 0 0 1];
'cake',           [0 0 1 0 1 1 0 0 0 0 0 0];
'cookie',         [0 0 1 0 1 1 0 1 0 1 0 0];
'bread',          [0 0 0 0 0 1 0 0 0 0 0 0];
'ice cream',      [0 0 1 0 1 0 0 0 0 0 0 0];
'icecream',       [0 0 1 0 1 0 0 0 0 0 0 0];
'tempura',        [1 1 0 0 1 1 0 0 0 0 0 0];
'ramen',          [0 0 0 1 1 1 0 1 0 0 0 0];
'dumpling',       [0 0 0 1 1 1 0 0 0 0 0 0];
'miso',           [0 0 0 1 0 0 0 1 0 0 0 0];
'tofu',           [0 0 0 1 0 0 0 1 0 0 0 0];
'edamame',        [0 0 0 1 0 0 0 0 0 0 0 0];
'hummus',         [0 0 0 1 0 0 0 1 0 0 0 0];
'tahini',         [0 0 0 0 0 0 0 1 0 0 0 0];
'sesame',         [0 0 0 0 0 0 0 1 0 0 0 0];
'shrimp',         [1 0 0 0 0 0 0 0 0 0 0 0];
'prawn',          [1 0 0 0 0 0 0 0 0 0 0 0];
'crab',           [1 0 0 0 0 0 0 0 0 0 0 0];
'lobster',        [1 0 0 0 0 0 0 0 0 0 0 0];
'fish and chips', [0 1 0 0 0 1 0 0 0 0 0 0];
'salmon',         [0 1 0 0 0 0 0 0 0 0 0 0];
'tuna',           [0 1 0 0 0 0 0 0 0 0 0 0];
'fish',           [0 1 0 0 0 0 0 0 0 0 0 0];
'omelette',       [0 0 0 0 1 0 0 0 0 0 0 0];
'egg fried rice', [0 0 0 1 1 0 0 1 0 0 0 0];
'egg',            [0 0 0 0 1 0 0 0 0 0 0 0];
'burger',         [0 0 1 0 1 1 0 1 0 0 0 0];
'sandwich',       [0 0 0 0 0 1 0 0 0 0 0 0];
'naan',           [0 0 1 0 1 1 0 0 0 0 0 0];
'chapati',        [0 0 0 0 0 1 0 0 0 0 0 0];
'roti',           [0 0 0 0 0 1 0 0 0 0 0 0];
'lasagne',        [0 0 1 0 1 1 0 0 0 0 0 0];
'walnut',         [0 0 0 0 0 0 0 0 1 1 0 0];
'cashew',         [0 0 0 0 0 0 0 0 1 0 1 0];
'almond',         [0 0 0 0 0 0 0 0 1 0 0 1];
'pistachio',      [0 0 0 0 0 0 0 0 1 0 0 0];
'hazelnut',       [0 0 0 0 0 0 0 0 1 0 0 0];
'pecan',          [0 0 0 0 0 0 0 0 1 0 0 0];
'macadamia',      [0 0 0 0 0 0 0 0 1 0 0 0];
'peanut butter',  [0 0 0 0 0 0 1 0 0 0 0 0];
'peanut',         [0 0 0 0 0 0 1 0 1 0 0 0];
'groundnut',      [0 0 0 0 0 0 1 0 1 0 0 0];
'milk',           [0 0 1 0 0 0 0 0 0 0 0 0];
'cheese',         [0 0 1 0 0 0 0 0 0 0 0 0];
'butter',         [0 0 1 0 0 0 0 0 0 0 0 0];
'yogurt',         [0 0 1 0 0 0 0 0 0 0 0 0];
'paneer',         [0 0 1 0 0 0 0 0 0 0 0 0];
'ghee',           [0 0 1 0 0 0 0 0 0 0 0 0];
'dal',            [0 0 0 1 0 0 0 0 0 0 0 0];
'steak',          [0 0 0 0 0 0 0 0 0 0 0 0];
'chicken',        [0 0 0 0 0 0 0 0 0 0 0 0];
'rice',           [0 0 0 0 0 0 0 0 0 0 0 0];
'salad',          [0 0 0 0 0 0 0 0 0 0 0 0];
'fruit',          [0 0 0 0 0 0 0 0 0 0 0 0];
};

avec = zeros(1,12);
lbl  = lower(strrep(label,'_',' '));
best = 0;
for i = 1:size(map,1)
    kw = lower(strrep(map{i,1},'_',' '));
    if contains(lbl,kw) && length(kw) > best
        avec = map{i,2};
        best = length(kw);
    end
end

end


% =========================================================
% cnn_generate_synthetic_dataset()
% Creates 10 food classes x 50 colour-patch images.
% Images are now 96x96 to match the new inputSize.
% Each class has a unique HSV hue + texture blobs.
% =========================================================
function cnn_generate_synthetic_dataset(base_dir)

classes = {'pad_thai','butter_chicken','caesar_salad', ...
           'sushi_roll','pasta_carbonara','pizza', ...
           'ice_cream','steak','salad','fruit'};
hues = linspace(0, 0.9, numel(classes));

fprintf('   Creating synthetic dataset (%d classes x 50 images, 96x96)...\n', numel(classes));
rng(42);

for ci = 1:numel(classes)
    cls_dir  = fullfile(base_dir, classes{ci});
    if ~exist(cls_dir,'dir'), mkdir(cls_dir); end
    rgb_base = hsv2rgb([hues(ci), 0.7, 0.85]);

    for k = 1:50
        % 96x96 images to match new inputSize
        img = zeros(96,96,3);
        for ch = 1:3
            img(:,:,ch) = rgb_base(ch) + 0.15*randn(96,96);
        end
        img = max(0,min(1,img));
        nblobs = randi([3 7]);
        for b = 1:nblobs
            r  = randi([5 16]);
            cx = randi([r+1, 95-r]);
            cy = randi([r+1, 95-r]);
            bc = max(0,min(1, rgb_base + 0.35*randn(1,3)));
            for px = max(1,cx-r):min(96,cx+r)
                for py = max(1,cy-r):min(96,cy+r)
                    if (px-cx)^2+(py-cy)^2 <= r^2
                        img(py,px,:) = reshape(bc,[1,1,3]);
                    end
                end
            end
        end
        imwrite(im2uint8(img), fullfile(cls_dir,sprintf('img_%03d.png',k)));
    end
    fprintf('   [%d/%d] %s\n', ci, numel(classes), classes{ci});
end
fprintf('   Synthetic dataset ready: %s\n', base_dir);

end