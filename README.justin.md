# Purpose
在本機端透過 `docker-compsose` 搭建簡易系統，包含 web service、monitor service、database

---

# Usage
```shell=sh
docker-compose -f docker-compose.yml up -d
```

# Configuration
```yaml=./docker-compose.yml
version: "3.7"

volumes:
  postgresql_data: {}
  prometheus_data: {}
  grafana_data: {}

networks:
  demo_net: {}

x-logging-stdout: &x-logging-stdout
  driver: "json-file"
  options:
    max-size: "1m"
    max-file: "1"

services:
  ########################################
  ### https://hub.docker.com/_/postgres
  ########################################
  postgresql:
    container_name: postgresql
    image: postgres:13
    networks:
      - demo_net
    ports:
      - 5432:5432
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=changeme
      - POSTGRES_DB=realworld
    logging: *x-logging-stdout
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  pgadmin:
    container_name: pgadmin
    image: dpage/pgadmin4:4
    networks:
      - demo_net
    ports:
      - 5050:80
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=changeme
      - PGADMIN_PORT=5050
      - PGADMIN_DEFAULT_EMAIL=pgadmin4@pgadmin.org
      - PGADMIN_DEFAULT_PASSWORD=admin

  web:
    container_name: web
    build: .
    image: flask-realworld-example-app
    networks:
      - demo_net
    ports:
      - 5000:5000
    environment:
      - FLASK_APP=/app/autoapp.py
      - FLASK_DEBUG=0
      - DATABASE_URL=postgresql://postgres:changeme@host.docker.internal:5432/realworld
    logging: *x-logging-stdout
    healthcheck:
      test: "wget --spider --server-response --quiet 'http://localhost:5000/health' 2>&1 | grep 'HTTP/.* 200' || exit 1"
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  prometheus:
    image: prom/prometheus:v2.22.2
    container_name: prometheus
    networks:
      - demo_net
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
      - ./prometheus/alert_rules.yaml:/etc/prometheus/alert_rules.yaml
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yaml"
      - "--web.enable-lifecycle"
    logging: *x-logging-stdout
    healthcheck:
      test: "wget --spider --server-response --quiet 'http://localhost:9090/-/healthy' 2>&1 || exit 1"
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  grafana:
    image: grafana/grafana:7.3.3
    container_name: grafana
    networks:
      - demo_net
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus
    logging: *x-logging-stdout
    healthcheck:
      test: "wget --spider --server-response --quiet 'http://localhost:3000/api/health' 2>&1 | grep 'HTTP/.* 200' || exit 1"
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  alertmanager:
    image: prom/alertmanager:v0.21.0
    container_name: alertmanager
    networks:
      - demo_net
    ports:
      - 9093:9093
    volumes:
      - ./alertmanager/alertmanager.yaml/:/etc/alertmanager/alertmanager.yaml
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yaml"
      - "--storage.path=/alertmanager"
    restart: unless-stopped
    depends_on:
      - prometheus
    logging:
      driver: "json-file"
      options:
        max-size: "1m"
        max-file: "1"
    healthcheck:
      test: "wget --spider --server-response --quiet 'http://localhost:9093/-/healthy' 2>&1 || exit 1"
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

```

# Architecture

## Web Service
以 [flask-realworld-example-app](https://github.com/gothinkster/flask-realworld-example-app) 為基礎，將 `branch/test` 視為主幹進行開發，並加入 proemtheus client 收集必要的 metrics
1. 判斷 web service 是否正常的 API
```
GET /health
```
2. 回傳自訂的 metrics 包含: `request_in`、`request_pending`、`health`
```
GET /metrics
```


## Monitoring Service
由 Prometheus、AlertManager、Grafana 組合
1. 以 Prometheus 作為 Grafana 的資料源，建立 3 組監控指標
    - `up{job="web"}`: web 是否在正常服務
    - `rate(request_in_total{job="web"}[10s])`: web 在 10 秒內收到的 request 平均數量
    - `rate(request_pending{job="web"}[10s])`: web 在 10 秒內尚在處理的 request 平均數量
2. 當滿足以下條件時，由`AlertManager`發送 alert 到`slack`
    - web 的 up 狀態為 0，並持續 10 秒
    - web 在10秒內收到的 request 數量超過 10 筆，並持續 10 秒

## Stress Tool
使用 [vegeta](https://github.com/tsenart/vegeta)，以平均 50 request/sec 並持續100秒，以模擬大量 request 打入 web service 的狀態
```
echo "GET http://localhost:5000/" \
  | vegeta attack -duration=100s \
  | tee result.bin \
  | vegeta report
```

## CI/CD
以 `Trunk Based Development` 為前提定義 [workflow/docker-image.yml](.github/workflows/docker-image.yml)，其中包含 3 組 jobs
1. `build`: 屬於 push branch/test，則打包 docker image，並以 SHA 命名 (例如:`flask-realworld-example-app:30599c65`)，接著進行 `unit test`，成功完成後上傳到 Github Registry
2. `tag_image`: 屬於 branch/test 的 tag event，則 pull 既有的 docker iamge，重新打上 tag (例如: `flask-realworld-example-app:0.1.0-r6`)，完成後再上傳到 Github Registry
3. `deploy`: 在 build 成功完成後，以 ssh 登入遠端主機以 docker-compose 進行服務部署


## Todo
- [ ] 以 Kubernetes (minikube、k3s) 取代 docker-compose
