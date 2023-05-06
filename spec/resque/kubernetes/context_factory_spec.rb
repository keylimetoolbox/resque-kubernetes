# frozen_string_literal: true

require "spec_helper"
require "googleauth"

ConfigDouble = Struct.new(:context)
ConfigContextDouble = Struct.new(:api_endpoint, :api_version, :namespace, :auth_options, :ssl_options)

RSpec.describe Resque::Kubernetes::ContextFactory do
  let(:context) { Resque::Kubernetes::ContextFactory.context }

  context "when run from a cluster" do
    before do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?).with(Resque::Kubernetes::Context::WellKnown::TOKEN_FILE).and_return(true)
    end

    it "returns a context using the available token file" do
      expect(context.endpoint).to eq "https://kubernetes.default.svc"
      expect(context.version).to eq "v1"
      expect(context.namespace).to be_nil
      expect(context.options[:auth_options].keys).to eq %i[bearer_token_file]
      token_file = Resque::Kubernetes::Context::WellKnown::TOKEN_FILE
      expect(context.options[:auth_options][:bearer_token_file]).to eq(token_file)
      expect(context.options[:ssl_options]).to be_empty
    end

    context "with a CA file" do
      before do
        allow(File).to receive(:exist?).with(Resque::Kubernetes::Context::WellKnown::CA_FILE).and_return(true)
      end

      it "includes the CA in the SSL options" do
        expect(context.options[:ssl_options].keys).to eq %i[ca_file]
        ca_file = Resque::Kubernetes::Context::WellKnown::CA_FILE
        expect(context.options[:ssl_options][:ca_file]).to eq(ca_file)
      end
    end

    context "with a namespace file" do
      before do
        allow(File).to receive(:exist?).with(Resque::Kubernetes::Context::WellKnown::NAMESPACE_FILE).and_return(true)
        allow(File).to receive(:read).with(Resque::Kubernetes::Context::WellKnown::NAMESPACE_FILE).and_return("name")
      end

      it "includes the namespace" do
        expect(context.namespace).to eq "name"
      end
    end
  end

  context "when run from a kubectl machine" do
    let(:kubectl_file) { Resque::Kubernetes::Context::Kubectl.new.send(:kubeconfig) }

    before do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?).with(kubectl_file).and_return(true)
      allow(Kubeclient::Config).to receive(:read).with(kubectl_file).and_return(config)
    end

    context "without Google default credentials" do
      let(:config) do
        ConfigDouble.new(
          ConfigContextDouble.new(
            "https://127.0.0.1:8443",
            "v1",
            nil,
            {bearer_token: "token"},
            {ca_file: "/path/to/ca.crt"}
          )
        )
      end

      it "returns a context from the kubectl configuration" do
        expect(context.endpoint).to eq "https://127.0.0.1:8443"
        expect(context.version).to eq "v1"
        expect(context.namespace).to be_nil
        expect(context.options[:auth_options].keys).to eq %i[bearer_token]
        expect(context.options[:auth_options][:bearer_token]).to eq("token")
        expect(context.options[:ssl_options].keys).to eq %i[ca_file]
        expect(context.options[:ssl_options][:ca_file]).to eq("/path/to/ca.crt")
      end
    end

    context "with Google default credentials" do
      let(:config) do
        ConfigDouble.new(
          ConfigContextDouble.new(
            "https://127.0.0.1:8443",
            "v1",
            nil,
            {},
            {}
          )
        )
      end

      it "retrieves authentication from the Google application default credentials" do
        expect(Kubeclient::GoogleApplicationDefaultCredentials).to receive(:token).and_return("token")

        expect(context.endpoint).to eq "https://127.0.0.1:8443"
        expect(context.version).to eq "v1"
        expect(context.namespace).to be_nil
        expect(context.options[:auth_options].keys).to eq %i[bearer_token]
        expect(context.options[:auth_options][:bearer_token]).to eq("token")
        expect(context.options[:ssl_options].keys).to be_empty
      end
    end
  end
end
