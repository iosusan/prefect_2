FROM python:3.8.2-alpine

# install git
RUN apk update
RUN apk add git openssh-client openssh-keygen

# clone repo to /app
RUN mkdir /app
#RUN mkdir /root/.ssh
#RUN ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N ""
#RUN ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts
RUN git clone https://github.com/iosusan/prefect_2.git /app

# any CLI param will be appended to this line
ENTRYPOINT ["python3","/app/src/myapp.py"]

