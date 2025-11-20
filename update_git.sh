#!/bin/bash


echo "update gem5/src/"

# Enter gem5 directory
cd /home/siat/gem5-gpu-bak/gem5/src
git add --all
git commit -m "update gem5/src/"
git push https://miuzujia1995%40163.com:456843d9586f483cd04d0b8b28ce95b7@gitee.com/miuzujia/gem5.git master


# cd /home/siat/gem5-gpu-bak/gem5-gpu/
# git add .
# git commit -m "update gem5-gpu/src/"
# git push https://miuzujia1995%40163.com:456843d9586f483cd04d0b8b28ce95b7@gitee.com/miuzujia/gem5-gpu.git master

# cd /home/siat/gem5-gpu-bak/gpgpu-sim/
# git add .
# git commit -m "update gpgpu-sim/src/"
# git push https://miuzujia1995%40163.com:456843d9586f483cd04d0b8b28ce95b7@gitee.com/miuzujia/gpgpu-sim.git master

# cd /home/siat/gem5-gpu-bak/Graphite/
# git add .
# git commit -m "update Graphite/"
# git push https://miuzujia1995%40163.com:456843d9586f483cd04d0b8b28ce95b7@gitee.com/miuzujia/graphite.git master


cd -
