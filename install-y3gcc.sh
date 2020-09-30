# Set the environment variable Y3GCC_DIR to be the full path
# to where you want the software to be downloaded and built.
# This directory should NOT yet exist.

export Y3GCC_DIR=${PWD}/xxx

#-----------------------------------------------------------
# You should not need to modify anything in this section.

# All the python modules we build with 'python set.py install --user' will
# get installed under PYTHONUSERBASE, and they will be found without needing
# to put additional directories onto PYTHONPATH.
export PYTHONUSERBASE=${Y3GCC_DIR}

# Bash function 'die' is used to exit script with a message if something
# goes wrong.
die()
{
  local exitval 
  if [[ "$1" =~ ^[0-9]*$ ]]; then (( exitval = $1 )); shift; else (( exitval = 1 )); fi
  echo "ERROR: $@" 1>&2
  exit $exitval
}

os_string=$(uname)
if [[ "${os_string}" == "Darwin" ]]; then
  echo "I am on macOS"
elif [[ "${os_string}" == "Linux" ]]; then
  echo "I am on Linux"
else
  echo "Neither Darwin (macOS) nor Linux detected; aborting installation."
  exit 1
fi

# We will stop if the path ${Y3GCC_DIR} already exists (even if it is a file or
# an empty directory) so that we do not risk clobbering anything.

echo "Creating directory ${Y3GCC_DIR}"
if [[ -e "${Y3GCC_DIR}" ]]; then
  echo "The path ${Y3GCC_DIR} already exists."
  echo "Please edit the script so that Y3GCC_DIR to a path that does not yet exist,"
  echo "or remove whatever is at ${Y3GCC_DIR}"
  exit 1
fi

mkdir -p ${Y3GCC_DIR} || die "Failed to create ${Y3GCC_DIR}"
cd ${Y3GCC_DIR} || die "Failed to move to directory ${Y3GCC_DIR}"

# Obtain the right CosmoSIS environment before we build our own code.
if [[ "${os_string}" == "Linux" ]]; then
  # On Linux, we rely upon having cosmosis available in CVMFS, and loadable with
  # spack. We have to make our virtual environment in $Y3GCC_DIR."
  echo "Setting up CosmoSIS from spack"
  source /cvmfs/des.opensciencegrid.org/users/cosmosis/neutrinoless_mass_function_2-20200630/setup-env.sh || die "Spack setup failed"
  spack load -r gcc@8.2.0 || die "Required GCC version not found by spack"
  spack load -r cosmosis@neutrinoless_mass_function_2 || die "Require cosmosis version not found by spack"
  spack load -r cmake || die "cmake not found by spack"
  echo "Creating Python virtual environment"
  python -m venv local-venv
  source local-venv/bin/activate || die "Failed to activate python virtual environment"
  pip install --upgrade pip
  pip install wheel
  # The python module required by cosmosis itself are already available.
else
  # On macOS, we get tools from Homebrew and build cosmosis ourselves.
  echo "Installing homebrew requirements"
  brew install cmake ninja gcc gsl cfitsio fftw minuit2 openblas python numpy scipy mpi4py
  
  echo "Cloning cosmosis and CSL"
  git clone --branch develop https://bitbucket.org/mpaterno/cosmosis || die "Cloning cosmosis failed"
  cd cosmosis
  git clone --branch develop https://bitbucket.org/mpaterno/cosmosis-standard-library || die "Cloning CSL failed"

  echo "Creating Python virtual environment"
  python3 -m venv local-venv
  source local-venv/bin/activate || die "Failed to activate python virtual environment"
  pip install --upgrade pip
  pip install wheel
  pip install -r config/requirements.txt || die "pip install of cosmosis requirements failed"
  deactivate  # the environment will be re-activated when we set up cosmosis
  source config/setup-cosmosis-mac || die "setup of comsosis failed"
  echo "Building cosmosis and CSL"
  # We don't do a parallel build because some of the Fortran targets aren't robust.
  make || die "build of cosmosis failed"
fi

cd ${Y3GCC_DIR}
# Install the Python modules required by y3_cluster_cpp.
echo "Installing Python modules needed by y3_cluster_cpp"
# First we need pycparser and cffi
pip install "pycparser==2.20"
pip install "cffi==1.14.0"

# Note: the official installation is broken on CentOS 7 because of a bad flag
# in the invocation of the system's 'ln' program. I have modified the script
# to remove the flag.
echo "Getting and building cluster_toolkit"
git clone https://github.com/marcpaterno/cluster_toolkit.git
cd cluster_toolkit
python setup.py install
cd ${Y3GCC_DIR}
rm -rf cluster_toolkit

# Now install C and C++ code use.

cd ${Y3GCC_DIR}
echo "Getting and building cuba"
git clone https://github.com/marcpaterno/cuba.git
cd cuba
if [[ "${os_string}" == "Linux" ]]; then
  CC=$(which gcc) ./configure
else
  CC=$(which clang) ./configure
fi
./makesharedlib.sh || die "Failed to build libcuba.so"
mkdir -p ${Y3GCC_DIR}/central/lib
mkdir -p ${Y3GCC_DIR}/central/include
mv libcuba.* ${Y3GCC_DIR}/central/lib/ || die "Failed to move cuba library"
mv cuba.h ${Y3GCC_DIR}/central/include/ || die "Failed to move cuba header"
cd ${Y3GCC_DIR} 
rm -rf cuba/

# For macOS, we need to adjust the install name of the library, so that the
# runtime linker will find it.
if [[ "${os_string}" == Darwin ]]; then
  install_name_tool -id ${Y3GCC_DIR}/central/lib/libcuba.dylib ${Y3GCC_DIR}/central/lib/libcuba.dylib || die "Failed to fix install-name of libcuba.so"
fi

cd ${Y3GCC_DIR}
echo "Cloning cubacpp"
git clone git@bitbucket.org:mpaterno/cubacpp.git
# Nothing to build

echo "Cloning y3_cluster_cpp"
git clone git@bitbucket.org:mpaterno/y3_cluster_cpp.git
cd y3_cluster_cpp
export Y3_CLUSTER_CPP_DIR=$PWD
export Y3_CLUSTER_WORK_DIR=$PWD

echo "Configuring build of y3_cluster_cpp"
cmake -DCMAKE_MODULE_PATH="${Y3_CLUSTER_CPP_DIR}/cmake;${Y3GCC_DIR}/cubacpp/cmake/modules" -DCUBACPP_DIR=${Y3GCC_DIR}/cubacpp -DCUBA_DIR=${Y3GCC_DIR}/central  -DCMAKE_BUILD_TYPE=Release  .

echo "Building y3_cluster_cpp"
make -j 4
ctest -j 4
