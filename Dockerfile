ARG BASEIMAGE=alpine:3
FROM $BASEIMAGE as base

RUN true \
 && apk add --update --no-cache \
      cairo \
      cairo-dev \
      findutils \
      librrd \
      memcached \
      nodejs \
      npm \
      openldap \
      redis \
      sqlite \
      expect \
      python3-dev \
      postgresql-client \
      postgresql-dev \
      librdkafka \
      jansson \
      bash \
 && mkdir -p \
      /var/log/graphite \
 && touch /var/log/messages

FROM base as build

ARG python_extra_flags="--single-version-externally-managed --root=/"
ENV PYTHONDONTWRITEBYTECODE=1

RUN true \
 && apk add --update \
      alpine-sdk \
      curl \
      git \
      pkgconfig \
      wget \
      go \
      cairo-dev \
      libffi-dev \
      openldap-dev \
      python3-dev \
      rrdtool-dev \
      jansson-dev \
      librdkafka-dev \
      postgresql-dev \
      py3-pip py3-setuptools py3-wheel py3-virtualenv \
 && virtualenv -p python3 /opt/graphite \
 && . /opt/graphite/bin/activate \
 && echo 'INPUT ( libldap.so )' > /usr/lib/libldap_r.so \
 && pip install --no-cache-dir \
      cairocffi==1.1.0 \
      django==4.2.15 \
      django-tagging==0.5.0 \
      django-statsd-mozilla \
      gunicorn==20.1.0 \
      eventlet>=0.24.1 \
      gevent>=1.4 \
      msgpack==0.6.2 \
      redis \
      rrdtool-bindings \
      python-ldap \
      psycopg2==2.8.6 \
      django-cockroachdb==4.2.*

ARG version=master


# install graphite
ARG graphite_version=${version}
ARG graphite_repo=https://github.com/graphite-project/graphite-web.git
RUN . /opt/graphite/bin/activate \
 && git clone -b ${graphite_version} --depth 1 ${graphite_repo} /usr/local/src/graphite-web \
 && cd /usr/local/src/graphite-web \
 && pip3 install --no-cache-dir -r requirements.txt \
 && python3 ./setup.py install $python_extra_flags


COPY conf/opt/graphite/conf/                             /opt/defaultconf/graphite/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/defaultconf/graphite/local_settings.py

# config graphite
COPY conf/opt/graphite/conf/* /opt/graphite/conf/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
WORKDIR /opt/graphite/webapp
RUN mkdir -p /var/log/graphite/ \
  && PYTHONPATH=/opt/graphite/webapp /opt/graphite/bin/django-admin collectstatic --noinput --settings=graphite.settings

FROM base as production

# copy config BEFORE build
COPY conf /

# copy from build image
COPY --from=build /opt /opt

# defaults
EXPOSE 8181
VOLUME ["/opt/graphite/conf", "/opt/graphite/storage", "/opt/graphite/webapp/graphite/functions/custom"]

STOPSIGNAL SIGHUP

ENTRYPOINT ["/entrypoint"]
