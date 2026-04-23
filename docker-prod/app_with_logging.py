from flask import Flask, jsonify
import psutil
import time
import random
import threading
import logging
import json
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

def log_structured(level, message, **kwargs):
    log_entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'level': level,
        'message': message,
        'service': 'web-app',
        'version': '1.0',
        **kwargs
    }
    logger.info(json.dumps(log_entry))

def background_work():
    while True:
        cpu_usage = psutil.cpu_percent()
        memory_usage = psutil.virtual_memory().percent
        log_structured('INFO', 'Background metrics collected',
                      cpu_percent=cpu_usage,
                      memory_percent=memory_usage)
        for i in range(random.randint(1000, 10000)):
            _ = i ** 2
        time.sleep(random.randint(1, 5))

threading.Thread(target=background_work, daemon=True).start()

@app.route('/')
def home():
    log_structured('INFO', 'Home endpoint accessed')
    return jsonify({
        'message': 'Hello from monitored container!',
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent
    })

@app.route('/health')
def health():
    log_structured('INFO', 'Health check performed', status='healthy')
    return jsonify({'status': 'healthy'})

@app.route('/load')
def create_load():
    log_structured('WARNING', 'Load generation started')
    for i in range(100000):
        _ = i ** 3
    log_structured('INFO', 'Load generation completed')
    return jsonify({'message': 'Load created'})

@app.route('/error')
def create_error():
    log_structured('ERROR', 'Intentional error triggered', error_type='test_error')
    return jsonify({'error': 'This is a test error'}), 500

if __name__ == '__main__':
    log_structured('INFO', 'Application starting')
    app.run(host='0.0.0.0', port=5000)
