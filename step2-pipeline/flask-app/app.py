from flask import flask

app = flask(__name__)

@app.route("/")
def hello():
    return "hello world"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
