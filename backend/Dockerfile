# Use official Python image as base
FROM python:3.11-slim

# Set environment variables for Python
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Create and set the working directory
WORKDIR /app

# Install system dependencies required for building some Python packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Poetry, the dependency manager
RUN pip install --upgrade pip && \
    pip install poetry

# Copy dependency files first to leverage Docker's layer caching
COPY pyproject.toml poetry.lock* ./

# Configure Poetry to not create a virtual environment and install dependencies
RUN poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi

# Copy the rest of the application source code
COPY . .

# Run database migrations
RUN python manage.py migrate

# Seed the database with initial data
RUN python manage.py seed

# Collect static files for production
RUN python manage.py collectstatic --noinput

# The command to run when the container starts
CMD ["daphne", "-b", "0.0.0.0", "-p", "$PORT", "food_delivery.asgi:application"]
