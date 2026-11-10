FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py config.json ./
EXPOSE 8000
CMD ["ddtrace-run", "gunicorn", "-w", "1", "--threads", "8", "-b", "0.0.0.0:8000", "app:app"]
