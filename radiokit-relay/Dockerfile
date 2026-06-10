FROM rust:1.85-alpine AS build
RUN apk add --no-cache musl-dev
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release 2>/dev/null || true
COPY src/ src/
RUN cargo build --release

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=build /app/target/release/radiokit-relay /server
EXPOSE 443
ENTRYPOINT ["/server"]
