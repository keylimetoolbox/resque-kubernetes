# frozen_string_literal: true

require "spec_helper"

describe Resque::Kubernetes::Job do
  class ThingExtendingJob
    extend Resque::Kubernetes::Job

    def self.job_manifest
      default_manifest
    end

    def self.default_manifest
      {
          "metadata" => {"name" => "thing"},
          "spec"     => {
              "template" => {
                  "spec" => {"containers" => [{}]}
              }
          }
      }
    end
  end

  class K8sStub < OpenStruct
    def initialize(hash)
      new_hash = hash.merge(metadata: {namespace: "default", name: "pod-#{Time.now.to_i}"})
      deep_struct = new_hash.map do |key, value|
        if value.is_a?(Hash)
          [key, OpenStruct.new(value)]
        else
          [key, value]
        end
      end.to_h
      super(deep_struct)
    end
  end

  subject { ThingExtendingJob }

  let(:jobs_client) { spy("jobs client") }

  before do
    allow(subject).to receive(:jobs_client).and_return(jobs_client)
  end

  context "#before_enqueue_kubernetes_job" do
    let(:done_job)    { K8sStub.new(spec: {completions: 1}, status: {succeeded: 1}) }
    let(:working_job) { K8sStub.new(spec: {completions: 1}, status: {succeeded: 0}) }
    let(:done_pod)    { K8sStub.new(status: {phase: "Succeeded"}) }
    let(:working_pod) { K8sStub.new(status: {phase: "Running"}) }

    context "when Rails.env is not defined" do
      before do
        expect(defined? Rails).not_to be true
      end

      it "calls kubernetes APIs" do
        expect(subject).to receive(:jobs_client).and_return(jobs_client)
        subject.before_enqueue_kubernetes_job
      end
    end

    context "when Rails.env is defined" do
      let(:rails_stub) { Class.new }

      before do
        stub_const("Rails", rails_stub)
        allow(rails_stub).to receive(:env).and_return("test")
      end

      context "and is included in the supported environments" do
        before do
          allow(Resque::Kubernetes).to receive(:environments).and_return(["test"])
        end

        it "calls kubernetes APIs" do
          expect(subject).to receive(:jobs_client).and_return(jobs_client)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "and is not included in the supported environments" do
        before do
          allow(Resque::Kubernetes).to receive(:environments).and_return(["production"])
        end

        it "does not make any kubernetes calls" do
          expect(subject).not_to receive(:jobs_client)
          subject.before_enqueue_kubernetes_job
        end
      end
    end

    it "reaps any completed jobs matching our label" do
      jobs = [working_job, done_job]
      expect(jobs_client).to receive(:get_jobs).with(label_selector: "resque-kubernetes=job").and_return(jobs)
      expect(jobs_client).to receive(:delete_job).with(done_job.metadata.name, done_job.metadata.namespace)
      subject.before_enqueue_kubernetes_job
    end

    context "when the maximum number of matching, working jobs is met" do
      before do
        allow(Resque::Kubernetes).to receive(:max_workers).and_return(1)
        allow(jobs_client).to receive(:get_jobs).and_return([working_job])
      end

      it "does not try to create a new job" do
        expect(Kubeclient::Resource).not_to receive(:new)
        subject.before_enqueue_kubernetes_job
      end
    end

    context "when matching, completed jobs exist" do
      before do
        allow(Resque::Kubernetes).to receive(:max_workers).and_return(2)
        allow(jobs_client).to receive(:get_jobs).and_return([done_job, working_job])
      end

      it "creates a new job using the provided job manifest" do
        expect(jobs_client).to receive(:create_job)
        subject.before_enqueue_kubernetes_job
      end
    end

    context "when more job workers can be launched" do
      let(:job) { double("job") }

      before do
        allow(Resque::Kubernetes).to receive(:max_workers).and_return(10)
        allow(jobs_client).to receive(:get_jobs).and_return([])
        allow(Kubeclient::Resource).to receive(:new).and_return(job)
      end

      it "creates a new job using the provided job manifest" do
        expect(jobs_client).to receive(:create_job)
        subject.before_enqueue_kubernetes_job
      end

      it "labels the job and the pod" do
        manifest = hash_including(
            "metadata" => hash_including(
                "labels" => hash_including(
                    "resque-kubernetes" => "job"
                )
            ),
            "spec"     => hash_including(
                "template" => hash_including(
                    "metadata" => hash_including(
                        "labels" => hash_including(
                            "resque-kubernetes" => "pod"
                        )
                    )
                )
            )
        )
        expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
        subject.before_enqueue_kubernetes_job
      end

      it "label the job to group it based on the provided name in the manifest" do
        manifest = hash_including(
            "metadata" => hash_including(
                "labels" => hash_including(
                    "resque-kubernetes-group" => "thing"
                )
            )
        )
        expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
        subject.before_enqueue_kubernetes_job
      end

      it "updates the job name to make it unique" do
        manifest = hash_including(
            "metadata" => hash_including(
                "name" => match(/^thing-[a-z0-9]{5}$/)
            )
        )
        expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
        subject.before_enqueue_kubernetes_job
      end

      context "when the restart policy is included" do
        before do
          manifest = subject.default_manifest.dup
          manifest["spec"]["template"]["spec"]["restartPolicy"] = "Always"
          allow(subject).to receive(:job_manifest).and_return(manifest)
        end

        it "retains it" do
          manifest = hash_including(
              "spec" => hash_including(
                  "template" => hash_including(
                      "spec" => hash_including(
                          "restartPolicy" => "Always"
                      )
                  )
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "when the restart policy is not set" do
        it "ensures it is set to OnFailure" do
          manifest = hash_including(
              "spec" => hash_including(
                  "template" => hash_including(
                      "spec" => hash_including(
                          "restartPolicy" => "OnFailure"
                      )
                  )
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "when TERM_ON_EMPTY environment is included" do
        before do
          manifest = subject.default_manifest.dup
          manifest["spec"]["template"]["spec"]["containers"][0]["env"] = [
              {"name" => "TERM_ON_EMPTY", "value" => "true"}
          ]
          allow(subject).to receive(:job_manifest).and_return(manifest)
        end

        it "ensures it is set to 1" do
          manifest = hash_including(
              "spec" => hash_including(
                  "template" => hash_including(
                      "spec" => hash_including(
                          "containers" => array_including(
                              hash_including(
                                  "env" => array_including(
                                      hash_including("name" => "TERM_ON_EMPTY", "value" => "1")
                                  )
                              )
                          )
                      )
                  )
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "when TERM_ON_EMPTY environment is not set" do
        it "ensures it is set to 1" do
          manifest = hash_including(
              "spec" => hash_including(
                  "template" => hash_including(
                      "spec" => hash_including(
                          "containers" => array_including(
                              hash_including(
                                  "env" => array_including(
                                      hash_including("name" => "TERM_ON_EMPTY", "value" => "1")
                                  )
                              )
                          )
                      )
                  )
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "when the namespace is not included" do
        it "sets it to 'default'" do
          manifest = hash_including(
              "metadata" => hash_including(
                  "namespace" => "default"
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

      context "when the namespace is set" do
        before do
          manifest = subject.default_manifest.dup
          manifest["metadata"]["namespace"] = "staging"
          allow(subject).to receive(:job_manifest).and_return(manifest)
        end

        it "retains it" do
          manifest = hash_including(
              "metadata" => hash_including(
                  "namespace" => "staging"
              )
          )
          expect(Kubeclient::Resource).to receive(:new).with(manifest).and_return(job)
          subject.before_enqueue_kubernetes_job
        end
      end

    end
  end

end
