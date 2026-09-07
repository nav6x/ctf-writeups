FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY beers.csproj ./
RUN dotnet restore
COPY *.cs ./
RUN dotnet publish -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out ./
COPY wwwroot ./wwwroot
ENV ASPNETCORE_URLS=http://0.0.0.0:3000
EXPOSE 3000
USER $APP_UID
ENTRYPOINT ["./beers"]
