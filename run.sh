#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# run.sh (CLI-only, sem abrir Xcode GUI)
#
# Uso:
#   ./run.sh ios
#   ./run.sh ipad
#   ./run.sh ios <UDID>
#   ./run.sh ipad <UDID>
#
# Opcional (env):
#   SCHEME=BLEControlApp
#   CONFIG=Debug
#   WORKSPACE=BLEControlApp.xcworkspace
#   PROJECT=BLEControlApp.xcodeproj
#   BUNDLE_ID=com.gustavosore.blecontrolapp
#   AUTO_YES=1                           # aceita prompts automaticamente
#   ALLOW_PLATFORM_DOWNLOAD=1            # baixa plataforma iOS se faltar
#   ALLOW_PROVISIONING_UPDATES=1         # passa -allowProvisioningUpdates
# ============================================================

PLATFORM="${1:-}"
UDID="${2:-}"

if [[ -z "$PLATFORM" ]]; then
  echo "Uso: $0 <ios|ipad> [udid]"
  exit 1
fi
if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "ipad" ]]; then
  echo "[erro] plataforma inválida: $PLATFORM (use ios ou ipad)"
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-BLEControlApp}"
CONFIG="${CONFIG:-Debug}"
BUNDLE_ID="${BUNDLE_ID:-com.gustavosore.blecontrolapp}"
WORKSPACE="${WORKSPACE:-}"
PROJECT="${PROJECT:-}"
AUTO_YES="${AUTO_YES:-0}"
ALLOW_PLATFORM_DOWNLOAD="${ALLOW_PLATFORM_DOWNLOAD:-0}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

step() { echo; echo "============================================================"; echo "[$1] $2"; echo "============================================================"; }
info() { echo "[info] $*"; }
warn() { echo "[warn] $*" >&2; }
err()  { echo "[erro] $*" >&2; }

ask_yes_no() {
  local prompt="$1"
  if [[ "$AUTO_YES" == "1" ]]; then
    echo "[auto-yes] $prompt -> y"
    return 0
  fi
  read -r -p "$prompt [y/N]: " ans
  [[ "${ans:-}" =~ ^[Yy]$ ]]
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "comando não encontrado: $1"; exit 1; }
}

extract_uuid_from_line() {
  grep -Eo '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' || true
}

xcodebuild_base_cmd() {
  if [[ -n "$WORKSPACE" ]]; then
    printf 'xcodebuild -workspace "%s" -scheme "%s" -configuration "%s"' "$WORKSPACE" "$SCHEME" "$CONFIG"
  else
    printf 'xcodebuild -project "%s" -scheme "%s" -configuration "%s"' "$PROJECT" "$SCHEME" "$CONFIG"
  fi
}

maybe_add_provisioning_flags() {
  local flags=""
  if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    flags+=" -allowProvisioningUpdates"
  fi
  printf "%s" "$flags"
}

ensure_project_or_workspace() {
  step "1/10" "Detectando .xcworkspace / .xcodeproj"

  if [[ -n "$PROJECT" && "$PROJECT" != *.xcodeproj ]]; then
    err "PROJECT inválido: $PROJECT (deve terminar com .xcodeproj)"
    exit 1
  fi
  if [[ -n "$WORKSPACE" && "$WORKSPACE" != *.xcworkspace ]]; then
    err "WORKSPACE inválido: $WORKSPACE (deve terminar com .xcworkspace)"
    exit 1
  fi

  if [[ -z "$WORKSPACE" && -z "$PROJECT" ]]; then
    if compgen -G "*.xcworkspace" >/dev/null; then
      WORKSPACE="$(ls -1d *.xcworkspace | head -n1)"
      info "Workspace detectado: $WORKSPACE"
    elif compgen -G "*.xcodeproj" >/dev/null; then
      PROJECT="$(ls -1d *.xcodeproj | head -n1)"
      info "Project detectado: $PROJECT"
    else
      err "Nenhum .xcworkspace ou .xcodeproj encontrado em: $ROOT"
      ls -la
      exit 1
    fi
  else
    [[ -n "$WORKSPACE" ]] && info "Workspace informado: $WORKSPACE"
    [[ -n "$PROJECT" ]] && info "Project informado: $PROJECT"
  fi

  if [[ -n "$WORKSPACE" && ! -d "$WORKSPACE" ]]; then
    err "Workspace não encontrado: $WORKSPACE"
    exit 1
  fi
  if [[ -n "$PROJECT" && ! -d "$PROJECT" ]]; then
    err "Project não encontrado: $PROJECT"
    exit 1
  fi
}

