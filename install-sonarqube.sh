#!/usr/bin/env bash
set -euo pipefail

# =======================
# Config (override via env)
# =======================
SONAR_VERSION="${SONAR_VERSION:-2025.1}"          # e.g., 2025.1 or 2025.1.1
SONAR_USER="${SONAR_USER:-sonarqube}"
SONAR_GROUP="${SONAR_GROUP:-sonarqube}"

SONAR_BASE="${SONAR_BASE:-/opt/sonarqube}"        # install root (will create /opt/sonarqube/current)
SONAR_DATA="${SONAR_DATA:-/var/sonarqube}"        # data/logs/temp live here
SONAR_PORT="${SONAR_PORT:-9000}"

# Database options
USE_LOCAL_PG="${USE_LOCAL_PG:-true}"              # true = install/configure local PostgreSQL
PG_VERSION="${PG_VERSION:-15}"
DB_NAME="${DB_NAME:-sonarqube}"
DB_USER="${DB_USER:-sonar}"
DB_PASS="${DB_PASS:-ChangeMe_S0nar!}"             # << update in production
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

# =======================
# Helpers
# =======================
log() { echo -e "\n[INFO] $*"; }
warn() { echo -e "\n[WARN] $*" >&2; }
die() { echo -e "\n[ERROR] $*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."; }

# =======================
# Start
# =======================
need_root

log "Updating OS packages (dnf update)..."
dnf -y update

log "Installing prerequisites (curl, unzip, coreutils)..."
dnf -y install curl unzip which

# ===== Java 21 (Amazon Corretto) =====
log "Installing Amazon Corretto 21 (required by current SonarQube)..."
dnf -y install java-21-amazon-corretto
# Try to determine JAVA_HOME robustly
if [ -d /usr/lib/jvm/java-21-amazon-corretto ]; then
  JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
else
  JAVA_BIN="$(command -v java)"
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "${JAVA_BIN}")")")"
fi
[ -d "${JAVA_HOME}" ] || die "JAVA_HOME not found"

log "JAVA_HOME=${JAVA_HOME}"

# ===== Create user/group and directories (fixes systemd 217/USER) =====
log "Creating group and user: ${SONAR_GROUP}:${SONAR_USER}"
getent group "${SONAR_GROUP}" >/dev/null || groupadd --system "${SONAR_GROUP}"
if ! id -u "${SONAR_USER}" >/dev/null 2>&1; then
  useradd --system --gid "${SONAR_GROUP}" \
          --home-dir "${SONAR_DATA}" --shell /sbin/nologin "${SONAR_USER}"
fi

log "Creating directories: ${SONAR_BASE} and ${SONAR_DATA}/{data,logs,temp,extensions}"
mkdir -p "${SONAR_BASE}" \
         "${SONAR_DATA}/data" \
         "${SONAR_DATA}/logs" \
         "${SONAR_DATA}/temp" \
         "${SONAR_DATA}/extensions"
chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONAR_BASE}" "${SONAR_DATA}"

# ===== Optional: Local PostgreSQL =====
if [ "${USE_LOCAL_PG}" = "true" ]; then
  log "Installing local PostgreSQL ${PG_VERSION}..."
  dnf -y install "postgresql${PG_VERSION}" "postgresql${PG_VERSION}-server" || die "Failed to install PostgreSQL"

  # Initialize DB store (RHEL9/AL2023 style)
  if [ ! -d "/var/lib/pgsql/data" ] && command -v postgresql-setup >/dev/null 2>&1; then
    /usr/bin/postgresql-setup --initdb
  fi

  systemctl enable --now postgresql || systemctl restart postgresql

  log "Creating DB role and database (if missing)..."
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';"

  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"

  # Restrict to localhost
  sed -i "s/^#\?listen_addresses.*/listen_addresses = 'localhost'/" /var/lib/pgsql/data/postgresql.conf
  if ! grep -qE "host\s+${DB_NAME}\s+${DB_USER}\s+127\.0\.0\.1/32\s+md5" /var/lib/pgsql/data/pg_hba.conf; then
    echo "host ${DB_NAME} ${DB_USER} 127.0.0.1/32 md5" >> /var/lib/pgsql/data/pg_hba.conf
  fi
  systemctl restart postgresql

  DB_HOST="127.0.0.1"
  DB_PORT="5432"
