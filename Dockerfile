
# Step 0 - Base image JAVA 8
FROM openjdk:8-jre

# Step 1 - Update and install packages 
RUN apt-get update && \
  apt-get -y install lsof procps wget gpg && \
  rm -rf /var/lib/apt/lists/*

# Step 2 - Set up variables
ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="4.10.4" \
    SOLR_URL="https://archive.apache.org/dist/lucene/solr/4.10.4/solr-4.10.4.tgz" \
    SOLR_SHA256="ac3543880f1b591bcaa962d7508b528d7b42e2b5548386197940b704629ae851" \
    SOLR_KEYS="https://archive.apache.org/dist/lucene/solr/4.10.4/KEYS" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

# Step 3 - Add group and user
RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

# Step 5 - Check Signature
RUN echo "downloading $SOLR_KEYS" && \
  wget -nv $SOLR_KEYS -O /opt/KEYS && \
  gpg --import /opt/KEYS && \
  echo "downloading $SOLR_URL.asc" && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  gpg --verify /opt/solr.tgz.asc && \
  echo "downloading $SOLR_URL" && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \

# Step 4 - Download Solr and .asc file and check hashes
# RUN mkdir -p /opt/solr && \
#   echo "downloading $SOLR_URL" && \
#   wget -nv $SOLR_URL -O /opt/solr.tgz && \
#   echo "downloading $SOLR_URL.asc" && \
#   wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
#   echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
#   (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
#   gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
#   echo "Hashes checked"

# Step 6 - Extract Solr and install
RUN tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr /opt/mysolrhome && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr /opt/mysolrhome

# Step 7 - Copy scripts and permissions
COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/docker-solr

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
