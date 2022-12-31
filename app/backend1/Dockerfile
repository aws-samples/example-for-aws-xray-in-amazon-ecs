FROM python:3.9.13-slim-buster

RUN apt update && apt install -y curl

WORKDIR /usr/src/app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["python", "app.py"]
EXPOSE 80