function [names, onsets, durations] = createSPMconditions(events, names)
% [names, onsets, durations] = createSPMconditions(events, names)
% function that takes a BIDS events.tsv (already read into MATLAB as a
% struct) and extracts onsets and durations into different cells 
% for each condition
% when all three outputs are saved as one .mat file, they are compatible
% with SPM's Multiple Conditions field for GLM estimation
%
% INPUTS:
% events:   a MATLAB struct of events as obtained from a BIDS-conform
% events.tsv via bids.util.tsvread
% names:    [optional] cell array of characters. Will be matched with every trial_type
% that CONTAINS() them (does NOT need to be an exact match)
%
% OUTPUTS:
% names:    same as input, if given. otherwise all unique entries for
% trial_type as a cell array
% onsets:   cell array. for each condition (name), one cell with all its onsets
% durations:    as onsets, but for durations
%
% written by Jonathan Wehnert
% current version: 2023.11.09

% check if user supplied specific condition names to match the trial_type
% column. If not, just make a condition of every unique trial type
% prevalent.
% names must be supplied as a 
if ~exist('names', 'var')
    names = unique(events.trial_type);
end
onsets = cell(0);
durations = cell(0);
for i = 1:numel(names)
    idx = find(contains(events.trial_type, names{i}));
    onsets{1,i} = events.onset(idx);
    durations{1,i} = events.duration(idx);
end
end