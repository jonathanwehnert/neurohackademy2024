in order to obtain mediapipe vectors for pose and hand models from the sample stimulus videos in sample_stimuli/gestures: 
- create a conda environment using the environment.yml in this directory
- next, in this conda environment, run estimate_pose_hands.py; done!

afterwards, if you want to create a RDM between the landmark vectors of each video, go to RDM_prep directory. There:
- create a conda environment using the environment.yml in this (RDM_prep) directory
- next, in that conda environment, run create_landmark_RDM.py; done!
