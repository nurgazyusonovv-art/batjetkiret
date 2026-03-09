# CI/CD configuration examples for Flutter refresh intervals

## GitHub Actions

```yaml
# .github/workflows/build-android.yml
name: Build Android with Config

on:
  push:
    branches: [ main, staging ]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to build for'
        required: true
        type: choice
        options:
          - dev
          - staging
          - production

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.8.1'
    
    - name: Determine Environment
      id: env
      run: |
        if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
          ENV=${{ github.event.inputs.environment }}
        elif [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          ENV=production
        else
          ENV=staging
        fi
        echo "ENVIRONMENT=$ENV" >> $GITHUB_OUTPUT
    
    - name: Build Config (Production)
      if: steps.env.outputs.ENVIRONMENT == 'production'
      run: |
        cd frontend
        flutter build apk --release \
          --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15 \
          --dart-define=REFRESH_HOME_IDLE_INTERVAL=30 \
          --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15 \
          --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=30 \
          --dart-define=REFRESH_PROFILE_INTERVAL=120 \
          --dart-define=REFRESH_MAX_BACKOFF_MINUTES=5
    
    - name: Build Config (Staging)
      if: steps.env.outputs.ENVIRONMENT == 'staging'
      run: |
        cd frontend
        flutter build apk --release \
          --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8 \
          --dart-define=REFRESH_HOME_IDLE_INTERVAL=20 \
          --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8 \
          --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15 \
          --dart-define=REFRESH_PROFILE_INTERVAL=60 \
          --dart-define=REFRESH_MAX_BACKOFF_MINUTES=2
    
    - name: Build Config (Dev)
      if: steps.env.outputs.ENVIRONMENT == 'dev'
      run: |
        cd frontend
        flutter build apk --release \
          --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=5 \
          --dart-define=REFRESH_HOME_IDLE_INTERVAL=15 \
          --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=5 \
          --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=12 \
          --dart-define=REFRESH_PROFILE_INTERVAL=30
    
    - name: Upload APK
      uses: actions/upload-artifact@v3
      with:
        name: app-release.apk
        path: frontend/build/app/outputs/flutter-apk/app-release.apk
```

## GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test

variables:
  FLUTTER_VERSION: "3.8.1"

build_android_production:
  stage: build
  image: cirrusci/flutter:latest
  only:
    - main
  script:
    - cd frontend
    - flutter pub get
    - flutter build apk --release
        --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15
        --dart-define=REFRESH_HOME_IDLE_INTERVAL=30
        --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15
        --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=30
        --dart-define=REFRESH_PROFILE_INTERVAL=120
        --dart-define=REFRESH_MAX_BACKOFF_MINUTES=5
  artifacts:
    paths:
      - frontend/build/app/outputs/flutter-apk/app-release.apk
    expire_in: 30 days

build_android_staging:
  stage: build
  image: cirrusci/flutter:latest
  only:
    - staging
  script:
    - cd frontend
    - flutter pub get
    - flutter build apk --release
        --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8
        --dart-define=REFRESH_HOME_IDLE_INTERVAL=20
        --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8
        --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15
        --dart-define=REFRESH_PROFILE_INTERVAL=60
        --dart-define=REFRESH_MAX_BACKOFF_MINUTES=2
  artifacts:
    paths:
      - frontend/build/app/outputs/flutter-apk/app-release.apk
    expire_in: 30 days
```

## Fastlane (iOS/Android)

```ruby
# ios/fastlane/Fastfile

default_platform(:ios)

platform :ios do
  desc "Build for production"
  lane :build_production do
    build_app(
      workspace: "ios/Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release",
      xcargs: [
        "-dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15",
        "-dart-define=REFRESH_HOME_IDLE_INTERVAL=30",
        "-dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15",
        "-dart-define=REFRESH_ORDERS_IDLE_INTERVAL=30",
        "-dart-define=REFRESH_PROFILE_INTERVAL=120",
      ].join(" "),
      export_method: "app-store"
    )
  end

  desc "Build for staging"
  lane :build_staging do
    build_app(
      workspace: "ios/Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release",
      xcargs: [
        "-dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8",
        "-dart-define=REFRESH_HOME_IDLE_INTERVAL=20",
        "-dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8",
        "-dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15",
        "-dart-define=REFRESH_PROFILE_INTERVAL=60",
      ].join(" "),
      export_method: "ad-hoc"
    )
  end
end

platform :android do
  desc "Build for production"
  lane :build_production do
    gradle(
      task: "bundle",
      project_dir: "android/",
      properties: {
        "REFRESH_HOME_ACTIVE_INTERVAL" => "15",
        "REFRESH_HOME_IDLE_INTERVAL" => "30",
        "REFRESH_ORDERS_ACTIVE_INTERVAL" => "15",
        "REFRESH_ORDERS_IDLE_INTERVAL" => "30",
        "REFRESH_PROFILE_INTERVAL" => "120",
      }
    )
  end
end
```

## Docker Build

```dockerfile
# Dockerfile
FROM cirrusci/flutter:latest

WORKDIR /app

# Build args for refresh intervals
ARG REFRESH_HOME_ACTIVE_INTERVAL=15
ARG REFRESH_HOME_IDLE_INTERVAL=30
ARG REFRESH_ORDERS_ACTIVE_INTERVAL=15
ARG REFRESH_ORDERS_IDLE_INTERVAL=30
ARG REFRESH_PROFILE_INTERVAL=120
ARG REFRESH_MAX_BACKOFF_MINUTES=5

COPY . .

RUN cd frontend && \
    flutter pub get && \
    flutter build apk --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=${REFRESH_HOME_ACTIVE_INTERVAL} \
      --dart-define=REFRESH_HOME_IDLE_INTERVAL=${REFRESH_HOME_IDLE_INTERVAL} \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=${REFRESH_ORDERS_ACTIVE_INTERVAL} \
      --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=${REFRESH_ORDERS_IDLE_INTERVAL} \
      --dart-define=REFRESH_PROFILE_INTERVAL=${REFRESH_PROFILE_INTERVAL} \
      --dart-define=REFRESH_MAX_BACKOFF_MINUTES=${REFRESH_MAX_BACKOFF_MINUTES}

# Usage:
# docker build \
#   --build-arg REFRESH_HOME_ACTIVE_INTERVAL=8 \
#   --build-arg REFRESH_PROFILE_INTERVAL=60 \
#   -t batjetkiret-apk:prod .
```

## Environment Variables in Cloud

### Google Cloud Build

```yaml
# cloudbuild.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build',
           '--build-arg', 'REFRESH_HOME_ACTIVE_INTERVAL=15',
           '--build-arg', 'REFRESH_PROFILE_INTERVAL=120',
           '-t', 'gcr.io/$PROJECT_ID/batjetkiret:$BUILD_ID', '.']
```

### AWS CodeBuild

```yaml
# buildspec.yml
phases:
  build:
    commands:
      - cd frontend
      - flutter build apk --release
          --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=$HOME_ACTIVE_INTERVAL
          --dart-define=REFRESH_PROFILE_INTERVAL=$PROFILE_INTERVAL

env:
  parameter-store:
    HOME_ACTIVE_INTERVAL: /batjetkiret/prod/home_active_interval
    PROFILE_INTERVAL: /batjetkiret/prod/profile_interval
```
