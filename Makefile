DEBUG ?= false
CONTAINERD ?= true
NVIDIA ?= false
IGNORE_NVIDIA_FAIL ?= false
LIMIT ?=
PROM_VAR_FILE ?= ./prometheus_node_metric_relabel_configs.yaml

.PHONY: all build reset build_docker build_k8s clean help
.DEFAULT_GOAL := help


# define overides for above variables in here
-include PrivateRules.mak

all: build ## alias for build

reset: ## Reset Kubernetes installation  **CAUTION** this wipes iptables
	ansible-playbook -i inventory/hosts playbooks/reset-k8s.yml \
	--extra-vars="activate_containerd=$(CONTAINERD) activate_nvidia=$(NVIDIA) ignore_nvidia_fail=$(IGNORE_NVIDIA_FAIL) debug=$(DEBUG)"

clean: reset ## alias for reset

build_docker: # Install Docker and dependencies
	ansible-playbook -i ./inventory playbooks/docker.yml \
	--extra-vars="activate_nvidia=$(NVIDIA) ignore_nvidia_fail=$(IGNORE_NVIDIA_FAIL) debug=$(DEBUG)"

build_k8s: # Install containerd and Kubernetes and dependencies
	ansible-playbook -i ./inventory $(LIMIT) playbooks/k8s.yml \
	--extra-vars="activate_containerd=$(CONTAINERD) activate_nvidia=$(NVIDIA) ignore_nvidia_fail=$(IGNORE_NVIDIA_FAIL) debug=$(DEBUG)"

build: build_docker build_k8s ## Build all Docker and Kubernetes

# prometheus: build_docker ## Build all Docker and Prometheus
prometheus: ## Build all Docker and Prometheus
	ansible-playbook -i ./inventory $(LIMIT) playbooks/prometheus.yml \
	--extra-vars=@$(PROM_VAR_FILE) \
	--extra-vars="activate_containerd=$(CONTAINERD) activate_nvidia=$(NVIDIA) ignore_nvidia_fail=$(IGNORE_NVIDIA_FAIL) debug=$(DEBUG)"

checkhosts: ## check Ansible can talk to all
	ansible -i ./inventory cluster -b -m shell -a  "hostname;whoami; du -s -k /data/* || ture"

checkdns: ## check DNS works in the Cluster
	@echo "Check DNS:"
	kubectl run -it --rm --restart=Never checkdns1 --image=busybox:1.28.3 \
	sh -- -c "nslookup ingress-nginx.ingress-nginx"
	kubectl run -it --rm --restart=Never checkdns2 --image=busybox:1.28.3 \
	sh -- -c "nslookup www.ibm.com"

checkingress: ## check the Ingress works in the Cluster
	kubectl kustomize git@github.com:piersharding/kustomize-echo.git | kubectl apply -f -
	while [ -z "$$(kubectl -n echoserver get ingress echoserver --template='{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}')" ]; do echo "Waiting..."; sleep 10; done
	sleep 5
	kubectl -n echoserver get ingress echoserver
	ip=`kubectl -n echoserver get ingress echoserver -o json | jq -r .status.loadBalancer.ingress[].ip`; \
	printf "\nIP for echoservers is: $$ip\n\n"
	curl -H "Host: echoserver.example.com" http://localhost:30080/ping
	kubectl kustomize git@github.com:piersharding/kustomize-echo.git | kubectl -n echoserver delete -f -

help:  ## show this help.
	@echo "make targets:"
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ": .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""; echo "make vars (+defaults):"
	@grep -E '^[0-9a-zA-Z_-]+ \?=.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = " \\?\\= "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
