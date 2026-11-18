FROM dart:3.13.5-sdk AS build
WORKDIR /app
COPY apps/server/tool/pubspec.docker.yaml pubspec.yaml
COPY pubspec.lock pubspec.lock
COPY packages/domain packages/domain
COPY packages/use_cases packages/use_cases
COPY packages/contracts packages/contracts
COPY packages/api_mapping packages/api_mapping
COPY apps/server apps/server
RUN dart pub get
RUN mkdir -p bin && dart compile exe apps/server/bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY database/migrations /app/database/migrations
WORKDIR /app
EXPOSE 8080
CMD ["/app/bin/server"]
