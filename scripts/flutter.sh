#!/usr/bin/env sh
# Roda o Flutter dentro da imagem Docker do projeto (sem SDK local).
# Uso: ./scripts/flutter.sh <argumentos do flutter>
#   ex.: ./scripts/flutter.sh test
#        DOCKER_ARGS="-p 8080:8080" ./scripts/flutter.sh run -d web-server --web-hostname 0.0.0.0 --web-port 8080
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="territorio-vivo-flutter"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo ">> Construindo a imagem $IMAGE (só na primeira vez, alguns minutos)..."
  docker build --network host -t "$IMAGE" "$ROOT/docker" || exit 1
fi

# O container roda como root; ao sair, devolve a posse dos arquivos gerados
# (build/, .dart_tool/, pubspec.lock) ao usuário do host.
fix_owner() {
  docker run --rm -v "$ROOT:/app" --entrypoint chown "$IMAGE" -R "$(id -u):$(id -g)" /app
}
trap fix_owner EXIT
trap 'exit 130' INT TERM

TTY=""
[ -t 0 ] && [ -t 1 ] && TTY="-it"

docker run --rm $TTY \
  -v "$ROOT:/app" -w /app \
  -v territorio-vivo-pub:/root/.pub-cache \
  -v territorio-vivo-gradle:/root/.gradle \
  ${DOCKER_ARGS:-} "$IMAGE" flutter "$@"
