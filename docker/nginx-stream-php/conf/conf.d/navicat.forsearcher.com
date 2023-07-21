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
