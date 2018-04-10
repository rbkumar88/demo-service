FROM repos.gbt.gbtad.com:9444/gbt/alpine-java:8_server-jre_unlimited_gbtcerts
ENV PORT=8080 

ARG VERSION
ARG ARTIFACT_ID

ENV VERSION ${VERSION:-0.0.1-SNAPSHOT}
ENV ARTIFACT_ID ${ARTIFACT_ID:-demo}

# Change working directory for spring-boot-app
WORKDIR /opt/spring-boot-app

# Create directories for  logs
RUN mkdir /var/log/RT
RUN mkdir /var/log/BT
RUN chmod -R 777 /var/log/

EXPOSE 8080 8080

ADD target/${ARTIFACT_ID}-${VERSION}.jar /opt/spring-boot-app
CMD java -Xmx512m -jar  ${ARTIFACT_ID}-${VERSION}.jar
