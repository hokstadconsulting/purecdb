DR=docker run -t -i -v ${PWD}:/app ${IMAGE}
B=${DR} bundle
BE=${B} exec

build: container
	echo Building gem
	rm -f pkg/*
	${BE} rake build

push: build
	gem push `/bin/ls -q pkg/* | tail -n1`

container: Dockerfile
	docker build -t ${IMAGE} .

update: container
	${B} update

bundle: container
	${B} install --binstubs ./bin --path=./vendor/bundle

rdoc:
	rm -rf doc
	${BE} rdoc --main=README.md -O -U -x'~' README.md lib

.PHONY: spec
spec:
	${BE} rspec ./spec


cli:
	${DR} /bin/bash -l

