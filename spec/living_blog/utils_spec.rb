# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LivingBlog::Utils do
  let(:test_class) do
    Class.new do
      include LivingBlog::Utils
    end
  end

  let(:instance) { test_class.new }

  describe '#sh!' do
    context 'when command succeeds' do
      it 'executes the command' do
        expect(instance).to receive(:system).with('echo hello').and_return(true)
        instance.sh!('echo hello')
      end

      it 'prints the command being executed' do
        allow(instance).to receive(:system).and_return(true)
        expect { instance.sh!('echo hello') }.to output(/\+ echo hello/).to_stdout
      end

      it 'does not raise an error' do
        allow(instance).to receive(:system).and_return(true)
        expect { instance.sh!('echo hello') }.not_to raise_error
      end
    end

    context 'when command fails' do
      it 'raises LivingBlog::Error' do
        allow(instance).to receive(:system).and_return(false)

        expect do
          instance.sh!('false')
        end.to raise_error(LivingBlog::Error, /Command failed: false/)
      end

      it 'includes the failed command in error message' do
        allow(instance).to receive(:system).and_return(false)

        expect do
          instance.sh!('git push origin main')
        end.to raise_error(LivingBlog::Error, /git push origin main/)
      end
    end

    context 'when command returns nil' do
      it 'raises LivingBlog::Error' do
        allow(instance).to receive(:system).and_return(nil)

        expect do
          instance.sh!('nonexistent-command')
        end.to raise_error(LivingBlog::Error, /Command failed/)
      end
    end
  end
end

RSpec.describe LivingBlog do
  describe '.sh!' do
    context 'when command succeeds' do
      it 'executes the command via system' do
        expect(described_class).to receive(:system).with('echo hello').and_return(true)
        described_class.sh!('echo hello')
      end

      it 'prints the command being executed' do
        allow(described_class).to receive(:system).and_return(true)
        expect { described_class.sh!('echo hello') }.to output(/\+ echo hello/).to_stdout
      end
    end

    context 'when command fails' do
      it 'raises LivingBlog::Error' do
        allow(described_class).to receive(:system).and_return(false)

        expect do
          described_class.sh!('false')
        end.to raise_error(LivingBlog::Error, /Command failed/)
      end
    end
  end
end
