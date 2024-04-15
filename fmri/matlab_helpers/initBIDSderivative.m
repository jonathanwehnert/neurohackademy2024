function out_path = initBIDSderivative(BIDS_dir, pipeline, filters)
% create BIDS derivatives style output folder and subfolders for current
% data. note: this does not overwrite existing subfolders but DOES
% overwrite CHANGES, README, and dataset_description.json, so if editing
% these before data analysis is finished, I would need to save them under
% different names for the meantime.
%
% INPUTS:
% BIDS_dir: path to overarching BIDS directory (the one with the raw data)
% pipeline: current processing stream; this will be the name of the
% derivatives folder in BIDS_dir/derivatives/pipeline
% filters:  struct containing parameters to use as filters with
% bids.query() to obtain select files from a BIDS directory, such as
% subject, session, task, modality, space, ...
%
% OUTPUT:
% out_path: path to the new derivatives folder
%
% written by Jonathan Wehnert
% current version: 2023.11.09

deriv_path    = fullfile(BIDS_dir, 'derivatives', pipeline);
folders.subjects    = {filters.subj};
folders.sessions    = {filters.ses};
folders.modalities  = {filters.modality};
bids.init(deriv_path, 'folders', folders, 'is_derivative', true);

out_path = fullfile(deriv_path, ['sub-' filters.subj], ['ses-' filters.ses], filters.modality);
end