FROM ubuntu:16.04

RUN apt-get update && apt-get install -y curl openalpr python-openalpr vim

RUN curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" \
 && python "get-pip.py" \
 && pip install Pillow

ADD files /opt/docker-alpr/
WORKDIR /opt/docker-alpr/

ENV PYTHONUNBUFFERED=0 \
    OPEN_ALPR_CONFIG_PATH="/opt/docker-alpr/openalpr.conf"

ENTRYPOINT ["python", "run.py"]
CMD ["--help"]
