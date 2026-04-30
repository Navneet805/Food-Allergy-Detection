% =========================================================
% MODULE 2: K-Means + Spectral Clustering
% =========================================================
function module2_clustering()

global CONFIG;

% Load using tmp struct to avoid static workspace error
tmp          = load(fullfile(CONFIG.OUTPUT_DIR,'preprocessed_data.mat'));
X_sample     = tmp.X_sample;
X_raw_sample = tmp.X_raw_sample;
allergen_names = tmp.allergen_names;
nA           = tmp.nA;

K    = CONFIG.K;
N    = size(X_sample,1);
F    = size(X_sample,2);
opts = statset('MaxIter',500,'Display','off');

fprintf('   Patients: %d | Features: %d | Clusters: %d\n', N, F, K);

% ── Elbow method ─────────────────────────────────────────
fprintf('   Running elbow analysis...\n');
K_range    = 2:8;
inertia    = zeros(1,numel(K_range));
sil_scores = zeros(1,numel(K_range));

for ki = 1:numel(K_range)
    k = K_range(ki);
    [lbl,~,sumd]  = kmeans(X_sample, k, 'Replicates',5, 'Options',opts);
    inertia(ki)   = sum(sumd);
    sil_scores(ki)= mean(silhouette(X_sample, lbl));
end

figure('Name','Elbow + Silhouette','NumberTitle','off','Position',[100 100 800 350]);
subplot(1,2,1);
plot(K_range, inertia,'b-o','LineWidth',2,'MarkerFaceColor','b');
xlabel('K'); ylabel('Inertia'); title('Elbow Method'); grid on;
xline(K,'r--',sprintf('K=%d',K),'LabelVerticalAlignment','bottom');

subplot(1,2,2);
plot(K_range, sil_scores,'g-s','LineWidth',2,'MarkerFaceColor','g');
xlabel('K'); ylabel('Silhouette Score'); title('Silhouette Analysis'); grid on;
xline(K,'r--',sprintf('K=%d',K),'LabelVerticalAlignment','bottom');

% ── K-Means ───────────────────────────────────────────────
fprintf('   Running K-Means (K=%d)...\n', K);
[km_labels, km_centroids, km_sumd] = kmeans(X_sample, K,...
    'Replicates',20,'Options',opts,'Distance','sqeuclidean');

sil_km = mean(silhouette(X_sample, km_labels));
fprintf('   K-Means Silhouette: %.4f\n', sil_km);

% ── Spectral Clustering ───────────────────────────────────
fprintf('   Running Spectral Clustering...\n');
n_spec = min(2000,N);
idx_sp = randperm(N,n_spec);
X_sp   = X_sample(idx_sp,:);

sigma     = 0.5;
D         = pdist2(X_sp, X_sp,'euclidean');
W         = exp(-D.^2/(2*sigma^2)) - eye(n_spec);
deg       = sum(W,2);
D_invsqrt = diag(1./sqrt(deg+eps));
L_norm    = eye(n_spec) - D_invsqrt*W*D_invsqrt;

[V,E]    = eig(L_norm);
evals    = diag(E);
[~,sidx] = sort(evals,'ascend');
V_k      = V(:,sidx(1:K));
V_k      = V_k ./ (sqrt(sum(V_k.^2,2))+eps);

[sp_labels_sub,~] = kmeans(V_k, K,'Replicates',10,'Options',opts);
sil_sp_sub = mean(silhouette(X_sp, sp_labels_sub));
fprintf('   Spectral Silhouette (subset): %.4f\n', sil_sp_sub);

% Extend spectral labels to full dataset via nearest centroid
sp_centroids = zeros(K, size(X_sp,2));
for c = 1:K
    sp_centroids(c,:) = mean(X_sp(sp_labels_sub==c,:));
end
[~,sp_labels] = min(pdist2(X_sample, sp_centroids),[],2);
sil_sp = mean(silhouette(X_sample, sp_labels));

% ── Choose best method ────────────────────────────────────
if sil_km >= sil_sp
    best_labels = km_labels;
    best_method = 'K-Means';
    best_sil    = sil_km;
