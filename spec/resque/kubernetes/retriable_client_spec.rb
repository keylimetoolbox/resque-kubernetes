# frozen_string_literal: true

require "spec_helper"

describe Resque::Kubernetes::RetriableClient do
  subject { Resque::Kubernetes::RetriableClient.new(kubeclient) }

  let(:kubeclient) { double("Kubeclient::Client", get_pods: "datum") }

  context "when a method on the client raises Kubeclient::HttpError" do
    let(:error) { Kubeclient::HttpError.new(0, message, "body") }

    context "and that has a 'Timed out' message" do
      before do
        expect(kubeclient).to receive(:get_pods).twice.and_raise(error)
      end

      let(:message) { "Timed out connecting to server" }

      it "retries the call" do

        expect { subject.get_pods }.to raise_error Kubeclient::HttpError
      end
    end

    context "and that has a message other than 'Timed out'" do
      before do
        expect(kubeclient).to receive(:get_pods).once.and_raise(error)
      end

      let(:message) { "Resource not found" }

      it "raises the error immediately without retry" do
        expect { subject.get_pods }.to raise_error Kubeclient::HttpError
      end
    end
  end

  context "when a method on the client raises an error other than Kubeclient::HttpError" do
    before do
      allow(kubeclient).to receive(:get_pods).and_raise(StandardError.new("message"))
    end

    it "raises the error immediately without retry" do
      expect { subject.get_pods }.to raise_error StandardError
    end
  end

  context "when a method on the client returns a value" do
    it "returns the value without errors" do
      expect(subject.get_pods).to eq "datum"
    end
  end
end