check_cli_tools() {
  step "2/10" "Validando ferramentas CLI"
  need_cmd xcodebuild
  need_cmd xcrun

  info "xcodebuild version:"
  xcodebuild -version

  if xcrun --find devicectl >/dev/null 2>&1; then
    info "devicectl disponível"
    HAS_DEVICECTL=1
  else
    warn "devicectl não encontrado"
    HAS_DEVICECTL=0
  fi

  if command -v ios-deploy >/dev/null 2>&1; then
    info "ios-deploy disponível (fallback)"
    HAS_IOS_DEPLOY=1
  else
    warn "ios-deploy não encontrado (fallback opcional)"
    HAS_IOS_DEPLOY=0
  fi

  if [[ "$HAS_DEVICECTL" -eq 0 && "$HAS_IOS_DEPLOY" -eq 0 ]]; then
    err "Você precisa de devicectl (preferencial) ou ios-deploy (fallback)."
    exit 1
  fi
}

validate_scheme_exists() {
  step "3/10" "Validando scheme"

  local list_out
  if [[ -n "$WORKSPACE" ]]; then
    list_out="$(xcodebuild -list -workspace "$WORKSPACE" 2>&1 || true)"
  else
    list_out="$(xcodebuild -list -project "$PROJECT" 2>&1 || true)"
  fi

  echo "$list_out"

  if ! grep -Fq "$SCHEME" <<< "$list_out"; then
    err "Scheme '$SCHEME' não encontrado."
    exit 1
  fi
}

print_devices_devicectl() {
  xcrun devicectl list devices 2>/dev/null || true
}

auto_find_udid_devicectl() {
  local kind="$1" # ios|ipad
  local out line lower uuid

  out="$(print_devices_devicectl)"
  [[ -z "${out// }" ]] && return 1

  while IFS= read -r line; do
    lower="$(echo "$line" | tr '[:upper:]' '[:lower:]')"

    [[ "$lower" != *"available"* ]] && continue
    [[ "$lower" == *"simulator"* ]] && continue
    [[ "$lower" == mac* ]] && continue

    uuid="$(echo "$line" | extract_uuid_from_line | head -n1)"
    [[ -z "$uuid" ]] && continue

    if [[ "$kind" == "ios" ]]; then
      [[ "$lower" == *"iphone"* ]] && { echo "$uuid"; return 0; }
    else
      [[ "$lower" == *"ipad"* ]] && { echo "$uuid"; return 0; }
    fi
  done <<< "$out"

  return 1
}

select_device() {
  step "4/10" "Selecionando dispositivo físico"

  if [[ -z "$UDID" ]]; then
    if [[ "$HAS_DEVICECTL" -eq 1 ]]; then
      info "Dispositivos detectados:"
      print_devices_devicectl
      if ! UDID="$(auto_find_udid_devicectl "$PLATFORM")"; then
        err "Não consegui escolher automaticamente um device $PLATFORM."
        err "Passe manualmente: ./run.sh $PLATFORM <UDID>"
        exit 2
      fi
    else
      err "Sem devicectl para auto-detecção. Passe UDID manualmente."
      exit 2
    fi
  fi

  if [[ ! "$UDID" =~ ^[0-9A-Fa-f-]{24,}$ ]]; then
    warn "UDID com formato inesperado: $UDID"
    ask_yes_no "Continuar mesmo assim?" || exit 1
  fi

  info "Device selecionado: $UDID"
  if [[ "$HAS_DEVICECTL" -eq 1 ]]; then
    info "Verificando estado do device via devicectl..."
    xcrun devicectl list devices | grep -F "$UDID" || {
      err "UDID não encontrado na lista do devicectl no momento."
      err "Confira cabo/Wi-Fi pareado e desbloqueie o dispositivo."
      exit 2
    }
  fi
}

ensure_platform_available() {
  step "5/10" "Checando suporte da plataforma iOS no Xcode"

  # Checagem rápida e confiável: não depende do device remoto.
  local sdks
  sdks="$(xcodebuild -showsdks 2>/dev/null || true)"

  if grep -qi "iphoneos" <<< "$sdks"; then
    info "SDK iphoneos disponível no toolchain atual."
    return 0
  fi

  warn "SDK iphoneos não encontrado neste Xcode/CLI tools."
  if [[ "$ALLOW_PLATFORM_DOWNLOAD" == "1" ]] || ask_yes_no "Baixar plataforma iOS agora via xcodebuild -downloadPlatform iOS?"; then
    xcodebuild -downloadPlatform iOS

    # Revalida após download
    sdks="$(xcodebuild -showsdks 2>/dev/null || true)"
    if grep -qi "iphoneos" <<< "$sdks"; then
      info "SDK iphoneos instalado com sucesso."
      return 0
    fi

    err "Download finalizado, mas iphoneos ainda não aparece em xcodebuild -showsdks."
    err "Tente: sudo xcodebuild -runFirstLaunch"
    exit 1
  fi

  err "Sem SDK iphoneos não há como buildar para device físico via CLI."
  exit 1
}

