import numpy as np

def create_asymmetrical_matrix():
    # Construct a 5x5 binary matrix with an asymmetrical object
    return np.array([
        [0, 1, 0, 0, 0],
        [0, 0, 1, 0, 0],
        [1, 0, 0, 0, 0],
        [0, 0, 0, 0, 1],
        [0, 0, 0, 1, 0]
    ])

def rotate_270(matrix):
    # Rotate matrix 270 degrees clockwise
    return np.rot90(matrix, -3)

def reflect_horizontally(matrix):
    # Reflect the matrix horizontally
    return np.fliplr(matrix)

def hamming_distance(matrix_a, matrix_b):
    # Compute Hamming distance between two matrices
    return np.sum(np.logical_xor(matrix_a, matrix_b))

# Original Matrix
original_matrix = create_asymmetrical_matrix()
transformed_matrix = reflect_horizontally(rotate_270(original_matrix))
hamming_dist = hamming_distance(original_matrix, transformed_matrix)

print(hamming_dist)
