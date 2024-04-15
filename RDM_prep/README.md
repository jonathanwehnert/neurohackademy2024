first, create a conda environment using the environment.yml in this directory
activate that environment

to create an RDM based on fasttext vectors of individual words:
WARNING: This will download a pre-trained German-language fasttext model. ~4.5GB download size, requires ~12GB of storage
run get_fasttext_vectors.py
(this gets the vectors AND computes/saves the RDM)

to create an RDM based on mediapipe-derived landmark vectors of videos:
run create_landmark_RDM.py
(this uses pre-computed landmark vectors, stored in sample_stimuli/gestures_pose.
If you want to see the landmark vector computation itself, see the README in mediapipe_estimate_pose_hands directory)
