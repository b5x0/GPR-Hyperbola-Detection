function detect_hyperboles()
    clc;
    fprintf('--- Démarrage V13 (SVD Pure + Smart Crop uniquement) ---\n');
    
    % --- CONFIGURATION ---
    output_base = 'results';
    dirs_to_process = {'with_aug', 'without_aug'};
    
    % --- PARAMÈTRES ---
    % SVD: 1 = Retire la structure horizontale principale (le sol/surface)
    eigen_to_remove = 1; 
    
    % Smart Crop (Bas uniquement)
    min_keep_ratio = 0.20; 
    max_keep_ratio = 0.65;
    
    summary_data = {}; 
    all_curves_data = struct(); 
    curve_counter = 0;

    for k = 1:length(dirs_to_process)
        dir_name = dirs_to_process{k};
        
        % Recherche Dossier
        if exist(fullfile(pwd, dir_name), 'dir') == 7
            input_path = fullfile(pwd, dir_name);
        else
            input_path = uigetdir(pwd, sprintf('Sélectionnez %s', dir_name));
            if input_path == 0, continue; end
        end

        [~, name_only] = fileparts(input_path);
        output_path = fullfile(pwd, output_base, name_only);
        if exist(output_path, 'dir') ~= 7, mkdir(output_path); end
        
        images = dir(fullfile(input_path, '*.*'));
        images = images(~[images.isdir]); 
        
        fprintf('Traitement de %d images dans %s...\n', length(images), dir_name);
        
        for i = 1:length(images)
            img_name = images(i).name;
            full_path = fullfile(input_path, img_name);
            
            try
                % 1. Lecture
                original_img = imread(full_path);
                if size(original_img, 3) == 3, gray_img = rgb2gray(original_img); else, gray_img = original_img; end
                [rows, cols] = size(gray_img);
                
                % --- 2. SMART CROP (Calcul Ligne Bleue) ---
                row_std = std(double(gray_img), 0, 2);
                smooth_std = conv(row_std, ones(10,1)/10, 'same');
                mean_act = mean(smooth_std);
                
                cut_row = floor(rows * max_keep_ratio);
                start_s = floor(rows * min_keep_ratio);
                end_s = floor(rows * max_keep_ratio);
                
                for r = start_s : end_s
                    if smooth_std(r) < (mean_act / 1.2)
                        cut_row = r; break;
                    end
                end
                
                % Image de travail (Double précision obligatoire pour SVD)
                % On coupe le bas, mais ON GARDE LE HAUT intact
                work_img = double(gray_img(1:cut_row, :));
                
                % --- 3. SVD FILTERING (Suppression mathématique du sol) ---
                % C'est ici que la magie opère : on retire l'énergie horizontale
                [U, S, V] = svd(work_img, 'econ');
                
                % On annule la composante dominante (le sol plat / la surface)
                for e = 1:min(eigen_to_remove, size(S,1))
                    S(e, e) = 0;
                end
                
                % Reconstruction
                reconstructed_img = U * S * V';
                
                % Normalisation
                abs_img = abs(reconstructed_img);
                norm_img = (abs_img - min(abs_img(:))) / (max(abs_img(:)) - min(abs_img(:)));
                
                % --- 4. SEUILLAGE ---
                level = graythresh(norm_img);
                % On booste un peu le seuil pour ne garder que les contrastes forts
                bw = im2bw(norm_img, level * 1.2);
                
                % --- 5. NETTOYAGE ---
                % On retire les petits points isolés
                bw = bwareaopen(bw, 60);
                
                % Reconnexion (Closing)
                se = strel('rectangle', [5 2]);
                bw = imclose(bw, se);
                
                % Squelettisation
                full_mask = false(rows, cols);
                full_mask(1:cut_row, :) = bw;
                final_skel = bwmorph(full_mask, 'skel', Inf);

                % --- 6. SÉLECTION (Plus grand objet) ---
                cc = bwconncomp(final_skel);
                
                if cc.NumObjects > 0
                    props = regionprops(cc, 'PixelList', 'MajorAxisLength');
                    % On garde la ligne la plus longue
                    [~, idx] = max([props.MajorAxisLength]);
                    best_xy = props(idx).PixelList;
                    num_obj = 1;
                else
                    num_obj = 0;
                    best_xy = [];
                end
                
                summary_data{end+1, 1} = img_name;
                summary_data{end, 2} = num_obj;
                
                if num_obj > 0
                    curve_counter = curve_counter + 1;
                    all_curves_data(curve_counter).image_name = img_name;
                    all_curves_data(curve_counter).id = sprintf('%s_h1', img_name);
                    all_curves_data(curve_counter).xy = best_xy;
                    all_curves_data(curve_counter).folder = dir_name;
                end
                
                % --- VISUALISATION ---
                fig = figure('Visible', 'off'); 
                imshow(original_img); hold on;
                
                % Ligne Bleue (Smart Crop) UNIQUEMENT
                line([1 cols], [cut_row cut_row], 'Color', 'b', 'LineWidth', 1);
                
                if ~isempty(best_xy)
                    % Points MAGENTA
                    plot(best_xy(:,1), best_xy(:,2), 'm.', 'MarkerSize', 3);
                    title('SVD Pure: Detected');
                else
                    title('SVD Pure: Rien détecté');
                end
                
                print(fig, fullfile(output_path, ['det_' img_name]), '-dpng'); 
                close(fig);
                
                if mod(i, 20) == 0, fprintf('.'); end
                
            catch ME
                fprintf('\nErreur %s: %s\n', img_name, ME.message);
            end
        end
        fprintf('\n[OK] %s terminé.\n', dir_name);
    end
    
    if ~isempty(summary_data)
        fid = fopen('detection_summary.csv', 'w');
        fprintf(fid, 'Image,Count\n');
        for r=1:size(summary_data,1), fprintf(fid,'%s,%d\n',summary_data{r,1},summary_data{r,2}); end
        fclose(fid);
        save('hyperboles_data.mat', 'all_curves_data');
        fprintf('Terminé.\n');
    end
end