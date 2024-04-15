NOTE: None of this will run out of the box due to this project not being open-data. If you wish to use some of these scripts, adapt any paths so they point to YOUR data.

when first creating a BIDS directory:
- run dcm2bids_manual-setup.sh manually, line-by-line, to setup BIDS directory and test on data from one subject and one session
- requires: dcm2bids_config.json
- requires: conda activate dcm2bids (set up using dcm2bids_environment.yaml)
- does:
  - sets up BIDS directory
  - automatically removes all BOLD DICOM folders with too few volumes, i.e. interrupted/incomplete runs via remove_incomplete_fmri_runs.sh
  - converts data for 1 sub, 1 ses
  - adds all audio stimulus files as listed in *events.tsv[stim_file] to BIDS/stimuli/

also do/add the following:
- add dataset_description.json (to-do: make standard version in git repo)
  - dataset name
  - authors
- add events.json (to-do: make standard version in git repo)

when adding new data:
- run run_dcm2bids.sh to convert DICOM to BIDS-conform NIfTI
- update BIDS/participants.tsv --> maybe the script can do that automatically?
- run MRIQC
- run fmriprep
- at some point: add events.tsv files (via script?)

you're now ready to:
- run FLB_1stlevel_GLM.m (does univariate and multivariate (LSS) GLMs for one session?)
