#!/bin/bash

set -v

halt() {
  echo $*
  exit 1
}

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SYSTEM=`uname -s`

[ -z "$HOME" ] && export HOME="/root"
if [ $SYSTEM == "Linux" ] && which apt-get > /dev/null ; then
    sudo apt-get update
    sudo apt-get install -y  \
        build-essential \
        libatlas-base-dev \
        liblapack-dev \
        libffi-dev \
        wget \
        gfortran \
        git \
        libxft-dev \
        libxpm-dev
fi

mkdir -p $HOME/.config/matplotlib
echo 'backend: agg' > $HOME/.config/matplotlib/matplotlibrc
if [ -n "$TRAVIS_PYTHON_VERSION" ] ; then
    PENV_NAME="rep_py${TRAVIS_PYTHON_VERSION:0:1}"
elif which python ; then
    PYTHON_VERSION=`python --version 2>&1|awk '{print $2}'`
    PENV_NAME="rep_py${PYTHON_VERSION:0:1}"
else
    PENV_NAME="rep_py2"
fi
if ! which conda ; then
    wget http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh -O miniconda.sh
    chmod +x miniconda.sh
    ./miniconda.sh -b -p $HOME/miniconda || halt "Error installing miniconda"
    rm ./miniconda.sh
    export PATH=$HOME/miniconda/bin:$PATH
    hash -r
    conda update --yes conda
fi
ENV_FILE=$HERE/environment.yaml
[ -f $HERE/environment_${SYSTEM}.yaml ] && ENV_FILE=$HERE/environment_${SYSTEM}.yaml
conda env create --name $PENV_NAME --file $ENV_FILE #|| halt "Error installing $PENV_NAME environment"
source activate $PENV_NAME
conda uninstall --yes gcc qt
conda clean --yes -p # -t

# install xgboost
git clone https://github.com/dmlc/xgboost.git
cd xgboost
# taking particular xgboost commit, which is working
git checkout 8e4dc4336849c24ae48636ae60f5faddbb789038
./build.sh
cd python-package
python setup.py install
cd ../..
# end install xgboost

# test installed packages
pushd $ENV_BIN_DIR/.. 
source 'bin/thisroot.sh' || halt "Error installing ROOT"
popd
python -c 'import ROOT, root_numpy' || halt "Error installing root_numpy"
python -c 'import xgboost' || halt "Error installing XGboost"

echo $PYTHONPATH
ipython -c "import os, sys, IPython
#print os.environ['VIRTUAL_ENV']
print os.getcwd()
print sys.executable
print IPython.__file__
print sys.path
print sys.argv
"

find $HOME/miniconda/pkgs -name "*tar.bz2" | xargs md5sum
# environment
cat << EOF
# add to your environment:
export PATH=$HOME/miniconda/bin:$PATH
source activate $PENV_NAME
pushd $ENV_BIN_DIR/.. ; source 'bin/thisroot.sh' ; popd
EOF
