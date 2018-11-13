# frozen_string_literal: true

module Resque
  module Kubernetes
    # Provides methods to ensure a mannifest conforms to a job specification
    # and includes details needed for resque-kubernetes
    module ManifestConformance
      def adjust_manifest(manifest)
        add_labels(manifest)
        ensure_term_on_empty(manifest)
        ensure_reset_policy(manifest)
        update_job_name(manifest)
      end

      def add_labels(manifest)
        manifest.deep_add(%w[metadata labels resque-kubernetes], "job")
        manifest["metadata"]["labels"]["resque-kubernetes-group"] = manifest["metadata"]["name"]
        manifest.deep_add(%w[spec template metadata labels resque-kubernetes], "pod")
      end

      def ensure_term_on_empty(manifest)
        manifest["spec"]["template"]["spec"] ||= {}
        manifest["spec"]["template"]["spec"]["containers"] ||= []
        manifest["spec"]["template"]["spec"]["containers"].each do |container|
          container_term_on_empty(container)
        end
      end

      def container_term_on_empty(container)
        container["env"] ||= []
        term_on_empty = container["env"].find { |env| env["name"] == "INTERVAL" }
        unless term_on_empty
          term_on_empty = {"name" => "INTERVAL"}
          container["env"] << term_on_empty
        end
        term_on_empty["value"] = "0"
      end

      def ensure_reset_policy(manifest)
        manifest["spec"]["template"]["spec"]["restartPolicy"] ||= "OnFailure"
      end

      def ensure_namespace(manifest)
        manifest["metadata"]["namespace"] ||= @default_namespace
      end

      def update_job_name(manifest)
        manifest["metadata"]["name"] += "-#{DNSSafeRandom.random_chars}"
      end
    end
  end
end
