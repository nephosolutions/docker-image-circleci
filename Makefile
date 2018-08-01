requirements-frozen.txt:
	docker build --build-arg REQUIREMENTS=upgrade --tag nephosolutions/circleci .
	docker run --rm nephosolutions/circleci pip freeze --quiet > requirements-frozen.txt

.PHONY: requirements-frozen.txt
