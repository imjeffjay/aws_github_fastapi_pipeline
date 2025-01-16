# Use an official Python runtime as the base image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy only the dependency file first (to leverage Docker cache)
COPY requirements.txt /app/

# Install dependencies globally
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . /app

# Environment variables to optimize Python runtime
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Expose the application port (optional, but recommended for clarity)
EXPOSE 8000

# Command to run the application (parameterized for flexibility)
CMD ["python", "src/main.py"]