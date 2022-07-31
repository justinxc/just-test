# Purpose

This is a simple monitoring service setup with docker-compose, and demonstrate following goals

1. Monitor target website with collecting metrics periodically
2. Provide a time-serial dashboard to make metrics human-readiable
3. Send alarms to team's slack channel while abnormal cases are detected

# Usage

Run all services on your host

```shell=sh
git clone --branch demo https://github.com/justinxc/flask-realworld-example-app.git
cd flask-realworld-example-app/demo
docker-compose -f docker-compose.yml up -d
```

# Architecture

![monitoring.drawio.png](https://github.com/justinxc/flask-realworld-example-app/blob/demo/demo/resources/monitoring.drawio.png)

## Web/API Service

The webiste is forked from [flask-realworld-example-app](https://github.com/gothinkster/flask-realworld-example-app), and the main branch is `branch/demo`. To make the website executable, I have fixed it by adding version contaract on dependencies.

I integrate [Prometheus Flask Exporter](https://github.com/rycus86/prometheus_flask_exporter) into the webiste to make the website observable, so that you could get more flask related metrics from endpoint `/metrics`

```shell=sh
curl -i http://localhost:5566/metrics
```

Also, I add a endpoint `/health` for health check only

```shell=sh
curl -i http://localhost:5566/health
```

## Monitoring Service

The entire monitoring service consist of well-known components

1. [Prometheus](https://github.com/prometheus/prometheus), the time-series database to store metrics
2. [Grafana](https://github.com/grafana/grafana), the website for metrics visualization
3. [AlertManager](https://github.com/prometheus/alertmanager), the service to send alarm to 3rd platform (e.g. slack, email)
4. [Blackbox Exporter](https://github.com/prometheus/blackbox_exporter), the service allows blackbox probing of endpoints over HTTP, HTTPS, DNS, TCP, ICMP and gRPC

## Alerting Rules

Monitoring service should send alarms while one of following criteria is hit

1. website is down for 1 minutes
   - expr: `probe_http_status_code{instance=~".*"} == 0`
2. website gets too many request (> 5 rps) for 1 minute
   - expr: `sum by (instance) (rate (flask_http_request_total{job=~".*-web"} [1m])) > 5`

![example_web_down.drawio.png](https://github.com/justinxc/flask-realworld-example-app/blob/demo/demo/resources/example_web_down.drawio.png)

![example_high_rps.drawio.png](https://github.com/justinxc/flask-realworld-example-app/blob/demo/demo/resources/example_high_rps.drawio.png)

## Load Testing

[k6](https://github.com/grafana/k6) is introduced here for load testing. We would like to simulate to send concurrency requests to target website with N virual-user (VUs), and you could refer to K6 script [load-testing.js](https://github.com/justinxc/flask-realworld-example-app/blob/demo/test/load-testing.js) in detail.

1. The first `30 sec`, init with `10 VUs`
2. The next `180 sec`, increase to `20 VUs`
3. The last `30 sec`, decrease VUs to `0 VUs`

```
cd flask-realworld-example-app/demo/test
./run.sh load-testing.js
```

# CI/CD

## Workflow

![cicd.drawio.png](https://github.com/justinxc/flask-realworld-example-app/blob/demo/demo/resources/cicd.drawio.png)

Assume we choose `Trunk-Based Development` as our git flow.

1. main branch

   - it is used for `development` environment by default, and developers will focus on this branch
   - for `pull-request event`, it will trigger following jobs

     - lint checking
     - build container image
     - run unit test

   - for `merged event`, it will trigger jobs

     - build container image with tag by `SHA`
     - upload image to container registry
     - auto deploy to `development environment`

2. release branch

   - it will be forked from `main branch` on the 1st day of the sprint
   - it is used for both `testing and production enviornment`
   - QAs will validate test cases on `testing environemnt`
   - for `pull-request event`, it will trigger following jobs

     - lint checking
     - build container image
     - run unit test

   - for `merged event`, it will trigger jobs

     - build container image and tag by `symantec version`
     - upload image to container registry
     - auto deploy to `testing environment`

3. hot-fix

   - Developers have to hot-fix issue reported from QAs
   - hot-fix will `NOT` trigger auto deploy to `testing enviornment` unless get QA's approval

4. cherry-pick

   - each hot-fix should be synced to `main branch` by default

5. formal release

   - According to the latest testing report, `PM` would decide whether deploye to production environment

## TODO

- [ ] add sample to demo on Kubernetes
