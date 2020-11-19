# -*- coding: utf-8 -*-
"""Create an application instance."""
from flask.helpers import get_debug_flag

from conduit.app import create_app
from conduit.settings import DevConfig, ProdConfig

CONFIG = DevConfig if get_debug_flag() else ProdConfig

app = create_app(CONFIG)


####################
### collect metrics for prometheus
####################
from prometheus_client import CollectorRegistry, generate_latest, Counter, Gauge
from flask import Response

collector_registry = CollectorRegistry()
health_count = Counter('health', 'Total health count', registry=collector_registry)
request_in_count = Counter('request_in', 'Total request in count', registry=collector_registry)
request_pending_gauge = Gauge('request_pending', 'Current request pending count', registry=collector_registry)

@app.before_request
def before_request_func():
    request_in_count.inc()
    request_pending_gauge.inc()
    # print(">> before_request")

@app.teardown_request
def teardown_request(exception):
    request_pending_gauge.dec()
    # print('<< teardown_request')

@app.route("/metrics")
def metrics():
    return Response(generate_latest(collector_registry), mimetype='text/plain')

@app.route("/health")
def health():
    health_count.inc()
    return {"msg":"health"}