else
  log "Skipping local PostgreSQL install. Expecting external DB at ${DB_HOST}:${DB_PORT}."
fi

# ===== Kernel/ulimit settings for Elasticsearch =====
log "Applying kernel + ulimit settings required by SonarQube search engine..."
# vm.max_map_count & file-max
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=524288
grep -q '^vm.max_map_count' /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
grep -q '^fs.file-max' /etc/sysctl.conf || echo "fs.file-max=524288" >> /etc/sysctl.conf

# Disable Transparent Huge Pages at runtime (best effort) and attempt to persist
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
  if ! grep -q 'transparent_hugepage=never' /etc/default/grub 2>/dev/null; then
    sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never /' /etc/default/grub || true
    grub2-mkconfig -o /boot/grub2/grub.cfg || true
  fi
fi

# Per-user limits
cat >/etc/security/limits.d/99-sonarqube.conf <<'EOF'
sonarqube   soft   nofile   65536
sonarqube   hard   nofile   65536
sonarqube   soft   nproc    4096
sonarqube   hard   nproc    8192
EOF

# ===== Download & Install SonarQube =====
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

log "Downloading SonarQube ${SONAR_VERSION} from ${SONAR_URL} ..."
curl -fL "${SONAR_URL}" -o "/tmp/${SONAR_ZIP}"

log "Unpacking to ${SONAR_BASE} ..."
rm -rf "${SONAR_BASE}/current" "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" 2>/dev/null || true
unzip -q "/tmp/${SONAR_ZIP}" -d "${SONAR_BASE}"
ln -sfn "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" "${SONAR_BASE}/current"
chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONAR_BASE}"

# ===== Configure sonar.properties =====
SONAR_CONF="${SONAR_BASE}/current/conf/sonar.properties"
cp -n "${SONAR_CONF}" "${SONAR_CONF}.bak" || true

# Web & paths
sed -i "s|^#sonar.web.port=.*|sonar.web.port=${SONAR_PORT}|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.data=.*|sonar.path.data=${SONAR_DATA}/data|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.temp=.*|sonar.path.temp=${SONAR_DATA}/temp|" "${SONAR_CONF}"
sed -i "s|^#sonar.path.logs=.*|sonar.path.logs=${SONAR_DATA}/logs|" "${SONAR_CONF}"

# DB
grep -q '^sonar.jdbc.url=' "${SONAR_CONF}" && \
  sed -i "s|^sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}|" "${SONAR_CONF}" || \
  echo "sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "${SONAR_CONF}"

grep -q '^sonar.jdbc.username=' "${SONAR_CONF}" && \
  sed -i "s|^sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" "${SONAR_CONF}" || \
  echo "sonar.jdbc.username=${DB_USER}" >> "${SONAR_CONF}"

grep -q '^sonar.jdbc.password=' "${SONAR_CONF}" && \
  sed -i "s|^sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASS}|" "${SONAR_CONF}" || \
  echo "sonar.jdbc.password=${DB_PASS}" >> "${SONAR_CONF}"

# ===== systemd unit (forking + PIDFile to avoid 217 issues) =====
log "Creating systemd service unit at /etc/systemd/system/sonarqube.service ..."
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

# ===== Start service =====
log "Enabling and starting SonarQube..."
systemctl enable sonarqube
systemctl start sonarqube || true

sleep 8
if ! systemctl is-active --quiet sonarqube; then
  warn "SonarQube not active yet. Showing last logs:"
  journalctl -u sonarqube -n 80 --no-pager || true
fi

log "Done! If your EC2 Security Group allows TCP ${SONAR_PORT}, open:  http://<EC2-PUBLIC-IP>:${SONAR_PORT}"
echo "Default credentials: admin / admin (you'll be prompted to change the password)."
