FROM node:16-alpine AS web-build
WORKDIR /src/web
COPY web/package*.json ./
RUN npm install --no-audit --no-fund
COPY web/ ./
RUN npm run build

FROM gradle:6.1.1-jdk8 AS app-build
WORKDIR /src
COPY --chown=gradle:gradle . ./
COPY --from=web-build /src/web/dist ./src/main/resources/web
RUN rm -f src/main/java/com/htmake/reader/ReaderUIApplication.kt \
    && gradle -b cli.gradle assemble --no-daemon --stacktrace \
    && cp build/libs/*.jar /tmp/reader.jar

FROM amazoncorretto:8-alpine
ENV TZ=Asia/Shanghai JAVA_OPTS="-Dfile.encoding=UTF-8"
RUN apk add --no-cache ca-certificates tini wget tzdata && update-ca-certificates
WORKDIR /app
COPY --from=app-build /tmp/reader.jar /app/bin/reader.jar
RUN mkdir -p /app/logs /data
EXPOSE 6788
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["sh", "-c", "exec java $JAVA_OPTS -jar /app/bin/reader.jar"]
