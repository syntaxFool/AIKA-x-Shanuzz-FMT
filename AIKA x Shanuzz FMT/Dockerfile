# Multi-stage Docker build for AIKA x Shanuzz FMT
# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter config --no-analytics && \
    flutter pub get && \
    flutter build web --release

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deployment/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
