% perform 1st level univariate analysis for FL_BILINGUAL project
% specifically, for the button press pilot
% in the first section of this script, define which runs to run for and
% where the data are located
% next, get metadata and filenames for BOLD data,copy the preprocessed BOLD
% data into a new derivative folder (name specified in 'pipeline') and
% unzip them, then smooth them using SPM. Next get event onsets from
% events.tsv files and perform GLM in SPM.

% Start fresh
clear
clc
close all
tTotal = tic();
%% user input (settings)
BIDS_dir = '/home/jonathan/Documents/analysis/fl_bilingual/7_data/pilot/BIDS';
code_dir = '/home/jonathan/Documents/analysis/fl_bilingual/6_ExperimentScripts/analysis/fmri';
filters.subj        = 'pilot01';
filters.ses         = '02';
filters.modality    = 'func';
filters.task        = 'english';
standard_space = 'MNI152NLin2009cAsym';
native_space = 'T1w';

cfg.multivariate = 1; % 1 if doing GLM for multivariate, 0 if doing GLM for univariate analyses; -1 for custom settings below

cfg.space = 'native'; % native or standard: brain space to perform analysis in
cfg.lss.doLSS = 1; % 1 if you want to perform LSS, 0 if OLS
cfg.smooth.smoothing = 0; % 1 if data should be smoothed, 0 if not

cfg.smooth.prefix = 'smoothed_';
cfg.smooth.sm_kernel = [5 5 5];


%% toggle cfg settings
% employ standard multi-/univariate settings
if cfg.multivariate == 1
    cfg.space = 'native'; % native or standard: brain space to perform analysis in
    cfg.lss.doLSS = 1; % 1 if you want to perform LSS, 0 if OLS
    cfg.smooth.smoothing = 0; % 1 if data should be smoothed, 0 if not
elseif cfg.multivariate == 0
    cfg.space = 'standard'; % native or standard: brain space to perform analysis in
    cfg.lss.doLSS = 0; % 1 if you want to perform LSS, 0 if OLS
    cfg.smooth.smoothing = 1; % 1 if data should be smoothed, 0 if not
    cfg.smooth.prefix = 'smoothed_';
    cfg.smooth.sm_kernel = [5 5 5];
elseif cfg.multivariate == -1
    % if set to custom [-1], don't do anything and keep custom specs from
    % user input
end

if cfg.lss.doLSS == 0
    pipeline    = 'SPM_univariate';
elseif cfg.lss.doLSS == 1
    pipeline    = 'SPM_LSS';
else
    error('Please specify whether you want to perform LSS or not!');
end

if strcmp(cfg.space, 'native')
    filters.space = native_space;
elseif strcmp(cfg.space, 'standard')
    filters.space = standard_space;
else
    error('Please specify which space to perform the analysis in! Can be either [native] or [standard].');
end

% add subfunctions of this project to path
addpath(genpath(code_dir));

% initialize BIDS derivatives folder
out_path = initBIDSderivative(BIDS_dir, pipeline, filters);

%% get metadata for raw BOLD data
[BIDS.raw, meta, glm] = getBOLDMetadataForGLM(BIDS_dir, filters);

%% get filenames for preprocessed (fmriprep) BOLD data, unzip them, and copy to SPM derivatives folder. If specificed in cfg, smooth them
% smoothing settings
[BIDS.fmriprep, glm, fn] = copyPreprocBOLDAndSmooth(BIDS_dir, filters, glm, cfg, out_path);

%% read events.tsv for onset times and save conditions .mat
% specify which conditions to extract
names = {'button_1', 'button_2', 'button_3', 'button_4'}; % don't specify in/correct, so both get combined; do not retrieve visual cue timings

% [fn, cfg, lss] = extractOnsets(BIDS.raw, filters, glm, cfg, fn, out_path,
% names); % this line commented out as I don't currently want to limit the
% retrieved conditions, so am not supplying names argument
[fn, cfg, lss] = extractOnsets(BIDS.raw, filters, glm, cfg, fn, out_path);


%% prepare confound regressor files for SPM
fn = extractConfoundRegressors(BIDS.fmriprep, filters, glm, out_path, fn);

%% retrieve fmriprep brain mask in space relevant for analysis
% to-do: regardless of space, change to some mean func(!) mask!
% check with group if this is the correct mask to use!
tmpSpace = filters.space;
if strcmp(cfg.space, 'native')
    filters.space = []; % fmriprep doesn't provide a space label for the T1w anat brain mask
