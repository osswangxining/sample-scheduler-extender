# sample-scheduler-extender

A sample to showcase how to create a k8s scheduler extender.

## UPDATE on 2020.6.10

Switch go module, and wire dependencies to k8s.io/*:v0.18.3.

For a fresh cloned repo, run `go mod vendor` and `GOOS=linux GOARCH=amd64 go build -o sample-scheduler-extender *.go` to compile the main binary.

## Running with a Kubernetes 

```
kubectl create configmap scheduler-extender --from-file=./scheduler-extender-config.yaml  --from-file=./scheduler-extender-policy.json

```

```
volumes:
- name: scheduler-extender-config
  configMap:
    name: scheduler-extender
```

```
volumeMounts:
- name: scheduler-extender-config
  mountPath: /etc/kubernetes/scheduler-extender-config
```

```
--config=/etc/kubernetes/scheduler-extender-config/scheduler-extender-config.yaml
```

```
- name: sample-scheduler-extender
  image: registry.cn-beijing.aliyuncs.com/aliyun-asm/sample-scheduler-extender:v0.1
  
```
## [TODO] Running with a hack-local env (for dev)

Make following changes on hack/local-up-cluster.sh

```diff
diff --git a/hack/local-up-cluster.sh b/hack/local-up-cluster.sh
index 8a59190..8dbec17 100755
--- a/hack/local-up-cluster.sh
+++ b/hack/local-up-cluster.sh
@@ -834,7 +834,7 @@ function start_kubescheduler {
     ${CONTROLPLANE_SUDO} "${GO_OUT}/hyperkube" scheduler \
       --v=${LOG_LEVEL} \
       --leader-elect=false \
-      --kubeconfig "${CERT_DIR}"/scheduler.kubeconfig \
+      --config /root/config/scheduler-config.yaml \
       --feature-gates="${FEATURE_GATES}" \
       --master="https://${API_HOST}:${API_SECURE_PORT}" >"${SCHEDULER_LOG}" 2>&1 &
     SCHEDULER_PID=$!
```

## Notes

- Prioritize webhook won't be triggered if it's running on an one-node cluster. As it makes no sense to run priorities logic when there is only one candidate:

```go
// from k8s.io/kubernetes/pkg/scheduler/core/generic_scheduler.go
func (g *genericScheduler) Schedule(pod *v1.Pod, nodeLister algorithm.NodeLister) (string, error) {
    ...
	// When only one node after predicate, just use it.
	if len(filteredNodes) == 1 {
		metrics.SchedulingAlgorithmPriorityEvaluationDuration.Observe(metrics.SinceInMicroseconds(startPriorityEvalTime))
		return filteredNodes[0].Name, nil
    }
    ...
}
```