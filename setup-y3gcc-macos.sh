# set Y3GCC_DIR to wherever you have done the installation.
export Y3GCC_DIR=${PWD}/xxx

#-----------------------------------------------------------
# You should not need to modify anything below this line.

# On macOS, the setup of cosmosis sets up the virtual environment.
pushd $Y3GCC_DIR/cosmosis
source config/setup-cosmosis-mac
popd

export Y3_CLUSTER_CPP_DIR=$Y3GCC_DIR/y3_cluster_cpp
export Y3_CLUSTER_WORK_DIR=$Y3GCC_DIR/y3_cluster_cpp