else
    best_labels = sp_labels;
    best_method = 'Spectral';
    best_sil    = sil_sp;
end
fprintf('   Best: %s (Silhouette=%.4f)\n', best_method, best_sil);

% ── Map clusters to risk levels by allergen burden ────────
cluster_burden = zeros(K,1);
for c = 1:K
    idx = best_labels==c;
    cluster_burden(c) = mean(sum(X_raw_sample(idx,1:nA),2));
end
[~,burden_order] = sort(cluster_burden,'ascend');
risk_map = zeros(K,1);
for r = 1:K
    risk_map(burden_order(r)) = r;
end
risk_labels_clustered = arrayfun(@(x) risk_map(x), best_labels);
risk_label_names = {'Low','Moderate','High','Anaphylactic'};

% ── PCA visualization ─────────────────────────────────────
[~,score,~,~,explained] = pca(X_sample);
colors = [0.2 0.75 0.3; 0.2 0.5 0.9; 0.95 0.45 0.1; 0.85 0.1 0.1];

figure('Name','Cluster Visualization','NumberTitle','off','Position',[100 100 1000 420]);
subplot(1,2,1); hold on; title('K-Means Clusters (PCA)');
for c = 1:K
    idx = km_labels==c;
    scatter(score(idx,1),score(idx,2),15,colors(risk_map(c),:),'filled','MarkerFaceAlpha',0.5);
end
legend(risk_label_names,'Location','best');
xlabel(sprintf('PC1 (%.1f%%)',explained(1))); ylabel(sprintf('PC2 (%.1f%%)',explained(2))); grid on;

subplot(1,2,2); hold on; title('Spectral Clusters (PCA)');
for c = 1:K
    idx = sp_labels==c;
    scatter(score(idx,1),score(idx,2),15,colors(risk_map(c),:),'filled','MarkerFaceAlpha',0.5);
end
legend(risk_label_names,'Location','best');
xlabel(sprintf('PC1 (%.1f%%)',explained(1))); ylabel(sprintf('PC2 (%.1f%%)',explained(2))); grid on;
sgtitle('Patient Risk Clusters (Real Zenodo Data)');

% ── Cluster heatmap ───────────────────────────────────────
cluster_means = zeros(K,nA);
for c = 1:K
    idx = best_labels==c;
    cluster_means(c,:) = mean(X_raw_sample(idx,1:nA));
end
cluster_means_ordered = cluster_means(burden_order,:);

figure('Name','Cluster Profiles','NumberTitle','off','Position',[100 100 900 300]);
imagesc(cluster_means_ordered); colorbar; colormap(hot);
set(gca,'XTick',1:nA,'XTickLabel',allergen_names,'XTickLabelRotation',40,...
        'YTick',1:K,'YTickLabel',risk_label_names);
title('Mean Allergen Prevalence per Risk Cluster');
for r = 1:K
    for a = 1:nA
        val = cluster_means_ordered(r,a);
        if val>0
            text(a,r,sprintf('%.2f',val),'HorizontalAlignment','center','FontSize',7,'Color','white');
        end
    end
end

% ── Summary ───────────────────────────────────────────────
fprintf('\n   --- Cluster Profiles ---\n');
fprintf('   %-14s %-8s %-14s %-14s\n','Risk Level','Size','Top Allergen','Avg Allergens');
for r = 1:K
    c   = burden_order(r);
    idx = best_labels==c;
    [~,top_a] = max(cluster_means(c,:));
    fprintf('   %-14s %-8d %-14s %.2f\n',...
        risk_label_names{r}, sum(idx), allergen_names{top_a},...
        mean(sum(X_raw_sample(idx,1:nA),2)));
end

save(fullfile(CONFIG.OUTPUT_DIR,'clustering_results.mat'),...
    'km_labels','sp_labels','km_centroids','sil_km','sil_sp',...
    'best_labels','best_method','best_sil','K','risk_map',...
    'risk_labels_clustered','risk_label_names','cluster_means','burden_order');

fprintf('\n   Clustering results saved.\n');
end