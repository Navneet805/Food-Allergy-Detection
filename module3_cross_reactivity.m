% =========================================================
% MODULE 3: Cross-Reactivity Constraint Matrix
% =========================================================
% Builds the 12x12 cross-reactivity matrix C used in ADMM.
% Values based on clinical immunology literature (AAAAI).
%
% Allergen order matches Module 1:
%   1=Shellfish 2=Fish   3=Milk    4=Soy    5=Egg    6=Wheat
%   7=Peanut   8=Sesame  9=TreeNut 10=Walnut 11=Cashew 12=Almond
% =========================================================
function module3_cross_reactivity()

global CONFIG;

allergen_names = {'Shellfish','Fish','Milk','Soy','Egg','Wheat',...
                  'Peanut','Sesame','TreeNut','Walnut','Cashew','Almond'};
nA = 12;

fprintf('   Building %dx%d cross-reactivity matrix...\n', nA, nA);

%            She   Fis   Mil   Soy   Egg   Whe   Pea   Ses   TrN   Wal   Cas   Alm
C = [
    1.00  0.65  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00;  % Shellfish
    0.65  1.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00;  % Fish
    0.00  0.00  1.00  0.00  0.45  0.00  0.00  0.00  0.00  0.00  0.00  0.00;  % Milk
    0.00  0.00  0.00  1.00  0.00  0.20  0.35  0.30  0.30  0.00  0.00  0.00;  % Soy
    0.00  0.00  0.45  0.00  1.00  0.00  0.00  0.00  0.00  0.00  0.00  0.00;  % Egg
    0.00  0.00  0.00  0.20  0.00  1.00  0.00  0.00  0.00  0.00  0.00  0.00;  % Wheat
    0.00  0.00  0.00  0.35  0.00  0.00  1.00  0.40  0.72  0.65  0.60  0.55;  % Peanut
    0.00  0.00  0.00  0.30  0.00  0.00  0.40  1.00  0.35  0.00  0.00  0.00;  % Sesame
    0.00  0.00  0.00  0.30  0.00  0.00  0.72  0.35  1.00  0.85  0.80  0.75;  % TreeNut
    0.00  0.00  0.00  0.00  0.00  0.00  0.65  0.00  0.85  1.00  0.70  0.65;  % Walnut
    0.00  0.00  0.00  0.00  0.00  0.00  0.60  0.00  0.80  0.70  1.00  0.60;  % Cashew
    0.00  0.00  0.00  0.00  0.00  0.00  0.55  0.00  0.75  0.65  0.60  1.00;  % Almond
];

assert(max(max(abs(C-C'))) < 1e-10, 'C must be symmetric!');
fprintf('   Symmetry check passed.\n');

threshold = 0.3;
C_sparse  = C .* (C >= threshold);

% ── Heatmap ───────────────────────────────────────────────
figure('Name','Cross-Reactivity Matrix','NumberTitle','off','Position',[100 100 1000 420]);

subplot(1,2,1);
imagesc(C); colorbar; colormap(hot); caxis([0 1]);
set(gca,'XTick',1:nA,'XTickLabel',allergen_names,'XTickLabelRotation',45,...
        'YTick',1:nA,'YTickLabel',allergen_names);
title('Full Cross-Reactivity Matrix C');
for i = 1:nA
    for j = 1:nA
        if C(i,j)>0.05
            clr='w'; if C(i,j)>0.6, clr='k'; end
            text(j,i,sprintf('%.2f',C(i,j)),'HorizontalAlignment','center','FontSize',7,'Color',clr);
        end
    end
end

subplot(1,2,2);
imagesc(C_sparse); colorbar; colormap(hot); caxis([0 1]);
set(gca,'XTick',1:nA,'XTickLabel',allergen_names,'XTickLabelRotation',45,...
        'YTick',1:nA,'YTickLabel',allergen_names);
title(sprintf('Sparse C (threshold >= %.1f) used in ADMM', threshold));
for i = 1:nA
    for j = 1:nA
        if C_sparse(i,j)>0.05
            clr='w'; if C_sparse(i,j)>0.6, clr='k'; end
            text(j,i,sprintf('%.2f',C_sparse(i,j)),'HorizontalAlignment','center','FontSize',7,'Color',clr);
        end
    end
end

% ── Network graph ─────────────────────────────────────────
figure('Name','Cross-Reactivity Network','NumberTitle','off','Position',[100 100 600 550]);
hold on;
theta = linspace(0,2*pi,nA+1); theta=theta(1:end-1);
cx=cos(theta); cy=sin(theta);

for i=1:nA
    for j=i+1:nA
        w=C(i,j);
        if w>=threshold
            plot([cx(i),cx(j)],[cy(i),cy(j)],'Color',[0.3 0.3 0.9 w],'LineWidth',w*5);
            mx=mean([cx(i),cx(j)]); my=mean([cy(i),cy(j)]);
            text(mx*1.1,my*1.1,sprintf('%.2f',w),'FontSize',7,'Color',[0.2 0.2 0.8],'HorizontalAlignment','center');
        end
    end
end
node_clr=lines(nA);
for i=1:nA
    scatter(cx(i),cy(i),350,node_clr(i,:),'filled','MarkerEdgeColor','k','LineWidth',1.2);
    ox=0.20*cos(theta(i)); oy=0.20*sin(theta(i));
    text(cx(i)+ox,cy(i)+oy,allergen_names{i},'FontSize',9,'FontWeight','bold','HorizontalAlignment','center');
end
axis equal; axis off;
title('Allergen Cross-Reactivity Network','FontSize',13);
text(0,-1.4,'Edge thickness = cross-reactivity strength','HorizontalAlignment','center','FontSize',9,'Color',[0.5 0.5 0.5]);

% ── Print pairs ───────────────────────────────────────────
fprintf('\n   Cross-reactive pairs (>= %.1f):\n', threshold);
fprintf('   %-12s <-> %-12s  Strength\n','Allergen A','Allergen B');
fprintf('   %s\n',repmat('-',1,42));
for i=1:nA
    for j=i+1:nA
        if C(i,j)>=threshold
            fprintf('   %-12s <-> %-12s  %.2f\n',allergen_names{i},allergen_names{j},C(i,j));
        end
    end
end

save(fullfile(CONFIG.OUTPUT_DIR,'cross_reactivity.mat'),...
    'C','C_sparse','allergen_names','threshold','nA');

fprintf('\n   Cross-reactivity matrix saved.\n');
end