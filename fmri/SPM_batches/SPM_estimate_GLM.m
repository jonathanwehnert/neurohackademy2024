function SPM_estimate_GLM(SPMmat)
% List of open inputs
% Model estimation: Select SPM.mat - cfg_files
nrun = 1; % enter the number of runs here
[cpath, fn] = fileparts(mfilename); % determine path and filename of this file
jobfile = {fullfile(cpath, [fn '_job.m'])}; % construct path and filename of jobfile from the above
jobs = repmat(jobfile, 1, nrun);
inputs = cell(1, nrun);
for crun = 1:nrun
    inputs{1, crun} = cellstr(SPMmat); % Model estimation: Select SPM.mat - cfg_files
end
spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('run', jobs, inputs{:});
end