#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

// =============================================================================
// KERNEL: Naive — one thread per output element
// =============================================================================
//
// Each thread independently computes one element C[row][col] = sum(A[row][k] * B[k][col]).
// Every thread walks the full K dimension, issuing individual global memory
// reads for every A and B element.  No data is reused between threads, so the
// same global-memory values are fetched repeatedly by neighbouring threads.
//
// Complexity (memory transactions): O(N^3) global reads for an N×N multiply.
// Best for: small matrices, quick prototyping, or a correctness baseline.
// =============================================================================
__global__ void matmul_naive(const float* __restrict__ A,
                             const float* __restrict__ B,
                             float*       __restrict__ C,
                             int M, int N, int K)
{
    // Map this thread to one (row, col) output element.
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row >= M || col >= N) return;   // guard for non-square / non-tile-aligned dims

    float acc = 0.0f;
    for (int k = 0; k < K; ++k) {
        acc += A[row * K + k] * B[k * N + col];
    }
    C[row * N + col] = acc;
}

// =============================================================================
// Host driver
// =============================================================================
void check(cudaError_t err, const char* msg) {
    if (err != cudaSuccess) {
        fprintf(stderr, "CUDA error at %s: %s\n", msg, cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
}

int main(void)
{
    const int M = 1024, N = 1024, K = 1024;
    const int BLOCK = 16;
    const size_t bytesA = M * K * sizeof(float);
    const size_t bytesB = K * N * sizeof(float);
    const size_t bytesC = M * N * sizeof(float);

    float *hA = (float*)malloc(bytesA);
    float *hB = (float*)malloc(bytesB);
    float *hC = (float*)malloc(bytesC);

    srand(42);
    for (int i = 0; i < M * K; ++i) hA[i] = (float)rand() / RAND_MAX;
    for (int i = 0; i < K * N; ++i) hB[i] = (float)rand() / RAND_MAX;

    float *dA, *dB, *dC;
    check(cudaMalloc(&dA, bytesA), "cudaMalloc dA");
    check(cudaMalloc(&dB, bytesB), "cudaMalloc dB");
    check(cudaMalloc(&dC, bytesC), "cudaMalloc dC");

    check(cudaMemcpy(dA, hA, bytesA, cudaMemcpyHostToDevice), "H2D A");
    check(cudaMemcpy(dB, hB, bytesB, cudaMemcpyHostToDevice), "H2D B");

    dim3 block(BLOCK, BLOCK);
    dim3 grid((N + BLOCK - 1) / BLOCK, (M + BLOCK - 1) / BLOCK);

    matmul_naive<<<grid, block>>>(dA, dB, dC, M, N, K);
    check(cudaGetLastError(),      "naive launch");
    check(cudaDeviceSynchronize(), "naive sync");
    check(cudaMemcpy(hC, dC, bytesC, cudaMemcpyDeviceToHost), "D2H");

    printf("C[0][0] = %f\n", hC[0]);
    printf("Done.\n");

    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB); free(hC);
    return 0;
}
