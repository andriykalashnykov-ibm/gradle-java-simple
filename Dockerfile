# Build stage - compile the application
FROM --platform=linux/amd64 gradle:9.1.0-jdk21 AS builder

WORKDIR /build

# Copy source files
COPY gradle gradle
COPY gradlew gradlew.bat gradle.properties settings.gradle ./
COPY app app

# Build the application
RUN ./gradlew :app:build -x test

# Runtime stage - use FIPS-enabled Semeru runtime
FROM --platform=linux/amd64 icr.io/webmethods/stig-hardened-images/dev-release/ubi9/ubi9-basic-java-semeru21-runtime:latest

WORKDIR /app

USER root

# Copy compiled classes and dependencies
COPY --from=builder /build/app/build/classes/java/main /app/classes
COPY --from=builder /build/app/build/libs /app/libs
COPY --from=builder /root/.gradle/caches /root/.gradle/caches

RUN ln -sf /etc/ssl/conf.d/openssl-fips.cnf /etc/ssl/openssl.cnf && update-crypto-policies --set FIPS

USER 1001

# Set FIPS mode
ENV JAVA_TOOL_OPTIONS="-Dsemeru.fips=true -Dsemeru.customprofile=OpenJCEPlusFIPS.FIPS140-3"

# Build classpath and run FIPSValidatorRunner
CMD CLASSPATH="/app/classes"; \
    for jar in $(find /root/.gradle/caches/modules-2/files-2.1 -name "*.jar" 2>/dev/null); do \
        CLASSPATH="$CLASSPATH:$jar"; \
    done; \
    java -cp "$CLASSPATH" org.example.FIPSValidatorRunner
