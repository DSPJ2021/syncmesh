go test ./...

go build --ldflags "-s -w" -a -installsuffix cgo -o handler .

faas build -f syncmesh-fn-local.yml 
docker push danielhabenicht/syncmesh-fn:latest