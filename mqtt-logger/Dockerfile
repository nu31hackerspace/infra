FROM python:3.13-alpine

WORKDIR /app

RUN pip install --no-cache-dir paho-mqtt==2.1.0 psycopg2-binary==2.9.10

COPY logger.py .

CMD ["python", "-u", "logger.py"]
