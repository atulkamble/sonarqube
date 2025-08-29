#!/usr/bin/env bash
# SonarQube + PostgreSQL 17 on Amazon Linux 2023 (fully automated)
# - Installs Corretto 21, PG17, SonarQube (default 2025.1)
# - Creates DB, user, kernel sysctls, ulimits, systemd unit (forking)
# - Fixes common 217/USER error
set -euo pipefail

### -------- Configuration (override via env before running) --------
SONAR_VERSION="${SONAR_VERSION:-2025.1}"       # e.g. 2025.1 or 2025.1.x
SONAR_PORT="${SONAR_PORT:-9000}"

# App user/group and paths
SONAR_USER="${SONAR_USER:-sonarqube}"
SONAR_GROUP="${SONAR_GROUP:-sonarqube}"
SONAR_BASE="${SONAR_BASE:-/opt/sonarqube}"     # will contain /current symlink
SONAR_DATA="${SONAR_DATA:-/var/sonarqube}"     # {data,logs,temp,extensions}

# DB settings
USE_LOCAL_PG="${USE_LOCAL_PG:-true}"           # true => install local PG17
PG_MAJOR="${PG_MAJOR:-17}"                      # pin to 17 to avoid conflicts
DB_NAME="${DB_NAME:-sonarqube}"
DB_USER="${DB_USER:-sonar}"
DB_PASS="${DB_PASS:-ChangeMe_S0nar!}"          # <<< CHANGE ME in production
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

### -------- Helpers --------
log() { echo -e "\n[INFO] $*"; }
warn() { echo -e "\n[WARN] $*" >&2; }
die() { echo -e "\n[ERROR] $*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."; }
file_contains() { grep -qE "$2" "$1"; }

### -------- Start --------
need_root

log "Updating base packages..."
dnf -y update

log "Installing base tools (curl, unzip, which, tar)..."
dnf -y install curl unzip which tar

log "Installing Amazon Corretto 21 (Java 21)..."
dnf -y install java-21-amazon-corretto
if [ -d /usr/lib/jvm/java-21-amazon-corretto ]; then
  JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
else
  JAVA_BIN="$(command -v java)"
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "${JAVA_BIN}")")")"
fi
[ -d "${JAVA_HOME}" ] || die "JAVA_HOME not found"
log "JAVA_HOME=${JAVA_HOME}"

### -------- OS user/group & directories (prevents 217/USER) --------
log "Ensuring ${SONAR_GROUP}:${SONAR_USER} exist..."
getent group "${SONAR_GROUP}" >/dev/null || groupadd --system "${SONAR_GROUP}"
id "${SONAR_USER}" >/dev/null 2>&1 || \
  useradd --system --gid "${SONAR_GROUP}" --home-dir "${SONAR_DATA}" --shell /sbin/nologin "${SONAR_USER}"

log "Creating directories: ${SONAR_BASE} and ${SONAR_DATA}/{data,logs,temp,extensions}..."
mkdir -p "${SONAR_BASE}" "${SONAR_DATA}/"{data,logs,temp,extensions}
chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONAR_BASE}" "${SONAR_DATA}"

### -------- PostgreSQL 17 (local) --------
if [ "${USE_LOCAL_PG}" = "true" ]; then
  log "Removing other PostgreSQL major versions (if present) to avoid file conflicts..."
  # Removes postgresqlNN* but keeps client libs used by our target after re-install
  dnf -y remove "postgresql[0-9][0-9]*" || true

  log "Installing PostgreSQL ${PG_MAJOR} server..."
  dnf -y install "postgresql${PG_MAJOR}" "postgresql${PG_MAJOR}-server"

  # Initialize data directory if needed
  if [ ! -d "/var/lib/pgsql/data" ] && command -v postgresql-setup >/dev/null 2>&1; then
    /usr/bin/postgresql-setup --initdb
  fi

  systemctl enable --now postgresql || systemctl restart postgresql

  log "Creating DB role and database (idempotent)..."
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';"

  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"

  # Listen only on localhost and allow DB_USER from 127.0.0.1
  PGCONF="/var/lib/pgsql/data/postgresql.conf"
  PGHBA="/var/lib/pgsql/data/pg_hba.conf"
  sed -i "s/^#\?listen_addresses.*/listen_addresses = 'localhost'/" "${PGCONF}"
  if ! file_contains "${PGHBA}" "host\\s+${DB_NAME}\\s+${DB_USER}\\s+127\\.0\\.0\\.1/32\\s+md5"; then
    echo "host ${DB_NAME} ${DB_USER} 127.0.0.1/32 md5" >> "${PGHBA}"
  fi
  systemctl restart postgresql

  DB_HOST="127.0.0.1"
  DB_PORT="5432"