end
filter = struct(...
    'sub', filters.subj, ...
    'space', filters.space, ...
    'modality', 'anat', ...
    'desc', 'brain', ...
    'suffix', 'mask');
filters.space = tmpSpace; % reset filters.space

[fn.brain_mask, BIDS.fmriprep] = get_fn_unzip(BIDS.fmriprep, filter);

%% prepare inputs for 1st level GLM in SPM

% open questions with current first batch attempt:
% HRF: time and dispersion derivatives?
% explicit mask: provide fmriprep output brain mask here? or segmentation
% mask? or none since normalized func images are skull-stripped anyways?

% get files for GLM
% scans
BIDS.(pipeline) = bids.layout(fullfile(BIDS_dir, 'derivatives', pipeline), ...
    'use_schema', false);
filter = struct(...
    'sub', filters.subj, ...
    'ses', filters.ses, ...
    'task', filters.task, ...
    'suffix', 'bold');
glm.scans = bids.query(BIDS.(pipeline), 'data', filter);
% conditions
filter.suffix = 'events';
glm.conditions = bids.query(BIDS.(pipeline), 'data', filter);
% regressors
filter.suffix = 'timeseries';
glm.regressors = bids.query(BIDS.(pipeline), 'data', filter);
% brain mask
glm.mask = fn.brain_mask;

%% remove all entries from lss relating to non-existent trial categories
% explanation: a participant might not press all 4 buttons in each run.
% lss will still have a name, onset, duration for each button that was
% pressed in the first run, for every run. leading to empty conditions and
% an SPM error during GLM creation because of conditions without onset.
% Solution: remove those entries here before making temporary folders and
% SPM conditions.mat files

% Find indices of empty cells
for crun = 1:length(lss.onsets) % loop through runs
    emptyIndices = find(cellfun('isempty', lss.onsets{1,crun}));
    lss.names{1,crun}(emptyIndices) = [];
    lss.onsets{1,crun}(emptyIndices) = [];
    lss.durations{1,crun}(emptyIndices) = [];
end

