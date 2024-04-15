function SPM_univariate_GLM(out_path, glm)
% List of open inputs
nrun = 1; % enter 1, as this is the amount of times it runs the jobfile
nruns = glm.meta.nruns; % enter the number of runs in your fMRI session
[cpath, fn] = fileparts(mfilename); % determine path and filename of this file
jobfile = {fullfile(cpath, [fn '_job.m'])}; % construct path and filename of jobfile from the above
jobs = repmat(jobfile, 1, nrun);
inputs = cell(1, nrun);
inputs{1,1} = cellstr(out_path);
inputs{2,1} = glm.meta.TR;
inputs{3,1} = glm.meta.microRes;
inputs{4,1} = glm.meta.microOnset;

for crun = 1:nruns
    inputSize = size(inputs, 1);
    inputs{inputSize + 1,1} = glm.scans(crun);
    inputs{inputSize + 2,1} = glm.conditions(crun);
    inputs{inputSize + 3,1} = glm.regressors(crun);
end
inputSize = size(inputs, 1);
inputs{inputSize + 1,1} = glm.mask;

spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('run', jobs, inputs{:});
end