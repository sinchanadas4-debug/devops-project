import os
import requests
from flask import Flask, jsonify

app = Flask(__name__)

USER_URL = os.getenv("USER_SERVICE_URL", "http://user-service:5001")
PRODUCT_URL = os.getenv("PRODUCT_SERVICE_URL", "http://product-service:5002")

ORDERS = [
    {"id": 1, "user_id": 1, "product_id": 2},
    {"id": 2, "user_id": 2, "product_id": 1},
]

@app.route("/health")
def health():
    return jsonify(status="ok", service="order-service")

@app.route("/api/orders")
def get_orders():
    try:
        users = {u["id"]: u for u in requests.get(f"{USER_URL}/api/users", timeout=3).json()}
        products = {p["id"]: p for p in requests.get(f"{PRODUCT_URL}/api/products", timeout=3).json()}
    except requests.RequestException as e:
        return jsonify(error="dependency unavailable", detail=str(e)), 503

    result = [
        {"id": o["id"], "user": users.get(o["user_id"]), "product": products.get(o["product_id"])}
        for o in ORDERS
    ]
    return jsonify(result)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5003)