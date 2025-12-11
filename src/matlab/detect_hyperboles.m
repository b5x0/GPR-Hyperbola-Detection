function detect_hyperboles_v4()
    % --- Configuration ---
    dirs_to_process = {'with_aug', 'without_aug'};
    output_base = 'results';
    
    % --- PARAMÈTRES ---
    min_pixel_size = 50;   % Taille min des objets (nettoyage)
    
    % Paramètres de Rognage (Smart Crop)
    min_keep_ratio = 0.20; 
    max_keep_ratio = 0.60;
    
    summary_data = {}; 
    all_curves_data = struct(); 
    curve_counter = 0;

    fprintf('--- Démarrage V4 (Background Subtraction + Smart Crop) ---\n');

    for k = 1:length(dirs_to_process)
        current_dir = dirs_to_process{k};
        input_path = current_dir; 
        output_path = fullfile(output_base, current_dir);
        
        if exist(input_path, 'dir') ~= 7, continue; end
        if exist(output_path, 'dir') ~= 7, mkdir(output_path); end
        
        images = dir(fullfile(input_path, '*.*'));
        images = images(~[images.isdir]); 
        
        for i = 1:length(images)
            img_name = images(i).name;
            full_img_path = fullfile(input_path, img_name);
            
            try
                % 1. Lecture
                original_img = imread(full_img_path);
                if size(original_img, 3) == 3
                    gray_img = rgb2gray(original_img);
                else
                    gray_img = original_img;
                end
                
                [rows, cols] = size(gray_img);
                
                % --- A. SMART CROP (Rognage) ---
                % Même logique que la V2 qui marchait bien
                row_std = std(double(gray_img), 0, 2);
                smooth_std = conv(row_std, ones(10,1)/10, 'same');
                mean_activity = mean(smooth_std);
                
                cut_row = floor(rows * max_keep_ratio);
                start_search = floor(rows * min_keep_ratio);
                end_search = floor(rows * max_keep_ratio);
                
                for r = start_search : end_search
                    if smooth_std(r) < (mean_activity / 1.2)
                        cut_row = r;
                        break;
                    end
                end
                
                % On rogne
                cropped_img = gray_img(1:cut_row, :);
                
                % --- B. BACKGROUND SUBTRACTION (NOUVEAU) ---
                % On convertit en double pour les calculs
                d_img = double(cropped_img);
                
                % On calcule la moyenne de chaque ligne (profil moyen horizontal)
                mean_trace = mean(d_img, 2);
                
                % On soustrait ce profil à chaque colonne de l'image
                % Cela efface les bandes horizontales (le sol)
                % repmat étend le vecteur moyen pour qu'il ait la taille de l'image
                subtracted_img = d_img - repmat(mean_trace, 1, cols);
                
                % On prend la valeur absolue (car les hyperboles peuvent être noires ou blanches)
                abs_img = abs(subtracted_img);
                
                % On normalise entre 0 et 1
                abs_img = (abs_img - min(abs_img(:))) / (max(abs_img(:)) - min(abs_img(:)));
                
                % --- C. SEUILLAGE ADAPTATIF ---
                % Au lieu d'un seuil fixe, on utilise adaptthresh (Sensibilité)
                % sensitivity : plus c'est haut (0-1), plus ça détecte de choses.
                % 0.4 est une bonne base pour éviter le bruit.
                if exist('adaptthresh', 'file')
                    T = adaptthresh(abs_img, 0.4, 'ForegroundPolarity', 'bright');
                    binary_img = imbinarize(abs_img, T);
                else
                    % Fallback vieux Matlab
                    level = graythresh(abs_img);
                    binary_img = im2bw(abs_img, level);
                end
                
                % --- D. NETTOYAGE ---
                % Suppression du bruit
                binary_img = bwareaopen(binary_img, min_pixel_size);
                
                % Dilatation verticale pour relier les points pointillés
                se_v = strel('rectangle', [3 1]);
                binary_img = imdilate(binary_img, se_v);
                
                % Squelettisation finale
                % On remet l'image à la taille réelle (avec le bas noir)
                full_binary_img = false(rows, cols);
                full_binary_img(1:cut_row, :) = binary_img;
                full_binary_img = bwmorph(full_binary_img, 'skel', Inf);

                % 3. Extraction
                cc = bwconncomp(full_binary_img);
                num_hyperboles = cc.NumObjects;
                
                summary_data{end+1, 1} = img_name;
                summary_data{end, 2} = num_hyperboles;
                
                % 4. Visualisation
                fig = figure('Visible', 'off'); 
                imshow(original_img); hold on;
                
                % Ligne de coupe
                plot([1 cols], [cut_row cut_row], 'b-', 'LineWidth', 1);
                
                props = regionprops(cc, 'PixelList');
                for j = 1:num_hyperboles
                    unique_id = sprintf('%s_h%d', img_name, j);
                    xy = props(j).PixelList;
                    
                    curve_counter = curve_counter + 1;
                    all_curves_data(curve_counter).image_name = img_name;
                    all_curves_data(curve_counter).id = unique_id;
                    all_curves_data(curve_counter).xy = xy;
                    all_curves_data(curve_counter).folder = current_dir;

                    % Dessin Bleu Cyan (très visible)
                    plot(xy(:,1), xy(:,2), 'c.', 'MarkerSize', 3);
                end
                
                title(sprintf('V4 Subtraction: %d hyperboles', num_hyperboles));
                print(fig, fullfile(output_path, ['det_v4_' img_name]), '-dpng'); 
                close(fig);
                
                if mod(i, 50) == 0
                    fprintf('Image %s traitée...\n', img_name);
                end
                
            catch ME
                % skip
            end
        end
    end

    % --- Sauvegarde ---
    fid = fopen('detection_summary.csv', 'w');
    fprintf(fid, 'Image_Name,Nb_Hyperboles\n');
    for row = 1:size(summary_data, 1)
        fprintf(fid, '%s,%d\n', summary_data{row, 1}, summary_data{row, 2});
    end
    fclose(fid);
    save('hyperboles_data.mat', 'all_curves_data');
    fprintf('Terminé. Vérifie les images.\n');
end