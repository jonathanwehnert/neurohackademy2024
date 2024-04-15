function [fn, cfg, lss] = extractOnsets(BIDSraw, filters, glm, cfg, fn, out_path, names)
% [fn, cfg, lss] = extractOnsets(BIDSraw, filters, glm, cfg, names)
% 1) reads in BIDS-style *events.tsv files from raw BIDS directory according
% to filters
% 2) extracts names, onsets, and durations per run via
% createSPMconditions()
% 3a) returns struct lss with names, onsets, and
% durations per run to continue creating SPM style *conditions.mat in a
% later function
% 3b) if cfg.lss.doLSS = 0 saves these as SPM-compatible *conditions.mat
% files for OLS GLMs
%
% INPUTS:
% BIDSraw:  BIDS directory containing the raw BOLD data
% filters:  struct containing parameters to use as filters with
% bids.query() to obtain select files from a BIDS directory, such as
% subject, session, task, modality, space, ...
% glm:      struct containing metadata relevant for the GLM
% cfg:      struct containing settings
% fn:       struct containing filenames
% out_path: path where results are saved, in this case the BIDS derivative
% directory for the currently employed pipeline
% names:    [cell array] limits the conditions extracted from *events.tsv
% to those containing one of the cells specified in names
%
% OUTPUTS:
% fn:       struct containing filenames
% cfg:      struct containing settings
% lss:      struct containing once cell per run, containing names, onsets,
% and durations for that run
%
% written by Jonathan Wehnert
% current version: 2023.11.10

% get all events.tsv filenames
filter = struct(...
    'sub', filters.subj, ...
    'ses', filters.ses, ...
    'task', filters.task, ...
    'suffix', 'events');
fn.events = bids.query(BIDSraw, 'data', filter);

% loop across all runs
for crun = 1:glm.meta.nruns
    % read them into a MATLAB struct
    events = bids.util.tsvread(fn.events{crun});
    % this function reads events by condition into a SPM-compatible
    % multiple conditions cell
    % specify which donditions you want to extract
    if ~exist('names', 'var')
        [names, onsets, durations] = createSPMconditions(events);
    else
        [names, onsets, durations] = createSPMconditions(events, names);
    end

    lss.names{crun} = names;
    lss.onsets{crun} = onsets;
    lss.durations{crun} = durations;
    if cfg.lss.doLSS == 0
        % save these 3 cells as an SPM-compatible .mat file in the session's folder
        % in the SPM univariate derivative folder
        % create filename
        run = sprintf('%02d', crun);
        input = struct('ext', '.mat', ...
            'suffix', 'events', ...
            'entities', struct('sub', filters.subj, ...
            'ses', filters.ses, ...
            'task', filters.task, ...
            'run', run, ...
            'desc', 'spmConditions'));
        file = bids.File(input, 'use_schema', true);
        % if exist(fullfile(out_path, file.filename), 'file') ~= 2
        save(fullfile(out_path, file.filename), "names", "onsets", "durations");
        % end
    end
end