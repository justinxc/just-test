# -*- coding: utf-8 -*-
"""Create an application instance."""
from flask.helpers import get_debug_flag

from conduit.app import create_app
from conduit.settings import DevConfig, ProdConfig

CONFIG = DevConfig if get_debug_flag() else ProdConfig

app = create_app(CONFIG)


####################
# add endpoint for health check
####################

from flask import jsonify


@app.route("/health")
def health():
    return jsonify({"status": "ok"})
