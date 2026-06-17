# ===== Build =====
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Root + poms de módulos (para caché)
COPY pom.xml ./
COPY f1Hub/pom.xml f1Hub/pom.xml
COPY overcut/pom.xml overcut/pom.xml
COPY overcutPredictions/pom.xml overcutPredictions/pom.xml

# Código necesario (para que el reactor exista)
COPY f1Hub/frontend f1Hub/frontend
COPY f1Hub/src f1Hub/src

COPY overcut/src overcut/src
COPY overcut/frontend overcut/frontend

COPY overcutPredictions/src overcutPredictions/src
COPY overcutPredictions/frontend overcutPredictions/frontend

# Build del módulo f1Hub (reactor completo)
RUN mvn -DskipTests -Pdocker -pl f1Hub -am package

# ===== Runtime =====
FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY --from=build /app/f1Hub/target/*.jar app.jar

EXPOSE 8082
ENTRYPOINT ["java","-jar","app.jar"]
