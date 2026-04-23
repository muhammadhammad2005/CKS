FROM python:3.9-slim

WORKDIR /app

RUN pip install flask psutil

COPY app_with_logging.py app.py

EXPOSE 5000

CMD ["python", "app.py"]
