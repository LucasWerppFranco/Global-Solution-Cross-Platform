# Ambiente de build do Território Vivo: Flutter 3.44.0 + Android SDK 36.
# Construída automaticamente por scripts/flutter.sh (tag: territorio-vivo-flutter).
FROM ghcr.io/cirruslabs/flutter:3.44.0

# Pré-aquece os caches (artefatos web/android, distribuição do Gradle,
# dependências Maven e NDK) com um projeto descartável. Assim os builds do
# app não baixam gigabytes a cada execução.
RUN flutter config --no-analytics \
 && flutter precache --android --web \
 && flutter create --platforms android,web /tmp/warmup \
 && cd /tmp/warmup \
 && flutter build apk --debug \
 && cd / && rm -rf /tmp/warmup

WORKDIR /app
