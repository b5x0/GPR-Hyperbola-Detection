function detect_hyperboles()
    % --- Configuration ---
    dirs_to_process = {'with_aug', 'without_aug'};
    output_base = 'results';
    
    % Paramètres de la version 1
    min_pixel_size = 50; 
    
    summary_data = {}; 
    all_curves_data = struct(); 
    curve_counter = 0;

    fprintf('--- Démarrage Détection (Version Originale) ---\n');

    for k = 1:length(dirs_to_process)
        current_dir = dirs_to_process{k};
        input_path = current_dir; 
        output_path = fullfile(output_base, current_dir);
        
        % Correction Compatibilité (exist au lieu de isfolder)
        if exist(input_path, 'dir') ~= 7
            warning('Dossier introuvable : %s', input_path);
            continue;
        end
        if exist(output_path, 'dir') ~= 7
            mkdir(output_path);
        end
        
        images = dir(fullfile(input_path, '*.*'));
        images = images(~[images.isdir]); 
        
        for i = 1:length(images)
            img_name = images(i).name;
            full_img_path = fullfile(input_path, img_name);
            
            try
                % 1. Lecture
                original_img = imread(full_img_path);
                
                % 2. Prétraitement
                if size(original_img, 3) == 3
                    gray_img = rgb2gray(original_img);
                else
                    gray_img = original_img;
                end
                
                % --- ALGORITHME INITIAL ---
                % Gestion compatibilité imbinarize / im2bw
                if exist('imbinarize', 'file')
                    binary_img = ~imbinarize(gray_img); 
                else
                    level = graythresh(gray_img);
                    binary_img = ~im2bw(gray_img, level);
                end
                
                % Nettoyage standard (50 pixels)
                binary_img = bwareaopen(binary_img, min_pixel_size);

                % 3. Détection
                cc = bwconncomp(binary_img);
                num_hyperboles = cc.NumObjects;
                
                summary_data{end+1, 1} = img_name;
                summary_data{end, 2} = num_hyperboles;
                
                % 4. Annotation
                fig = figure('Visible', 'off'); 
                imshow(original_img); hold on;
                
                props = regionprops(cc, 'PixelList');
                
                for j = 1:num_hyperboles
                    unique_id = sprintf('%s_h%d', img_name, j);
                    xy = props(j).PixelList;
                    
                    curve_counter = curve_counter + 1;
                    all_curves_data(curve_counter).image_name = img_name;
                    all_curves_data(curve_counter).id = unique_id;
                    all_curves_data(curve_counter).xy = xy;
                    all_curves_data(curve_counter).folder = current_dir;

                    plot(xy(:,1), xy(:,2), 'r.', 'MarkerSize', 2);
                end
                
                title(sprintf('Détection : %d hyperboles', num_hyperboles));
                
                % Sauvegarde Image
                save_name = fullfile(output_path, ['detected_' img_name]);
                print(fig, save_name, '-dpng'); 
                close(fig);
                
                if mod(i, 50) == 0
                    fprintf('Image traitée : %s (%d courbes)\n', img_name, num_hyperboles);
                end
                
            catch ME
                fprintf('Erreur sur %s : %s\n', img_name, ME.message);
            end
        end
    end

    % --- Sauvegarde Finale (Correction Compatibilité Table) ---
    fprintf('Sauvegarde des résultats en cours...\n');
    
    if ~isempty(summary_data)
        % Écriture fichier texte simple (CSV) sans utiliser 'table'
        fid = fopen('detection_summary.csv', 'w');
        fprintf(fid, 'Image_Name,Nb_Hyperboles\n');
        for row = 1:size(summary_data, 1)
            fprintf(fid, '%s,%d\n', summary_data{row, 1}, summary_data{row, 2});
        end
        fclose(fid);
        
        save('hyperboles_data.mat', 'all_curves_data');
        fprintf('Terminé. Fichiers sauvegardés.\n');
    else
        fprintf('Aucune donnée trouvée.\n');
    end
end