validate_target_is_ios_capable() {
  step "5.5/10" "Validando se o target/scheme suporta iOS"

  local pbxproj
  if [[ -n "$PROJECT" ]]; then
    pbxproj="$PROJECT/project.pbxproj"
  else
    # workspace: tenta localizar o primeiro .xcodeproj no diretório atual
    local first_proj
    first_proj="$(ls -1d *.xcodeproj 2>/dev/null | head -n1 || true)"
    pbxproj="${first_proj:+$first_proj/project.pbxproj}"
  fi

  if [[ -z "${pbxproj:-}" || ! -f "$pbxproj" ]]; then
    warn "Não foi possível localizar project.pbxproj para validação estática."
    warn "Seguindo para build..."
    return 0
  fi

  # Heurística: se existir referência a iphoneos/iphonesimulator/ios no projeto, considera iOS-capable.
  if grep -Eqi 'iphoneos|iphonesimulator|SUPPORTED_PLATFORMS\s*=\s*.*iphoneos|SDKROOT\s*=\s*iphoneos' "$pbxproj"; then
    info "Projeto contém sinais de suporte a iOS (iphoneos/iphonesimulator)."
    return 0
  fi

  err "Este projeto/scheme não parece ter target iOS."
  err "Por isso o xcodebuild retorna: 'Supported platforms for the buildables in the current scheme is empty'."
  echo
  echo "Como resolver (sem abrir IDE durante o build):"
  echo "  1) Garanta que exista um target iOS App no .xcodeproj (SDKROOT=iphoneos)."
  echo "  2) Use esse scheme no script: SCHEME=<SeuSchemeiOS> ./run.sh $PLATFORM ${UDID:-}"
  echo "  3) Se hoje só existe target macOS/SwiftPM executable, ele NÃO instala em iPhone/iPad."
  echo
  echo "Dica de verificação rápida:" 
  echo "  grep -nE 'SDKROOT = (iphoneos|macosx)|SUPPORTED_PLATFORMS' '$pbxproj' | head -n 20"
  exit 3
}

build_for_device() {
  step "6/10" "Build para o device"

  local base_cmd build_flags
  base_cmd="$(xcodebuild_base_cmd)"
  build_flags="$(maybe_add_provisioning_flags)"

  BUILD_ROOT="$ROOT/.build-run"
  DERIVED="$BUILD_ROOT/DerivedData-$PLATFORM-$UDID"
  mkdir -p "$DERIVED"

  info "Base: $base_cmd"
  info "Dica: se falhar com 'Supported platforms ... empty', o scheme atual não é iOS."
  info "      Tente: SCHEME=<scheme_iOS> ./run.sh $PLATFORM ${UDID:-}"

  if ! eval "$base_cmd -destination-timeout 30 -destination \"id=$UDID\" -derivedDataPath \"$DERIVED\" -sdk iphoneos $build_flags build"; then
    err "Falha no build para device id=$UDID"
    err "Causas comuns: target não-iOS, signing/team, profile, bundle id."
    exit 1
  fi
}

locate_app() {
  step "7/10" "Localizando .app"
  APP_PATH="$(find "$DERIVED/Build/Products" -type d -name "*.app" -path "*iphoneos*" | head -n1 || true)"
  if [[ -z "$APP_PATH" ]]; then
    err ".app não encontrado em $DERIVED/Build/Products"
    exit 1
  fi
  info "App encontrado: $APP_PATH"
}

install_and_launch_devicectl() {
  local udid="$1"
  local app_path="$2"
  local bundle_id="$3"

  step "8/10" "Instalando (devicectl)"
  xcrun devicectl device install app --device "$udid" "$app_path"

  step "9/10" "Abrindo app (devicectl)"
  xcrun devicectl device process launch --device "$udid" "$bundle_id"
}

install_and_launch_ios_deploy() {
  local udid="$1"
  local app_path="$2"

  step "8/10" "Instalando/abrindo (ios-deploy fallback)"
  ios-deploy --id "$udid" --bundle "$app_path" --justlaunch
}

post_summary() {
  step "10/10" "Concluído"
  info "Plataforma: $PLATFORM"
  info "UDID: $UDID"
  info "Bundle: $BUNDLE_ID"
  info "App: $APP_PATH"
}

# ------------------------- main -------------------------
ensure_project_or_workspace
check_cli_tools
validate_scheme_exists
select_device
ensure_platform_available
validate_target_is_ios_capable
build_for_device
locate_app

if [[ "$HAS_DEVICECTL" -eq 1 ]]; then
  if install_and_launch_devicectl "$UDID" "$APP_PATH" "$BUNDLE_ID"; then
    post_summary
    exit 0
  else
    warn "devicectl falhou, tentando ios-deploy..."
  fi
fi

if [[ "$HAS_IOS_DEPLOY" -eq 1 ]]; then
  if install_and_launch_ios_deploy "$UDID" "$APP_PATH"; then
    post_summary
    exit 0
  fi
fi

err "Falha ao instalar/abrir app no device."
exit 1