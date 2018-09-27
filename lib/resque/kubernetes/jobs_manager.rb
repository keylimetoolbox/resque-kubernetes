# frozen_string_literal: true

require "kubeclient"

module Resque
  module Kubernetes
    # Spins up Kubernetes Jobs to run Resque workers.
    class JobsManager
      attr_reader :owner
      private :owner

      def initialize(owner)
        @owner             = owner
        @default_namespace = "default"
      end

      def reap_finished_jobs
        finished_jobs.each do |job|
          begin
            jobs_client.delete_job(job.metadata.name, job.metadata.namespace)
          rescue KubeException => e
            raise unless e.error_code == 404
          end
        end
      end

      def apply_kubernetes_job
        manifest = DeepHash.new.merge!(owner.job_manifest)
        ensure_namespace(manifest)

        # Do not start job if we have reached our maximum count
        return if jobs_maxed?(manifest["metadata"]["name"], manifest["metadata"]["namespace"])

        adjust_manifest(manifest)

        job = Kubeclient::Resource.new(manifest)
        jobs_client.create_job(job)
      end

      private

      def jobs_client
        @jobs_client ||= client("/apis/batch")
      end

      def client(scope)
        return Resque::Kubernetes.kubeclient if Resque::Kubernetes.kubeclient

        context = ContextFactory.context
        return unless context
        @default_namespace = context.namespace if context.namespace

        Kubeclient::Client.new(context.endpoint + scope, context.version, context.options)
      end

      def finished_jobs
        resque_jobs = jobs_client.get_jobs(label_selector: "resque-kubernetes=job")
        resque_jobs.select { |job| job.spec.completions == job.status.succeeded }
      end

      def jobs_maxed?(name, namespace)
        resque_jobs = jobs_client.get_jobs(
            label_selector: "resque-kubernetes=job,resque-kubernetes-group=#{name}",
            namespace:      namespace
        )
        running = resque_jobs.reject { |job| job.spec.completions == job.status.succeeded }
        running.size >= owner.max_workers
      end

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
