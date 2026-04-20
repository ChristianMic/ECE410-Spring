#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>

#define TILE_SIZE 8

// =============================================================================
// KERNEL: Tiled shared-memory — tile size 8
// =============================================================================
//
// Threads cooperate in (TILE_SIZE × TILE_SIZE) blocks.  Each phase loads one
// tile of A and one tile of B into shared memory (fast, on-chip SRAM), then
// every thread computes its partial dot-product against those cached tiles.
//
// Key idea: each global value is loaded ONCE per tile phase and read
// TILE_SIZE times from shared memory instead of global memory.
// This reduces global memory traffic by a factor of TILE_SIZE (8×).
//
// Shared memory layout:
//   tileA[TILE_SIZE][TILE_SIZE]  — tile of A currently in SRAM
//   tileB[TILE_SIZE][TILE_SIZE]  — tile of B currently in SRAM
//
// Complexity (memory transactions): O(N^3 / TILE_SIZE) global reads.
// Best for: medium-to-large matrices; foundation for cuBLAS-style kernels.
// =============================================================================
__global__ void matmul_tiled(const float* __restrict__ A,
                             const float* __restrict__ B,
                             float*       __restrict__ C,
                             int M, int N, int K)
{
    // Shared-memory tiles — declared with TILE_SIZE (compile-time constant).
    __shared__ float tileA[TILE_SIZE][TILE_SIZE];
    __shared__ float tileB[TILE_SIZE][TILE_SIZE];

    // Thread indices within this block.
    int tx = threadIdx.x;   // column index inside the tile
    int ty = threadIdx.y;   // row    index inside the tile

    // Global output coordinates for this thread.
    int row = blockIdx.y * TILE_SIZE + ty;
    int col = blockIdx.x * TILE_SIZE + tx;

    float acc = 0.0f;

    // Sweep through tiles along the K dimension.
    int numTiles = (K + TILE_SIZE - 1) / TILE_SIZE;

    for (int t = 0; t < numTiles; ++t) {

        // ------------------------------------------------------------------
        // Collaborative load: each thread loads one element into shared mem.
        // Boundary checks ensure we don't read out-of-bounds for matrices
        // whose dimensions are not multiples of TILE_SIZE.
        // ------------------------------------------------------------------
        int aCol = t * TILE_SIZE + tx;   // column in A (= row in B) for this thread
        int bRow = t * TILE_SIZE + ty;   // row    in B for this thread

        tileA[ty][tx] = (row < M && aCol < K) ? A[row * K + aCol] : 0.0f;
        tileB[ty][tx] = (bRow < K && col < N) ? B[bRow * N + col] : 0.0f;

        // Ensure ALL threads have finished loading before any thread computes.
        __syncthreads();

        // ------------------------------------------------------------------
        // Compute partial dot-product from the two tiles now in SRAM.
        // ------------------------------------------------------------------
        #pragma unroll
        for (int k = 0; k < TILE_SIZE; ++k) {
            acc += tileA[ty][k] * tileB[k][tx];
        }

        // Ensure no thread starts loading the next tile before all threads
        // are done reading the current one (prevents RAW hazards).
        __syncthreads();
    }

    // Write the final result (guard for non-tile-aligned dimensions).
    if (row < M && col < N) {
        C[row * N + col] = acc;
    }
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

    dim3 block(TILE_SIZE, TILE_SIZE);
    dim3 grid((N + TILE_SIZE - 1) / TILE_SIZE, (M + TILE_SIZE - 1) / TILE_SIZE);

    matmul_tiled<<<grid, block>>>(dA, dB, dC, M, N, K);
    check(cudaGetLastError(),      "tiled launch");
    check(cudaDeviceSynchronize(), "tiled sync");
    check(cudaMemcpy(hC, dC, bytesC, cudaMemcpyDeviceToHost), "D2H");

    printf("C[0][0] = %f\n", hC[0]);
    printf("Done.\n");

    cudaFree(dA); cudaFree(dB); cudaFree(dC);
    free(hA); free(hB); free(hC);
    return 0;
}