else
  log "Skipping local PostgreSQL. Expecting external DB at ${DB_HOST}:${DB_PORT}."
fi

### -------- Kernel & ulimits (Elasticsearch requirements) --------
log "Applying kernel & ulimit prerequisites..."
# Increase mappings and file descriptors
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=524288

# Make persistent
grep -q '^vm.max_map_count' /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
# Raise fs.file-max only if lower than target
if ! grep -q '^fs.file-max=524288' /etc/sysctl.conf; then
  sed -i '/^fs\.file-max/d' /etc/sysctl.conf || true
  echo "fs.file-max=524288" >> /etc/sysctl.conf
fi

# Per-user limits for sonarqube
cat >/etc/security/limits.d/99-sonarqube.conf <<'EOF'
sonarqube   soft   nofile   65536
sonarqube   hard   nofile   65536
sonarqube   soft   nproc    4096
sonarqube   hard   nproc    8192
EOF

# Best-effort: disable THP at runtime (persistence may require grub edit; AL2023 often OK without)
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
fi

### -------- Download & install SonarQube --------
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

log "Downloading SonarQube ${SONAR_VERSION} ..."
curl -fL "${SONAR_URL}" -o "/tmp/${SONAR_ZIP}"

log "Unpacking to ${SONAR_BASE} ..."
rm -rf "${SONAR_BASE}/current" "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" || true
unzip -q "/tmp/${SONAR_ZIP}" -d "${SONAR_BASE}"
ln -sfn "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" "${SONAR_BASE}/current"
chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONAR_BASE}"

### -------- Configure sonar.properties --------
SONAR_CONF="${SONAR_BASE}/current/conf/sonar.properties"
cp -n "${SONAR_CONF}" "${SONAR_CONF}.bak" || true

# Web & paths
sed -i "s|^#sonar.web.port=.*|sonar.web.port=${SONAR_PORT}|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.data=.*|sonar.path.data=${SONAR_DATA}/data|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.temp=.*|sonar.path.temp=${SONAR_DATA}/temp|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.logs=.*|sonar.path.logs=${SONAR_DATA}/logs|" "${SONAR_CONF}"

# DB connection
if grep -q '^sonar.jdbc.url=' "${SONAR_CONF}"; then
  sed -i "s|^sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}|" "${SONAR_CONF}"
else
  echo "sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "${SONAR_CONF}"
fi
if grep -q '^sonar.jdbc.username=' "${SONAR_CONF}"; then
  sed -i "s|^sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" "${SONAR_CONF}"
else
  echo "sonar.jdbc.username=${DB_USER}" >> "${SONAR_CONF}"
fi
if grep -q '^sonar.jdbc.password=' "${SONAR_CONF}"; then
  sed -i "s|^sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASS}|" "${SONAR_CONF}"
else
  echo "sonar.jdbc.password=${DB_PASS}" >> "${SONAR_CONF}"
fi

### -------- systemd unit (forking + PIDFile) --------
log "Creating systemd unit..."
cat >/etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
User=${SONAR_USER}
Group=${SONAR_GROUP}
LimitNOFILE=65536
LimitNPROC=8192
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="SONAR_HOME=${SONAR_BASE}/current"
Environment="SONAR_DATA=${SONAR_DATA}/data"
Environment="SONAR_TEMP=${SONAR_DATA}/temp"
Environment="SONAR_LOG_DIR=${SONAR_DATA}/logs"
Environment="PATH=${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=${SONAR_BASE}/current/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_BASE}/current/bin/linux-x86-64/sonar.sh stop
PIDFile=${SONAR_DATA}/temp/sonar.pid
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

### -------- Start service + health print --------
log "Enabling and starting SonarQube..."
systemctl enable sonarqube
systemctl start sonarqube || true

sleep 8
if systemctl is-active --quiet sonarqube; then
  log "SonarQube is active."
else
  warn "SonarQube not active yet; showing recent logs:"
  journalctl -u sonarqube -n 120 --no-pager || true
fi

echo
echo "=============================================================="
echo "  SonarQube URL:  http://<EC2-PUBLIC-IP>:${SONAR_PORT}"
echo "  Default login:  admin / admin  (you will be asked to change)"
echo "  Data dir:       ${SONAR_DATA}"
echo "  Logs dir:       ${SONAR_DATA}/logs"
echo "=============================================================="
