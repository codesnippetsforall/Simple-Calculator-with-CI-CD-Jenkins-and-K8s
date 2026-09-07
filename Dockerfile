FROM httpd:alpine
COPY index.html /usr/local/apache2/htdocs/index.html
# HOSTNAME in Kubernetes is the pod name; inject it into the page at container start.
ENTRYPOINT ["/bin/sh", "-c", "sed -i \"s/__POD_HOSTNAME__/${HOSTNAME:-unknown}/g\" /usr/local/apache2/htdocs/index.html && exec httpd-foreground"]
