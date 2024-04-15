"""
estimate_pose_hands.py
script to obtain pose & hand landmark vectors from video via Google's MediaPipe

- takes path with videos as input (mediapipe_indir)
- performs the following for each *.mp4 file in given directory:
    - apply pose model
    - apply left & right hand models
    - remove vectors irrelevant to current study (mainly the not-shown legs)
    - save npy array of each model over time (i.e. frames)
    - save video with vectors overlaid to mediapipe_outdir

required conda environment: mediapipe_estimate_pose_hands (on MacBook)
current version: 2024-03
written by: Jonathan Wehnert
"""

import copy
import os
import cv2
import mediapipe as mp
import numpy as np
import csv

# relevant description of the results_pose format:
# https://developers.google.com/mediapipe/solutions/vision/pose_landmarker/python#handle_and_display_results

# WARNING: At the very bottom of this script, several landmark locations (everything below the hips) get REMOVED!
# this is because for these specific videos, they are not displayed in the videos. Change this as desired!

# get location of this script:
script_path = os.path.abspath(__file__)
script_dir = os.path.abspath(os.path.dirname(script_path))
# path to audio files directory, relative to this script's location
relative_path = '../sample_stimuli'
main_dir = os.path.normpath(os.path.join(script_dir, relative_path))

mediapipe_indir = os.path.join(main_dir, 'gestures')
mediapipe_outdir = os.path.join(main_dir, 'gestures_pose')

# select all files that are *.mp4 files in mediapipe_indir
input_video_path = [f for f in sorted(os.listdir(mediapipe_indir)) if f.endswith('.mp4')]

if not os.path.exists(mediapipe_outdir):
    os.makedirs(mediapipe_outdir)

# Initialize MediaPipe Pose.
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(static_image_mode=False,
                    model_complexity=2,
                    smooth_landmarks=True,
                    enable_segmentation=False,
                    min_detection_confidence=0.5,
                    min_tracking_confidence=0.5)

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=False,
                       max_num_hands=2,
                       model_complexity=1,
                       min_detection_confidence=0.5,
                       min_tracking_confidence=0.5)

# Initialize MediaPipe drawing module for annotations.
mp_drawing = mp.solutions.drawing_utils
mp_drawing_styles = mp.solutions.drawing_styles

# Define landmark ndarray to store result. Dimensions is (videoid, frame, landmark, coordinate-dimensions (x,y,z))
# WARNING: max. number of frames (150) is hard-coded here and might be different for each video!
# WARNING: number of landmarks (33) is hardcoded here and might be different for different models
landmarks = np.full((len(input_video_path), 200, 33, 3), np.nan)
lh_marks = np.full((len(input_video_path), 200, 21, 3), np.nan) # same structure as landmarks
rh_marks = np.full((len(input_video_path), 200, 21, 3), np.nan) # same structure as landmarks
cntr_frame = np.zeros(len(input_video_path), dtype=int)

