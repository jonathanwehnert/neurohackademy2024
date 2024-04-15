function [BIDSfmriprep, glm, fn] = copyPreprocBOLDAndSmooth(BIDS_dir, filters, glm, cfg, out_path)
% [BIDSfmriprep, glm, nruns] = copyPreprocBOLDAndSmooth(BIDS_dir, filters, glm, cfg, out_path)
% takes all functional .nii.gz from fmriprep folder and
% 1) unzips them (if they aren't already)
% 2) copies them to derivative directory as specified in out_path
% 3) if specified in cfg.smooth.smoothing = 1, smoothes the data and
% 4) renames the smoothed data to be BIDS conform
% 5) when smoothing, the non-smoothed data is removed from out_path
%
% INPUTS:
% BIDS_dir: BIDS directory containing the raw BOLD data
% filters:  struct containing parameters to use as filters with
% bids.query() to obtain select files from a BIDS directory, such as
% subject, session, task, modality, space, ...
% glm:      struct containing metadata relevant for the GLM
% cfg:      struct containing settings
% out_path: path where results are saved, in this case the BIDS derivative
% directory for the currently employed pipeline
%
% OUTPUTS:
% BIDSfmriprep: struct describing fmriprep derivative BIDS directory via
% bids.layout()
% glm:      struct containing metadata relevant for the GLM
% fn:       struct containing filenames
%
% written by Jonathan Wehnert
% current version: 2023.11.10

% 1) get files from fmriprep directory and unzip if necessary
BIDSfmriprep = bids.layout(fullfile(BIDS_dir, 'derivatives', 'fmriprep'), ...
    'use_schema', false);
filter = struct(...
    'sub', filters.subj, ...
    'ses', filters.ses, ...
    'task', filters.task, ...
    'space', filters.space, ...
    'extension', '.nii', ...
    'suffix', 'bold');
fn.bold.preproc.mni = get_fn_unzip(BIDSfmriprep, filter);
% save number of runs in this session
glm.meta.nruns = length(fn.bold.preproc.mni);

% 2) copy files to out_path
for i = 1:length(fn.bold.preproc.mni)
    copyfile(fn.bold.preproc.mni{i}, out_path); % copy files from fmriprep to SPM output folder
    [~,tmp_fn,tmp_ext] = fileparts(fn.bold.preproc.mni(i));
    % 3) if supposed to, smooth the data, 4) rename them, and 5) delete
    % non-smoothed data
    if cfg.smooth.smoothing == 1 % only do the following if data is supposed to be smoothed
        % if so: smooth data, rename SPM filename to BIDS conform filename
        % & delete copied, non-smoothed data
        infn = fullfile(out_path, [tmp_fn{1} tmp_ext{1}]); % retrieve full paths to files in SPM folder
        [tmp_path,tmp_fn,tmp_ext] = fileparts(infn);
        % prefix 'smoothed_' needs to match the SPM prefix specified in the _job.m file
        spm_fn = fullfile(tmp_path, [cfg.smooth.prefix tmp_fn tmp_ext]); % construct SPM-created filename of newly smoothed file
        new_fn = strrep(tmp_fn, 'preproc', 'preprocsm5');
        new_fn = fullfile(tmp_path, [new_fn tmp_ext]); % construct BIDS conform name for newly smoothed file
        if exist(new_fn,"file") == 0
            SPM_univariate_smooth(infn, cfg.smooth.sm_kernel, cfg.smooth.prefix); % smooth
            movefile(spm_fn, new_fn); % rename file
        end
        if exist(infn, "file") == 2
            delete (infn); % delete the file copied from fmriprep folder
        end
    end
end
end