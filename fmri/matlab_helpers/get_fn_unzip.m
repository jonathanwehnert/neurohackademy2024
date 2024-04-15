function [fn, BIDS_dir] = get_fn_unzip(BIDS_dir, filter)
% [fn, BIDS_dir] = get_fn_unzip(BIDS_dir, filter)
% function assumes a filter and looks for matching unzipped niftis (extension =
% '.nii'). if it doesn't find them, it searches for 'nii.gz' instead and
% then unzips those in the same directory
%
% INPUTS:
% BIDS_dir: a BIDS directory as indexed via bids.layout()
% filter:   a filter for files within said directory, conforming to
% bids.query()
%
% OUTPUTS:
% fn:       the file name of the newly unzipped file
% BIDS_dir: same as put in but updated to reflect the newly created files
%
% written by Jonathan Wehnert
% current version: 2023.11.09

filter.extension = '.nii';
fn = bids.query(BIDS_dir, 'data', filter);
if isempty(fn)
    filter.extension = '.nii.gz';
    fn = bids.query(BIDS_dir, 'data', filter);
    gunzip(fn);
    % update fn for unzipped files only
    filter.extension = '.nii';
    % search through BIDS directory
    BIDS_dir = bids.layout(BIDS_dir.pth, 'use_schema', false);
    fn = bids.query(BIDS_dir, 'data', filter);
end
end