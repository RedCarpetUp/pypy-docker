FROM buildpack-deps:sid

# ensure local pypy is preferred over distribution pypy
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# runtime dependencies
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     tcl \
#     tk \
#     && rm -rf /var/lib/apt/lists/*

ENV PYPY_VERSION 7.3.1

RUN set -ex; \
    \
    # this "case" statement is generated via "update.sh"
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
    # amd64
    amd64) pypyArch='linux64'; sha256='f67cf1664a336a3e939b58b3cabfe47d893356bdc01f2e17bc912aaa6605db12' ;; \
    *) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding PyPy $PYPY_VERSION binary release"; exit 1 ;; \
    esac; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    # sometimes "pypy3" itself is linked against libexpat1 / libncurses5, sometimes they're ".so" files in "/usr/local/lib_pypy"
    libexpat1 \
    libncurses5 \
    # (so we'll add them temporarily, then use "ldd" later to determine which to keep based on usage per architecture)
    ; \
    \
    wget -O pypy.tar.bz2 "https://bitbucket.org/pypy/pypy/downloads/pypy3.6-v${PYPY_VERSION}-${pypyArch}.tar.bz2" --progress=dot:giga; \
    echo "$sha256 *pypy.tar.bz2" | sha256sum -c; \
    tar -xjC /usr/local --strip-components=1 -f pypy.tar.bz2; \
    sed  's/PyAPI_FUNC(int) Py_EnterRecursiveCall(char \*arg0)/PyAPI_FUNC(int) Py_EnterRecursiveCall(const char \*arg0)/g' -i  /usr/local/include/pypy_decl.h; \
    sed  's/PyAPI_FUNC(PyObject \*) PyErr_SetFromErrnoWithFilename(PyObject \*arg0, char \*arg1)/PyAPI_FUNC(PyObject \*) PyErr_SetFromErrnoWithFilename(PyObject \*arg0, const char \*arg1)/g' -i  /usr/local/include/pypy_decl.h; \
    find /usr/local/lib-python -depth -type d -a \( -name test -o -name tests \) -exec rm -rf '{}' +; \
    rm pypy.tar.bz2; \
    \
    # smoke test
    pypy3 --version; \
    \
    if [ -f /usr/local/lib_pypy/_ssl_build.py ]; then \
    # on pypy3, rebuild ffi bits for compatibility with Debian Stretch+ (https://github.com/docker-library/pypy/issues/24#issuecomment-409408657)
    cd /usr/local/lib_pypy; \
    pypy3 _ssl_build.py; \
    # TODO rebuild other cffi modules here too? (other _*_build.py files)
    fi; \
    \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
    | awk '/=>/ { print $(NF-1) }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    # smoke test again, to be sure
    pypy3 --version; \
    \
    find /usr/local -depth \
    \( \
    \( -type d -a \( -name test -o -name tests \) \) \
    -o \
    \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' +

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 20.0.2
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/d59197a3c169cef378a22428a3fa99d33e080a5d/get-pip.py
ENV PYTHON_GET_PIP_SHA256 421ac1d44c0cf9730a088e337867d974b91bdce4ea2636099275071878cc189e

RUN set -ex; \
    \
    wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
    echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum --check --strict -; \
    \
    pypy3 get-pip.py \
    --disable-pip-version-check \
    --no-cache-dir \
    "pip==$PYTHON_PIP_VERSION" \
    ; \
    # smoke test
    pip --version; \
    \
    find /usr/local -depth \
    \( \
    \( -type d -a \( -name test -o -name tests \) \) \
    -o \
    \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
    \) -exec rm -rf '{}' +; \
    rm -f get-pip.py

# CMD ["pypy3"]


WORKDIR /usr/src/app


# Tell Python not to recreate the bytecode files. Since this is a docker image,
# these will be recreated every time, writing them just uses unnecessary disk
# space.
ENV PYTHONDONTWRITEBYTECODE=true

RUN apt-get  update &&  apt-get install -y build-essential 

#4 opencv3
ENV OPENCV_VERSION 3.4.2


RUN apt-get install --no-install-recommends -y openssh-client git cmake make




RUN apt-get install --no-install-recommends -y libopenblas-base  libopenblas-dev 

RUN apt-get install -y gfortran
RUN pip install --no-cache-dir  numpy cython 

RUN apt-get install -y libopenblas-dev liblapack-dev 
RUN  pip install git+https://github.com/scipy/scipy@master#egg=scipy

RUN pip install --no-cache-dir  pandas dask 

# RUN pip install --no-cache-dir  pandas dask 

RUN apt-get install -y llvm-8-dev  llvm-8 
RUN update-alternatives --install /usr/local/bin/llvm-config llvm-config /usr/bin/llvm-config-8 40 && \
    # update-alternatives --install /usr/local/bin/clang clang /usr/bin/clang-8 40 && \
    update-alternatives --install /usr/local/bin/opt opt /usr/bin/opt-8 40 && \
    update-alternatives --install /usr/local/bin/llvm-link llvm-link /usr/bin/llvm-link-8 40
RUN pip install --no-cache-dir  llvmlite


RUN apt-get install -y libqpdf-dev
# ENV CFLAGS "-fpermissive"
RUN pip install --no-cache-dir pikepdf


ADD requirements.txt .

RUN pip install -r /usr/src/app/requirements.txt

RUN pip install gunicorn uvicorn inotify
RUN pip install databases fastapi
RUN pip install pydantic[email]

RUN pip install pendulum==2.0.3
# RUN pip install opencv-python
RUN git clone https://github.com/skvark/opencv-python
WORKDIR opencv-python
ENV ENABLE_HEADLESS=1
RUN git submodule update --init --recursive
RUN ln -sf /usr/local/bin/pypy3 /usr/local/bin/python3.6
RUN CMAKE_ARGS="-DPYTHON3_INCLUDE_DIR=/opt/pypy3/include  -D PYTHON3_LIBRARY=~/.pyenv/versions/pypy3.6-7.2.0/lib/libpypy-c.so" pypy3 setup.py bdist_wheel

RUN pip install dist/**.whl

RUN pip install  async-exit-stack async-generator

RUN pip install git+https://github.com/chtd/psycopg2cffi.git@master#psycopg2cffi

WORKDIR /usr/src/app

RUN pip install pycryptodome

# if implementation.name == "pypy":
# from psycopg2cffi import compat

# compat.register()

# You should use this in your python code
# if version_info < (3, 6, 0):
# raise RuntimeError(
# "Not intended to run on the Python less than '3.6.0' Got version: '%s.%s.%s'"
# % version_info[:3]
# )

# if version_info < (3, 7, 0):
# try:
# import async_generator

# # from async_exit_stack import AsyncExitStack
# # from async_generator import asynccontextmanager
# except ImportError:
# raise ImportError(
# "You should install 'async_generator' package to run tests in Python 3.6"
# )
# else:
# from contextlib import asynccontextmanager