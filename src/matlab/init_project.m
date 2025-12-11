% init_project.m
function init_project()
    % Définition des dossiers sources
    source_dirs = {'with_aug', 'without_aug'};
    
    % Définition des dossiers de résultats selon le PDF
    % [cite: 22, 24, 35]
    result_dirs = {
        fullfile('results', 'with_aug'), ...
        fullfile('results', 'without_aug'), ...
        fullfile('results', 'interpolation')
    };

    % Création des dossiers s'ils n'existent pas
    for i = 1:length(result_dirs)
        if ~exist(result_dirs{i}, 'dir')
            mkdir(result_dirs{i});
            fprintf('Dossier créé : %s\n', result_dirs{i});
        else
            fprintf('Dossier existant : %s\n', result_dirs{i});
        end
    end
    
    fprintf('Initialisation terminée.\n');
end