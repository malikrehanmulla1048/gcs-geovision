FROM python:3.10-slim

# Install system build dependencies and runtime dependencies for OpenCV
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    cmake \
    g++ \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Upgrade build utilities and install prerequisites for insightface compilation
RUN pip install --no-cache-dir --upgrade pip setuptools wheel Cython numpy==1.26.4

# Copy requirements and install remaining dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source code
COPY . .

# Expose port 7860 (Hugging Face default port)
EXPOSE 7860

# Run FastAPI using uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
