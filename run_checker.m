% =========================================================
% run_checker.m — Interactive Food Allergy Risk Checker
% WITH SMART CORRECTION MEMORY
% =========================================================

function run_checker()

% ── Config ────────────────────────────────────────────────
RESULTS_DIR     = 'C:\Amrita Notes\MATLAB\SEM4\Project\results';
feedback_file   = fullfile(RESULTS_DIR, 'user_feedback.mat');

% Load Smart Correction Memory
if exist(feedback_file, 'file')
    data = load(feedback_file);
    feedback = data.feedback;           % cnn_label → corrected_label
    path_feedback = data.path_feedback; % img_path → corrected_label
else
    feedback = containers.Map;
    path_feedback = containers.Map;
end

SPOONACULAR_KEY = '956b0bf940234ffabcbdd46a4d89a4de';

% ── Check results exist ───────────────────────────────────
if ~exist(fullfile(RESULTS_DIR,'cross_reactivity.mat'),'file')
    error('Results not found at %s\nRun main.m first.', RESULTS_DIR);
end

tmp            = load(fullfile(RESULTS_DIR,'cross_reactivity.mat'));
C              = tmp.C;
allergen_names = tmp.allergen_names;
nA             = tmp.nA;

% =========================================================
% DISH DATABASE
% =========================================================
dish_map = {
    'butter chicken', [0 0 1 0 0 0 0 0 0 0 0 0];
    'paneer butter masala', [0 0 1 0 0 0 0 0 0 0 0 0];
    'palak paneer', [0 0 1 0 0 0 0 0 0 0 0 0];
    'shahi paneer', [0 0 1 0 0 0 0 0 0 0 0 0];
    'dal makhani', [0 0 1 0 0 0 0 0 0 0 0 0];
    'korma', [0 0 1 0 0 0 1 0 1 0 0 1];
    'biryani', [0 0 0 0 0 1 0 0 0 0 0 0];
    'veg biryani', [0 0 0 0 0 1 0 0 0 0 0 0];
    'chicken biryani', [0 0 0 0 0 1 0 0 0 0 0 0];
    'dosa', [0 0 0 0 0 1 0 0 0 0 0 0];
    'masala dosa', [0 0 0 0 0 1 0 0 0 0 0 0];
    'idli', [0 0 0 0 0 1 0 0 0 0 0 0];
    'vada', [0 0 0 0 0 1 0 0 0 0 0 0];
    'sambar', [0 0 0 0 0 0 0 0 0 0 0 0];
    'chapati', [0 0 0 0 0 1 0 0 0 0 0 0];
    'roti', [0 0 0 0 0 1 0 0 0 0 0 0];
    'naan', [0 0 1 0 1 1 0 0 0 0 0 0];
    'paratha', [0 0 1 0 0 1 0 0 0 0 0 0];
    'fried rice', [0 0 0 1 1 1 0 0 0 0 0 0];
    'noodles', [0 0 0 1 0 1 0 0 0 0 0 0];
    'hakka noodles', [0 0 0 1 0 1 0 0 0 0 0 0];
    'ramen', [0 0 0 1 1 1 0 0 0 0 0 0];
    'dumplings', [0 0 0 1 1 1 0 0 0 0 0 0];
    'spring rolls', [0 0 0 1 0 1 0 0 0 0 0 0];
    'manchurian', [0 0 0 1 0 1 0 0 0 0 0 0];
    'pad thai', [0 0 0 0 1 0 1 1 0 0 0 0];
    'sushi', [1 1 0 1 0 0 0 1 0 0 0 0];
    'pizza', [0 0 1 0 1 1 0 0 0 0 0 0];
    'burger', [0 0 1 0 1 1 0 1 0 0 0 0];
    'sandwich', [0 0 1 0 1 1 0 0 0 0 0 0];
    'pasta', [0 0 1 0 1 1 0 0 0 0 0 0];
    'lasagna', [0 0 1 0 1 1 0 0 0 0 0 0];
    'mac and cheese', [0 0 1 0 0 1 0 0 0 0 0 0];
    'spaghetti', [0 0 1 0 1 1 0 0 0 0 0 0];
    'cake', [0 0 1 0 1 1 0 0 0 0 0 0];
    'chocolate cake', [0 0 1 0 1 1 0 0 0 0 0 0];
    'almond cake', [0 0 1 0 1 1 0 0 1 0 0 1];
    'ice cream', [0 0 1 0 0 0 0 0 0 0 0 0];
    'brownie', [0 0 1 0 1 1 0 0 0 0 0 0];
    'cookies', [0 0 1 0 1 1 0 0 0 0 0 0];
    'laddu', [0 0 1 0 0 1 1 0 0 0 0 0];
    'gulab jamun', [0 0 1 0 0 1 0 0 0 0 0 0];
    'kheer', [0 0 1 0 0 0 0 0 0 0 0 0];
    'samosa', [0 0 0 0 0 1 0 0 0 0 0 0];
    'pakora', [0 0 0 0 0 1 0 0 0 0 0 0];
    'chips', [0 0 0 0 0 0 0 0 0 0 0 0];
    'popcorn', [0 0 0 0 0 0 0 0 0 0 0 0];
};

