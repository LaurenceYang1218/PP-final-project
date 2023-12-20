#include <vector>
#include <string>
#include <climits>
#include <fstream>
#include <iostream>
#include "CycleTimer.h"


// __global__ void minimumDistance(int *deviceDist, bool *deviceVisited, int *deviceMinIndex, int numNodes) {
//     int min = INT_MAX, min_index = 0;
//     for (int v = 0; v < numNodes; v++) {
//         if (!deviceVisited[v] && deviceDist[v] <= min) {
//             min = deviceDist[v];
//             min_index = v;
//         }
//     }
//     deviceMinIndex[0] = min_index;
//     deviceVisited[min_index] = true;
// }

int minimumDistance(int *dist, bool *visited, int numNodes) {
    int min = INT_MAX, min_index = 0;
    for (int v = 0; v < numNodes; v++) {
        if (!visited[v] && dist[v] <= min) {
            min = dist[v];
            min_index = v;
        }
    }
    visited[min_index] = true;
    return min_index;
}

__global__ void dijkstra(int *deviceAdjMatrix, int *deviceDist, bool *deviceVisited, int *deviceMinIndex, int numNodes) {
    int u = deviceMinIndex[0];
    deviceVisited[u] = true;
    int v = blockIdx.x * blockDim.x + threadIdx.x;
    if (!deviceVisited[v] && deviceAdjMatrix[u * numNodes + v] && deviceDist[u] + deviceAdjMatrix[u * numNodes + v] < deviceDist[v])
        deviceDist[v] = deviceDist[u] + deviceAdjMatrix[u * numNodes + v];

}

int main(int argc, char *argv[]) {
    if (argc < 4) {
        std::printf("usage: ./dijkstra file.txt node_num edge_num");
        return 1;
    }
    unsigned int numNodes = std::atoi(argv[2]);
    unsigned int numEdges = std::atoi(argv[3]);
    std::printf("[Nodes]: %u [Edges]: %u\n", numNodes, numEdges);
    
    int* adjMatrix = (int *)calloc(numNodes * numNodes, sizeof(int *));
    // std::vector<std::vector<int>> adjMatrix(numNodes, std::vector<int>(numNodes, 0));
    
    std::ifstream ifs;
    ifs.open(argv[1], std::ifstream::in);
    if (!ifs.good()) {
        std::printf("[Error] Cannot open file %s\n", argv[1]);
        return 1;
    }
    int srcNode, dstNode;
    ifs >> srcNode >> dstNode;
    std::printf("[srcNode]: %d [dstNode]: %d\n", srcNode, dstNode);
    int source, target, weight;
    for (unsigned int i = 0; i < numEdges; i++) {
        ifs >> source >> target >> weight;
        adjMatrix[source * numNodes + target] = weight;
    }
    std::printf("Successfully construct adjacency matrix\n");
    ifs.close();
    
    cudaEvent_t startEvent, endEvent;
    cudaEventCreate(&startEvent);
    cudaEventCreate(&endEvent);

    size_t adjMatrixSize = numNodes * numNodes;
    int *deviceAdjMatrix;
    cudaMalloc((void **)&deviceAdjMatrix, adjMatrixSize * sizeof(int));
    cudaMemcpy(deviceAdjMatrix, adjMatrix, adjMatrixSize * sizeof(int), cudaMemcpyHostToDevice);
    int *dist = (int *)calloc(numNodes, sizeof(int));
    int *minIndex = (int *)malloc(1 * sizeof(int));
    bool *visited  = (bool *)calloc(numNodes, sizeof(int));
    for (int i = 0; i < numNodes; i++) {
        dist[i] = INT_MAX;
        visited[i] = false;
    }
    dist[srcNode] = 0;
    minIndex[0] = 0;

    int *deviceDist, *deviceMinIndex; 
    bool *deviceVisited;
    cudaMalloc((void **)&deviceDist, numNodes * sizeof(int));
    cudaMalloc((void **)&deviceMinIndex, sizeof(int));
    cudaMalloc((void **)&deviceVisited, numNodes * sizeof(bool));
    cudaMemcpy(deviceDist, dist, numNodes * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(deviceVisited, visited, numNodes * sizeof(int), cudaMemcpyHostToDevice);
    // dim3 threadsPerBlockMin(1, 1);
    // dim3 numBlockMin(1, 1);
    dim3 threadsPerBlockRelax(16, 1);
    dim3 numBlockRelax(numNodes / threadsPerBlockRelax.x, 1);

    cudaEventRecord(startEvent);
    for (int i = 0; i < numNodes-1; i++) {
        minIndex[0] = minimumDistance(dist, visited, numNodes);
        cudaMemcpy(deviceMinIndex, minIndex, sizeof(int), cudaMemcpyHostToDevice);
        dijkstra<<<numBlockRelax, threadsPerBlockRelax>>>(deviceAdjMatrix, deviceDist, deviceVisited, deviceMinIndex, numNodes);
        cudaMemcpy(dist, deviceDist, numNodes * sizeof(int), cudaMemcpyDeviceToHost);
    }
    cudaEventRecord(endEvent);

    cudaMemcpy(dist, deviceDist, numNodes * sizeof(int), cudaMemcpyDeviceToHost);
    int minDist = dist[dstNode];

    float execTime;
    cudaEventElapsedTime(&execTime, startEvent, endEvent);
    std::printf("[Dijkstra cuda]:\t\t[%f] ms\n", execTime);
    std::printf("The minimum distance from %d to %d is: %d\n", srcNode, dstNode, minDist);
    

    cudaFree(deviceAdjMatrix);
    cudaFree(deviceDist);
    cudaFree(deviceMinIndex);
    cudaFree(deviceVisited);
    free(adjMatrix);
    return 0;
}