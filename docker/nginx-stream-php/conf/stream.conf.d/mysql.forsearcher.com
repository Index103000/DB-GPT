upstream mysql {
    server mysql:3306;
}

server {
    listen 33060;
    proxy_pass mysql;
}
