FROM python:3.11-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt

# 复制应用代码
COPY . .

# 确保数据目录存在（实际数据由 volume 挂载覆盖）
RUN mkdir -p data/images

EXPOSE 8098

CMD ["python", "app.py"]
