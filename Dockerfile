FROM ubuntu:16.04
LABEL maintainer="Markus Krogh <markus@nordu.net>"

RUN apt-get update && apt-get install -y apache2 libapache2-mod-auth-mellon wget
RUN a2enmod auth_mellon ssl proxy proxy_http proxy_balancer lbmethod_byrequests headers && a2dissite 000-default

ADD apache2 /opt/templates/
ADD saml-entrypoint.sh /
CMD ["/saml-entrypoint.sh"]

