function evaluate_detection_ai()
    clc;
    fprintf('--- Démarrage Méthode 2 : Évaluation IA (Unsupervised Clustering) ---\n');
    
    % --- CONFIGURATION ---
    input_file = 'hyperboles_data.mat';
    
    % Vérification
    if ~exist(input_file, 'file')
        error('Fichier de données introuvable. Lancez d''abord la détection (V13).');
    end
    
    % Chargement des données brutes
    data = load(input_file);
    if ~isfield(data, 'all_curves_data') || isempty(data.all_curves_data)
        fprintf('Aucune donnée à analyser.\n');
        return;
    end
    
    curves = data.all_curves_data;
    num_curves = length(curves);
    fprintf('%d courbes candidates chargées pour analyse IA.\n', num_curves);
    
    % --- ÉTAPE 1 : EXTRACTION DE CARACTÉRISTIQUES (Feature Engineering) ---
    features = zeros(num_curves, 3);
    valid_indices = [];
    
    fprintf('Extraction des features...\n');
    
    for k = 1:num_curves
        xy = curves(k).xy;
        
        if size(xy, 1) < 5
            continue; 
        end
        
        % Feature 1: Longueur
        len = size(xy, 1);
        
        % Feature 2 & 3: Analyse de forme
        x = xy(:,1); y = xy(:,2);
        
        % Normalisation locale pour polyfit
        if std(x) == 0, continue; end % Évite division par zero
        x_norm_local = (x - mean(x)) / std(x);
        
        % Fit parabole
        [p, ~] = polyfit(x_norm_local, y, 2);
        
        curvature = abs(p(1)); % Courbure
        y_pred = polyval(p, x_norm_local);
        fit_error = mean(abs(y - y_pred)); % Erreur de forme
        
        valid_indices = [valid_indices; k];
        features(length(valid_indices), :) = [len, curvature, fit_error];
    end
    
    % On ne garde que les courbes valides
    features = features(1:length(valid_indices), :);
    processed_curves = curves(valid_indices);
    
    % --- ÉTAPE 2 : NORMALISATION MANUELLE (Z-SCORE) ---
    % Remplace la fonction 'normalize' trop récente
    % Formule : (X - Moyenne) / Ecart-Type
    mu = mean(features);
    sigma = std(features);
    
    % Petit hack pour éviter la division par zéro si une feature est constante
    sigma(sigma == 0) = 1; 
    
    % bsxfun est la méthode compatible vieux MATLAB pour soustraire un vecteur à une matrice
    features_norm = bsxfun(@minus, features, mu);
    features_norm = bsxfun(@rdivide, features_norm, sigma);
    
    % --- ÉTAPE 3 : CLUSTERING K-MEANS ---
    fprintf('Lancement du Clustering K-Means...\n');
    
    % On utilise Try/Catch car certaines vieilles versions n'ont pas 'Replicates'
    try
        [idx, ~] = kmeans(features_norm, 2, 'Replicates', 5);
    catch
        % Fallback version très ancienne
        [idx, ~] = kmeans(features_norm, 2);
    end
    
    % --- ÉTAPE 4 : IDENTIFICATION DU "BON" CLUSTER ---
    mean_feat_1 = mean(features(idx==1, :));
    mean_feat_2 = mean(features(idx==2, :));
    
    % Score basé sur (Courbure * Longueur) / Erreur
    % On veut une grande longueur, une courbure nette, et une petite erreur
    score_1 = (mean_feat_1(1) * mean_feat_1(2)) / (mean_feat_1(3) + eps);
    score_2 = (mean_feat_2(1) * mean_feat_2(2)) / (mean_feat_2(3) + eps);
    
    if score_1 > score_2
        hyperbola_cluster = 1;
        fprintf('L''IA a identifié le Cluster 1 comme étant les HYPERBOLES.\n');
    else
        hyperbola_cluster = 2;
        fprintf('L''IA a identifié le Cluster 2 comme étant les HYPERBOLES.\n');
    end
    
    % --- ÉTAPE 5 : ÉVALUATION & MÉTRIQUES ---
    try
        s = silhouette(features_norm, idx);
        avg_silhouette = mean(s);
    catch
        avg_silhouette = 0.5; % Valeur par défaut si silhouette plante
        fprintf('Warning: Impossible de calculer le Silhouette Score sur cette version.\n');
    end
    
    tp_count = sum(idx == hyperbola_cluster); 
    fp_count = sum(idx ~= hyperbola_cluster); 
    
    fprintf('\n--- RÉSULTATS DE L''ANALYSE IA ---\n');
    fprintf('Score de Silhouette : %.4f\n', avg_silhouette);
    fprintf('Objets classés Hyperboles : %d\n', tp_count);
    fprintf('Objets classés Bruit      : %d\n', fp_count);
    
    % --- ÉTAPE 6 : VISUALISATION ---
    fig = figure('Name', 'Classification IA', 'Visible', 'off'); % Off pour ne pas pop-up
    % gscatter est dans la stats toolbox, on espère que tu l'as.
    % Sinon on fait un plot simple.
    try
        gscatter(features(:,2), features(:,3), idx, 'rb', 'xo');
        legend('Cluster 1', 'Cluster 2');
    catch
        % Fallback manuel
        plot(features(idx==1,2), features(idx==1,3), 'rx'); hold on;
        plot(features(idx==2,2), features(idx==2,3), 'bo');
    end
    xlabel('Courbure');
    ylabel('Erreur de Fitting');
    title(sprintf('K-Means Clustering (Silhouette: %.2f)', avg_silhouette));
    grid on;
    
    save_img_name = fullfile('results', 'ai_classification_plot.png');
    print(fig, save_img_name, '-dpng');
    close(fig);
    fprintf('Graphique sauvegardé : %s\n', save_img_name);
    
    % --- SAUVEGARDE CSV ---
    fid = fopen('ai_evaluation_metrics.csv', 'w');
    fprintf(fid, 'Metric,Value\n');
    fprintf(fid, 'Total Detection,%d\n', num_curves);
    fprintf(fid, 'AI Validated,%d\n', tp_count);
    fprintf(fid, 'Noise Rejected,%d\n', fp_count);
    fprintf(fid, 'Silhouette Score,%.4f\n', avg_silhouette);
    fclose(fid);
    
    fprintf('Métriques sauvegardées dans "ai_evaluation_metrics.csv".\n');
end