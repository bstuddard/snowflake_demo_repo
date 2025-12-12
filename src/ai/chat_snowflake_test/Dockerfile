ARG BASE_IMAGE=python:3.11-slim-buster
FROM $BASE_IMAGE
COPY src/ ./src/
COPY app.py ./
COPY requirements.txt ./
RUN pip install --upgrade pip && \
    pip install -r requirements.txt
CMD ["python", "-m", "streamlit", "run", "app.py"]

