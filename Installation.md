```
Luanch ubuntu server | t2 medium 
SG: 9000, 8080, 22

Blog URL: https://medium.com/@rahmanazhar/sonarqube-installation-on-ubuntu-20-04-4a47255ffb47
// 
sudo apt update -y
sudo apt upgrade -y 

// java installation
sudo apt install openjdk-11-jdk -y

Ref: https://pkg.jenkins.io/debian-stable/
// jenkins installation
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

  sudo apt-get update
  sudo apt-get install fontconfig openjdk-17-jre
  sudo apt-get install jenkins

Password#123

// Install postgre
sudo sh -c 'echo “deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main” /etc/apt/sources.list.d/pgdg.list'
sudo apt install postgresql postgresql-contrib -y
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo passwd postgres
su - postgres
 sudo apt-get install zip -y

// install sonarqube
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.3.79811.zip
sudo unzip sonarqube-9.9.3.79811.zip
sudo mv sonarqube-9.9.3.79811 /opt/sonarqube
sudo groupadd sonar
sudo useradd -d /opt/sonarqube -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube -R
sudo nano /opt/sonarqube/conf/sonar.properties
sudo nano /etc/systemd/system/sonar.service
sudo systemctl enable sonar
sudo systemctl start sonar
sudo systemctl status sonar
sudo nano /etc/sysctl.conf
sudo reboot
sudo systemctl status sonar
```