% =========================================================
% KEYWORD MAP
% =========================================================
keyword_map = {
    'shellfish',  [1 0 0 0 0 0 0 0 0 0 0 0];
    'shrimp',     [1 0 0 0 0 0 0 0 0 0 0 0];
    'prawn',      [1 0 0 0 0 0 0 0 0 0 0 0];
    'crab',       [1 0 0 0 0 0 0 0 0 0 0 0];
    'lobster',    [1 0 0 0 0 0 0 0 0 0 0 0];
    'squid',      [1 0 0 0 0 0 0 0 0 0 0 0];
    'fish',       [0 1 0 0 0 0 0 0 0 0 0 0];
    'salmon',     [0 1 0 0 0 0 0 0 0 0 0 0];
    'tuna',       [0 1 0 0 0 0 0 0 0 0 0 0];
    'anchovy',    [0 1 0 0 0 0 0 0 0 0 0 0];
    'sardine',    [0 1 0 0 0 0 0 0 0 0 0 0];
    'cod',        [0 1 0 0 0 0 0 0 0 0 0 0];
    'milk',       [0 0 1 0 0 0 0 0 0 0 0 0];
    'cheese',     [0 0 1 0 0 0 0 0 0 0 0 0];
    'butter',     [0 0 1 0 0 0 0 0 0 0 0 0];
    'cream',      [0 0 1 0 0 0 0 0 0 0 0 0];
    'yogurt',     [0 0 1 0 0 0 0 0 0 0 0 0];
    'dairy',      [0 0 1 0 0 0 0 0 0 0 0 0];
    'paneer',     [0 0 1 0 0 0 0 0 0 0 0 0];
    'ghee',       [0 0 1 0 0 0 0 0 0 0 0 0];
    'whey',       [0 0 1 0 0 0 0 0 0 0 0 0];
    'soy',        [0 0 0 1 0 0 0 0 0 0 0 0];
    'tofu',       [0 0 0 1 0 0 0 0 0 0 0 0];
    'edamame',    [0 0 0 1 0 0 0 0 0 0 0 0];
    'miso',       [0 0 0 1 0 0 0 0 0 0 0 0];
    'tempeh',     [0 0 0 1 0 0 0 0 0 0 0 0];
    'egg',        [0 0 0 0 1 0 0 0 0 0 0 0];
    'mayo',       [0 0 0 0 1 0 0 0 0 0 0 0];
    'mayonnaise', [0 0 0 0 1 0 0 0 0 0 0 0];
    'omelette',   [0 0 0 0 1 0 0 0 0 0 0 0];
    'wheat',      [0 0 0 0 0 1 0 0 0 0 0 0];
    'bread',      [0 0 0 0 0 1 0 0 0 0 0 0];
    'flour',      [0 0 0 0 0 1 0 0 0 0 0 0];
    'pasta',      [0 0 0 0 0 1 0 0 0 0 0 0];
    'noodle',     [0 0 0 0 0 1 0 0 0 0 0 0];
    'gluten',     [0 0 0 0 0 1 0 0 0 0 0 0];
    'roti',       [0 0 0 0 0 1 0 0 0 0 0 0];
    'chapati',    [0 0 0 0 0 1 0 0 0 0 0 0];
    'barley',     [0 0 0 0 0 1 0 0 0 0 0 0];
    'peanut',     [0 0 0 0 0 0 1 0 1 0 0 0];
    'groundnut',  [0 0 0 0 0 0 1 0 1 0 0 0];
    'sesame',     [0 0 0 0 0 0 0 1 0 0 0 0];
    'tahini',     [0 0 0 0 0 0 0 1 0 0 0 0];
    'treenut',    [0 0 0 0 0 0 0 0 1 0 0 0];
    'pistachio',  [0 0 0 0 0 0 0 0 1 0 0 0];
    'pecan',      [0 0 0 0 0 0 0 0 1 0 0 0];
    'hazelnut',   [0 0 0 0 0 0 0 0 1 0 0 0];
    'macadamia',  [0 0 0 0 0 0 0 0 1 0 0 0];
    'walnut',     [0 0 0 0 0 0 0 0 1 1 0 0];
    'cashew',     [0 0 0 0 0 0 0 0 1 0 1 0];
    'almond',     [0 0 0 0 0 0 0 0 1 0 0 1];
};

