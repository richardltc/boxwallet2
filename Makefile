dev:
	go run httpd/main.go

tidy:
	go mod tidy
	go mod vendor

build:
	rm ./boxwallet2.tar.gz
	env GOOS=linux go build -ldflags="-s -w" .
	tar -zcvf "./boxwallet2.tar.gz" "./boxwallet2"

	# env GOOS=windows go build -ldflags="-s -w" .
builddebug:
	env GOOS=linux go build -gcflags="all=-N -l" .
