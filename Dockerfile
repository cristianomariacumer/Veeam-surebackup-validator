FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create scripts directory
RUN mkdir -p scripts

# Make all scripts executable
RUN if [ -d "scripts" ]; then chmod +x scripts/*; fi

# Expose the port the app runs on
EXPOSE 5000

# Command to run the application
CMD ["python", "app.py"] 