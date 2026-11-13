FROM python:3.12-slim
WORKDIR /app
COPY aw_panel.py bg.jpg ./
ENV AW_NO_BROWSER=1
EXPOSE 8765
CMD ["python3", "aw_panel.py"]
