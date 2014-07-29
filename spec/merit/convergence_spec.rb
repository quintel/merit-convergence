require 'spec_helper'

module Merit
  describe Convergence do
    describe '#competitive_load' do
      let(:attributes) {{
        key:                      :dispatchable,
        marginal_costs:           10.0,
        output_capacity_per_unit: 10.0,
        number_of_units:          10,
        availability:             1.0,
        fixed_costs_per_unit:     1.0,
        fixed_om_costs_per_unit:  1.0
      }}

      context 'given a Constant cost producer' do
        let(:producer) do
          DispatchableProducer.new(attributes)
        end

        it 'returns max capacity if the limit is much lower than the cost' do
          expect(Convergence.competitive_load(producer, 0, 1.0)).to be_zero
        end

        it 'returns zero if the limit is lower than the cost' do
          expect(Convergence.competitive_load(producer, 0, 9.6)).to be_zero
        end

        it 'returns max capacity if the limit is equal to the cost' do
          expect(Convergence.competitive_load(producer, 0, 10.0)).to eq(100.0)
        end

        it 'returns max capacity if the limit is higher than the cost' do
          expect(Convergence.competitive_load(producer, 0, 10.4)).to eq(100.0)
        end

        it 'returns max capacity if the limit is much higher than the cost' do
          expect(Convergence.competitive_load(producer, 0, 20.0)).to eq(100.0)
        end
      end # given a Constant cost producer

      context 'given a CostFunction producer' do
        let(:producer) do
          DispatchableProducer.new(attributes.merge(cost_spread: 0.2))
        end

        it 'returns max capacity if the limit is much lower than the cost' do
          expect(Convergence.competitive_load(producer, 0, 1.0)).to be_zero
        end

        it 'returns a partial load if the limit is slightly lower than the cost' do
          expect(Convergence.competitive_load(producer, 0, 9.6)).to eq(30.0)
        end

        it 'returns half capacity if the limit is equal to the cost' do
          expect(Convergence.competitive_load(producer, 0, 10.0)).to eq(50.0)
        end

        it 'returns a partial load if the limit is slightly higher than the cost' do
          expect(Convergence.competitive_load(producer, 0, 10.4)).to eq(70.0)
        end

        it 'rounds down to the nearest whole plant size' do
          expect(Convergence.competitive_load(producer, 0, 10.45)).to eq(70.0)
        end

        it 'returns max capacity if the limit is much higher than the cost' do
          expect(Convergence.competitive_load(producer, 0, 20.0)).to eq(100.0)
        end
      end # given a CostFunction producer
    end # competitive_load
  end # Convergence
end # Merit
