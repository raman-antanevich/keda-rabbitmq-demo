# KEDA: RabbitMQ scaler

The repository has been created to demonstrate how KEDA scales application based on RabbitMQ metrics.

![KEDA Architecture](docs/keda-arch.png)


## Requirements

- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [Helm](https://helm.sh/)
- [Docker](https://www.docker.com/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/)
- [make](https://man7.org/linux/man-pages/man1/make.1.html)


## Walkthrough

### Preparation

#### Run sandbox

Let's start from provisioning a new Kubernetes cluster and setting up RabbitMQ Cluster.

I will use `make` tool through all demo. If you don't have this one, you can just copy-paste commands from `Makefile`.

```sh
make up
```

#### Get access to RabbitMQ

At this point, we shoud have running Kubernetes and RabbitMQ clusters.

To get access to RabbitMQ, I will set up forwarding local `5762/tcp` and `15672/tcp` ports to a RabbitMQ pod.

Advice: run the command in a separate terminal because you should keep it open until you finished.

```sh
make rabbitmq-port-forward
```

#### Setup RebbitMQ and deploy application

Now you are able to create RabbitMQ resources such as Exchange, Queue etc and deploy demo application.

```sh
make rabbitmq-setup
make app-deploy
```

If you want to look at the application, you can open it in the browser. You just need to execute the command to get URL:

```
make app-url
```

### Review ScaledObject

All KEDA magic is in the one Kubernetes resourse - ScaledObject (`manifests/scaledobject.yml`).

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: whoami
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: whoami
  pollingInterval: 10
  minReplicaCount: 1
  maxReplicaCount: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 30
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: rabbitmq
    metadata:
      mode: QueueLength
      queueName: demo_queue
      value: "10"
      vhostName: /
      hostFromEnv: KEDA_RABBITMQ_URI
```

In the example, the app scales from 1 to 10 pods based on length of `demo_queue` queue.

`KEDA_RABBITMQ_URI` is the app's environment variable that looks like `amqp://demo:demo@rabbitmq.default:5672/vhost` (recommend to retrieve it from Secret).

The trigger has threshold value (`value`) that is used to calculate how many pods should be destroyed or created. Kubernetes will use the following formula to decide whether to scale the pods up and down:

```
desiredReplicas = ceil[currentReplicas * ( currentMetricValue / desiredMetricValue )]
```

### Getting and Publishing messages

I will use `buneary` CLI client for RabbitMQ ([source](https://github.com/dominikbraun/buneary)).

```sh
make publish 23
make get 45
```


## Links

- [Scaling of Deployments and StatefulSets](https://keda.sh/docs/2.6/concepts/scaling-deployments)
- [Scalers](https://keda.sh/docs/2.6/scalers)
- [RabbitMQ Queue](https://keda.sh/docs/2.6/scalers/rabbitmq-queue)
- [How KEDA works with HPA](https://github.com/kedacore/keda/blob/main/CREATE-NEW-SCALER.md#getmetricspecforscaling)
- [Scaling policies](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-policies)
- [Stabilization window](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#stabilization-window)
