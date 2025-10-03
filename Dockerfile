FROM python:3.11-slim

WORKDIR /app

# Install system dependencies including Microsoft SQL Server tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl gnupg2 apt-transport-https ca-certificates \
    && curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
        > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc-dev mssql-tools18 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Ensure sqlcmd is on the PATH for all users
ENV PATH="/opt/mssql-tools18/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create necessary directories
RUN mkdir -p scripts logs

# Make all scripts executable
RUN if [ -d "scripts" ]; then chmod +x scripts/*; fi

# Expose the port the app runs on
EXPOSE 5000

# Command to run the application
CMD ["python", "app.py"]
