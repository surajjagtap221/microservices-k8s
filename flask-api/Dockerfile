FROM python:3.12-alpine

WORKDIR /app

# Install dependencies first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

ENV PORT 5000
EXPOSE 5000

CMD ["python", "app.py"]