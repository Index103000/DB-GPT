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
