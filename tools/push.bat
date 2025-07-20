docker build -t everything-wine:latest .
docker tag everything-wine:latest bluscream1/everything-wine:latest
docker login
docker push bluscream1/everything-wine:latest