# Stage 1: Build the React application
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./

# Install dependencies
RUN npm install --prefer-offline --no-audit --progress=false

COPY . .

# Remove the existing environment.development.ts file (if exists)
RUN rm -f environments/.env.development

COPY environments/.env.preprod environments/.env.development
# Log the contents of the environment file for debugging
RUN cat environments/.env.development
# Build the application
ARG CONFIG=preprod
ENV CONFIG=$CONFIG
RUN npm run build -- --mode $CONFIG

# Stage 2: Serve the application using Nginx
FROM nginx:alpine

# Copy the React build output to the Nginx html directory
COPY --from=builder /app/dist/preprod /usr/share/nginx/html

# Copy the Nginx configuration
COPY devops/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 5173

CMD ["nginx", "-g", "daemon off;"]