% remove umlauts from condition names (SPM can't handle them)
patterns_to_replace = {'ä', 'ö', 'ü', 'ß'};
for crun = 1:length(lss.onsets) % loop through runs
    for ccond = 1:length(lss.names{crun}) % loop through conditions within run
        if contains(lss.names{1,crun}(ccond), patterns_to_replace)
            lss.names{1,crun}(ccond) = strrep(lss.names{1,crun}(ccond), 'ä', 'ae');
            lss.names{1,crun}(ccond) = strrep(lss.names{1,crun}(ccond), 'ö', 'oe');
            lss.names{1,crun}(ccond) = strrep(lss.names{1,crun}(ccond), 'ü', 'ue');
            lss.names{1,crun}(ccond) = strrep(lss.names{1,crun}(ccond), 'ß', 'ss');
        end
    end
end

%% gather number of trials across experiment for LSS
if cfg.lss.doLSS == 1
ntrials = 0;
for crun = 1:length(lss.onsets) % loop through runs
    for ccond = 1:length(lss.onsets{crun}) % loop through conditions within run
        for ctrial = 1:length(lss.onsets{crun}{ccond})
            ntrials = ntrials + 1;
        end
    end
end
totalTrials = ntrials;
end

%% LSS in parallel computing, prepare temporary folders and SPM conditions.mat files
if cfg.lss.doLSS == 1
    tic()
tmp_paths = cell(0,0);
ntrials = 0;
    % first for loop: create SPM conditions.mat files for each trial
    % according to LSS rules, save them each in their trial's own temporary folder 
    for crun = 1:length(lss.onsets) % loop through runs
        for ccond = 1:length(lss.onsets{crun}) % loop through conditions within run
            sprintf('\ncurrently performing LSS on:\nsub: %s\nses: %s\ntask: %s\nrun: %02d of %02d\ncondition: %02d of %02d\n', ...
                filters.subj, filters.ses, filters.task, crun, length(lss.onsets), ccond, length(lss.onsets{crun}));
            for ctrial = 1:length(lss.onsets{crun}{ccond})
                ntrials = ntrials + 1;

                % adapt names, onsets, durations so that the current trial is
                % separately denoted as 'ctrial' in names and as the first
                % (additional) column in onsets & durations
                tmp = lss; % reinitialize
                tmp.names{crun} = [{'ctrial'}; lss.names{crun}];
                tmp.onsets = moveTrialForLSS(tmp.onsets, crun, ccond, ctrial);
                tmp.durations = moveTrialForLSS(tmp.durations, crun, ccond, ctrial);

                % define tmp path for this trial
                % why? -> every SPM GLM needs its own folder to store
                % intermediate results. so I'm making one temporary folder
                % per trial
                condition_name = tmp.names{crun}{ccond+1};
                patterns_to_replace = {'_', 'ä', 'ö', 'ü', 'ß'};
                if contains(condition_name, patterns_to_replace) % remove underscores as they would mess with BIDS filenames
                    condition_name = strrep(condition_name, '_', '');
                    condition_name = strrep(condition_name, 'ä', 'ae');
                    condition_name = strrep(condition_name, 'ö', 'oe');
                    condition_name = strrep(condition_name, 'ü', 'ue');
                    condition_name = strrep(condition_name, 'ß', 'ss');
                end
                % define pathname
                run = sprintf('%02d', crun);
                trial = sprintf('%02d', ctrial);
                input = struct('prefix', sprintf('parallelTMP%02d_', crun), ...
                    'ext', '', ...
                    'entities', struct('sub', filters.subj, ...
                    'ses', filters.ses, ...
                    'task', filters.task, ...
                    'run', run, ...
                    'space', filters.space, ...
                    'desc', 'LSS', ...
                    'condition', condition_name, ...
                    'trial', trial));
                pathname = bids.File(input, 'use_schema', true);
                tmp_path = fullfile(out_path, pathname.filename); % in order for SPM to run in parallel, it needs to have its own temporary output folder per parfor loop iteration
                tmp_paths{ntrials} = tmp_path; % save all tmp folders to loop through in next loop
                if exist(tmp_path, 'dir') ~= 7
                    mkdir(tmp_path);
                end
        
                % save temporary spmConditions_events.mat for each run
                for i = 1:length(tmp.onsets) % i denotes current run for this subloop within crun loop
                    % find empty cells
                    % explanation: this has generally been done already
                    % before this loop. BUT: If a condition only has one
                    % trial and that is moved to the 'ctrial' condition,
                    % then that condition itself will become empty and
                    % cause a problem with the SPM GLM estimation.
                    % Therefore that condition then needs to be removed
                    % here.
                    emptyIndices = find(cellfun('isempty', tmp.onsets{1,i}));
                    tmp.names{1,i}(emptyIndices) = [];
                    tmp.onsets{1,i}(emptyIndices) = [];
                    tmp.durations{1,i}(emptyIndices) = [];

                    names = tmp.names{i};
                    onsets = tmp.onsets{i};
                    durations = tmp.durations{i};

                    % define filename
                    run = sprintf('%02d', i);
                    input = struct('ext', '.mat', ...
                        'suffix', 'events', ...
                        'entities', struct('sub', filters.subj, ...
                        'ses', filters.ses, ...
                        'task', filters.task, ...
                        'run', run, ...
                        'desc', 'spmConditions'), ...
                        'prefix', 'tmp_');
                    file = bids.File(input, 'use_schema', true);
                    save(fullfile(tmp_path, file.filename), 'names', 'onsets', 'durations');
                end
            end
        end
    end
toc()
end
%% LSS in parallel computing, GLM specification and estimation in SPM
if cfg.lss.doLSS == 1
    estimateLSS(tmp_paths, totalTrials, glm, out_path)
end

%% specify and estimate OLS GLM
if cfg.lss.doLSS == 0
% estimating the GLM overwrites the SPM.mat created by specification step
% create filename
input = struct('ext', '.mat', ...
    'suffix', 'SPM', ...
    'entities', struct('sub', filters.subj, ...
    'ses', filters.ses, ...
    'task', filters.task, ...
    'desc', 'OLS'));
file = bids.File(input, 'use_schema', true);

% specify GLM (creates design matrix)
SPM_univariate_GLM(out_path, glm);

% estimate GLM (estimates betas)
SPM_estimate_GLM(fullfile(out_path, 'SPM.mat'));

% % change filename
% movefile(fullfile(out_path, 'SPM.mat'), fullfile(out_path, file.filename));
end

%% define contrasts
% definition of contrasts has to happen MANUALLY!!! in the job file
% corresponding to the function called in this step!

if cfg.lss.doLSS == 0
% !! WARNING: This will delete existing contrasts in the same folder !!
SPM_contrasts_button(fullfile(out_path, 'SPM.mat'));
end

%% calculate results
% sample batch is in code/SPM_results_1stlevel.mat
% but need to figure out masking, thresholding, output format, etc.
toc(tTotal)
%% local functions
function estimateLSS(tmp_paths, totalTrials, glm, out_path)
% function estimateLSS(tmp_paths, totalTrials, glm)
% REQUIRES function setupLSS to be run beforehand! 
% loops through tmp_paths created by setupLSS() and performs LSS-style GLM
% on each of the temporary folders. It then moves the current trial's
% [ctrial] beta to the parent folder and deletes all other betas in the tmp
% folder, before moving on to the next iteration.
%
% INPUTS:
% tmp_paths:    all temporary paths as created by setupLSS(), meaning they
% have BIDS-conform names with condition-<condition>_trial-<trial> and a
% tmp_sub-<sub>_ses-<ses>_task-<task>_run-<run>_desc-spmConditions_events.mat
% for each run
% totalTrials:  total number of trials in this session
% glm:          struct containing information for specification and
% estimation of the GLM by SPM
% out_path:     path where results are saved, in this case the BIDS derivative
% directory for the currently employed pipeline
%
% OUTPUTS:
% none to workspace. saves one GLM beta per trial conforming with LSS in
% the derivative folder
%
% written by:   Jonathan Wehnert
% current version: 2023.11.15
tic()
ticBytes(gcp);
q = parallel.pool.DataQueue;
afterEach(q, @parforProgress)
iter = 1; % keep track of progress across parallel workers
% second for loop (parallel): estimate the GLMs for each trial
    parfor j = 1:length(tmp_paths)
        glm_parallel = glm; % duplicate glm variable so variable outside of loop does not need to be changed

        % remove all SPM.mat & other results files of previous run
                % from tmp folder
                toDelete = {'mask.nii', 'ResMS.nii', 'RPV.nii', 'SPM.mat'};
                for i = 1:length(toDelete)
                    if exist(fullfile(tmp_paths{j}, toDelete{i}), 'file')
                    delete(fullfile(tmp_paths{j}, toDelete{i}));
                    end
                end
        
                % retrieve paths to GLM conditions.mat files in
                % tmp_paths{j}
        conditions = dir(fullfile(tmp_paths{j}, 'tmp*.mat'));
        glm_parallel.conditions = {conditions.name};
        glm_parallel.conditions = strcat(tmp_paths{j}, filesep, glm_parallel.conditions);
        
        % perform GLM for ctrial
        % specify GLM (creates design matrix)
        sprintf('specifying SPM GLM model for %s', tmp_paths{j}) % print to console to troubleshoot where things went wrong if there are errors
        SPM_univariate_GLM(tmp_paths{j}, glm_parallel);
        % estimate GLM (estimates betas)
        sprintf('estimating SPM GLM model for %s', tmp_paths{j})
        SPM_estimate_GLM(fullfile(tmp_paths{j}, 'SPM.mat'));

        % rename beta of ctrial -> needs to be renamed or moved so
        % it doesn't get deleted during next GLM run
        % find beta of ctrial
        input = load(fullfile(tmp_paths{j}, 'SPM.mat'), 'SPM');
        SPM = input.SPM;
        beta_idx = 0;
        for i = 1:length(SPM.Vbeta)
            if contains(SPM.Vbeta(i).descrip, 'ctrial')
                beta_idx = i;
                break
            end
        end
        beta_fn = SPM.Vbeta(beta_idx).fname;
        beta_fn = fullfile(tmp_paths{j}, beta_fn);
        % rename beta for ctrial and move to out_path
        % to define filename for beta file, just use and adapt
        % folder filename
        input = tmp_paths{j}; % replace one with loop idx
        newfn = bids.File(input, 'use_schema', true);
        newfn.prefix = ''; % remove prefix
        newfn.extension = '.nii';
        newfn.suffix = 'beta';
        movefile(beta_fn, fullfile(out_path, newfn.filename));

        % delete all betas in tmp folder
        delete(fullfile(tmp_paths{j},'beta*'));

        send(q, j);
    end
    
    tocBytes(gcp)
toc()
    function parforProgress(~) % nested function to keep track of parallel worker progress
message = sprintf('\nfinished LSS parfor iteration: %03d of %03d\n', iter, totalTrials);
disp(message);
iter = iter + 1;
end
end



% % currently unused functions below:
% function [onsets, durations] = reorderEventsByConds(events)
% % function that takes a BIDS events.tsv (already read into MATLAB as a
% % struct) and extracts onsets and durations into different struct fields
% % for each condition
% conds = unique(events.trial_type);
% onsets = struct;
% durations = struct;
% for i = 1:numel(conds)
%     idx = find(strcmp(events.trial_type, conds{i}));
%     onsets.(conds{i}) = events.onset(idx);
%     durations.(conds{i}) = events.duration(idx);
% end
% end

