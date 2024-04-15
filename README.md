Hey there! This repo is specifically tailored to my application to the 2024 NeuroHackademy, thanks for checking it out!
I usually keep most of my stuff on a university-hosted GitLab server, hence everything here is fairly copy/paste and without any actual data (so not all scripts will work, but some will).

Here's what you can find here:
(Each of the directories has its own README with more detailed descriptions/instructions)
- mediapipe_estimate_pose_hands
  - takes videos from sample_stimuli/gestures and applies Google's MediaPipe to create body pose and hand landmark vectors for each frame
- RDM_prep
  - create_landmark_RDM.py: takes results from MediaPipe and calculates an RDM between the landmark vectors of multiple videos, using the rsatoolbox
  - get_fasttext_vectors.py: for a list of German words, gets their feature vectors from a pre-trained fasttext model, then calculates an RDM between them, using the rsatoolbox
- fmri
  - preprocessing: takes DICOMs and converts them to NIfTI (provided one has the same scan parameters as our data does..); runs fmriprep
  - FLB_1stlevel_GLM.m: runs single trial 1st level GLMs following Mumford et al., 2014 via SPM in MATLAB
