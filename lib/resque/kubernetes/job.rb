# frozen_string_literal: true

require "kubeclient"

module Resque
  module Kubernetes
    # Resque hook to autoscale Kubernetes Jobs for workers.
    #
    # To use, extend your Resque job class with this module and then define a
    # class method `job_manifest` that produces the Kubernetes Job manifest.
    #
    # Example:
    #
    #     class ResourceIntensiveJob
    #       extend Resque::Kubernetes::Job
    #
    #       def perform
    #         # ... your existing code
    #       end
    #
    #       def job_manifest
    #         <<-EOD
    #     apiVersion: batch/v1
    #     kind: Job
    #     metadata:
    #       name: worker-job
    #     spec:
    #       template:
    #         metadata:
    #           name: worker-job
    #         spec:
    #           containers:
    #           - name: worker
    #             image: us.gcr.io/project-id/some-resque-worker
    #             env:
    #             - name: QUEUE
    #               value: high-memory
    #         EOD
    #       end
    #     end
    module Job
      # A before_enqueue hook that adds worker jobs to the cluster.
      def before_enqueue_kubernetes_job(*_)
        if defined? Rails
          return unless Resque::Kubernetes.environments.include?(Rails.env)
        end

        reap_finished_jobs
        reap_finished_pods
        apply_kubernetes_job
      end

      private

      def jobs_client
        return @jobs_client if @jobs_client
        @jobs_client = client("/apis/batch")
      end

      def pods_client
        return @pods_client if @pods_client
        @pods_client = client("")
      end

      def client(scope)
        context = ContextFactory.context
        return unless context

        Kubeclient::Client.new(
            context.api_endpoint + scope,
            context.api_version,
            ssl_options:  context.ssl_options,
            auth_options: context.auth_options
        )
      end

      def finished_jobs
        resque_jobs = jobs_client.get_jobs(label_selector: "resque-kubernetes=job")
        resque_jobs.select { |job| job.spec.completions == job.status.succeeded }
      end

      def reap_finished_jobs
        finished_jobs.each do |job|
          jobs_client.delete_job(job.metadata.name, job.metadata.namespace)
        end
      end

      def reap_finished_pods
        resque_jobs = pods_client.get_pods(label_selector: "resque-kubernetes=pod")
        finished = resque_jobs.select { |pod| pod.status.phase == "Succeeded" }

        finished.each do |pod|
          pods_client.delete_pod(pod.metadata.name, pod.metadata.namespace)
        end
      end

      def apply_kubernetes_job
        manifest = DeepHash.new.merge!(job_manifest)
        ensure_namespace(manifest)

        # Do not start job if we have reached our maximum count
        return if jobs_maxed?(manifest["metadata"]["name"], manifest["metadata"]["namespace"])

        adjust_manifest(manifest)

        job = Kubeclient::Resource.new(manifest)
        jobs_client.create_job(job)
      end

      def jobs_maxed?(name, namespace)
        resque_jobs = jobs_client.get_jobs(
            label_selector: "resque-kubernetes=job,resque-kubernetes-group=#{name}",
            namespace:      namespace
        )
        running = resque_jobs.reject { |job| job.spec.completions == job.status.succeeded }
        running.size == Resque::Kubernetes.max_workers
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
        term_on_empty = container["env"].find { |env| env["name"] == "TERM_ON_EMPTY" }
        unless term_on_empty
          term_on_empty = {"name" => "TERM_ON_EMPTY"}
          container["env"] << term_on_empty
        end
        term_on_empty["value"] = "1"
      end

      def ensure_reset_policy(manifest)
        manifest["spec"]["template"]["spec"]["restartPolicy"] ||= "OnFailure"
      end

      def ensure_namespace(manifest)
        manifest["metadata"]["namespace"] ||= "default"
      end

      def update_job_name(manifest)
        manifest["metadata"]["name"] += "-#{DNSSafeRandom.random_chars}"
      end
    end
  end
end
