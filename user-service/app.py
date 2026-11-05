from flask import Flask, jsonify

app = Flask(__name__)

USERS = [
    {"id": 1, "name": "Asha"},
    {"id": 2, "name": "Ravi"},
]

@app.route("/health")
def health():
    return jsonify(status="ok", service="user-service")

@app.route("/api/users")
def get_users():
    return jsonify(USERS)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)