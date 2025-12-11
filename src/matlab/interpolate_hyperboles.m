function interpolate_hyperboles()
    clc;
    fprintf('--- Démarrage Étape II : Interpolation & Comparaison ---\n');
    
    % --- CONFIGURATION ---
    input_file = 'hyperboles_data.mat';
    output_dir = fullfile('results', 'interpolation');
    
    % On ne génère les images que pour les 50 premières courbes pour gagner du temps
    max_plot_count = 50; 
    
    if exist(output_dir, 'dir') ~= 7, mkdir(output_dir); end
    
    % Chargement
    if ~exist(input_file, 'file')
        error('Fichier %s introuvable. Lancez la détection V13 d''abord !', input_file);
    end
    data = load(input_file);
    
    if ~isfield(data, 'all_curves_data') || isempty(data.all_curves_data)
        fprintf('ATTENTION : Aucune courbe n''a été détectée dans l''étape précédente.\n');
        return;
    end
    
    curves = data.all_curves_data;
    num_curves = length(curves);
    fprintf('%d courbes chargées.\n', num_curves);
    
    % Fichier Résultats CSV
    fid_csv = fopen('interpolation_results.csv', 'w');
    fprintf(fid_csv, 'Image,ID,Method,EMR\n');
    
    % Stats
    stats_lin = []; stats_spl = []; stats_pol = [];
    
    plot_counter = 0;
    
    for k = 1:num_curves
        xy = curves(k).xy;
        
        % Sécurité : il faut au moins 4 points pour interpoler
        if size(xy, 1) < 5
            continue; 
        end
        
        % 1. PRÉPARATION DES DONNÉES
        % Les interpolateurs MATLAB (interp1) détestent les doublons en X.
        % On trie par X et on moyenne les Y si plusieurs points ont le même X.
        [x_sorted, sort_idx] = sort(xy(:,1));
        y_sorted = xy(sort_idx, 2);
        
        [x_unique, unique_idx] = unique(x_sorted);
        y_unique = y_sorted(unique_idx);
        
        % Si après nettoyage il reste trop peu de points, on saute
        if length(x_unique) < 5, continue; end
        
        % On définit les points où on va tracer la courbe (du premier au dernier X détecté)
        x_query = linspace(min(x_unique), max(x_unique), 100); 
        
        % --- 2. MÉTHODES D'INTERPOLATION ---
        
        % A. Linéaire (Relie les points bêtement)
        y_lin = interp1(x_unique, y_unique, x_query, 'linear');
        
        % B. Spline (Courbe lisse qui passe par tous les points)
        y_spl = interp1(x_unique, y_unique, x_query, 'spline');
        
        % C. Polynomiale (Degré 3) - Lisse le nuage de points (ne passe pas forcément par tous)
        % C'est souvent le MEILLEUR pour le GPR bruité
        [p, S, mu] = polyfit(x_unique, y_unique, 3); 
        y_pol = polyval(p, x_query, [], mu);
        
        % --- 3. CALCUL DE L'ERREUR (EMR) ---
        % Pour calculer l'erreur, on doit comparer aux points originaux (x_unique, y_unique)
        % On recalcule les Y estimés aux positions X originales
        y_est_lin = interp1(x_unique, y_unique, x_unique, 'linear'); % Erreur nulle par définition
        y_est_spl = interp1(x_unique, y_unique, x_unique, 'spline'); % Erreur nulle par définition
        y_est_pol = polyval(p, x_unique, [], mu); % Erreur non nulle (lissage)
        
        % Formule EMR du PDF : mean( |(y_est - y_vrai)/y_vrai| )
        % On ajoute eps pour éviter division par zéro
        err_lin = mean(abs((y_est_lin - y_unique) ./ (y_unique + eps)));
        err_spl = mean(abs((y_est_spl - y_unique) ./ (y_unique + eps)));
        err_pol = mean(abs((y_est_pol - y_unique) ./ (y_unique + eps)));
        
        % Stockage
        stats_lin(end+1) = err_lin;
        stats_spl(end+1) = err_spl;
        stats_pol(end+1) = err_pol;
        
        fprintf(fid_csv, '%s,%s,Linear,%.4f\n', curves(k).image_name, curves(k).id, err_lin);
        fprintf(fid_csv, '%s,%s,Spline,%.4f\n', curves(k).image_name, curves(k).id, err_spl);
        fprintf(fid_csv, '%s,%s,Poly3,%.4f\n', curves(k).image_name, curves(k).id, err_pol);
        
        % --- 4. VISUALISATION ---
        if plot_counter < max_plot_count
            fig = figure('Visible', 'off');
            
            % Points détectés (Noirs)
            plot(x_unique, y_unique, 'ko', 'MarkerSize', 4, 'DisplayName', 'Détection SVD'); hold on;
            
            % Courbes interpolées
            plot(x_query, y_lin, 'b--', 'LineWidth', 1, 'DisplayName', 'Linéaire');
            plot(x_query, y_spl, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Spline');
            plot(x_query, y_pol, 'r-', 'LineWidth', 2, 'DisplayName', 'Poly (Deg 3)');
            
            legend('Location', 'best');
            title(sprintf('Interpolation: %s', curves(k).id), 'Interpreter', 'none');
            grid on;
            set(gca, 'YDir', 'reverse'); % GPR : Y vers le bas souvent
            
            save_name = fullfile(output_dir, [curves(k).id '_interp.png']);
            print(fig, save_name, '-dpng');
            close(fig);
            
            plot_counter = plot_counter + 1;
        end
        
        if mod(k, 20) == 0, fprintf('.'); end
    end
    
    fclose(fid_csv);
    fprintf('\n');
    
    % --- RÉSUMÉ FINAL ---
    fprintf('\n--- RÉSULTATS MOYENS (EMR) ---\n');
    fprintf('Plus c''est bas, mieux c''est.\n');
    fprintf('Linéaire    : %.5f (Référence)\n', mean(stats_lin));
    fprintf('Spline      : %.5f (Colle aux points)\n', mean(stats_spl));
    fprintf('Polynomiale : %.5f (Lisse le bruit)\n', mean(stats_pol));
    
    fprintf('\nTerminé. Regarde les courbes dans results/interpolation !\n');
end