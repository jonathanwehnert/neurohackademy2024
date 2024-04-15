function SPM_contrasts_button(SPMmatpath)
% function to call SPM_contrasts_button_job.m and create contrasts
% those contrasts need to be manually altered in the job file!
nrun = 1; % enter the number of runs here
[cpath, fn] = fileparts(mfilename); % determine path and filename of this file
jobfile = {fullfile(cpath, [fn '_job.m'])}; % construct path and filename of jobfile from the above
jobs = repmat(jobfile, 1, nrun);
inputs = cell(0, nrun);
inputs{1,1} = cellstr(SPMmatpath);
spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('run', jobs, inputs{:});
end