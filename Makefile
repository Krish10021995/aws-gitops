.PHONY: help tf-fmt tf-validate tf-plan tf-apply gitops-check apps-lint apps-test ci

help:
	@echo "tf-fmt       terraform fmt -recursive -check"
	@echo "tf-validate  terraform init -backend=false + validate (no AWS creds needed)"
	@echo "tf-plan      terraform plan (needs AWS creds + S3 backend)"
	@echo "tf-apply     terraform apply (needs AWS creds + S3 backend)"
	@echo "gitops-check kustomize build all overlays"
	@echo "apps-lint    ruff check api + worker"
	@echo "apps-test    pytest api + worker"
	@echo "ci           run everything CI does, locally"

TF_DIR := terraform/envs/dev

tf-fmt:
	cd terraform && terraform fmt -recursive -check

tf-validate:
	cd $(TF_DIR) && terraform init -input=false -backend=false
	cd $(TF_DIR) && terraform validate

tf-plan:
	cd $(TF_DIR) && terraform init -input=false
	cd $(TF_DIR) && terraform plan -out=tfplan

tf-apply:
	cd $(TF_DIR) && terraform init -input=false
	cd $(TF_DIR) && terraform apply -auto-approve tfplan

gitops-check:
	@set -e; for d in gitops/apps gitops/apps/api gitops/apps/worker gitops/apps/web gitops/app-infra gitops/argocd; do \
		echo ">> $$d"; kustomize build "$$d" >/dev/null; \
	done

apps-lint:
	cd apps/api && .venv/bin/ruff check .
	cd apps/worker && .venv/bin/ruff check .

apps-test:
	cd apps/api && .venv/bin/pytest -q
	cd apps/worker && .venv/bin/pytest -q

ci: tf-fmt tf-validate gitops-check apps-lint apps-test
	@echo "all CI checks passed"