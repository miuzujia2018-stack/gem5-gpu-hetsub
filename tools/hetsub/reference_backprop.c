/* CPU reference using the benchmark's existing scalar training routine.
 * Compile with benchmarks/rodinia/backprop/backprop.c, without changing the
 * application binary. The test input is the existing 16-element workload.
 */
#include <stdio.h>
#include <stdlib.h>
#include "backprop.h"

int main(void)
{
    int i, j;
    float output_error, hidden_error;
    BPNN* net;
    bpnn_initialize(7);
    net = bpnn_create(16, 16, 1);
    for (i = 1; i <= 16; ++i)
        net->input_units[i] = (float)rand() / RAND_MAX;
    printf("Partial Sums:\n");
    for (j = 1; j <= 16; ++j) {
        float sum = 0;
        for (i = 1; i <= 16; ++i)
            sum += net->input_units[i] * net->input_weights[i][j];
        printf("%.9g\n", sum);
    }
    bpnn_train(net, &output_error, &hidden_error);
    printf("Input Weights:\n");
    for (i = 0; i <= 16; ++i) {
        for (j = 0; j <= 16; ++j) printf("%.9g ", net->input_weights[i][j]);
        printf("\n");
    }
    printf("Net Inputs:\n");
    for (i = 0; i < 16; ++i) printf("%.9g ", net->input_units[i]);
    printf("\n");
    bpnn_free(net);
    return 0;
}
