function fn = extractConfoundRegressors(BIDSfmriprep, filters, glm, out_path, fn)
% fn = extractConfoundRegressors(BIDSfmriprep, filters, glm, out_path, fn)
% 1) reads in confound *timeseries.tsv from fmriprep derivatives directory
% 2) for each run, selects 6 motion parameters (trans & rot) and global
% signal and saves them to a *spmRegressors_timeseries.mat in out_path
%
% INPUTS:
% BIDSfmriprep: struct describing fmriprep derivative BIDS directory via
% bids.layout()
% filters:      struct containing parameters to use as filters with
% bids.query() to obtain select files from a BIDS directory, such as
% subject, session, task, modality, space, ...
% glm:          struct containing metadata relevant for the GLM
% out_path:     path where results are saved, in this case the BIDS derivative
% directory for the currently employed pipeline
% fn:           struct containing filenames
%
% OUTPUT:
% fn:           struct containing filenames
%
% written by Jonathan Wehnert
% current version: 2023.11.10

% 1) bids.query for confounder files
filter = struct(...
    'sub', filters.subj, ...
    'ses', filters.ses, ...
    'task', filters.task, ...
    'suffix', 'timeseries', ...
    'extension', '.tsv');
fn.confounds = bids.query(BIDSfmriprep, 'data', filter);

% 2) loop across all runs
for crun = 1:glm.meta.nruns
    confounds_all = bids.util.tsvread(fn.confounds{crun});

    % select the confound variables relevant to me using contains() in the
    % below if statements, save to confounds_model (each confound is one
    % column, each volume one row); save confound names to cell array 'names'
    % in the same order. save both of these to a .mat file to load in SPM batch
    % editor for 'Multiple Regressors'
    fieldn_confounds = fieldnames(confounds_all);
    confounds_model = [];
    names = cell(0);
    cnt = 1;
    for i = 1:length(fieldn_confounds)
        if contains(fieldn_confounds{i}, 'trans_') || contains(fieldn_confounds{i}, 'rot_')
            if ~contains(fieldn_confounds{i}, '1') && ~contains(fieldn_confounds{i}, '2')
                confounds_model(:,cnt) = confounds_all.(fieldn_confounds{i});
                names{cnt} = fieldn_confounds{i};
                cnt = cnt + 1;
            end
        end
    end
    confounds_model(:,cnt) = confounds_all.global_signal;
    names{cnt} = 'global_signal';

    % create filename
    run = sprintf('%02d', crun);
    input = struct('ext', '.mat', ...
        'suffix', 'timeseries', ...
        'entities', struct('sub', filters.subj, ...
        'ses', filters.ses, ...
        'task', filters.task, ...
        'run', run, ...
        'desc', 'spmRegressors'));
    file = bids.File(input, 'use_schema', true);
    R = confounds_model;
    if exist(fullfile(out_path, file.filename), 'file') ~= 2
        save(fullfile(out_path, file.filename), "R", "names");
    end
end