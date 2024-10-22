FROM ubuntu:24.04

RUN cp /home/ubuntu/.bashrc /root/.bashrc

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Seoul

RUN apt-get update \
  && apt-get install -y software-properties-common \
  && add-apt-repository ppa:deadsnakes/ppa \
  && apt-get install -y python3.11 pip \
  && apt-get update \
  && apt-get install -y \
     sudo \
     gettext \
     # envsubst 사용 할 수 있게 하는 패키지
     openssh-server \
     curl \
     net-tools \
     git \
     wget \
     tree \
     vim \
     openssh-server \
     mysql-server \
     openjdk-17-jre-headless \
     telnet \
     tcpdump \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -s /bin/python3.11 /bin/python

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1


RUN pip install kafka-python pandas sqlalchemy pymysql asyncssh
RUN pip install --force-reinstall cffi
RUN pip install --force-reinstall cryptography


RUN echo "\nexport JAVA_HOME=/usr/lib/jvm/java-1.17.0-openjdk-amd64\n" >> /root/.bashrc

RUN cd &&  \
  mkdir zkdata &&  \
  cd zkdata &&  \
  echo 1 > ./myid

# Kafka 다운로드 및 압축 해제
RUN mkdir -p /root/app/kafka && \
  cd /root/app/kafka && \
  wget https://downloads.apache.org/kafka/3.6.2/kafka_2.13-3.6.2.tgz && \
  tar -xzf kafka_2.13-3.6.2.tgz && \
  rm kafka_2.13-3.6.2.tgz


#### 여기부터 SSH 
RUN mkdir /var/run/sshd

# root password 변경, $PASSWORD를 변경한다.
RUN echo 'root:$PASSWORD' |  chpasswd

# ssh 설정 변경
# root 계정으로의 로그인을 허용한다. 아래 명령을 추가하지 않으면 root 계정으로 로그인이 불가능하다. 
RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
# 응용 프로그램이 password 파일을 읽어 오는 대신 PAM이 직접 인증을 수행 하도록 하는 PAM 인증을 활성화
# RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

RUN sed -ri 's/^#Port 22/Port 22/' /etc/ssh/sshd_config

RUN sed -ri 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config



# SSH 키 생성
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N ""

# SSH 설정
RUN mkdir -p /root/.ssh && \
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh

# ssh 최초 접속시 yes 생략
RUN echo "Host server*\n \
 StrictHostKeyChecking no\n \
 UserKnownHostsFile=/dev/null" >> /root/.ssh/config


# MySQL 초기화 설정
RUN chown -R mysql:mysql /var/run/mysqld
RUN chmod 755 /var/run/mysqld

RUN sed -ri 's/^#.+port.+= 3306/port = 3306/' /etc/mysql/mysql.conf.d/mysqld.cnf
RUN sed -ri 's/^bind-address.+= 127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

RUN service mysql start && \
    mysql -e "CREATE DATABASE IF NOT EXISTS mydatabase; \
    CREATE USER 'ubuntu'@'%' IDENTIFIED BY '1234'; \
    GRANT ALL PRIVILEGES ON *.* TO 'ubuntu'@'%' WITH GRANT OPTION; \
    FLUSH PRIVILEGES;"

RUN echo "[mysqld]\n \
    character-set-server=utf8\n \
    collation-server=utf8_general_ci\n \
    \n \
    [client]\n \
    default-character-set=utf8\n \
    \n \
    [mysql]\n \
    default-character-set=utf8" >> /etc/mysql/mysql.conf.d/mysqld.cnf
    

# 포트 노출
# EXPOSE 22
# EXPOSE 3306


# SSH와 MySQL을 동시에 실행하기 위한 커맨드
CMD [ \
  "/bin/bash", "-c", \
  "service mysql start && /usr/sbin/sshd -D" \
]
