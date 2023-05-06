# frozen_string_literal: true

require "kubeclient"

require_relative "manifest_conformance"

module Resque
  module Kubernetes
    # Spins up Kubernetes Jobs to run Resque workers.
    class JobsManager
      include Resque::Kubernetes::ManifestConformance

      attr_reader :owner
      private :owner

      def initialize(owner)
        @owner             = owner
        @default_namespace = "default"
      end

      def reap_finished_jobs
        finished_jobs.each do |job|
          jobs_client.delete_job(job.metadata.name, job.metadata.namespace)
        rescue KubeException => e
          raise unless e.error_code == 404
        end
      end

      def reap_finished_pods
        finished_pods.each do |pod|
          pods_client.delete_pod(pod.metadata.name, pod.metadata.namespace)
        rescue KubeException => e
          raise unless e.error_code == 404
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

      def pods_client
        @pods_client ||= client("")
      end

      def client(scope)
        return RetriableClient.new(Resque::Kubernetes.kubeclient) if Resque::Kubernetes.kubeclient

        client = build_client(scope)
        RetriableClient.new(client) if client
      end

      def build_client(scope)
        context = ContextFactory.context
        return unless context

        @default_namespace = context.namespace if context.namespace

        Kubeclient::Client.new(context.endpoint + scope, context.version, **context.options)
      end

      def finished_jobs
        resque_jobs = jobs_client.get_jobs({label_selector: "resque-kubernetes=job"})
        resque_jobs.select { |job| job.spec.completions == job.status.succeeded }
      end

      def finished_pods
        resque_jobs = pods_client.get_pods({label_selector: "resque-kubernetes=pod"})
        resque_jobs.select do |pod|
          pod.status.phase == "Succeeded" && pod.status.containerStatuses.all? do |status|
            status.state.terminated.reason == "Completed"
          end
        end
      end

      def jobs_maxed?(name, namespace)
        resque_jobs = jobs_client.get_jobs({
                                               label_selector: "resque-kubernetes=job,resque-kubernetes-group=#{name}",
                                               namespace:      namespace
                                           })
        running = resque_jobs.reject { |job| job.spec.completions == job.status.succeeded }
        running.size >= owner.max_workers
      end
    end
  end
end
