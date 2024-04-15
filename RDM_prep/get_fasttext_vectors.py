# script to download pre-trained German-language fastText
# model and then extract word-vectors for the 40 words used
# in FL_BILINGUAL project
#
# 1) extracts word-vectors based on full fasttext model (300 dimensions)
# 2) calculates pairwise cosine dissimilarity of these vectors, saves to .npy
# 3) reduces fasttext model to 5 dimensions
# 4) repeats steps 1 & 2 using reduced model, additionally saves resulting vectors as csv for use in R
#
# current version: 20240118
# written by: Jonathan Wehnert


# requires to be in conda activate fasttext OR conda activate fl_bilingual_RDM
# where fasttext is installed

import fasttext.util
import rsatoolbox.rdm
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import pandas as pd
from rsatoolbox import rdm
import matplotlib.pyplot as plt
import os

### SETTINGS
compare_dimensionalities = False


def extract_ft_vectors(ft_model, words):
    # create empty list to store the fastText word vectors
    ft_vectors = []
    # extract word vector for each entry in 'word' series
    for i in word:
        tmp_vector = ft_model.get_word_vector(i)
        ft_vectors.append(tmp_vector)
    ft_vectors = pd.DataFrame(ft_vectors)
    return ft_vectors


# get location of this script:
script_path = os.path.abspath(__file__)
script_dir = os.path.abspath(os.path.dirname(script_path))

# load list of words
stimlist_relative = '../../../1_Organisation/Materials/Stimuli/L1_German/FL_BILINGUAL_stimuli_alphabeticalID.csv'
stimlist_path = os.path.normpath(os.path.join(script_dir, stimlist_relative))
df = pd.read_csv(stimlist_path)
# create pandas Series of the words and stimulus_ids
stimulus_id = df['stimulus_id']
word = df['german_umlaut']
# concatenate necessary information into one df
word_vector_descriptors = pd.DataFrame({'stimulus_id': stimulus_id, 'word': word})
word_vector_descriptors.to_csv('ft_word_vector_descriptors.csv', index=False)

# first, obtain fasttext vectors and cosine dissimilarity for full model (300 dimensions)
# download German ('de') model to project folder and load as ft
fasttext.util.download_model('de', if_exists='ignore')  # German
ft = fasttext.load_model('cc.de.300.bin')

# extract vectors for our words, full model
ft_vectors_300 = extract_ft_vectors(ft, word)
ft_vectors_300.to_csv('ft_word_vectors_300.csv', index=False)  # save as csv for use in R
# transform into ndarray
ft_vectors_300 = ft_vectors_300.to_numpy()


# Calculate & save pairwise cosine dissimilarity
ft_300_cosine_dissimilarities = 1 - cosine_similarity(ft_vectors_300)
print(ft_300_cosine_dissimilarities)
np.save('ft_300_cosine_dissimilarities.npy', ft_300_cosine_dissimilarities)
print(ft.get_dimension())


### compare correlation between full 300-dimensional-based dissimilarities and those based on fewer dimensions
# ONLY IF compare_dimensionalities is set to True (manually at beginning of script!)
if compare_dimensionalities:
    dims = np.arange(5, 101, 5)  # compare in steps of 5 (going above 100 dimensions leads to memory overload)


    def compare_dimensionalities(dims, ft_300_dis, word):
        r_corr = []
        r_rhoa = []
        ft_300_dis = ft_300_dis[np.newaxis, :, :]  # rsatoolbox.rdm.RDMs requires nparray of dissimilarities in shape (n_rdm x n_cond x n_con)
        ft_300_rdm = rsatoolbox.rdm.RDMs(ft_300_dis)

        for i, dim in enumerate(dims):
            # reload ft model (as it became reduced in previous iteration)
            ft = fasttext.load_model('cc.de.300.bin')
            print(ft.get_dimension())
            # reduce model dimensions
            fasttext.util.reduce_model(ft, dim)
            print(ft.get_dimension())
            # extract vectors for our words
            ft_vectors = extract_ft_vectors(ft, word)
            # transform into ndarray
            ft_vectors = ft_vectors.to_numpy()
            # Calculate pairwise cosine dissimilarity
            ft_cosine_dissimilarities = 1 - cosine_similarity(ft_vectors)
            ft_cosine_dissimilarities = ft_cosine_dissimilarities[np.newaxis, :, :]  # rsatoolbox.rdm.RDMs requires nparray of dissimilarities in shape (n_rdm x n_cond x n_con)
            ft_cosine_RDM = rsatoolbox.rdm.RDMs(ft_cosine_dissimilarities)

            # compare to full 300-dimensional-based dissimilarities
            r_corr.append(rdm.compare(ft_300_rdm, ft_cosine_RDM, method='corr')[0][0])
            print(
                f'similarity (corr) between 300-D & {dims[i]}-D based RDMs for fasttext vectors: {r_corr[i]}')
            r_rhoa.append(rdm.compare(ft_300_rdm, ft_cosine_RDM, method='rho-a')[0][0])
            print(
                f'similarity (rho-a) between 300-D & {dims[i]}-D based RDMs for fasttext vectors: {r_rhoa[i]}')

        return r_corr, r_rhoa


    r_corr, r_rhoa = compare_dimensionalities(dims, ft_300_cosine_dissimilarities, word)

    # plot r_corr and r_rhoa over dims
    plt.figure()
    plt.plot(dims, r_corr, label='corr')
    plt.plot(dims, r_rhoa, label='rho-a')

    plt.title('Correlation between RDMs,\nbased on pairwise cosine dissimilarities,\nbased on: ft_300-D and ft_xxx-D\nxxx = fastText dimensionality')
    plt.xlabel('fastText dimensionality')
    plt.ylabel('correlation')
    legend = plt.legend()
    plt.xticks(dims[1::2])
    legend.set_title('comparison method:')

    plt.savefig('ft_300-ft_xxx_correlation.png')


###
# reduce model dimensions to a specific, hardcoded level (target_dim), for later use with anticluster in R
target_dim = [10, 35]
for dims in target_dim:
    ft = fasttext.load_model('cc.de.300.bin')
    fasttext.util.reduce_model(ft, dims)
    print(ft.get_dimension())

    # extract vectors for our words
    ft_vectors_005 = extract_ft_vectors(ft, word)
    ft_vectors_005.to_csv(f'ft_word_vectors_{dims:03}.csv', index=False)  # save as csv for use in R

    # transform into ndarray
    ft_vectors_005 = ft_vectors_005.to_numpy()
    # Calculate & save pairwise cosine dissimilarity
    ft_005_cosine_dissimilarities = 1 - cosine_similarity(ft_vectors_005)
    print(ft_005_cosine_dissimilarities)
    np.save(f'ft_{dims:03}_cosine_dissimilarities.npy', ft_005_cosine_dissimilarities)
