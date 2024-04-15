conda activate dcm2bids

project_dir="$HOME/Documents/analysis/fl_bilingual"
code_dir="$project_dir/6_ExperimentScripts/analysis/fmri"
BIDS_dir="$project_dir/7_data/pilot/BIDS"
source_dir1="$BIDS_dir/sourcedata/pilot01/26265_1"
source_dir2="$BIDS_dir/sourcedata/pilot01/26390_2"


cd $BIDS_dir

# remove incomplete fmri runs (script finds all runs with less than 150 volumes)
"$code_dir"/remove_incomplete_fmri_runs.sh "$source_dir1" "cmrr_mbep2d_bold_2.5iso" 150  # change to 168!
"$code_dir"/remove_incomplete_fmri_runs.sh "$source_dir2" "cmrr_mbep2d_bold_2.5iso" 150  # change to 168!


# to-do: make this loop (at least within participant across sessions)
# for now, the sourcedata/* paths are hard-coded, as are the participant and session codes
# in this experiment, both sessions have identical fMRI protocols, but participants perform different tasks in each session
# hence, two different config.json files, that are identical except for the task-name properties
dcm2bids -d "$source_dir1" -p pilot01 -s 01 -c "$code_dir/dcm2bids_config_german.json" --auto_extract_entities
dcm2bids -d "$source_dir2" -p pilot01 -s 02 -c "$code_dir/dcm2bids_config_english.json" --auto_extract_entities
