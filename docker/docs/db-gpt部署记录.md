## docker desktop

### 镜像源（有时候，带着镜像反而不行）

```json
  {
      "registry-mirrors": [
            "https://docker.mirrors.ustc.edu.cn"
      ]
  }
```



## nginx

### 构建安装`stream`模块的nginx

Nginx Docker 镜像

一、基于 nginx 1.22.1 版本制作的，支持 stream 反向代理的镜像；

二、/docker/nginx-stream-php/conf/conf.d 目录存放 HTTP 反向代理配置文件；

三、/docker/nginx-stream-php/conf/stream.conf.d 目录存放 stream（ssh、tcp） 反向代理配置文件；

### Dockerfile

#### nginx Dockerfile（开启 stream）

```dockerfile
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

```

#### php-fpm Dockerfile（安装有 mysqli）

```dockerfile
# 使用 php:5.6-fpm 作为基础镜像
FROM php:5.6-fpm

# Install MySQL extension
RUN docker-php-ext-install mysqli
```

### 构建镜像

```sh
# 构建 nginx
cd /docker/nginx-stream-php/
docker build -t nginx-stream-php:1.22.1 .

# 构建 php-fpm
cd /docker/nginx-stream-php/php-fpm
docker build -t php-mysql:5.6-fpm


```

### nginx基础配置

/docker/nginx-stream-php/conf/nginx.conf

```sh
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    client_max_body_size 100m;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    include /etc/nginx/conf.d/*;
}

stream {
    include /etc/nginx/stream.conf.d/*;
}
```

#### 基础http服务转发

/docker/nginx-stream-php/conf/conf.d/admin.forsearcher.com

```sh
# gateway upstream
upstream gateway {
    ip_hash;
    # gateway 地址
    server 127.0.0.1:8080;
    # server 127.0.0.1:8081;
}

server {
    listen       80;
    server_name  admin.forsearcher.com;

    access_log  /var/log/nginx/admin.forsearcher.com/access.log  main;

    location ~ ^(/[^/]*)?/actuator(/.*)?$ {
        return 403;
    }

    location / {
        root   /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        index  index.html index.htm;
    }

    location /prod-api/ {
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://gateway/;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   html;
    }
}
```

#### mysql转发

##### 通过stream配置nginx转发mysql

/docker/nginx-stream-php/conf/stream.conf.d/mysql.forsearcher.com 配置文件内容如下
```sh
upstream mysql {
    server mysql:3306;
}

server {
    listen 33060;
    proxy_pass mysql;
}
```

##### 通过http配置nginx转发mysql（navicat ntunnel_mysql.php）

/docker/nginx-stream-php/conf/conf.d/admin.forsearcher.com 配置文件内容如下

```sh
# 定义 PHP-FPM 上游服务器
upstream php-fpm {
    server php-fpm:9000;
}

server {
    listen  3307;
    server_name  navicat.forsearcher.com;

    access_log  /var/log/nginx/navicat.forsearcher.com/access.log  main;

    root   /usr/share/php-fpm/html;

    # 处理非 PHP 请求
    location / {
        index  index.html index.htm index.php ;
        try_files $uri $uri/ /index.php?$query_string;
        autoindex  on;
    }

    # 处理 PHP 请求
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
```

TODO: 待补充 navicat 连接示例截图说明

## 配置 docker-compose.yml

/docker/docker-compose.yml

```yaml
version: '3.10'

services:
  mysql:
    image: mysql:8.0.33
    environment:
      MYSQL_DATABASE: 'db_gpt'
      MYSQL_USER: 'user'
      MYSQL_PASSWORD: 'password'
      MYSQL_ROOT_PASSWORD: 'dbgpt@forsearcher.com'
    ports:
      - "3306:3306"
    volumes:
      # 数据挂载
      - ./mysql/data/:/var/lib/mysql/
      # 配置挂载
      - ./mysql/conf/:/etc/mysql/conf.d/
    command:
      # 将mysql8.0默认密码策略 修改为 原先 策略 (mysql8.0对其默认策略做了更改 会导致密码无法匹配)
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_general_ci
      --explicit_defaults_for_timestamp=true
      --lower_case_table_names=1

  webserver:
    build:
      context: ../
      dockerfile: Dockerfile
    command: python3 pilot/server/webserver.py
    environment:
      - MODEL_SERVER=http://llmserver:8000
      - LOCAL_DB_HOST=mysql
      - WEB_SERVER_PORT=7860
      - ALLOWLISTED_PLUGINS=db_dashboard
    depends_on:
      - mysql
      - llmserver
    volumes:
      - ../models:/app/models
      - ../plugins:/app/plugins
      - ./webserver/data:/app/pilot/data
    env_file:
      - ../.env.template
    ports:
      - "7860:7860"

  llmserver:
    build:
      context: ../
      dockerfile: Dockerfile
    command: python3 pilot/server/llmserver.py
    environment:
      - LOCAL_DB_HOST=mysql
    depends_on:
      - mysql
    volumes:
      - ../models:/app/models
    env_file:
      - ../.env.template
    ports:
      - "8000:8000"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0']
              capabilities: [gpu]

  nginx-stream-php:
    image: nginx-stream-php:1.22.1
    container_name: nginx-stream-php
    environment:
      # 时区上海
      TZ: Asia/Shanghai
    ports:
      - "80:80"
      - "33060:33060"
      - "3307:3307"
    volumes:
      # nginx证书映射
      - ./nginx-stream-php/cert:/etc/nginx/cert
      # nginx配置文件映射
      - ./nginx-stream-php/conf/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx-stream-php/conf/conf.d:/etc/nginx/conf.d
      - ./nginx-stream-php/conf/stream.conf.d:/etc/nginx/stream.conf.d
      # nginx页面目录
      - ./nginx-stream-php/html:/usr/share/nginx/html
      # php-fpm页面目录
      - ./nginx-stream-php/php-fpm/html:/usr/share/php-fpm/html
      # nginx日志目录
      - ./nginx-stream-php/log:/var/log/nginx
    depends_on:
      - php-fpm

  php-fpm:
    image: php-mysql:5.6-fpm
    container_name: php-fpm
    environment:
      # 时区上海
      TZ: Asia/Shanghai
    ports:
      - "9000:9000"
    volumes:
      # php-fpm页面目录
      - ./nginx-stream-php/php-fpm/html:/usr/share/php-fpm/html
      # 日志目录
#      - ./docker/nginx-stream-php/php-fpm/log:/var/log
      # php 配置
#      - ./docker/nginx-stream-php/php-fpm/conf:/usr/local/etc/php

  tunnel:
    image: cloudflare/cloudflared:2023.7.1
    container_name: cloudflared-tunnel
    command: tunnel --no-autoupdate run --token eyJhIjoiYjUzNWE0MDNhMzJhMmM4YzQ2YzliMWQyNjNmYTNmMzUiLCJ0IjoiNWE0MTNlY2ItODY2ZS00ZGRkLWEyNzctYzkyNjY1MWE2OGY2IiwicyI6Ik5XRTNZVFZsTUdJdE1tTXhNaTAwTURCbExXSXlZalF0TkRjd1pESXhNak00T0RCbSJ9

```

## 利用Cloudflare Pages中转api.openai.com

* TODO 待补充操作截图说明



