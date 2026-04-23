from flask import Flask, jsonify
import psutil
import time
import random
import threading

app = Flask(__name__)

def background_work():
    while True:
        for i in range(random.randint(1000, 10000)):
            _ = i ** 2
        time.sleep(random.randint(1, 5))

threading.Thread(target=background_work, daemon=True).start()

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from monitored container!',
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/load')
def create_load():
    for i in range(100000):
        _ = i ** 3
    return jsonify({'message': 'Load created'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
