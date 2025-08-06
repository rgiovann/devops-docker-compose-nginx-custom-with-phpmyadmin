# Docker Stack: MySQL + phpMyAdmin with Custom Nginx

This project implements a complete stack for MySQL database administration through a phpMyAdmin web interface, using Docker containers with custom nginx configuration.
Note: Requires Docker.io and docker-compose to be pre-installed on the system

## 📋 Project Structure

```
.
├── docker-compose.yml
├── Dockerfile  
├── nginx.conf
├── config.inc.php
└── README.md
```

## 🐳 Container Architecture

- **Container 1**: MySQL 8 (database server)
- **Container 2**: Nginx + PHP-FPM + phpMyAdmin (web interface)

## 📁 File Description

### `docker-compose.yml`
Orchestrates the two application services:
- **mysql**: Official MySQL 8 container with persistent volume
- **phpmyadmin**: Custom container based on local Dockerfile
- Defines dependencies, exposed ports, and environment variables

### `Dockerfile`
Builds custom container with:
- **Base**: Debian 12
- **Web Server**: Nginx 
- **PHP**: PHP-FPM 8.2 with MySQL driver
- **Application**: phpMyAdmin 5.2.1 downloaded and configured automatically
- **Config**: Configuration file embedded in the image

### `nginx.conf`
Web server configuration:
- Serves static files and processes PHP via Unix socket
- Defines `/phpmyadmin/` location for application access
- Basic security configurations (deny .ht files)
- Processes PHP through PHP-FPM 8.2

### `config.inc.php`
phpMyAdmin configuration file:
- Defines connection to MySQL container via hostname
- Configures cookie-based authentication
- Blowfish secret for session encryption
- Embedded in image during build (not ephemeral)

## 🚀 How to Run

1. **Clone the files** to desired directory
2. **Run the stack**:
   ```bash
   docker-compose up --build -d
   ```
3. **Access phpMyAdmin**: `http://localhost:8080/phpmyadmin/`
4. **MySQL Credentials**:
   - Username: `root`
   - Password: `root`

## 🔧 Useful Commands

```bash
# Start containers
docker-compose up --build -d

# Check containers up and running
docker ps
```

## 🌐 Access Points

- **phpMyAdmin**: http://<bridge network interface ip>:8080/phpmyadmin/
- **MySQL Direct**: <bridge network interface ip>:3306 (if direct access needed)

## 📊 Port Usage

| Service | Internal Port | External Port |
|---------|---------------|---------------|
| MySQL | 3306 | 3306 |
| Nginx | 80 | 8080 |

## 💾 Data Persistence

- **MySQL**: Docker volume `mysql-data` to persist database data
- **phpMyAdmin Config**: Embedded in image (no volumes required)

## 🔒 Security Configurations

- Mandatory authentication in phpMyAdmin
- .htaccess files blocked by nginx  
- Inter-container communication via Docker internal network
- MySQL password configured via environment variable

---

**Project developed as a practical DevOps challenge - +Devs2Blu Course**
