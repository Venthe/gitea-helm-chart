readme: helm-doc
	readme-generator -v values.yaml -r README.md
	markdownlint *.md -f

.PHONY: helm-doc
helm-doc:
ifeq (, $(shell which readme-generator))
	@{ \
	set -e ;\
	echo 'installing readme-generator-for-helm' ;\
	npm install -g readme-generator-for-helm ;\
	}
else
	echo 'readme-generator-for-helm is already installed'
endif