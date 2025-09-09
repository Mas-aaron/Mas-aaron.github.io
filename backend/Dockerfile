# Use official Python image as base
FROM python:3.12-slim

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
# Paths are relative to the backend directory (the build context)
COPY pyproject.toml poetry.lock* ./

# Configure Poetry to not create a virtual environment and install dependencies
RUN poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi

# Copy the rest of the application source code
# This copies the contents of the current directory into the container's working directory
COPY . ./

# Collect static files for production. This is run during the build.
RUN python manage.py collectstatic --noinput

# Make the entrypoint script executable (already copied in line 32)
RUN chmod +x /app/entrypoint.sh

# Set the entrypoint script as the command to run when the container starts
ENTRYPOINT ["/app/entrypoint.sh"]
