#!/bin/bash

# script to remove incomplete fmri runs from dicom folders before (!) calling dcm2bids
#
# custom script that runs through all subdirectories of $directory that
# end in "filename_selector". checks for each if the number of elements exceeds
# $min_volumes. if not, it removes this subdirectory and the preceding directory
# if that ends on *"SBRef"

# Parse command-line arguments
directory_A="$1"
filename_selector="$2"
min_volumes="$3"

# Get a list of all directories in directory_A
all_directories=("$directory_A"/*)

# Initialize variables
directories_to_delete=()
preceding_sbref=""

# Function to count elements recursively
count_elements() {
    local directory="$1"
    local num_elements=$(find "$directory" -mindepth 1 | wc -l)
    echo "$num_elements"
}

# Loop through subdirectories
for ((i=0; i<${#all_directories[@]}; i++)); do
    subdirectory="${all_directories[$i]}"

    # Check if the current subdirectory matches the filename_selector
    if [[ -d "$subdirectory" && "$subdirectory" == *"$filename_selector" ]]; then
        # Count the number of elements in each subdirectory recursively
        num_elements=$(count_elements "$subdirectory")

        # Check if the number of elements is less than min_volumes
        if [ "$num_elements" -lt "$min_volumes" ]; then
            # Check if there is a preceding subdirectory
            if [ -n "$preceding_sbref" ]; then
                # Save the preceding subdirectory to the list
                directories_to_delete+=("$preceding_sbref")
                echo "Preceding SBRef Subdirectory: $preceding_sbref"
            fi

            # Save the current subdirectory to the list
            directories_to_delete+=("$subdirectory")
            echo "Subdirectory: $subdirectory has $num_elements elements (less than $min_volumes)"
        fi
    fi

    # Update the variable for the next iteration
    preceding_sbref="${all_directories[$i]}"
done

# Delete the directories in directories_to_delete
for dir_to_delete in "${directories_to_delete[@]}"; do
    rm -r "$dir_to_delete"
    echo "Deleted: $dir_to_delete"
done