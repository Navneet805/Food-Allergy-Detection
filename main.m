% =========================================================
% MAIN.m — Food Allergy Risk Classification
% =========================================================

clc; clear; close all;

fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║   Personalized Food Allergy Risk Classification     ║\n');
fprintf('║   Clustering + CNN + ADMM Optimization | 22MAT230  ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

% ─────────────────────────────────────────────────────────
%  CONFIG — Edit these paths before running
% ─────────────────────────────────────────────────────────
global CONFIG;

% Path to the Zenodo CSV file
CONFIG.DATASET_CSV   = 'C:\Amrita Notes\MATLAB\SEM4\Project\food-allergy-analysis-Zenodo.csv';

% Path to output_dataset folder (created by coco_to_folders.py)
% Subfolders = class names, each containing food images.
% If folder is missing/empty, synthetic demo data is auto-generated.
CONFIG.IMAGE_DATASET = 'C:\Amrita Notes\MATLAB\SEM4\Project\output_dataset';

% Folder where all .mat result files will be saved
CONFIG.OUTPUT_DIR    = 'C:\Amrita Notes\MATLAB\SEM4\Project\results';

% Spoonacular API key (optional)
CONFIG.SPOONACULAR_KEY = '956b0bf940234ffabcbdd46a4d89a4de';

% Number of risk clusters
CONFIG.K = 4;

% ─────────────────────────────────────────────────────────
% Create results folder if it doesn't exist
if ~exist(CONFIG.OUTPUT_DIR, 'dir')
    mkdir(CONFIG.OUTPUT_DIR);
end

% Add project folder to path so all modules are found
addpath(fileparts(mfilename('fullpath')));

% ── MODULE 1: Load + preprocess Zenodo dataset ────────────
fprintf('[1/5] Loading and preprocessing allergy dataset...\n');
module1_load_data();
fprintf('      Done.\n\n');

% ── MODULE 2: Clustering ──────────────────────────────────
fprintf('[2/5] Running K-Means + Spectral Clustering...\n');
module2_clustering();
fprintf('      Done.\n\n');

% ── MODULE 3: Cross-reactivity matrix ─────────────────────
fprintf('[3/5] Building cross-reactivity constraint matrix...\n');
module3_cross_reactivity();
fprintf('      Done.\n\n');

% ── MODULE 4: ADMM optimization demo ──────────────────────
fprintf('[4/5] Running ADMM optimization demo...\n');
module4_admm();
fprintf('      Done.\n\n');

% ── MODULE 5: CNN food image classifier ───────────────────
% First run: trains ~3-6 min (CPU) or ~45 sec (GPU).
% Every subsequent run: <2 sec (loads saved cnn_model.mat).
fprintf('[5/5] Training / loading food image CNN...\n');
module5_cnn();
fprintf('      Done.\n\n');

% ── Launch interactive checker ─────────────────────────────
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║  All modules complete. Launching allergy checker... ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');
pause(1);
run_checker();