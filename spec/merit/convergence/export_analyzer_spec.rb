require 'spec_helper'

module Merit
  describe Convergence::ExportAnalyzer do
    let(:producer_attrs) {{
      output_capacity_per_unit: 1.0,
      number_of_units:          1,
      availability:             1.0,
      fixed_costs_per_unit:     1.0,
      fixed_om_costs_per_unit:  1.0
    }}

    let(:prod1_attrs) do
      producer_attrs.merge(key: :prod1, marginal_costs: 10.0)
    end

    let(:prod2_attrs) do
      producer_attrs.merge(key: :prod2, marginal_costs: 20.0)
    end

    let(:prod3_attrs) do
      producer_attrs.merge(
        key: :prod3, marginal_costs: 30.0, number_of_units: 3)
    end

    let(:local_order) do
      Merit::Order.new.tap do |order|
        order.add(DispatchableProducer.new(prod1_attrs))
        order.add(DispatchableProducer.new(prod2_attrs))
        order.add(DispatchableProducer.new(prod3_attrs))

        l_curve = Curve.new([local_demand] * Merit::POINTS)
        order.add(User.create(key: :user, load_curve: l_curve))
      end
    end

    let(:other_demand) { 4.0 }
    let(:other_prices) { [10.0] * 5 }

    let(:other_order) do
      # Add five producers each with "other_demand" / 5 demand
      Merit::Order.new.tap do |order|
        5.times do |i|
          order.add(DispatchableProducer.new(
            producer_attrs.merge(
              key: :"other_#{ i }",
              output_capacity_per_unit: 1.0,
              marginal_costs: other_prices[i]
            )
          ))
        end

        l_curve = Curve.new([other_demand] * Merit::POINTS)
        order.add(User.create(key: :user, load_curve: l_curve))
      end
    end

    let(:export) do
      c_curve = Curve.new([ic_capacity] * Merit::POINTS)

      other_order.calculate(Merit::Convergence::Calculator.new)
      local_order.calculate(Merit::Convergence::Calculator.new)

      Convergence::ExportAnalyzer.new(
        local_order, other_order, c_curve
      ).load_curve.get(0)
    end

    # --------------------------------------------------------------------------

    context 'when the main country has spare capacity' do
      let(:local_demand) { 2.0 }
      let(:ic_capacity)  { 2.0 }

      context 'and the foreign country is cheaper' do
        let(:other_prices) { [10.0] * 5 }

        it 'does not export' do
          expect(export).to be_zero
        end
      end # and the foreign country is cheaper

      context 'and the foreign country is more expensive' do
        let(:other_prices) { [40.0] * 5 }

        context 'limited by local capacity' do
          let(:ic_capacity) { 10.0 }

          it 'assigns the remaining capacity to the interconnect' do
            # The total available capacity is 5.0. Load is 2.0 (assigned to the
            # cheapest two producers) which leaves 3.0 available in the third
            # producer.
            expect(export).to eq(3.0)
          end
        end # limited by local capacity

        context 'when an available local producer is partially used' do
          let(:local_demand) { 1.5 }
          let(:ic_capacity)  { 10.0 }

          it 'assigns the remaining capacity to the interconnect' do
            # 0.5 from #2, 3.0 from #3
            expect(export).to eq(3.5)
          end
        end # when an available local producer is partially used

        context 'when some producers are more expensive' do
          let(:local_demand) { 0.5 }
          let(:prod3_attrs)  { super().merge(marginal_costs: 50.0) }

          it 'assigns demand only from the cheaper producers' do
            # 0.5 from #1, 1.0 from #2, nothing from #3
            expect(export).to eq(1.5)
          end
        end # when only one available producer is cheaper

        context 'limited by interconnect capacity' do
          let(:ic_capacity) { 2.0 }

          it 'assigns the interconnect capacity to the interconnect' do
            # 3.0 capacity is available from the third producer, but the
            # interconnect capacity is only 2.0.
            expect(export).to eq(2.0)
          end
        end # limited by interconnect capacity

        context 'limited by foreign demand' do
          let(:other_prices) { [10.0, 10.0, 10.0, 40.0, 40.0] }

          it 'only assigns as much energy as is more expensive' do
            expect(export).to eq(1.0)
          end
        end # limited by foreign demand
      end # and the foreign country is more expensive
    end # when the main country has spare capacity

    context 'when the main country has no spare capacity' do
      let(:local_demand) { 5.0 }
      let(:ic_price)     { 40.0 }
      let(:ic_capacity)  { 10.0 }

      it 'assigns no load to the interconnect' do
        expect(export).to be_zero
      end
    end # when the main country has no spare capacity
  end # Convergence::ExportAnalyzer
end # Merit
