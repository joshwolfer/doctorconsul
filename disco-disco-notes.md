*I poked a hole in neopolitan so i could hit it directly with TP enabled - i didn't take the time to check or setup API/Ingress gateway*

# Create
```sh
kubectl create ns banana-split

pushd services/
kubectl apply -f banana_split-neopolitan.yaml 
kubectl apply -f banana_split-icecream_chocolate.yaml
kubectl apply -f banana_split-icecream_vanilla.yaml
kubectl apply -f banana_split-icecream_strawberry.yaml
popd


kubectl apply -f service-splitter/service-splitter-ice_cream.yaml
kubectl apply -f intentions/dc3-cernunnos-banana_split-ice_cream.yaml
```


# Destroy
```sh

kubectl delete -f banana_split-neopolitan.yaml 
kubectl delete -f banana_split-icecream_chocolate.yaml
kubectl delete -f banana_split-icecream_vanilla.yaml
kubectl delete -f banana_split-icecream_strawberry.yaml

kubectl apply -f intentions/dc3-cernunnos-banana_split-ice_cream.yaml
kubectl apply -f service-splitter/service-splitter-ice_cream.yaml
```




# service-resolver thoughts
Envoy attempts to map a service tag eg: `vanilla.ice-cream.virtual...` and since I've got distinct services backing it doesn't work. Without much critical thinking, first impression is this pattern does not apply for kube. Out of the box, a given kube deployment will have a specific set of tags that will be 'Recreated' or 'RollingUpdate' (default) when applied resulting in a short period of time where both versions exist.

for anythnig canary-like two deployments are required -
    https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#canary-deployment
    https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#canary-deployments

```sh
kubectl apply -f service-resolver/service-resolver-ice_cream.yaml
# "ice-cream" synthetic service will be assigned a virtual ip but we've got no intentions 
# From neopolitan - 
#  Error communicating with upstream service: Get \"http://ice-cream.virtual.banana-split.ns.cernunnos.ap.dc3.dc.consul/\": dial tcp 240.0.0.23:80: connect: connection refused


kubectl delete -f service-resolver/service-resolver-ice_cream.yaml # jank
```