thresholds     = [0.25, 0.55, 0.85];
verdict_labels = {'SAFE','MILD RISK','HIGH RISK','AVOID'};

% ── Check if CNN is available ─────────────────────────────
cnn_available = exist(fullfile(RESULTS_DIR,'cnn_model.mat'),'file') == 2;
if cnn_available
    fprintf('   [CNN] Model found — image classification enabled.\n');
    fprintf('   [Memory] Smart correction system active.\n\n');
else
    fprintf('   [CNN] Model not found. Run main.m to enable image input.\n\n');
end

% ── Main loop ─────────────────────────────────────────────
while true
    clc;
    fprintf('╔══════════════════════════════════════════════════════╗\n');
    fprintf('║        FOOD ALLERGY RISK CHECKER  (with Memory)     ║\n');
    fprintf('║        Clustering + CNN + ADMM | 22MAT230           ║\n');
    fprintf('╚══════════════════════════════════════════════════════╝\n\n');

    % STEP 1 — USER ALLERGENS
    fprintf('STEP 1 — Select your allergens\n');
    fprintf('══════════════════════════════════════════════════════\n');
    for i = 1:nA
        fprintf('  [%2d] %-12s', i, allergen_names{i});
        if mod(i,3)==0, fprintf('\n'); end
    end
    fprintf('\n\nEnter allergen numbers separated by commas.\n');
    fprintf('Example:  7,9  (Peanut + TreeNut)\n\n');

    alg_indices = [];
    while true
        raw = strtrim(input('Your allergen numbers: ','s'));
        if isempty(raw), fprintf('  Enter at least one number.\n'); continue; end
        parts = strsplit(raw,',');
        valid = true; alg_indices = [];
        for i = 1:numel(parts)
            num = str2double(strtrim(parts{i}));
            if isnan(num)||num<1||num>nA||floor(num)~=num
                fprintf('  Invalid: "%s". Use numbers 1-%d.\n', strtrim(parts{i}), nA);
                valid = false; break;
            end
            alg_indices(end+1) = round(num);
        end
        if valid && ~isempty(alg_indices), break; end
    end

    patient_allergens = zeros(1,nA);
    patient_allergens(alg_indices) = 1;

    fprintf('\nYour allergy profile:\n');
    for i = alg_indices
        fprintf('  [x] %s\n', allergen_names{i});
    end

    fprintf('\nCross-reactive allergens to also watch for:\n');
    found_cross = false;
    for i = 1:nA
        if patient_allergens(i)
            for j = 1:nA
                if j~=i && C(i,j)>=0.35 && ~patient_allergens(j)
                    fprintf('  [!] %-10s -> may react to %-10s (strength %.2f)\n',...
                        allergen_names{i}, allergen_names{j}, C(i,j));
                    found_cross = true;
                end
            end
        end
    end
    if ~found_cross, fprintf('  None for your profile.\n'); end

    % STEP 2 — FOOD INPUT WITH SMART MEMORY
    fprintf('\n══════════════════════════════════════════════════════\n');
    fprintf('STEP 2 — Choose food input method\n');
    fprintf('══════════════════════════════════════════════════════\n');
    fprintf('  [1] Type the food name\n');
    if cnn_available
        fprintf('  [2] Upload a food image (CNN + Smart Memory)\n');
    else
        fprintf('  [2] Upload image (unavailable — run main.m first)\n');
    end
    fprintf('\n');

    food_choice = strtrim(input('Choose (1 or 2): ','s'));
    food_name   = '';
    cnn_used    = false;
    cnn_label   = '';
    cnn_conf    = 0;
    cnn_top5    = [];
    food_allergen_vec = zeros(1,nA);
    assumed_mask = zeros(1,nA);   % Important: declare this

    % IMAGE INPUT + SMART MEMORY
    if strcmp(food_choice,'2') && cnn_available
        fprintf('\nEnter full path to your food image.\n');
        img_path = strtrim(input('Image path: ','s'));
        img_path = strrep(img_path,'"','');

        if ~exist(img_path,'file')
            fprintf('\n  Image not found. Switching to text entry.\n');
            food_choice = '1';
        else
            try
                img = imread(img_path);
                figure('Name','Uploaded Food Image','NumberTitle','off','Position',[300 200 480 440]);
                imshow(img);
                title('Your uploaded food image','FontSize',12,'FontWeight','bold');
                drawnow;
            catch
                fprintf('  (Could not display image)\n');
            end

            correction_applied = false;
            if isKey(path_feedback, img_path)
                food_name = path_feedback(img_path);
                fprintf('\n✅ Using learned correction from past!\n');
                correction_applied = true;
            end

            if ~correction_applied
                fprintf('\n══════════════════════════════════════════════════════\n');
                fprintf('CNN is classifying your image...\n');
                fprintf('══════════════════════════════════════════════════════\n');

                try
                    global CONFIG;
                    old_out = CONFIG.OUTPUT_DIR;
                    CONFIG.OUTPUT_DIR = RESULTS_DIR;

                    [cnn_label, cnn_conf, cnn_alg_vec, cnn_top5] = classify_food_image(img_path);

                    CONFIG.OUTPUT_DIR = old_out;
                    cnn_used = true;
                    food_name = cnn_label;
                    food_allergen_vec = cnn_alg_vec;

                    fprintf('\n  CNN Predictions:\n');
                    fprintf('  %-24s  Confidence\n', 'Food class');
                    fprintf('  %s\n', repmat('-',1,36));
                    for k = 1:numel(cnn_top5.labels)
                        marker = '  ';
                        if k==1, marker = '>>'; end
                        fprintf('%s %-24s  %.1f%%\n', marker, cnn_top5.labels{k}, cnn_top5.scores(k)*100);
                    end

                    fprintf('\n  CNN classified this as: "%s"  (%.1f%% confident)\n', cnn_label, cnn_conf*100);

                    %if isKey(feedback, lower(cnn_label))
                        %food_name = feedback(lower(cnn_label));
                        %fprintf('✅ Auto-corrected using memory: "%s"\n', food_name);
                    %end

                catch ME
                    fprintf('  CNN error: %s\n', ME.message);
                    food_choice = '1';
                    cnn_used = false;
                end
            end

            fprintf('\n  Press ENTER to accept "%s", or type a different food name: ', food_name);
            override = strtrim(input('','s'));
            if ~isempty(override)
                food_name = override;
                if cnn_used && ~isempty(cnn_label)
                    feedback(lower(cnn_label)) = lower(food_name);
                end
                path_feedback(img_path) = lower(food_name);
                save(feedback_file, 'feedback', 'path_feedback');
                fprintf('  💾 Correction saved to memory!\n');
            end
        end
    end

    % Text fallback
    if strcmp(food_choice,'1') || isempty(food_name)
        fprintf('\nType the food name:\n');
        fprintf('Examples: pad thai, butter chicken, sushi, almond cake\n\n');
        food_name = strtrim(input('Food name: ','s'));
    end

    % STEP 3 — ALLERGEN IDENTIFICATION
    fprintf('\n══════════════════════════════════════════════════════\n');
    fprintf('STEP 3 — Identifying allergens in "%s"...\n', food_name);
    fprintf('══════════════════════════════════════════════════════\n');

    food_lower = lower(food_name);
    found_in_db = false;

    for k = 1:size(dish_map,1)
        if strcmp(food_lower, dish_map{k,1})
            food_allergen_vec = dish_map{k,2};
            assumed_mask = dish_map{k,2};
            found_in_db = true;
            fprintf('  Using dish database (assumed recipe).\n');
            break;
        end
    end

    if ~cnn_used && ~found_in_db
        fprintf('  Keyword matching on food name...\n');
        for k2 = 1:size(keyword_map,1)
            if contains(food_lower, keyword_map{k2,1})
                food_allergen_vec = food_allergen_vec | keyword_map{k2,2};
            end
        end
    else
        fprintf('  Allergens from CNN classification.\n');
    end

    food_alg_list = allergen_names(logical(food_allergen_vec));
    if isempty(food_alg_list)
        fprintf('\n  No common allergens detected.\n');
    else
        fprintf('\n  Allergens in food:\n');
        for i = 1:numel(food_alg_list)
            fprintf('    [+] %s\n', food_alg_list{i});
        end
    end

    if cnn_used
        fprintf('\n  CNN confidence: [');
        filled = round(cnn_conf * 30);
        fprintf('%s%s', repmat(char(9608),1,filled), repmat(char(9617),1,30-filled));
        fprintf('] %.1f%%\n', cnn_conf*100);
    end

    % STEP 4 — ADMM
    fprintf('\n══════════════════════════════════════════════════════\n');
    fprintf('STEP 4 — Running ADMM optimization...\n');
    fprintf('══════════════════════════════════════════════════════\n');

    p_alg = patient_allergens(:);
    fd_alg = food_allergen_vec(:);

    w0 = p_alg .* fd_alg;
    for i = 1:nA
        for j = 1:nA
            if i~=j && C(i,j)>=0.35 && fd_alg(j)>0 && p_alg(i)>0
                w0(j) = max(w0(j), C(i,j)*p_alg(i)*0.8);
            end
        end
    end

    rho=1.0; lambda=0.05; gamma=0.35;
    x=w0; z=w0; u=zeros(nA,1); conv_iter=200;

    for iter = 1:200
        v = (w0 + rho*(z-u))/(1+rho);
        x = sign(v).*max(abs(v)-lambda/(1+rho), 0);
        z_old = z;
        z = max(x+u, 0);
        for iter_p = 1:10
            for ii=1:nA
                for jj=1:nA
                    if ii~=jj && C(ii,jj)>=gamma
                        z(ii) = max(z(ii), C(ii,jj)*z(jj));
                    end
                end
            end
        end
        u = u + x - z;
        if norm(x-z)<1e-4 && norm(-rho*(z-z_old))<1e-4
            conv_iter = iter; 
            break;
        end
    end

    risk_score = min(sum(x), 1.0);

    % STEP 5 — VERDICT + VISUALIZATION
    if risk_score < thresholds(1)
        verdict=verdict_labels{1}; msg='No significant allergen risk. Food appears safe.';
    elseif risk_score < thresholds(2)
        verdict=verdict_labels{2}; msg='Minor allergen overlap. Consume with caution.';
    elseif risk_score < thresholds(3)
        verdict=verdict_labels{3}; msg='Significant allergen. Avoid if sensitive.';
    else
        verdict=verdict_labels{4}; msg='Dangerous allergen detected. Do NOT consume.';
    end

    fprintf('\n╔══════════════════════════════════════════════════════╗\n');
    fprintf('║                    RISK VERDICT                     ║\n');
    fprintf('╠══════════════════════════════════════════════════════╣\n');
    fprintf('║  Food    : %-42s║\n', food_name);
    if cnn_used
        fprintf('║  CNN     : %-42s║\n', sprintf('%s (%.1f%% conf)', cnn_label, cnn_conf*100));
    end
    fprintf('║  Score   : %-42s║\n', sprintf('%.4f / 1.0  (%.1f%%)', risk_score, risk_score*100));
    fprintf('║  Verdict : %-42s║\n', verdict);
    fprintf('╠══════════════════════════════════════════════════════╣\n');
    fprintf('║  %-52s║\n', msg);
    fprintf('╚══════════════════════════════════════════════════════╝\n\n');

    filled = round(risk_score*40);
    fprintf('Risk Meter:\n');
    fprintf('[%s%s] %.1f%%\n\n', repmat(char(9608),1,filled), repmat(char(9617),1,40-filled), risk_score*100);
    fprintf('  0%%         25%%         55%%         85%%       100%%\n');
    fprintf('  SAFE        MILD        HIGH        AVOID\n\n');

    % Allergen Breakdown
    fprintf('Allergen Breakdown:\n');
    fprintf('%-14s  %-10s  %-12s  %-12s  %s\n','Allergen','In Food','You Allergic','ADMM Weight','Note');
    fprintf('%s\n', repmat('-',1,72));
    for i = 1:nA
        in_food     = fd_alg(i)>0;
        is_allergic = p_alg(i)>0;
        w_val       = x(i);
        if w_val>0.005 || in_food || is_allergic
            note = '';
            if is_allergic && in_food
                note = 'HIGH RISK (confirmed)';
            elseif assumed_mask(i) && is_allergic
                note = 'POSSIBLE RISK (assumed)';
            elseif w_val>0.005 && is_allergic && ~in_food
                note = 'CROSS-REACTIVE (novel)';
            end
            fprintf('%-14s  %-10s  %-12s  %.4f  %s\n',...
                allergen_names{i}, bool2str(in_food), bool2str(is_allergic), w_val, note);
        end
    end

    fprintf('\n  ADMM converged in %d iterations.\n', conv_iter);

    % Visualization
    active = find(x>0.005 | fd_alg>0 | p_alg>0);
    if ~isempty(active)
        figure('Name',sprintf('Risk Breakdown: %s', food_name),'NumberTitle','off','Position',[150 150 900 500]);
        bar(x(active));
        set(gca,'XTick',1:numel(active),'XTickLabel',allergen_names(active),'XTickLabelRotation',45);
        ylabel('ADMM Risk Weight');
        title(sprintf('Allergen Risk: "%s" | Verdict: %s', food_name, verdict));
        grid on;
    end

    % Check another food?
    fprintf('\n══════════════════════════════════════════════════════\n');
    again = strtrim(input('Check another food? (y/n): ','s'));
    if ~strcmpi(again,'y')
        fprintf('\nThank you. Stay safe!\n\n');
        break;
    end
    close all;
end

end % function run_checker

% Helper function
function s = bool2str(b)
    if b, s = 'YES'; else, s = ''; end
end