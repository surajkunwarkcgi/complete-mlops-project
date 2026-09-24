# Install Secrets Store CSI Driver (Kubernetes SIGs)
resource "helm_release" "secrets_store_csi_driver" {
  depends_on = [ 
    aws_eks_addon.podidentity,
    aws_eks_node_group.private_nodes
   ]

   name = "csi-secrets-store"
   repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
   chart      = "secrets-store-csi-driver"
   namespace = "kube-system"

   set = [
    {
        name = "syncSecret.enabled"
        value = "true"
    },
    {
        name = "tokenRequests[0].audience"
        value = "pods.eks.amazonaws.com"
    }
   ]

    # Wait until the pods are ready
    wait = true
    timeout = 600
    cleanup_on_fail = true
}

output "helm_secrets_store_csi_driver_metadata" {
  description = "Metadata for the Secrets Store CSI Driver Helm release"
  value       = helm_release.secrets_store_csi_driver.metadata
}