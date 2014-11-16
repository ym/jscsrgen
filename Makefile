TARGETS=jscsrgen.coffee securerandom.coffee worker.coffee

build:
	coffee -c -b $(TARGETS)

watch:
	coffee -c -b -w $(TARGETS)
