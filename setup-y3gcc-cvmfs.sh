# set Y3GCC_DIR to wherever you have done the installation.
export Y3GCC_DIR=${PWD}/xxx

#-----------------------------------------------------------
# You should not need to modify anything below this line.

source /cvmfs/des.opensciencegrid.org/users/cosmosis/neutrinoless_mass_function_2-20200630/setup-env.sh
spack load -r gcc@8.2.0
spack load -r cosmosis
spack load -r cmake

source ${Y3GCC_DIR}/local-venv/bin/activate

export Y3_CLUSTER_CPP_DIR=$Y3GCC_DIR/y3_cluster_cpp
export Y3_CLUSTER_WORK_DIR=$Y3GCC_DIR/y3_cluster_cpp

export PYTHONUSERBASE=$Y3GCC_DIR
export LD_LIBRARY_PATH=${Y3GCC_DIR}/cuba/lib:${LD_LIBRARY_PATH}
