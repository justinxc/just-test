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
import prometheus_client
from prometheus_client import Counter, Gauge
from flask import Response

health_count = Counter('health', 'Total health count')
request_in_count = Counter('request_in', 'Total request in count')
request_pending_gauge = Gauge('request_pending', 'Current request pending count')

@app.before_request
def before_request_func():
    request_in_count.inc()
    request_pending_gauge.inc()
    # print(">> before_request")

@app.teardown_request
def teardown_request(exception):
    request_pending_gauge.dec()
    # print('<< teardown_request')

@app.route("/metrics/health")
def health():
    health_count.inc()
    return Response(prometheus_client.generate_latest(health_count), mimetype='text/plain')
    # return {"msg":"health"}

@app.route("/metrics/request_in")
def request_in():
    return Response(prometheus_client.generate_latest(request_in_count), mimetype='text/plain')
    # return {"msg":"request_in"}

@app.route("/metrics/request_pending")
def request_pending():
    return Response(prometheus_client.generate_latest(request_pending_gauge), mimetype='text/plain')
    # return {"msg":"request_pending"}
