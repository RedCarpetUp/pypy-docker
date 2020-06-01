FROM python:3.8-slim as build_base

ENV LANG=C.UTF-8

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

# RUN pip install --no-cache-dir scipy

# RUN pip install --no-cache-dir \


# RUN pip install async-exit-stack async-generator

############## extra dependencies for xgboost #################
RUN apt-get install -y libgomp1 libaio-dev libaio1 tzdata
# RUN pip install --no-cache-dir xgboost
# RUN pip install uvicorn gunicorn inotify



################# first time clone ################
WORKDIR /app
# ENV CFLAGS="-I/usr/include/"
# ENV LDFLAGS="-L/usr/glibc-compat/lib -L/opt/conda/lib"
# RUN git clone -b feature/docker --single-branch --depth 1 git@bitbucket.org:redcarpetup/desktop-ux.git  /app



LABEL GIT_REF="$(git rev-parse --short HEAD)"


WORKDIR /app

################## shared packages for chromium headless ######################
RUN apt-get install -y libx11-xcb1 libxcb1 libx11-6 libxcomposite1 libxcursor1 \
    libxdamage1 libxext6 libxi6 libxtst6 libgtk-3-0 libnss3 libxss1 libasound2 libpq-dev zlib1g-dev libjpeg-dev
RUN pip install pyppeteer && pyppeteer-install
# RUN pip install opencv-contrib-python-headless bchlib  xxhash pyzbar
RUN apt-get install -y libzbar0 curl procps


LABEL GIT_REF="$(git rev-parse --short HEAD)"

RUN echo "Asia/Kolkata" > /etc/timezone &&  cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

RUN export LC_ALL=C.UTF-8
RUN export LANG=C.UTF-8
RUN export LC_CTYPE=C.UTF-8

ADD ./static-requirements.txt /app/rc/static-requirements.txt
RUN pip install --no-cache-dir -r /app/rc/static-requirements.txt > /tmp/out

ADD ./requirements.txt /app/rc/requirements.txt
# ADD marvin/libraries/  /app/apiv5/marvin/libraries/

RUN pip install --no-cache-dir -r /app/rc/requirements.txt > /tmp/out

RUN pip install fastapi gunicorn psycopg2-binary inotify uvicorn pydantic[email] pycryptodome
RUN pip install pendulum
ADD . /app/rc
RUN  apt-get remove -y gcc build-essential cmake make git libpq-dev openssh-client && apt-get autoremove -y && apt-get clean -y

# CMD  ["supervisord -c /supervisord.conf"]
