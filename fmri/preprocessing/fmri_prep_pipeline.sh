# custom pipeline to go from DICOM to preprocessed fMRI data
# assumes that a BIDS directory for the data has been set up, as well as a config.json file for dcm2bids
# if not, use dcm2bids_scaffold & dcm2bids_helper to do so

# this is not yet a loop but to be run per participant, might change later

project_dir="$HOME/Documents/analysis/fl_bilingual"
code_dir="$project_dir/6_ExperimentScripts/analysis/fmri"
BIDS_dir="$project_dir/7_data/pilot/BIDS"
fmriprep_wd="$project_dir/7_data/pilot/fmriprep_wd"

subID="pilot01"
sesID="identicalSbrefs"

# first, run dcm2bids, minimally like this:
conda activate dcm2bids
dcm2bids -d path/to/source/data -p subID -s sesID -c path/to/config/file.json --auto_extract_entities
conda deactivate
# --auto_extract_entities looks for some features that are not necessarily in config file to name nifti files

# next, do some quality checks using MRIQC v23.1.0 (no specific reason for this version, other than it being the one I started with)
# Docker Desktop needs to be running in the background for this to work!

# docker run -it nipreps/mriqc:23.1.0 --version # this line only needed to verify that Docker and correct MRIQC version are installed
docker run -it --rm -v $BIDS_dir:/data:ro -v $BIDS_dir/derivatives/mriqc:/out nipreps/mriqc:23.1.0 /data /out participant

# check the MRIQC results before continuing!

# run fmriprep

# before running fmriprep, replace all SBRefs with the SBRef of the 1st run of the 1st session (so that all runs get aligned to the first run)
# call: replace_sbrefs.py <BIDS directory> <subject ID> <session ID>
python "$code_dir"/replace_sbrefs.py $BIDS_dir $subID $sesID

# source the bash profile which exports $FS_LICENSE (provided this is installed on the given PC)
cd ~
source .bash_profile
# run fmriprep
fmriprep-docker $BIDS_dir $BIDS_dir/derivatives/fmriprep participant -w $fmriprep_wd --output-spaces MNI152NLin2009cAsym anat func --track-carbon --country-code DEU -i nipreps/fmriprep:23.2.1

# fmriprep writes an empty "IntendedFor": [] into the *fieldmap.json files
# this confuses bids.layout in Matlab and needs to be removed before calling the GLM functions in Matlab that depend on it
# the below line goes through all subjects and sessions and removes the line
# "IntendedFor": [],
# from all fmap/*.json files
out_dir="$BIDS_dir/derivatives/fmriprep"
find "$out_dir" -path "$out_dir/sub-*/ses-*/fmap/*.json" -type f -exec sed -i '/"IntendedFor": \[\],/d' {} \;


# once fmriprep has run, create derivatives folders for SPM to place GLM results in
cd $BIDS_dir/derivatives
mkdir "SPM_univariate"
mkdir "SPM_LSS"

# from here, move on to MATLAB and SPM for further preprocessing of univariate (smoothing, GLM) and multivariate (GLM, LSS) analyses
# FLB_1stlevel_GLM.m smoothes the normalized func images and performs standard OLS as well as LSS GLM
# for now, you'd need to run it twice: once set to OLS and smoothing; and separately set to LSS and no smoothing
