# Project Setup
PROJECT_NAME := wordpress-operator
PROJECT_REPO := github.com/bitpoke/$(PROJECT_NAME)

PLATFORMS = linux_amd64 darwin_amd64

DOCKER_REGISTRY := docker.io/bitpoke

GO111MODULE=on

include build/makelib/common.mk

IMAGES ?= wordpress-operator

include build/makelib/image.mk

GO_STATIC_PACKAGES = $(GO_PROJECT)/cmd/wordpress-operator

GOLANGCI_LINT_VERSION = 1.37.1

include build/makelib/golang.mk
include build/makelib/kubebuilder-v2.mk
include build/makelib/helm.mk

GO_LDFLAGS += -X github.com/bitpoke/wordpress-operator/pkg/version.buildDate=$(BUILD_DATE) \
	       -X github.com/bitpoke/wordpress-operator/pkg/version.gitVersion=$(VERSION) \
	       -X github.com/bitpoke/wordpress-operator/pkg/version.gitCommit=$(GIT_COMMIT) \
	       -X github.com/bitpoke/wordpress-operator/pkg/version.gitTreeState=$(GIT_TREE_STATE)

.PHONY: .kubebuilder.update.chart
.kubebuilder.update.chart: kubebuilder.manifests $(YQ)
	@$(INFO) updating helm RBAC and CRDs from kubebuilder manifests
	@kustomize build config/ > $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml
	@yq e '.metadata.annotations["helm.sh/hook"]="crd-install"' -i $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml
	@yq e '.metadata.labels["app"]="wordpress-operator"'        -i $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml
	@yq e 'del(.metadata.creationTimestamp)'                    -i $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml
	@yq e 'del(.status)'                                        -i $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml
	@mv $(HELM_CHARTS_DIR)/wordpress-operator/crds/_crds.yaml $(HELM_CHARTS_DIR)/wordpress-operator/crds/crds.yaml
	@cp config/rbac/role.yaml $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml
	@yq eval-all 'select(fileIndex == 0) * select(filename == "hack/chart-metadata.yaml")' -i $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml hack/chart-metadata.yaml
	@yq e 'del(.metadata.creationTimestamp)'                                               -i $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml
	@yq e  '.metadata.name="{{ template \"wordpress-operator.fullname\" . }}"'               -i $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml
	@echo '{{- if .Values.rbac.create }}' > $(HELM_CHARTS_DIR)/wordpress-operator/templates/controller-clusterrole.yaml
	@cat $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml >> $(HELM_CHARTS_DIR)/wordpress-operator/templates/controller-clusterrole.yaml
	@echo '{{- end }}' >> $(HELM_CHARTS_DIR)/wordpress-operator/templates/controller-clusterrole.yaml
	@rm $(HELM_CHARTS_DIR)/wordpress-operator/templates/_rbac.yaml
	@$(OK) updating helm RBAC and CRDs from kubebuilder manifests
.generate.run: .kubebuilder.update.chart
