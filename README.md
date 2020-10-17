# sample-scheduler-extender

The Kubernetes scheduler is a policy-rich, topology-aware,
workload-specific function that significantly impacts availability, performance,
and capacity. The scheduler needs to take into account individual and collective
resource requirements, quality of service requirements, hardware/software/policy
constraints, affinity and anti-affinity specifications, data locality, inter-workload
interference, deadlines, and so on. Workload-specific requirements will be exposed
through the API as necessary.

This is a sample to showcase how to create a k8s scheduler extender.

参考： https://www.qikqiak.com/post/custom-kube-scheduler/#%E7%A4%BA%E4%BE%8B


## UPDATE based forked version 
一般来说，我们有4种扩展 Kubernetes 调度器的方法。

- 一种方法就是直接 clone 官方的 kube-scheduler 源代码，在合适的位置直接修改代码，然后重新编译运行修改后的程序，当然这种方法是最不建议使用的，也不实用，因为需要花费大量额外的精力来和上游的调度程序更改保持一致。

- 第二种方法就是和默认的调度程序一起运行独立的调度程序，默认的调度器和我们自定义的调度器可以通过 Pod 的 spec.schedulerName 来覆盖各自的 Pod，默认是使用 default 默认的调度器，但是多个调度程序共存的情况下也比较麻烦，比如当多个调度器将 Pod 调度到同一个节点的时候，可能会遇到一些问题，因为很有可能两个调度器都同时将两个 Pod 调度到同一个节点上去，但是很有可能其中一个 Pod 运行后其实资源就消耗完了，并且维护一个高质量的自定义调度程序也不是很容易的，因为我们需要全面了解默认的调度程序，整体 Kubernetes 的架构知识以及各种 Kubernetes API 对象的各种关系或限制。

- **[本示例中采用的方法]** 第三种方法是**调度器扩展程序**，这个方案目前是一个可行的方案，可以和上游调度程序兼容，所谓的调度器扩展程序其实就是一个可配置的 Webhook 而已，里面包含 过滤器 和 优先级 两个端点，分别对应调度周期中的两个主要阶段（过滤和打分）。

- 第四种方法是通过调度框架（Scheduling Framework），Kubernetes v1.15 版本中引入了可插拔架构的调度框架，使得定制调度器这个任务变得更加的容易。调库框架向现有的调度器中添加了一组插件化的 API，该 API 在保持调度程序“核心”简单且易于维护的同时，使得大部分的调度功能以插件的形式存在，而且在我们现在的 v1.16 版本中上面的 调度器扩展程序 也已经被废弃了，所以以后调度框架才是自定义调度器的核心方式。

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


## UPDATE on 2020.6.10

Switch go module, and wire dependencies to k8s.io/*:v0.18.3.

For a fresh cloned repo, run `go mod vendor` and `GOOS=linux GOARCH=amd64 go build -o sample-scheduler-extender *.go` to compile the main binary.

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