.PHONY: prepare-environment
prepare-environment:
	npm install

.PHONY: readme
readme: prepare-environment
	npm run readme:parameters
	npm run readme:lint

.PHONY: unittests
unittests:
	helm unittest --strict -f 'unittests/helm/**/*.yaml' -f 'unittests/helm/values-conflicting-checks.yaml' ./

.PHONY: helm
update-helm-dependencies:
	helm dependency update
  