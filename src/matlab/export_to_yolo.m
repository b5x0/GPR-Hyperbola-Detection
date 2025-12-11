function export_to_yolo()
    clc;
    fprintf('--- Démarrage Export YOLO (MATLAB -> Python AI) ---\n');
    
    % --- CONFIGURATION ---
    input_file = 'hyperboles_data.mat';
    
    % On va créer un dossier "dataset" prêt pour l'upload
    output_dir = 'dataset_yolo';
    images_dir = fullfile(output_dir, 'images');
    labels_dir = fullfile(output_dir, 'labels');
    
    if ~exist(input_file, 'file')
        error('Fichier hyperboles_data.mat introuvable !');
    end
    
    % Création des dossiers
    if exist(output_dir, 'dir') ~= 7, mkdir(output_dir); end
    if exist(images_dir, 'dir') ~= 7, mkdir(images_dir); end
    if exist(labels_dir, 'dir') ~= 7, mkdir(labels_dir); end
    
    data = load(input_file);
    curves = data.all_curves_data;
    
    fprintf('Traitement de %d annotations...\n', length(curves));
    
    % On groupe les courbes par image (car une image peut avoir plusieurs hyperboles)
    % On utilise une map ou un struct pour regrouper
    img_map = containers.Map();
    
    for k = 1:length(curves)
        im_name = curves(k).image_name;
        folder = curves(k).folder; % 'with_aug' ou 'without_aug'
        
        if ~isKey(img_map, im_name)
            img_map(im_name) = {curves(k)};
        else
            current_list = img_map(im_name);
            current_list{end+1} = curves(k);
            img_map(im_name) = current_list;
        end
    end
    
    keys = img_map.keys;
    
    for i = 1:length(keys)
        img_name = keys{i};
        curve_list = img_map(img_name);
        
        % 1. Trouver l'image source pour la copier et avoir sa taille
        % On cherche dans les deux dossiers possibles
        path_aug = fullfile(pwd, 'with_aug', img_name);
        path_no_aug = fullfile(pwd, 'without_aug', img_name);
        
        if exist(path_aug, 'file')
            src_path = path_aug;
        elseif exist(path_no_aug, 'file')
            src_path = path_no_aug;
        else
            fprintf('Warning: Image %s introuvable, ignorée.\n', img_name);
            continue;
        end
        
        % Copie de l'image
        dest_img_path = fullfile(images_dir, img_name);
        copyfile(src_path, dest_img_path);
        
        % Lecture dimensions pour normalisation YOLO
        info = imfinfo(src_path);
        im_w = info.Width;
        im_h = info.Height;
        
        % 2. Création du fichier label (.txt)
        [~, raw_name, ~] = fileparts(img_name);
        txt_path = fullfile(labels_dir, [raw_name '.txt']);
        fid = fopen(txt_path, 'w');
        
        for j = 1:length(curve_list)
            c = curve_list{j};
            xy = c.xy;
            
            % Calcul Bounding Box (Boîte englobante)
            min_x = min(xy(:,1));
            max_x = max(xy(:,1));
            min_y = min(xy(:,2));
            max_y = max(xy(:,2));
            
            % Calcul Centre et Largeur (Format YOLO)
            box_w = max_x - min_x;
            box_h = max_y - min_y;
            center_x = min_x + (box_w / 2);
            center_y = min_y + (box_h / 2);
            
            % Normalisation (0 à 1)
            norm_cx = center_x / im_w;
            norm_cy = center_y / im_h;
            norm_w = box_w / im_w;
            norm_h = box_h / im_h;
            
            % Sécurité (ne pas dépasser 1)
            norm_cx = min(max(norm_cx, 0), 1);
            norm_cy = min(max(norm_cy, 0), 1);
            norm_w = min(max(norm_w, 0), 1);
            norm_h = min(max(norm_h, 0), 1);
            
            % Écriture : class_id center_x center_y width height
            % class_id = 0 (Hyperbole)
            fprintf(fid, '0 %.6f %.6f %.6f %.6f\n', norm_cx, norm_cy, norm_w, norm_h);
        end
        fclose(fid);
        
        if mod(i, 50) == 0, fprintf('.'); end
    end
    
    fprintf('\nExport terminé ! Dossier "dataset_yolo" créé.\n');
    fprintf('Compressez ce dossier en ZIP pour l''envoyer sur Google Drive.\n');
end