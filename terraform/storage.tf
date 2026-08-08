# A default StorageClass, declared as infrastructure.
#
# EKS ships a "gp2" StorageClass but does NOT mark it default. That is why
# every EKS tutorial on the internet contains a step like:
#
#   kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{...}}}'
#
# ...an imperative, undocumented, easy-to-skip command whose only symptom when
# forgotten is a PersistentVolumeClaim stuck in Pending forever. This project
# hit exactly that bug: Postgres named gp2 explicitly and survived, Ollama did
# not and silently never started. Declaring the class here deletes the step.
#
# Why gp3 over gp2:
#   - cheaper: $0.08/GiB-month vs $0.10
#   - 3000 IOPS and 125 MB/s baseline at ANY size. gp2 ties IOPS to volume
#     size, so a 1 GiB Postgres volume gets 3 IOPS and a burst balance.

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"

  # Lets you grow a PVC in place later. Off by default, and you cannot turn it
  # on retroactively for volumes already provisioned by this class.
  allow_volume_expansion = true

  # This is not optional on a multi-AZ cluster.
  #
  # With Immediate binding the CSI driver provisions the EBS volume — and
  # therefore picks its AZ — before the scheduler has picked a node. An EBS
  # volume cannot cross AZs, so roughly two times in three the pod is then
  # unschedulable forever, with an error that blames affinity rather than
  # binding order. WaitForFirstConsumer inverts it: schedule first, then
  # provision the volume in whatever AZ the pod landed in.
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  # This resource talks to the Kubernetes API, so Terraform now depends on the
  # cluster being reachable. If your kubeconfig or IAM ever breaks and this
  # blocks a plan or destroy, the escape hatch is:
  #
  #   terraform state rm kubernetes_storage_class_v1.gp3
  depends_on = [module.eks]
}
