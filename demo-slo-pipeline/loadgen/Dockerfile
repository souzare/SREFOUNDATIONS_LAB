FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.3 requests==2.32.3
COPY loadgen.py .
EXPOSE 8081
CMD ["python", "loadgen.py"]
