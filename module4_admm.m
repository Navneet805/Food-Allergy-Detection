% =========================================================
% MODULE 4: ADMM Optimization with Cross-Reactivity Constraint
% =========================================================
% Demonstrates ADMM on example patient-food pairs.
% The actual interactive checker is in run_checker.m
%
% PROBLEM:
%   minimize  (1/2)||w-w0||^2 + lambda*||w||_1
%   subject to  w >= 0
%               w_i >= C(i,j)*w_j  for cross-reactive pairs
% =========================================================
function module4_admm()

global CONFIG;

% Load using tmp structs to avoid static workspace error
tmp1           = load(fullfile(CONFIG.OUTPUT_DIR,'preprocessed_data.mat'));
X_raw_sample   = tmp1.X_raw_sample;
allergen_names = tmp1.allergen_names;
nA             = tmp1.nA;

tmp2           = load(fullfile(CONFIG.OUTPUT_DIR,'clustering_results.mat'));
risk_label_names = tmp2.risk_label_names;

tmp3           = load(fullfile(CONFIG.OUTPUT_DIR,'cross_reactivity.mat'));
C              = tmp3.C;

fprintf('   ADMM: lambda=0.05, rho=1.0, gamma=0.35\n');

rho    = 1.0;
lambda = 0.05;
gamma  = 0.35;

% ── Example patient-food pairs for demo ───────────────────
food_names = {'Pad Thai','Butter Chicken','Caesar Salad','Sushi Roll','Pasta Carbonara'};
food_allergens = [
    1 0 0 0 1 0 1 0 0 0 0 0;   % Pad Thai
    0 0 1 0 0 1 0 0 0 0 0 0;   % Butter Chicken
    0 0 1 1 1 0 0 0 0 0 0 0;   % Caesar Salad
    1 1 0 0 0 0 0 0 0 0 0 0;   % Sushi Roll
    0 0 1 0 1 1 0 0 0 0 0 0;   % Pasta Carbonara
];

patient_names = {'Alice (Peanut+TreeNut)';'Bob (Dairy+Egg)';'Carol (Shellfish)'};
patient_allergens = [
    0 0 0 0 0 0 1 0 1 0 0 0;
    0 0 1 0 1 0 0 0 0 0 0 0;
    1 0 0 0 0 0 0 0 0 0 0 0;
];

nFoods    = size(food_allergens,1);
nPatients = size(patient_allergens,1);

risk_matrix    = zeros(nPatients,nFoods);
verdict_matrix = cell(nPatients,nFoods);
thresholds     = [0.25, 0.55, 0.85];
verdict_labels = {'Safe','Mild Risk','High Risk','AVOID'};

% Store convergence history for first pair
r_hist_save = []; s_hist_save = []; obj_hist_save = [];

fprintf('\n   Computing demo risk scores...\n\n');

