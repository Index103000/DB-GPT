# 使用 nginx:1.22.1 作为基础镜像
FROM nginx:1.22.1

# 安装编译工具和依赖项
RUN apt-get update && \
    apt-get install -y build-essential && \
    apt-get install -y libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev

# 下载 Nginx 源码
# 配置并编译 Nginx，包含 stream 模块
WORKDIR /tmp
RUN apt-get install wget && wget http://nginx.org/download/nginx-1.22.1.tar.gz && \
    tar -xvf nginx-1.22.1.tar.gz && \
    cd nginx-1.22.1 &&  \
    ./configure --with-stream && \
    make && \
    make install

# 清理安装后的无用文件
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 使用 ENTRYPOINT 而不是 CMD，以便在运行容器时可以传递参数
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
