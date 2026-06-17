# ===== Build =====
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY pom.xml ./
COPY overcut/pom.xml overcut/pom.xml
COPY f1Hub/pom.xml f1Hub/pom.xml

COPY overcut/src overcut/src
COPY overcut/frontend overcut/frontend

WORKDIR /app/overcut
RUN mvn -DskipTests package

# ===== Runtime =====
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY --from=build /app/overcut/target/*.[jw]ar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
