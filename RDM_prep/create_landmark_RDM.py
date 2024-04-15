"""
create_landmark_RDM.py
script to create a RDM from the pose & hand landmark vectors as obtained
for the gesture videos in the FL_BILINGUAL study.

- takes pose landmark, left handmark, right handmark arrays (as created in separate script)
- combines them into one array (landmarks_3d) and makes each dimension of the coordinate system (x, y, z)
its own value
- creates channel names and timing vector (both hard-coded)
- creates an rsatoolbox.data.TemporalDataset from landmarks_3d
- bins it over time (i.e. makes it non-temporal by instead creating one condition per condition x timepoint)
- calculates an RDM from this dataset (using cross-validation)

required conda environment: RDM_prep (on Linux office workstation)
current version: 2024-01-17
written by: Jonathan Wehnert
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import rsatoolbox
import os

from rsatoolbox.rdm import calc_rdm_movie


# directory with gesture landmark data:
# get location of this script:
script_path = os.path.abspath(__file__)
script_dir = os.path.abspath(os.path.dirname(script_path))
# path relative to this script's location
relative_path = '../../../1_Organisation/Materials/Stimuli/gestures/FL_BILINGUAL_gestures_pose/'
input_dir = os.path.normpath(os.path.join(script_dir, relative_path))
fps = 50 # hard-coded fps of videos for timing vector

# load landmark arrays
pose_landmarks = np.load(os.path.join(input_dir, 'pose_landmarks.npy'))
lh_landmarks = np.load(os.path.join(input_dir, 'lh_landmarks.npy'))
rh_landmarks = np.load(os.path.join(input_dir, 'rh_landmarks.npy'))

# reduce the pose landmark array:
# what to use: everything from the left and right hand arrays;
# what to use: everything from the pose array, EXCEPT the hands (15-22) and the legs/feet (25-32)
pose_idx = np.arange(0,15) # face, shoulders, elbows
pose_idx = np.append(pose_idx, [23, 24]) # hips
pose_landmarks = pose_landmarks[:, :, pose_idx, :]
# combine the 3 landmark ndarrays:
landmarks = np.append(pose_landmarks, lh_landmarks, 2)
landmarks = np.append(landmarks, rh_landmarks, 2)

# transform 4-dimensional landmarks array (video/condition, frame/time, landmark/channel, coordinate/'sub-channel')
# into 3-dimensional rsatoolbox-compatible array (conditions, channels, times)
landmarks_3d = landmarks.reshape((landmarks.shape[0], landmarks.shape[1], landmarks.shape[2] * landmarks.shape[3])) # landmarks_3d is of shape (video, frame, coordinate)
# the coordinates are ordered as: landmark1.x, landmark1.y, landmark1.z, landmark2.x, landmark2.y, ...
landmarks_3d = np.transpose(landmarks_3d, (0, 2, 1)) # swap dimensions to achieve rsatoolbox-compatible (video, coordinate, frame)

# create DESCRIPTORS for RDM data object
# load landmark video labels
cond_names = pd.read_csv(os.path.join(input_dir, 'landmark_inputs.csv'), header=None)
cond_names = cond_names.T.squeeze().tolist()
# make cond_idx ; very simple here: each video only has one datapoint (i.e. 'trial') and their order is the same as that of cond_names
cond_idx = np.arange(1, len(cond_names) + 1)
# make times vector of length = max. frame# in landmarks_3d; timing is hard-coded here at 50fps
times = np.arange(0, landmarks_3d.shape[2]/fps, 1/fps)
# make channel names
raw_text_pose = """
0 - nose
1 - left eye (inner)
2 - left eye
3 - left eye (outer)
4 - right eye (inner)
5 - right eye
6 - right eye (outer)
7 - left ear
8 - right ear
9 - mouth (left)
10 - mouth (right)
11 - left shoulder
12 - right shoulder
13 - left elbow
14 - right elbow
15 - left wrist
16 - right wrist
17 - left pinky
18 - right pinky
19 - left index
20 - right index
21 - left thumb
22 - right thumb
23 - left hip
24 - right hip
25 - left knee
26 - right knee
27 - left ankle
28 - right ankle
29 - left heel
30 - right heel
31 - left foot index
32 - right foot index
"""

raw_text_hand = """
0 - wrist
1 - thumb_cmc
2 - thumb_mcp
3 - thumb ip
4 - thumb tip
5 - index finger mcp
6 - index finger pip
7 - index finger dip
8 - index finger tip
9 - middle finger mcp
10 - middle finger pip
11 - middle finger dip
12 - middle finger tip
13 - ring finger mcp
14 - ring finger pip
15 - ring finger dip
16 - ring finger tip
17 - pinky mcp
18 - pinky pip
19 - pinky dip
20 - pinky tip
"""


def listify_newline(raw_text):
    # Split the text into lines and extract the relevant information
    lines = raw_text.strip().split('\n')
    lines = [line.split('-') for line in lines]
    # Create the Python list including the first letter of each row
    text_list = [item[1].strip() for item in lines]
    # Substitute each space character with an underscore
    text_list = [text.replace(' ', '_') for text in text_list]
    return text_list


pose_list = listify_newline(raw_text_pose)
pose_list = [pose_list[i] for i in pose_idx] # remove hands from pose_list
hand_list = listify_newline(raw_text_hand)
lh_list = ['left_' + string for string in hand_list]
rh_list = ['right_' + string for string in hand_list]
channel_names = pose_list + lh_list + rh_list
channel_names = [f'{item}_{suffix}' for item in channel_names for suffix in ['x', 'y', 'z']]  # repeat 3 times and
# append coordinate markers

measurements = landmarks_3d  # for ease of use, rename to 'measurements' to stay in line with rsatoolbox nomenclature

np.save('landmarks_by_word_and_frame.npy', measurements)  # saving a copy of the data going into the RSA Dataset (to
# use for PCA and anticluster in R later)

### SETTING UP THE RSA TOOLBOX DATASET ###
des = {'modality': 'mediapipe_landmarks'}
obs_des = {'conds': cond_names}
chn_des = {'channels': channel_names}
tim_des = {'time': times}

data = rsatoolbox.data.TemporalDataset(measurements,
                                       descriptors=des,
                                       obs_descriptors=obs_des,
                                       channel_descriptors=chn_des,
                                       time_descriptors=tim_des)
data.sort_by('conds')


## bin data across time - all observations *of each timepoint* get marked as separate observations (of the same conditions)
# so I get one giant vector over conditions (that really are conditions x timepoints) and therefore reduce this to a 'non-temporal' datset
data_binned = data.time_as_observations('time')
# calculate RDM for *unbalanced* data (unfortunately not currently possible for RDM movie; NOTE: apparently possible with rsatoolbox v0.1.5), this deals with missing data by weighting!
cv_desc = np.repeat(np.arange(0, len(cond_names)), len(times))  # make cross-validation descriptor (labeling each frame of the videos as their own session here)
data_binned.obs_descriptors['cv_desc'] = cv_desc
landmark_rdm_binned = rsatoolbox.rdm.calc_rdm_unbalanced(data_binned, method='crossnobis',
                                   descriptor='conds', cv_descriptor='cv_desc')  # use CV (crossnobis distance) to avoid bias due to unbalanced dataset

rsatoolbox.vis.show_rdm(landmark_rdm_binned,
                        pattern_descriptor='conds')
print(landmark_rdm_binned)
# save landmark RDM to disk; once RDM is finalized, change to overwrite=False
landmark_rdm_binned.save('landmark_RDM_binned.hdf5', file_type='hdf5', overwrite=True)  # save landmark RDM to disk


# # test-section:
# # compare landmark to fasttext RDM
ft_dis = np.load('ft_300_cosine_dissimilarities.npy')
ft_dis = ft_dis[np.newaxis, :, :]  # rsatoolbox.rdm.RDMs requires nparray of dissimilarities in shape (n_rdm x n_cond x n_con)
ft_rdm = rsatoolbox.rdm.RDMs(ft_dis)
r_binned = rsatoolbox.rdm.compare(ft_rdm, landmark_rdm_binned, method='rho-a')

# RDM movie: create RDM for each frame (gives error after 120th frame, because of nans then),
# compare each frame's RDM to fastText RDM, plot cosine distance over time
r = []
# WARNING: This fails at t = 2.38, as there are nans in rdm_loc (only few videos have that many frames)
for t in times:
    data_loc = data.subset_time('time', t_from=t, t_to=t)
    data_loc = data_loc.time_as_observations('time')
    rdm_loc = rsatoolbox.rdm.calc_rdm_unbalanced(data_loc,
                                                 method='euclidean',
                                                 descriptor='conds')
    r.append(rsatoolbox.rdm.compare(ft_rdm, rdm_loc, method='rho-a')[0][0])

plt.figure()
plt.plot(times[:len(r)], r)
plt.xlabel('time (s)')
plt.ylabel('rho-a correlation')
plt.suptitle('Correlation between RDMs across 40 gesture videos, based on:\n'
          '1) 300 dimensional fastText vectors,\n'
          '2) 177 dimensional hand and pose landmarks\n'
          'at each frame of the videos')
plt.title(f'mean correlation across frames: rho-a = {round(np.mean(r), 3)}\n'
          f'correlation when comparing fastText RDM against landmark\n'
          f'RDM created from all frames binned together: rho-a = {round(r_binned[0][0], 3)}')
plt.tight_layout()  # ensure the title fits into the figure
plt.savefig('gesture-landmark_to_fasttext_fit_across_frames.png')

## notes
# apparently, if for only one of the two conditions being compared for an RDM only one element of its measurements vector is missing
# there is no distance calculated whatsoever, resulting in an nan in the RDM for that comparison
# maybe it would be better to get RDM movies separately for the pose model, left hand, and right hand models?
# that way, each would have fewer nans, and then later they could still be averaged?
# so at least the information we do have doesn't get lost?
# example: for a condition at a given frame there is pose data but no hand data. currently that results in comparison = nan
# then we would get a pose RDM comparison, and only nan in the hand RDMs;
# after averaging, the pose RDM value would remain - albeit overweighted
#
# --> NO! instead, use calc_rdm_unbalanced(), which can deal with nans and will just weight values based on fewer data differently
# --> unfortunately doesn't exist for calc_rdm_movie(), so can only use on non-temporal RDMs for now

