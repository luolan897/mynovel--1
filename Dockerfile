# ==============================
# 阶段1: 构建前端 (Build Frontend)
# ==============================
FROM node:20-alpine AS frontend-builder

WORKDIR /frontend

# 1. 复制 package.json 并安装依赖
# 注意：Render 在海外，这里使用官方源，速度很快
COPY frontend/package*.json ./
RUN npm install

# 2. 复制源代码并构建
COPY frontend/ ./

# 修改配置让输出目录指向 dist
RUN sed -i "s|outDir: '../backend/static'|outDir: 'dist'|g" vite.config.ts
RUN npm run build

# ==============================
# 阶段2: 构建后端并整合 (Final Image)
# ==============================
FROM python:3.11-slim

WORKDIR /app

# 1. 安装系统级依赖 (包含 FFmpeg 和 编译器)
# Render 必须要装 ffmpeg 才能生成音频
RUN apt-get update && apt-get install -y \
    gcc \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 2. 复制 Python 依赖文件
COPY backend/requirements.txt ./

# 3. 安装 Python 包
# 使用官方源，指定 CPU 版本 Torch (省空间)
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r requirements.txt

# 4. 复制代码
COPY backend/ ./

# 5. 把前端打包好的文件复制过来
COPY --from=frontend-builder /frontend/dist ./static

# 6. 创建必要目录
# 确保 embedding 目录存在，用于存放模型
RUN mkdir -p /app/data /app/logs /app/embedding

# 7. 环境变量设置
# SENTENCE_TRANSFORMERS_HOME 指定模型下载/读取位置
ENV APP_HOST=0.0.0.0
ENV APP_PORT=8000
ENV SENTENCE_TRANSFORMERS_HOME=/app/embedding

# 8. 暴露端口
EXPOSE 8000

# 9. 启动命令
# 确保你的目录结构是正确的，通常 main.py 在 app 模块里
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]