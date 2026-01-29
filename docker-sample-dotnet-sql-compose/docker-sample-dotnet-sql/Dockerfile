# Sample: containerize an ASP.NET app with a multi-stage build
# - Build stage: compiles and publishes
# - Runtime stage: ships only the published output

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj first for better layer caching
COPY ["MyApp/MyApp.csproj", "MyApp/"]
RUN dotnet restore "MyApp/MyApp.csproj"

# Copy the rest and publish
COPY . .
RUN dotnet publish "MyApp/MyApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# ASP.NET defaults to port 8080 in some hosting patterns; set explicitly
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "MyApp.dll"]
