.PHONY: clean clean-test clean-pyc clean-build Makefile

BUCKET=your-bucket-to-put-templates
PREFIX=s3pypi/
DOMAIN=your.domain.to.serve.s3pypi.example.com
DOMAIN_CERT=your.domain.to.serve.s3pypi.example.com

clean: clean-build clean-pyc clean-tests

clean-build:
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	rm -fr pip-wheel-metadata/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc:
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-tests:
	rm -fr .tox/
	rm -f .coverage
	rm -fr coverave/
	rm -fr .pytest_cache/

install:
	poetry install

test:
	poetry run pytest

lint:
	poetry run flake8
	poetry run black . --check --quiet
	poetry run isort --check-only --quiet

format:
	poetry run isort --apply
	poetry run black .

create-cfn-bucket-stack: upload-templates
	aws cloudformation create-stack \
		--region us-east-1 \
		--stack-name s3pypi-bucket \
		--template-url https://s3.amazonaws.com/$(BUCKET)/$(PREFIX)s3-pypi-bucket.yml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters ParameterKey=DomainName,ParameterValue=$(DOMAIN)

create-cfn-api-stack: #upload-templates
	$(eval CERT := $(shell aws acm list-certificates --region us-east-1 | jq ".CertificateSummaryList | map(select(.DomainName == \"$(DOMAIN_CERT)\"))[0].CertificateArn"))
	aws cloudformation create-stack \
		--region us-east-1 \
		--stack-name s3pypi-api \
		--template-url https://s3.amazonaws.com/$(BUCKET)/$(PREFIX)s3-pypi-api.yml \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameters ParameterKey=S3BucketStackName,ParameterValue=s3pypi-bucket \
		             ParameterKey=AcmCertificateArn,ParameterValue=$(CERT)

delete-cfn-api-stack:
	aws cloudformation delete-stack \
		--region us-east-1 \
		--stack-name s3pypi-api

upload-templates:
	aws s3 cp ./cloudformation/s3-pypi-bucket.yml s3://$(BUCKET)/$(PREFIX)
	aws s3 cp ./cloudformation/s3-pypi-api.yml s3://$(BUCKET)/$(PREFIX)

