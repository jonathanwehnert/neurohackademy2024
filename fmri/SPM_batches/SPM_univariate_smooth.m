function SPM_univariate_smooth(infn, sm_kernel, prefix)
% function SPM_univariate_smooth(infn)
% function to call SPM batch to smooth input image (infn)
% infn:         must be .nii
% sm_kernel:    desired smoothing kernel in mm, e.g. [5 5 5]
% prefix:       prefix [char] that SPM puts before output filenames

nrun = 1; % enter the number of runs here
[cpath, fn] = fileparts(mfilename); % determine path and filename of this file
jobfile = {fullfile(cpath, [fn '_job.m'])}; % construct path and filename of jobfile from the above
jobs = repmat(jobfile, 1, nrun);
inputs = cell(1, nrun);
inputs{1,1} = cellstr(infn);
inputs{2,1} = sm_kernel;
inputs{3,1} = prefix;
spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('run', jobs, inputs{:});
end