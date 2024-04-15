function [BIDSraw, meta, glm] = getBOLDMetadataForGLM(BIDS_dir, filters)
% function [BIDS, meta, glm] = getBOLDMetadataForGLM(BIDS_dir)
% obtains metadata from raw (non-preprocessed) BOLD data to use as parameters for
% GLM in SPM
%
% INPUTS:
% BIDS_dir: path to BIDS directory containing the raw BOLD data
% filters:  struct containing parameters to use as filters with
% bids.query() to obtain select files from a BIDS directory, such as
% subject, session, task, modality, space, ...
%
% OUTPUTS:
% BIDS:     struct describing BIDS_dir via bids.layout
% meta:     struct containing all of the derived metadata
% glm:      struct containing metadata relevant for the GLM
%
% written by Jonathan Wehnert
% current version: 2023.11.10

BIDSraw = bids.layout(BIDS_dir);
filter = struct(...
    'sub', filters.subj, ...
    'ses', filters.ses, ...
    'run', '01', ...    % WARNING: This assumes that metadata is consistent across runs! And therefore only looks at the first run
    'task', filters.task, ...
    'suffix', 'bold');
meta.raw = bids.query(BIDSraw, 'metadata', filter);

glm.meta.TR = meta.raw.RepetitionTime; % TR
glm.meta.microRes = length(meta.raw.SliceTiming) / meta.raw.MultibandAccelerationFactor; % # of slices = microtime resolution % shouldn't this be # of slices divided by MB factor??
glm.meta.microOnset = round(glm.meta.microRes / 2); % middle slice = microtime onset (ignores DelayTime! figure out if this is a problem with eventual scan protocol's data)
end