FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /src

COPY pom.xml .

RUN mvn -q dependency:go-offline

COPY src ./src

RUN mvn -q package -DskipTests


FROM eclipse-temurin:21-jre

WORKDIR /app

RUN useradd \
    --system \
    --no-create-home \
    benchmark

COPY --from=build \
    /src/target/benchmark-java-cassandra-api-1.0.0.jar \
    /app/benchmark-api.jar

USER benchmark

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/benchmark-api.jar"]
