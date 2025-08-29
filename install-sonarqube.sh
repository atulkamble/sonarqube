#!/usr/bin/env bash
set -euo pipefail

# ========= Configurable variables =========
SONAR_VERSION="${SONAR_VERSION:-2025.1}"          # SonarQube LTA train (e.g., 2025.1)
SONAR_USER="sonarqube"
SONAR_GROUP="sonarqube"
SONAR_BASE="/opt/sonarqube"
SONAR_DATA="/var/sonarqube"
SONAR_PORT="${SONAR_PORT:-9000}"

# --- Database (use local Postgres by default; set USE_LOCAL_PG=false to use RDS/external) ---
USE_LOCAL_PG="${USE_LOCAL_PG:-true}"
PG_VERSION="${PG_VERSION:-15}"
DB_NAME="${DB_NAME:-sonarqube}"
DB_USER="${DB_USER:-sonar}"
DB_PASS="${DB_PASS:-sonar_password_str0ng!}"   # change me
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

# ========= Helpers =========
log() { echo -e "\n[INFO] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

require_root() { [ "$(id -u)" -eq 0 ] || fail "Run as root (sudo)."; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ========= Start =========
require_root
log "Updating system packages..."
dnf -y update

# ========= Java 21 (Amazon Corretto) =========
log "Installing Amazon Corretto 21 (required by current SonarQube LTA)..."
dnf -y install java-21-amazon-corretto
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
log "JAVA_HOME detected: $JAVA_HOME"

# ========= Optional: Local PostgreSQL =========
if [ "$USE_LOCAL_PG" = "true" ]; then
  log "Installing PostgreSQL ${PG_VERSION} server locally..."
  dnf -y install "postgresql${PG_VERSION}" "postgresql${PG_VERSION}-server"
  # Initialize DB if not already initialized
  if [ ! -d "/var/lib/pgsql/data" ] && [ -x /usr/bin/postgresql-setup ]; then
    /usr/bin/postgresql-setup --initdb
  fi
  systemctl enable --now postgresql || systemctl restart postgresql

  # Create DB + user if not present
  log "Configuring PostgreSQL roles and database..."
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';"
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"

  # Tweak Postgres for network (localhost only)
  sed -i "s/^#\?listen_addresses.*/listen_addresses = 'localhost'/" /var/lib/pgsql/data/postgresql.conf
  if ! grep -q "host *${DB_NAME} *${DB_USER} *127.0.0.1/32 *md5" /var/lib/pgsql/data/pg_hba.conf; then
    echo "host ${DB_NAME} ${DB_USER} 127.0.0.1/32 md5" >> /var/lib/pgsql/data/pg_hba.conf
  fi
  systemctl restart postgresql

  DB_HOST="127.0.0.1"
  DB_PORT="5432"
fi

# ========= System prerequisites for Elasticsearch (SonarQube search engine) =========
log "Applying kernel and ulimit settings required by SonarQube..."
# vm.max_map_count & file-max
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=524288
grep -q '^vm.max_map_count' /etc/sysctl.conf || echo "vm.max_map_count=262144" >> /etc/sysctl.conf
grep -q '^fs.file-max' /etc/sysctl.conf || echo "fs.file-max=524288" >> /etc/sysctl.conf

# Disable Transparent Huge Pages (THP) at runtime + persist across reboots
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled || true
  if ! grep -q 'transparent_hugepage=never' /etc/default/grub; then
    sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never /' /etc/default/grub || true
    grub2-mkconfig -o /boot/grub2/grub.cfg || true
  fi
fi

# Create sonarqube user, dirs
log "Creating $SONAR_USER user and directories..."
id -u "$SONAR_USER" &>/dev/null || useradd --system --create-home --home-dir "$SONAR_DATA" --shell /sbin/nologin "$SONAR_USER"
mkdir -p "$SONAR_BASE" "$SONAR_DATA/logs" "$SONAR_DATA/temp" "$SONAR_DATA/data" "$SONAR_DATA/extensions"
chown -R "$SONAR_USER:$SONAR_GROUP" "$SONAR_DATA" || chown -R "$SONAR_USER:$SONAR_USER" "$SONAR_DATA"

# ========= Download & Install SonarQube =========
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"
log "Downloading SonarQube ${SONAR_VERSION} from: $SONAR_URL"
dnf -y install unzip curl
curl -fL "$SONAR_URL" -o "/tmp/${SONAR_ZIP}"

log "Unpacking to ${SONAR_BASE}..."
rm -rf "${SONAR_BASE:?}/current" "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" || true
unzip -q "/tmp/${SONAR_ZIP}" -d "$SONAR_BASE"
ln -sfn "${SONAR_BASE}/sonarqube-${SONAR_VERSION}" "${SONAR_BASE}/current"
chown -R "$SONAR_USER:$SONAR_USER" "${SONAR_BASE}"

# ========= Configure sonar.properties =========
log "Configuring ${SONAR_BASE}/current/conf/sonar.properties..."
SONAR_CONF="${SONAR_BASE}/current/conf/sonar.properties"
cp -n "${SONAR_CONF}" "${SONAR_CONF}.bak" || true

# Basic web config
sed -i "s|^#sonar.web.port=.*|sonar.web.port=${SONAR_PORT}|" "$SONAR_CONF"
sed -i "s|^#sonar.path.data=.*|sonar.path.data=${SONAR_DATA}/data|" "$SONAR_CONF"
sed -i "s|^#sonar.path.temp=.*|sonar.path.temp=${SONAR_DATA}/temp|" "$SONAR_CONF"
sed -i "s|^#sonar.path.logs=.*|sonar.path.logs=${SONAR_DATA}/logs|" "$SONAR_CONF"

# Database config (PostgreSQL)
if grep -q "^sonar.jdbc.url=" "$SONAR_CONF"; then
  sed -i "s|^sonar.jdbc.url=.*|sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}|" "$SONAR_CONF"
else
  echo "sonar.jdbc.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "$SONAR_CONF"
fi
if grep -q "^sonar.jdbc.username=" "$SONAR_CONF"; then
  sed -i "s|^sonar.jdbc.username=.*|sonar.jdbc.username=${DB_USER}|" "$SONAR_CONF"
else
  echo "sonar.jdbc.username=${DB_USER}" >> "$SONAR_CONF"
fi
if grep -q "^sonar.jdbc.password=" "$SONAR_CONF"; then
  sed -i "s|^sonar.jdbc.password=.*|sonar.jdbc.password=${DB_PASS}|" "$SONAR_CONF"
else
  echo "sonar.jdbc.password=${DB_PASS}" >> "$SONAR_CONF"
fi

# ========= ulimits for sonarqube user =========
log "Setting ulimits..."
cat >/etc/security/limits.d/99-sonarqube.conf <<'EOF'
sonarqube   soft   nofile   65536
sonarqube   hard   nofile   65536
sonarqube   soft   nproc    4096
sonarqube   hard   nproc    8192
EOF

# ========= Systemd service =========
log "Creating systemd service..."
cat >/etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=simple
User=${SONAR_USER}
Group=${SONAR_USER}
LimitNOFILE=65536
LimitNPROC=8192
Environment="JAVA_HOME=${JAVA_HOME}"
Environment="SONAR_HOME=${SONAR_BASE}/current"
Environment="SONAR_JAVA_PATH=${JAVA_HOME}/bin/java"
Environment="SONAR_LOG_DIR=${SONAR_DATA}/logs"
Environment="SONAR_TEMP=${SONAR_DATA}/temp"
Environment="SONAR_DATA=${SONAR_DATA}/data"
ExecStart=${SONAR_BASE}/current/bin/linux-x86-64/sonar.sh start
ExecStop=${SONAR_BASE}/current/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sonarqube
log "Starting SonarQube..."
systemctl start sonarqube
sleep 8
systemctl status --no-pager sonarqube || true

log "Done. If your EC2 security group allows TCP ${SONAR_PORT}, open http://<EC2-PUBLIC-IP>:${SONAR_PORT} (default admin/admin)."
