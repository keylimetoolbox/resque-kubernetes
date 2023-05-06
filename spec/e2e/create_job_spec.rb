# frozen_string_literal: true

require "spec_helper"
require "googleauth"

class E2EThingExtendingJob
  extend Resque::Kubernetes::Job

  # rubocop:disable Metrics/MethodLength
  def self.job_manifest
    {
        "metadata" => {
            "name"   => "e2ething",
            "labels" => {"e2e-tests" => "E2EThingExtendingJob"}
        },
        "spec"     => {
            "template" => {
                "spec" => {
                    "containers" => [
                        {
                            "name"    => "e2e-test",
                            "image"   => "ubuntu",
                            "command" => ["pwd"]
                        }
                    ]
                }
            }
        }
    }
  end
  # rubocop:enable Metrics/MethodLength
end

RSpec.describe "Create a job", type: "e2e" do
  after do
    manager = Resque::Kubernetes::JobsManager.new(E2EThingExtendingJob)
    resque_jobs = manager.send(:jobs_client).get_jobs(
      label_selector: "resque-kubernetes=job,e2e-tests=E2EThingExtendingJob"
    )
    resque_jobs.each do |job|

      manager.send(:jobs_client).delete_job(job.metadata.name, job.metadata.namespace)
    rescue KubeException => e
      raise unless e.error_code == 404

    end

  end

  it "launches a job in the cluster which completes when done" do
    manager = Resque::Kubernetes::JobsManager.new(E2EThingExtendingJob)
    # Don't run #before_enqueue_kubernetes_job because we don't want this test reaping finished jobs from elsewhere
    manager.apply_kubernetes_job

    resque_jobs = manager.send(:jobs_client).get_jobs(
      label_selector: "resque-kubernetes=job,e2e-tests=E2EThingExtendingJob"
    )
    expect(resque_jobs.count).to eq 1
    expect(resque_jobs.first.spec.completions).to eq 1
  end
end
