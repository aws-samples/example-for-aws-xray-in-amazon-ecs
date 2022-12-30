FROM python:3.9.13-slim-buster

RUN apt update && apt install -y curl

WORKDIR /usr/src/app

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

COPY ./requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY project .

CMD ["python", "manage.py", "runserver", "0.0.0.0:80"]
EXPOSE 80