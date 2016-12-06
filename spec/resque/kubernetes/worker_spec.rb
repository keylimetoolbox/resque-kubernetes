require "spec_helper"

describe Resque::Kubernetes::Worker do
  class ThingIncludingWorker
    include Resque::Kubernetes::Worker

    def shutdown?
      "super called: #{@shutdown}"
    end

    def shutdown
      @shutdown = true
    end

    def log_with_severity(*_)
    end

    def prepare
    end

    def queues
      [:priority]
    end
  end

  subject { ThingIncludingWorker.new }

  context "#prepare" do
    context "when ENV[TERM_ON_EMPTY] is set" do
      before do
        with_term_on_empty("1") do
          subject.prepare
        end
      end

      it "sets the instance attribute term_on_empty" do
        expect(subject.term_on_empty).to eq "1"
      end
    end

    context "when ENV[TERM_ON_EMPTY] is not set" do
      before do
        with_term_on_empty(nil) do
          subject.prepare
        end
      end

      it "does not set the instance attribute term_on_empty" do
        expect(subject.term_on_empty).to be_nil
      end
    end
  end

  context "#shutdown?" do
    context "when term_on_empty is falsey" do
      before do
        with_term_on_empty(nil) do
          subject.prepare
        end
      end

      it "just does what super does" do
        expect(Resque).not_to receive(:size)
        expect(subject.shutdown?).to eq "super called: "
      end
    end

    context "when term_on_empty is truthy" do
      before do
        with_term_on_empty("1") do
          subject.prepare
        end
      end

      context "if the queues it is working are empty" do
        before do
          allow(Resque).to receive(:size).and_return 0
        end

        it "calls #shutdown" do
          expect(subject.shutdown?).to eq "super called: true"
        end

        it "logs a message" do
          expect(subject).to receive(:log_with_severity).with(:info, "shutdown: queues are empty")
          subject.shutdown?
        end

      end

      context "if there are still items in the queues it is working" do
        before do
          allow(Resque).to receive(:size).and_return 1
        end

        it "just does what super does" do
          expect(subject.shutdown?).to eq "super called: "
        end
      end

    end
  end

  private

  def with_term_on_empty(value)
    old_value = ENV["TERM_ON_EMPTY"]
    ENV["TERM_ON_EMPTY"] = value
    yield
  ensure
    ENV["TERM_ON_EMPTY"] = old_value
  end
end
