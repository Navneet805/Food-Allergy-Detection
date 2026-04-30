% =========================================================
% MODULE 1: Load + Preprocess Real Zenodo Allergy Dataset
% =========================================================
function module1_load_data()

global CONFIG;

fprintf('   Reading CSV: %s\n', CONFIG.DATASET_CSV);

opts = detectImportOptions(CONFIG.DATASET_CSV);
opts = setvartype(opts, 'char');
T    = readtable(CONFIG.DATASET_CSV, opts);

fprintf('   Raw dataset: %d rows x %d columns\n', height(T), width(T));

N = height(T);

allergen_cols = {'SHELLFISH_ALG_START','FISH_ALG_START','MILK_ALG_START',...
                 'SOY_ALG_START','EGG_ALG_START','WHEAT_ALG_START',...
                 'PEANUT_ALG_START','SESAME_ALG_START','TREENUT_ALG_START',...
                 'WALNUT_ALG_START','CASHEW_ALG_START','ALMOND_ALG_START'};

allergen_names = {'Shellfish','Fish','Milk','Soy','Egg','Wheat',...
                  'Peanut','Sesame','TreeNut','Walnut','Cashew','Almond'};

nA = numel(allergen_cols);

% Convert allergen columns: non-NA = 1 (allergic), NA = 0
A = zeros(N, nA);
for i = 1:nA
    col    = T.(allergen_cols{i});
    A(:,i) = double(~strcmp(col,'NA') & ~strcmp(col,''));
end

% Comorbidities
eczema   = double(~strcmp(T.ATOPIC_DERM_START,      'NA'));
rhinitis = double(~strcmp(T.ALLERGIC_RHINITIS_START, 'NA'));
asthma   = double(~strcmp(T.ASTHMA_START,            'NA'));
atopic   = double(strcmp(T.ATOPIC_MARCH_COHORT,      'TRUE'));

% Demographics
gender  = double(contains(T.GENDER_FACTOR, 'Female'));
age_str = T.AGE_START_YEARS;
age     = zeros(N,1);
for i = 1:N
    val = str2double(age_str{i});
    if ~isnan(val), age(i) = val; end
end

num_allergens = sum(A,2);

% Build feature matrix column by column (avoids concatenation errors)
nExtra = 7;
X_raw  = zeros(N, nA + nExtra);
for i = 1:nA
    X_raw(:,i) = A(:,i);
end
X_raw(:,nA+1) = eczema;
X_raw(:,nA+2) = rhinitis;
X_raw(:,nA+3) = asthma;
X_raw(:,nA+4) = atopic;
X_raw(:,nA+5) = gender;
X_raw(:,nA+6) = age;
X_raw(:,nA+7) = num_allergens;

% Build feature names safely
feature_names = cell(1, nA+nExtra);
for i = 1:nA
    feature_names{i} = allergen_names{i};
end
feature_names{nA+1} = 'Eczema';
feature_names{nA+2} = 'Rhinitis';
feature_names{nA+3} = 'Asthma';
feature_names{nA+4} = 'AtopicMarch';
feature_names{nA+5} = 'Gender';
feature_names{nA+6} = 'Age';
feature_names{nA+7} = 'NumAllergens';

fprintf('   Feature matrix: %d patients x %d features\n', N, size(X_raw,2));

% Keep only patients with at least 1 allergy
has_allergy = num_allergens > 0;
X_filtered  = X_raw(has_allergy,:);
fprintf('   Patients with >= 1 allergy: %d\n', sum(has_allergy));

% Normalize to [0,1]
X = zeros(size(X_filtered));
for f = 1:size(X_filtered,2)
    col = X_filtered(:,f);
    mn  = min(col); mx = max(col);
    if mx > mn
        X(:,f) = (col-mn)/(mx-mn);
    else
        X(:,f) = col;
    end
end

% Subsample for speed
rng(42);
max_patients = min(10000, size(X,1));
idx_sample   = randperm(size(X,1), max_patients);
X_sample     = X(idx_sample,:);
X_raw_sample = X_filtered(idx_sample,:);

fprintf('   Using %d patients for clustering\n', max_patients);

% Risk labels
peanut_idx  = 7;
n_alg       = sum(X_raw_sample(:,1:nA), 2);
peanut_flag = X_raw_sample(:,peanut_idx);
comorbidity = X_raw_sample(:,nA+1) | X_raw_sample(:,nA+2) | X_raw_sample(:,nA+3);

risk_labels = ones(max_patients,1);
risk_labels(n_alg==2 | n_alg==3)          = 2;
risk_labels(n_alg>=4)                      = 3;
risk_labels(peanut_flag==1 & comorbidity)  = 4;

% ── Plots ────────────────────────────────────────────────
allergen_counts = sum(X_raw_sample(:,1:nA) > 0);
risk_names      = {'Low','Moderate','High','Anaphylactic'};
rc              = histcounts(risk_labels, 1:5);

figure('Name','Dataset Overview','NumberTitle','off','Position',[100 100 1100 400]);

subplot(1,3,1);
bar(allergen_counts,'FaceColor',[0.2 0.5 0.8]);
set(gca,'XTick',1:nA,'XTickLabel',allergen_names,'XTickLabelRotation',45);
ylabel('Patients'); title('Patients per Allergen'); grid on;

subplot(1,3,2);
pie(rc, risk_names);
title('Risk Level Distribution');
colormap(gca,[0.2 0.75 0.3; 0.2 0.5 0.9; 0.95 0.45 0.1; 0.85 0.1 0.1]);

subplot(1,3,3);
bar([sum(X_raw_sample(:,nA+1)), sum(X_raw_sample(:,nA+2)), sum(X_raw_sample(:,nA+3))],...
    'FaceColor',[0.6 0.2 0.8]);
set(gca,'XTickLabel',{'Eczema','Rhinitis','Asthma'});
ylabel('Count'); title('Comorbidity Distribution'); grid on;

sgtitle('Dataset Overview — Zenodo Food Allergy Dataset');

fprintf('\n   --- Allergen Prevalence ---\n');
for i = 1:nA
    fprintf('   %-12s : %5d\n', allergen_names{i}, allergen_counts(i));
end
fprintf('\n   --- Risk Distribution ---\n');
for r = 1:4
    fprintf('   %-14s : %5d\n', risk_names{r}, rc(r));
end

save(fullfile(CONFIG.OUTPUT_DIR,'preprocessed_data.mat'),...
    'X_sample','X_raw_sample','risk_labels',...
    'allergen_names','feature_names','nA','max_patients');

fprintf('\n   Preprocessed data saved.\n');
end