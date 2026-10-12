FROM node:22-slim

# Prisma needs openssl at build and run time
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# NEXT_PUBLIC_* values are inlined into the client bundle, so they must be
# known at build time.
ARG NEXT_PUBLIC_BACKEND_URL
ARG NEXT_PUBLIC_STRIPE_KEY
ARG NEXT_PUBLIC_PAYPAL_CLIENT_ID
ARG NEXT_PUBLIC_PAYPAL_SANDBOX
ARG NEXT_PUBLIC_DEFAULT_REGION
ARG NEXT_PUBLIC_VIEW_ORDER

# keystone.ts validates these when the config is loaded, so the build needs
# placeholders. Real values are supplied at runtime and never baked in.
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL \
    NEXT_PUBLIC_STRIPE_KEY=$NEXT_PUBLIC_STRIPE_KEY \
    NEXT_PUBLIC_PAYPAL_CLIENT_ID=$NEXT_PUBLIC_PAYPAL_CLIENT_ID \
    NEXT_PUBLIC_PAYPAL_SANDBOX=$NEXT_PUBLIC_PAYPAL_SANDBOX \
    NEXT_PUBLIC_DEFAULT_REGION=$NEXT_PUBLIC_DEFAULT_REGION \
    NEXT_PUBLIC_VIEW_ORDER=$NEXT_PUBLIC_VIEW_ORDER

RUN DATABASE_URL="postgresql://build:build@localhost:5432/build" \
    SESSION_SECRET="build-time-placeholder-secret-at-least-32-chars" \
    S3_BUCKET_NAME=build S3_REGION=build S3_ACCESS_KEY_ID=build \
    S3_SECRET_ACCESS_KEY=build S3_ENDPOINT=https://build.invalid \
    npm run build

EXPOSE 3000

# Migrations run on start (the DB is not reachable during build), then Next serves.
CMD ["sh", "-c", "npm run migrate && npx next start -H 0.0.0.0 -p 3000"]