# loop over videos
for cntr_video, video in enumerate(input_video_path):
    video_path = os.path.join(mediapipe_indir, video)
    # add '_pose' to video (before '.mp4'!) for output
    idx = video.find('.') # only look for '.' to work with other file types
    if idx != -1:
        video = video[:idx] + '_pose' + video[idx:]
    output_video_path = os.path.join(mediapipe_outdir, video)

    # Open the local video file.
    cap = cv2.VideoCapture(video_path)

    # Get video properties for output file.
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # Define the codec and create VideoWriter object to save the output video.
    out = cv2.VideoWriter(output_video_path, cv2.VideoWriter_fourcc(*'mp4v'), fps, (frame_width, frame_height))

    cntr_frame[cntr_video] = -1
    while cap.isOpened():
        success, image = cap.read()
        if not success:
            break

        cntr_frame[cntr_video] = cntr_frame[cntr_video] + 1
        cntr_frame_loc = cntr_frame[cntr_video]
        # Convert the BGR image to RGB and process it with MediaPipe Pose.
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # POSE processing
        results_pose = pose.process(image)
        # HAND processing
        results_hands = hands.process(image)

        # loop through landmarks in results_pose objects and store in landmarks object
        for lm in range(len(results_pose.pose_landmarks.landmark._values)):
            landmarks[cntr_video, cntr_frame_loc, lm, 0] = results_pose.pose_landmarks.landmark._values[lm].x
            landmarks[cntr_video, cntr_frame_loc, lm, 1] = results_pose.pose_landmarks.landmark._values[lm].y
            landmarks[cntr_video, cntr_frame_loc, lm, 2] = results_pose.pose_landmarks.landmark._values[lm].z
           # landmarks[cntr_video, cntr_frame_loc, lm, 3] = results_pose.pose_landmarks.landmark._values[lm].visibility # not saving visibility for now, might re-include later

        # obtain results for hand model
        # get index for left and right hands, respectively. assumes there is one left and one right hand detected and nothing else!
        if results_hands.multi_handedness:
            if results_hands.multi_handedness[0].classification._values[0].label == 'Left':
                left_hand_idx = results_hands.multi_handedness[0].classification._values[0].index
            elif results_hands.multi_handedness[0].classification._values[0].label == 'Right':
                right_hand_idx = results_hands.multi_handedness[0].classification._values[0].index
            if len(results_hands.multi_handedness) > 1:
                if results_hands.multi_handedness[1].classification._values[0].label == 'Left':
                    left_hand_idx = results_hands.multi_handedness[1].classification._values[0].index
                elif results_hands.multi_handedness[1].classification._values[0].label == 'Right':
                    right_hand_idx = results_hands.multi_handedness[1].classification._values[0].index

        # store left hand results
        if results_hands.multi_hand_landmarks:
            if len(results_hands.multi_hand_landmarks) > left_hand_idx:
                for lm in range(len(results_hands.multi_hand_landmarks[left_hand_idx].landmark._values)):
                    lh_marks[cntr_video, cntr_frame_loc, lm, 0] = results_hands.multi_hand_landmarks[left_hand_idx].landmark._values[lm].x
                    lh_marks[cntr_video, cntr_frame_loc, lm, 1] = results_hands.multi_hand_landmarks[left_hand_idx].landmark._values[lm].y
                    lh_marks[cntr_video, cntr_frame_loc, lm, 2] = results_hands.multi_hand_landmarks[left_hand_idx].landmark._values[lm].z
            if len(results_hands.multi_hand_landmarks) > right_hand_idx:
                for lm in range(len(results_hands.multi_hand_landmarks[right_hand_idx].landmark._values)):
                    rh_marks[cntr_video, cntr_frame_loc, lm, 0] = results_hands.multi_hand_landmarks[right_hand_idx].landmark._values[lm].x
                    rh_marks[cntr_video, cntr_frame_loc, lm, 1] = results_hands.multi_hand_landmarks[right_hand_idx].landmark._values[lm].y
                    rh_marks[cntr_video, cntr_frame_loc, lm, 2] = results_hands.multi_hand_landmarks[right_hand_idx].landmark._values[lm].z

        # remove hand landmarks and connections from results_pose for visualization
        # apparently mp_drawing doesn't draw connections to out-of-frame landmarks, so just moving them out of frame [-1:1] suffices
        landmarks_to_remove = np.arange(17, 23)
        for lm in landmarks_to_remove:
            results_pose.pose_landmarks.landmark._values[lm].x = -2
            results_pose.pose_landmarks.landmark._values[lm].y = -2
            results_pose.pose_landmarks.landmark._values[lm].z = -2

        # Draw the pose annotations on the image (ideally, I would remove the hand landmarks and connections first)
        image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
        if results_pose.pose_landmarks:
            mp_drawing.draw_landmarks(image, results_pose.pose_landmarks, mp_pose.POSE_CONNECTIONS)
        # Draw the hand annotations on top of the pose annotations
        if results_hands.multi_hand_landmarks:
            for hand_landmarks in results_hands.multi_hand_landmarks:
                mp_drawing.draw_landmarks(
                    image,
                    hand_landmarks,
                    mp_hands.HAND_CONNECTIONS,
                    mp_drawing_styles.get_default_hand_landmarks_style(),
                    mp_drawing_styles.get_default_hand_connections_style())

        # Write the frame into the output file.
        out.write(image)

        # # Display the annotated image (optional, can be commented out).
        # cv2.imshow('MediaPipe Pose', image)



        # # Break the loop when 'q' is pressed.
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Release resources.
    cap.release()
    out.release()
    cv2.destroyAllWindows()

# CLEAN UP THE DATA
# delete all rows of landmarks > min(cntr_frame)
# this (for all videos) removes all frames that go beyond the number of frames in the SHORTEST of all input videos


def del_excess_frames(landmarks, cntr_frame):
    landmarks = landmarks[:,:min(cntr_frame)+1,:,:]
    return landmarks


landmarks = del_excess_frames(landmarks, cntr_frame)
lh_marks = del_excess_frames(lh_marks, cntr_frame)
rh_marks = del_excess_frames(rh_marks, cntr_frame)

# SAVE THE DATA
np.save(os.path.join(mediapipe_outdir, 'pose_landmarks.npy'), landmarks)
np.save(os.path.join(mediapipe_outdir, 'lh_landmarks.npy'), lh_marks)
np.save(os.path.join(mediapipe_outdir, 'rh_landmarks.npy'), rh_marks)
with open(os.path.join(mediapipe_outdir, "landmark_inputs.csv"), "w", newline='') as file:
    writer = csv.writer(file)
    writer.writerow(input_video_path)

# create and save txt legend describing the data output
legend = ["description of landmark creation process for videos in this folder",
          "both mediapipe_estimate_pose_hands Pose and Hand landmarks were created for each frame of each video and saved to 3 separate npy arrays (see below).",
          "additionally they were drawn onto the input videos and saved to this folder for visualization purposes only.",
          "in the visualizations, the finger landmarks were removed from the pose model (as they are included in greater detail in the hand model).",
          "they are nevertheless still included in pose_landmarks.npy",
          "",
          "",
          "landmark_inputs.csv contains a list (in order) of all videos put into mediapipe_estimate_pose_hands",
          "pose_landmarks.npy, lh_landmarks.npy, rh_landmarks.npy are all organised in the same fashion:",
          "(input_video, landmark, frame, landmark_position)",
          "input_video:     each row of each ndarray corresponds to each row in landmark_inputs.csv",
          "landmark:        each row corresponds to the 33 landmarks (pose) or 21 handmarks for the left (lh_landmarks) & right (rh_landmarks) hands",
          "frame:           progresses through all frames of video one-by-one, with frames exceeding the number of frames in the shortest video removed from all videos",
          "landmark_position: 3-dimensional array. x, y, z coordinates (in that order) of each landmark at each frame"]
with open(os.path.join(mediapipe_outdir, "landmark_desc.txt"), "w") as file:
    for string in legend:
        file.write(f"{string}\n")