for p = 1:nPatients
    p_alg = patient_allergens(p,:)';
    fprintf('   %s\n', patient_names{p});

    for f = 1:nFoods
        fd_alg = food_allergens(f,:)';

        % Build w0: direct overlap + cross-reactive pre-boost
        w0 = p_alg .* fd_alg;
        for i = 1:nA
            for j = 1:nA
                if i~=j && C(i,j)>=gamma && fd_alg(j)>0 && p_alg(i)>0
                    w0(j) = max(w0(j), C(i,j)*p_alg(i)*0.8);
                end
            end
        end

        % ADMM iterations
        x = w0; z = w0; u = zeros(nA,1);
        r_hist   = zeros(300,1);
        s_hist   = zeros(300,1);
        obj_hist = zeros(300,1);
        conv_iter = 300;

        for k = 1:300
            % x-update: soft threshold
            v = (w0 + rho*(z-u))/(1+rho);
            x = sign(v).*max(abs(v)-lambda/(1+rho), 0);

            % z-update: project onto non-negativity + cross-reactivity
            z_old = z;
            z     = max(x+u, 0);
            for iter_p = 1:10
                for ii = 1:nA
                    for jj = 1:nA
                        if ii~=jj && C(ii,jj)>=gamma
                            z(ii) = max(z(ii), C(ii,jj)*z(jj));
                        end
                    end
                end
            end

            % u-update
            u = u + x - z;

            r_hist(k)   = norm(x-z);
            s_hist(k)   = norm(-rho*(z-z_old));
            obj_hist(k) = 0.5*norm(x-w0)^2 + lambda*norm(x,1);

            eps_pri  = sqrt(nA)*1e-4 + 1e-3*max(norm(x),norm(z));
            eps_dual = sqrt(nA)*1e-4 + 1e-3*norm(rho*u);
            if r_hist(k)<eps_pri && s_hist(k)<eps_dual
                r_hist   = r_hist(1:k);
                s_hist   = s_hist(1:k);
                obj_hist = obj_hist(1:k);
                conv_iter = k;
                break;
            end
        end

        rs = min(sum(x),1.0);
        risk_matrix(p,f) = rs;

        % Save first pair history
        if p==1 && f==1
            r_hist_save   = r_hist;
            s_hist_save   = s_hist;
            obj_hist_save = obj_hist;
        end

        if rs<thresholds(1),     vd=verdict_labels{1};
        elseif rs<thresholds(2), vd=verdict_labels{2};
        elseif rs<thresholds(3), vd=verdict_labels{3};
        else,                    vd=verdict_labels{4};
        end
        verdict_matrix{p,f} = vd;

        fprintf('     %-22s -> %.3f  %s  (%d iters)\n', food_names{f}, rs, vd, conv_iter);
    end
    fprintf('\n');
end

% ── Convergence plot ──────────────────────────────────────
figure('Name','ADMM Convergence','NumberTitle','off','Position',[100 100 900 300]);
subplot(1,3,1);
semilogy(r_hist_save,'b-','LineWidth',2);
xlabel('Iteration'); ylabel('||r||_2'); title('Primal Residual'); grid on;

subplot(1,3,2);
semilogy(s_hist_save,'r-','LineWidth',2);
xlabel('Iteration'); ylabel('||s||_2'); title('Dual Residual'); grid on;

subplot(1,3,3);
plot(obj_hist_save,'g-','LineWidth',2);
xlabel('Iteration'); ylabel('Objective'); title('Objective Function'); grid on;
sgtitle('ADMM Convergence: Alice eating Pad Thai');

% ── Risk heatmap ──────────────────────────────────────────
figure('Name','Risk Heatmap','NumberTitle','off','Position',[100 100 900 350]);
imagesc(risk_matrix);
colormap(flipud(summer)); colorbar; caxis([0 1]);
set(gca,'XTick',1:nFoods,'XTickLabel',food_names,'XTickLabelRotation',35,...
        'YTick',1:nPatients,'YTickLabel',patient_names);
title('ADMM-Optimized Risk Scores with Cross-Reactivity','FontSize',12);
for p=1:nPatients
    for f=1:nFoods
        rs=risk_matrix(p,f);
        clr='k'; if rs>0.5, clr='w'; end
        text(f,p,sprintf('%.2f\n%s',rs,verdict_matrix{p,f}),...
            'HorizontalAlignment','center','FontSize',7,'Color',clr,'FontWeight','bold');
    end
end

% ── Print report ──────────────────────────────────────────
fprintf('   ADMM DEMO REPORT\n');
fprintf('   %-25s', '');
for f=1:nFoods, fprintf('%-16s',food_names{f}); end
fprintf('\n   %s\n',repmat('-',1,25+16*nFoods));
for p=1:nPatients
    fprintf('   %-25s',patient_names{p});
    for f=1:nFoods
        fprintf('%-16s',sprintf('%s(%.2f)',verdict_matrix{p,f},risk_matrix(p,f)));
    end
    fprintf('\n');
end

save(fullfile(CONFIG.OUTPUT_DIR,'admm_results.mat'),...
    'risk_matrix','verdict_matrix','patient_names','food_names',...
    'food_allergens','patient_allergens','thresholds','verdict_labels');

fprintf('\n   ADMM results saved.\n');
end