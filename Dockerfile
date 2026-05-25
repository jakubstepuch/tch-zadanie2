FROM busybox:1.37

RUN adduser -D static

USER static
WORKDIR /home/static

COPY src .

CMD ["busybox", "httpd", "-f", "-v", "-p", "3000"]
