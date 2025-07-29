FROM python:3.11-slim

WORKDIR /app

# Install system dependencies needed for psycopg2 (PostgreSQL driver)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install poetry

# Copy only dependency files first to leverage Docker's cache
COPY pyproject.toml poetry.lock ./

# Configure poetry and install dependencies
RUN poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-ansi

# Copy the rest of the application code
COPY . .

# Run migrations and seed the database during the build
RUN python manage.py migrate
RUN python manage.py seed

# Define the command to start the server
CMD ["daphne", "-b", "0.0.0.0", "-p", "$PORT", "food_delivery.asgi:application"]
