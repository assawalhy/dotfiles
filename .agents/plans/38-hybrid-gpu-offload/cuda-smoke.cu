// CUDA smoke test for epic 38 (hybrid GPU). Compile and run with:
//   nvcc cuda-smoke.cu -o /tmp/cuda-smoke && /tmp/cuda-smoke
// It prints the device name and a checksum, so a real run on the Quadro T2000
// is distinguishable from a CUDA failure. Expected last line: OK.
#include <cstdio>
#include <cuda_runtime.h>

__global__ void add(int *a, int *b, int *c, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) c[i] = a[i] + b[i];
}

#define CHECK(x)                                                              \
  do {                                                                        \
    cudaError_t e = (x);                                                      \
    if (e != cudaSuccess) {                                                   \
      printf("FAIL %s: %s\n", #x, cudaGetErrorString(e));                     \
      return 1;                                                               \
    }                                                                         \
  } while (0)

int main() {
  const int n = 1024;
  int h_a[n], h_b[n], h_c[n];
  for (int i = 0; i < n; i++) {
    h_a[i] = i;
    h_b[i] = 2 * i;
  }
  int *d_a, *d_b, *d_c;
  CHECK(cudaMalloc(&d_a, sizeof h_a));
  CHECK(cudaMalloc(&d_b, sizeof h_b));
  CHECK(cudaMalloc(&d_c, sizeof h_c));
  CHECK(cudaMemcpy(d_a, h_a, sizeof h_a, cudaMemcpyHostToDevice));
  CHECK(cudaMemcpy(d_b, h_b, sizeof h_b, cudaMemcpyHostToDevice));
  add<<<n / 256, 256>>>(d_a, d_b, d_c, n);
  CHECK(cudaGetLastError());
  CHECK(cudaDeviceSynchronize());
  CHECK(cudaMemcpy(h_c, d_c, sizeof h_c, cudaMemcpyDeviceToHost));

  cudaDeviceProp p;
  CHECK(cudaGetDeviceProperties(&p, 0));
  printf("device: %s (compute %d.%d, %d MiB)\n", p.name, p.major, p.minor,
         (int)(p.totalGlobalMem >> 20));
  printf("c[1023] = %d (expected 3069)\n", h_c[1023]);
  printf("%s\n", h_c[1023] == 3069 ? "OK" : "FAIL");

  cudaFree(d_a);
  cudaFree(d_b);
  cudaFree(d_c);
  return h_c[1023] == 3069 ? 0 : 1;
}
