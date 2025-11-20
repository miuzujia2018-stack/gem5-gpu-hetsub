#!/bin/bash

echo "Testing compilation of Router.cc with fixes..."
cd /home/siat/gem5-gpu/gem5

# Try to compile just the router object
python2 `which scons` build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/Router.o \
    --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
    PROTOCOL=VI_hammer \
    GPGPU_SIM=True \
    -j1

echo "Compilation test completed."