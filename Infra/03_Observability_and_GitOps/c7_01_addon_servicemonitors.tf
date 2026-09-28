resource "kubernetes_manifest" "node_exporter_servicemonitor" {
  depends_on = [
    helm_release.kube_prometheus_stack,
    aws_eks_addon.prometheus_node_exporter
  ]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "prometheus-node-exporter"
      namespace = "kube-system"
    }
    spec = {
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "prometheus-node-exporter"
        }
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "kube_state_metrics_servicemonitor" {
  depends_on = [
    helm_release.kube_prometheus_stack,
    aws_eks_addon.kube_state_metrics
  ]

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind = "ServiceMonitor"
    metadata = {
      name = "kube-state-metrics"
      namespace = "kube-system"
    }
    spec = {
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "kube-state-metrics"
        }
      }
      endpoints = [
        {
          port = "http"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}