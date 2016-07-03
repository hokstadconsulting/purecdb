
BX=bundle exec

rdoc:
	rm -rf doc
	${BX} rdoc --main=README.md -O -U -x'~' README.md lib

.PHONY: spec
spec:
	${BX} rspec

bundle:
	bundle install --path vendor/bundle
