# script to set up a BIDS compliant directory and set up the dcm2bids_config.json
# this script is meant to be run manually line-by-line as and when necessary when first setting up the directory
# afterwards, a more standardized script will be used to run dcm2bids over new incoming data within the BIDS directory

# script following this tutorial:
# https://unfmontreal.github.io/Dcm2Bids/3.1.1/tutorial/first-steps/

conda activate dcm2bids

# important: set XNAT download settings as follows:
# Option 2: ZIP download
# only check "include subject in file paths", none of the other options
# i.e. uncheck "simplify downloaded archive structure"
#
# then, download a single subject's single session (all images at once. you don't need to select which images to
# download, you can simply download everything. unnecessary images will be removed by remove_incomplete_fmri_runs.sh
# and dcm2bids
#
# next, manually drag downloaded ZIP file into BIDS_dir/sourcedata and extract there
#   if this is a subject's 2nd session, integrate files into existing subject directory?
# delete unextracted ZIP file
#
# change path for dir_for_helper as required
# change path for dcm2bids call as required

project_dir="$HOME/Documents/analysis/fl_bilingual"
fmriprep_wd="$project_dir/7_data/pilot/fmriprep_wd"
audio_dir="$project_dir/1_Organisation/Materials/Stimuli/FL_BILINGUAL_STIMULI"
code_dir="$project_dir/6_ExperimentScripts/analysis/fmri"
BIDS_dir="$project_dir/7_data/pilot/BIDS"
dir_for_helper="$BIDS_dir/sourcedata/pilot01/26265_1/scans"

mkdir "$fmriprep_wd"
## if needed, create project directory
#mkdir $BIDS_dir
cd $BIDS_dir
# yet another nested directory? otherwise remove -o flag. build bids scaffold
dcm2bids_scaffold
# copy audio files to stimuli/ so that BIDS won't complain about missing stimulus files
mkdir "$BIDS_dir/stimuli"
cp -R "$audio_dir/final_audio_english" "$audio_dir/final_audio_german" "$audio_dir/final_audio_vimmi" "$BIDS_dir/stimuli/"
## move DICOM data into sourcedata/  # probably best to do this manually
# mv source_data_path sourcedata/dcm_qa_nih

# before calling dcm2bids_helper, make sure to delete all incomplete fMRI runs
# using remove_incomplete_fmri_runs.sh
# supply 3 arguments:
# 1) folder to loop through (generally: $BIDS_dir/sourcedata/subject/session/scans/)
# 2) name of directories with BOLD sequences (NOT SBRef sequences)
# 3) 2 + minimum number of volumes for a run to be considered complete (the additional 2 accounts for the folder structure of ./resources/DICOM/, each of which is counted as an element)
"$code_dir"/remove_incomplete_fmri_runs.sh "$dir_for_helper" "cmrr_mbep2d_bold_2.5iso" 150  # change to 168!

# instead of doing this manually, make sure it loops over all subdirectories of $BIDS_dir/sourcedata/
dir_for_helper="$BIDS_dir/sourcedata/pilot01/26390_2/scans"
"$code_dir"/remove_incomplete_fmri_runs.sh "$dir_for_helper" "cmrr_mbep2d_bold_2.5iso" 150  # change to 168!

# convert single session of single participant to NIfTI to help create dcm2bids config file
dcm2bids_helper -d "$dir_for_helper"

## compare JSON files to highlight their differences (use text editor)
## to find something in a file's json that is unique (perhaps the "SeriesDescription" field, try it across all jsons via grep, e.g.:)
#grep "Axial EPI-FMRI*" tmp_dcm2bids/helper/*.json # --> in this case, matches too many files --> make more specific
#grep "Axial EPI-FMRI (Interleaved I to S)*" tmp_dcm2bids/helper/*.json # --> this works!

## once you know which data you want to BIDSify, set up configuration file in code/
#nano code/dcm2bids_config.json

# once the config.json is fully set up, check its validity, e.g. at:
# https://jsonlint.com/

## dcm2bids requires you to be in the BIDS directory you're operating on
## cd BIDS
## then, run dcm2bids, minimally like this:
#dcm2bids -d path/to/source/data -p subID -s sesID -c path/to/config/file.json --auto_extract_entities
## --auto_extract_entities looks for some features that are not necessarily in config file to name nifti files
## in this example, you'd run:
#dcm2bids -d sourcedata/dcm_qa_nih/In/ -p 01 -s 01 -c code/dcm2bids_config.json --auto_extract_entities


# to-do: make this loop (at least within participant across sessions)
# for future participants, this is shorthanded in run_dcm2bids.sh
dcm2bids -d sourcedata/pilot01/26265_1/ -p pilot01 -s 01 -c "$code_dir/dcm2bids_config_german.json" --auto_extract_entities
dcm2bids -d sourcedata/pilot01/26390_2/ -p pilot01 -s 02 -c "$code_dir/dcm2bids_config_english.json" --auto_extract_entities

