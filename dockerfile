# Use an official Python runtime as the base image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Copy only requirements file first (for caching purposes)
COPY requirements.txt /app/

# Install dependencies in a virtual environment
RUN python -m venv venv && \
    . venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the project files
COPY . /app

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Expose the application port
EXPOSE 8000

# Command to run the main script
CMD ["venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
