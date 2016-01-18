FROM fluent/fluentd:0.12.19
MAINTAINER Eduard Zaharia <eduard.zaharia@eaudeweb.ro>

USER root
RUN gem install fluent-plugin-record-reformer --no-rdoc --no-ri && \
    gem install fluent-plugin-elasticsearch --no-rdoc --no-ri && \
    gem install gelf --no-rdoc --no-ri
USER fluent
