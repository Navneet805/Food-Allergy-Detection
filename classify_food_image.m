function [label, confidence, allergen_vec, top5] = classify_food_image(img_path)
% =========================================================
% classify_food_image.m
% Loads trained CNN and predicts food class from image
% =========================================================

global CONFIG;

model_path = fullfile(CONFIG.OUTPUT_DIR, 'cnn_model.mat');

if ~exist(model_path, 'file')
    error('CNN model not found. Run main.m first.');
end

% Load trained network
data = load(model_path);
net = data.net;
classNames = data.classNames;

% Read image
img = imread(img_path);

% Resize to match training input
inputSize = net.Layers(1).InputSize;
img = imresize(img, inputSize(1:2));

% Ensure RGB (3 channels)
if size(img,3) == 1
    img = cat(3, img, img, img);
end

% Predict
scores = predict(net, img);

% Sort predictions
[s_sorted, idx] = sort(scores, 'descend');

% Top-1
label = classNames{idx(1)};
confidence = s_sorted(1);

% Top-5
k = min(5, numel(classNames));
top5.labels = classNames(idx(1:k));
top5.scores = s_sorted(1:k);

% =========================================================
% FOOD → ALLERGEN MAPPING (same format as your system)
% [Shell Fish Milk Soy Egg Wheat Peanut Sesame TreeNut Walnut Cashew Almond]
% =========================================================
food_map = containers.Map;

food_map('pad thai')       = [0 0 0 0 1 0 1 1 0 0 0 0];
food_map('pizza')          = [0 0 1 0 1 1 0 0 0 0 0 0];
food_map('burger')         = [0 0 1 0 1 1 0 1 0 0 0 0];
food_map('almond cake')    = [0 0 1 0 1 1 0 0 1 0 0 1];
food_map('cake')           = [0 0 1 0 1 1 0 0 0 0 0 0];
food_map('sushi')          = [1 1 0 1 0 0 0 1 0 0 0 0];
food_map('pasta')          = [0 0 1 0 1 1 0 0 0 0 0 0];

% Default: no allergens
allergen_vec = zeros(1,12);

% Map prediction → allergens
if isKey(food_map, lower(label))
    allergen_vec = food_map(lower(label));
end

end