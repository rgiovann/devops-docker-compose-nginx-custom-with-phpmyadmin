# Stack Docker: MySQL + phpMyAdmin com Nginx Customizado

Este projeto implementa uma stack completa para administração de banco de dados MySQL através de uma interface web phpMyAdmin, utilizando containers Docker com nginx customizado.

## 📋 Estrutura do Projeto

```
.
├── docker-compose.yml
├── Dockerfile  
├── nginx.conf
├── config.inc.php
└── README.md
```

## 🐳 Arquitetura dos Containers

- **Container 1**: MySQL 8 (banco de dados)
- **Container 2**: Nginx + PHP-FPM + phpMyAdmin (interface web)

## 📁 Descrição dos Arquivos

### `docker-compose.yml`
Orquestra os dois serviços da aplicação:
- **mysql**: Container oficial MySQL 8 com volume persistente
- **phpmyadmin**: Container customizado baseado no Dockerfile local
- Define dependências, portas expostas e variáveis de ambiente

### `Dockerfile`
Constrói container customizado com:
- **Base**: Debian 12
- **Web Server**: Nginx 
- **PHP**: PHP-FPM 8.2 com driver MySQL
- **Application**: phpMyAdmin 5.2.1 baixado e configurado automaticamente
- **Config**: Arquivo de configuração embedded na imagem

### `nginx.conf`
Configuração do servidor web:
- Serve arquivos estáticos e processa PHP via socket Unix
- Define location `/phpmyadmin/` para acesso à aplicação
- Configurações de segurança básicas (deny .ht files)
- Processa PHP através do PHP-FPM 8.2

### `config.inc.php`
Arquivo de configuração do phpMyAdmin:
- Define conexão com container MySQL via hostname
- Configura autenticação por cookie
- Blowfish secret para criptografia de sessão
- Embedded na imagem durante build (não efêmero)

## 🚀 Como Executar

1. **Clone os arquivos** no diretório desejado
2. **Execute a stack**:
   ```bash
   docker-compose up --build -d
   ```
3. **Acesse phpMyAdmin**: `http://localhost:8080/phpmyadmin/`
4. **Credenciais MySQL**:
   - Usuário: `root`
   - Senha: `root`

## 🔧 Comandos Úteis

```bash
# Subir os containers
docker-compose up --build -d

# Parar os containers
docker-compose down

# Ver logs
docker-compose logs -f

# Rebuild apenas o container customizado
docker-compose build phpmyadmin

# Acessar container phpMyAdmin
docker exec -it phpmyadmin bash
```

## 🌐 Acessos

- **phpMyAdmin**: http://localhost:8080/phpmyadmin/
- **MySQL Direct**: localhost:3306 (se necessário acesso direto)

## 📊 Portas Utilizadas

| Serviço | Porta Interna | Porta Externa |
|---------|---------------|---------------|
| MySQL | 3306 | 3306 |
| Nginx | 80 | 8080 |

## 💾 Persistência de Dados

- **MySQL**: Volume Docker `mysql-data` para persistir dados do banco
- **phpMyAdmin Config**: Embedded na imagem (não requer volumes)

## 🔒 Configurações de Segurança

- Autenticação obrigatória no phpMyAdmin
- Arquivos .htaccess bloqueados pelo nginx  
- Comunicação entre containers via rede interna Docker
- Senha MySQL configurada via environment variable

---

**Projeto desenvolvido como desafio prático de DevOps - Curso +Devs2Blu**