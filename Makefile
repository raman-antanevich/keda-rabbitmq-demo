MINIKUBE_PROFILE := minikube
MINIKUBE_DRIVER := kvm2    # https://minikube.sigs.k8s.io/docs/drivers/
MINIKUBE_NODES := 1
MINIKUBE_CPUS := 4
MINIKUBE_MEMORY := 8196

KUBERNETES_VERSION := 1.20.12
KUBERNETES_API_PORT := 8443


up: minikube-start ingress-nginx-install cert-manager-install rabbitmq-operator-install keda-install

down: minikube-stop

destroy: minikube-delete


minikube-start:
	minikube start \
		--profile ${MINIKUBE_PROFILE} \
		--nodes ${MINIKUBE_NODES} \
		--cpus ${MINIKUBE_CPUS} \
		--memory ${MINIKUBE_MEMORY} \
		--driver ${MINIKUBE_DRIVER} \
		--apiserver-port ${KUBERNETES_API_PORT} \
		--kubernetes-version ${KUBERNETES_VERSION} \
		--addons metrics-server

minikube-stop:
	minikube stop --profile ${MINIKUBE_PROFILE}

minikube-delete:
	minikube delete --profile ${MINIKUBE_PROFILE}


ingress-nginx-install:
	helm upgrade ingress-nginx ingress-nginx \
		--repo https://kubernetes.github.io/ingress-nginx \
		--install \
		--atomic \
		--wait \
		--timeout 300s \
		--cleanup-on-fail \
		--namespace ingress-nginx \
		--create-namespace \
		--values ./chart-values/ingress-nginx.yml

cert-manager-install:
	helm upgrade cert-manager cert-manager \
		--repo https://charts.jetstack.io \
		--install \
		--atomic \
		--wait \
		--timeout 300s \
		--cleanup-on-fail \
		--namespace cert-manager \
		--create-namespace \
		--values ./chart-values/cert-manager.yml

keda-install:
	helm upgrade keda keda \
		--repo https://kedacore.github.io/charts \
		--install \
		--atomic \
		--wait \
		--timeout 300s \
		--cleanup-on-fail \
		--namespace keda \
		--create-namespace \
		--values ./chart-values/keda.yml

rabbitmq-operator-install:
	helm upgrade rabbitmq rabbitmq-cluster-operator \
		--repo https://charts.bitnami.com/bitnami \
		--install \
		--atomic \
		--wait \
		--timeout 300s \
		--cleanup-on-fail \
		--namespace rabbitmq \
		--create-namespace \
		--values ./chart-values/rabbitmq-operator.yml


rabbitmq-port-forward:
	kubectl port-forward rabbitmq-server-0 5672:5672 15672:15672


define buneary
	docker run \
		--rm \
		--network host \
		dominikbraun/buneary:v0.3.1 \
			--user demo \
			--password demo \
			${1} localhost ${2} ${3}
endef

rabbitmq-setup: rabbitmq-create-exchange rabbitmq-create-queue rabbitmq-create-binding

rabbitmq-create-exchange:
	$(call buneary, create exchange, demo_exchange direct)

rabbitmq-create-binding:
	$(call buneary, create binding, demo_exchange demo_queue demo_key)

rabbitmq-create-queue:
	$(call buneary, create queue, demo_queue classic)

ifeq (publish,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

publish:
	for _ in $(shell seq $(RUN_ARGS)); do \
		$(call buneary, publish, demo_exchange demo_key, "demo_message"); \
	done

ifeq (get,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

get:
	$(call buneary, get messages, demo_queue, --force --max=$(RUN_ARGS))


app-deploy:
	kubectl apply --namespace default --filename ./manifests

app-url:
	minikube service ingress-nginx-controller --url --namespace ingress-nginx
