FROM python:3.8.2-alpine

# install git
RUN apk update
RUN apk add git openssh-client openssh-keygen

# clone repo to /app
RUN mkdir /app
RUN git clone https://github.com/iosusan/prefect_2.git /app

# any CLI param will be appended to this line
ENTRYPOINT ["python3","/app/src/myapp.py"]

