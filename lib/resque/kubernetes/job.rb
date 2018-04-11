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
    #       class << self
    #         def perform
    #           # ... your existing code
    #         end
    #
    #         def job_manifest
    #           <<~MANIFEST
    #           apiVersion: batch/v1
    #             kind: Job
    #             metadata:
    #               name: worker-job
    #            spec:
    #               template:
    #                 metadata:
    #                   name: worker-job
    #                 spec:
    #                   containers:
    #                   - name: worker
    #                     image: us.gcr.io/project-id/some-resque-worker
    #                     env:
    #                     - name: QUEUE
    #                       value: high-memory
    #           MANIFEST
    #         end
    #       end
    #     end
    module Job
      # A before_enqueue hook that adds worker jobs to the cluster.
      def before_enqueue_kubernetes_job(*_)
        if defined? Rails
          return unless Resque::Kubernetes.environments.include?(Rails.env)
        end

        reap_finished_jobs
        apply_kubernetes_job
      end

      protected

      # Return the maximum number of workers to autoscale the job to.
      #
      # While the number of active Kubernetes Jobs is less than this number,
      # the gem will add new Jobs to auto-scale the workers.
      #
      # By default, this returns `Resque::Kubernetes.max_workers` from the gem
      # configuration. You may override this method to return any other value,
      # either as a simple integer or with some complex logic.
      #
      # Example:
      #    def max_workers
      #      # A simple integer
      #      105
      #    end
      #
      # Example:
      #    def max_workers
      #      # Scale based on time of day
      #      Time.now.hour < 8 ? 15 : 5
      #    end
      def max_workers
        Resque::Kubernetes.max_workers
      end

      private

      def jobs_client
        return @jobs_client if @jobs_client
        @jobs_client = client("/apis/batch")
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
          begin
            jobs_client.delete_job(job.metadata.name, job.metadata.namespace)
          rescue KubeException => e
            raise unless e.error_code == 404
          end
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
        running.size == max_workers
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
