function entity = moveTrialForLSS(entity, crun, ccond, ctrial)
% entity = moveTrialForLSS(entity, crun, ccond, ctrial)
% requires to work on a set of onsets or durations structured for regular
% *conditions.mat files for SPM GLM multiple condition definitions.
% requires to be used within a set of for loops looping through said set by
% run [crun], condition [ccond], and trial [ctrial]
% extracts the current trial's data for [entity] and moves it to the
% beginning of the cell array in entity{crun} and removes it from its
% original position. all other conditions are pushed out by one position
% with the cell array
%
% INPUTS:
% entity:   can be either onsets or durations struct, composed of at least
% one run, condition, trial in the following structure:
% entity.run{cond}(trial)
% OUTPUT:
% entity:   the same entity, but reordered for one GLM estimation for
% ctrial according to LSS (Mumford et al., 2014)
%
% written by Jonathan Wehnert
% current version: 2023.11.10

entity{crun} = [cell(1,1) entity{crun}];
entity{crun}{1} = entity{crun}{ccond+1}(ctrial);
entity{crun}{ccond+1}(ctrial) = [];
end