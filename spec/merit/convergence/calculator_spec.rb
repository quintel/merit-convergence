require 'spec_helper'

module Merit
  describe Convergence::Calculator do
    let(:disp_1_attrs) {{
      key:                      :dispatchable,
      marginal_costs:           13.999791,
      output_capacity_per_unit: 0.1,
      number_of_units:          1,
      availability:             1.0,
      fixed_costs_per_unit:     222.9245208,
      fixed_om_costs_per_unit:  35.775
    }}

    let(:disp_2_attrs) {{
      key:                      :dispatchable_2,
      marginal_costs:           15.999791,
      output_capacity_per_unit: 0.005,
      number_of_units:          1,
      availability:             1.0,
      fixed_costs_per_unit:     222.9245208,
      fixed_om_costs_per_unit:  35.775
    }}

    let(:vol_1_attrs) {{
      key:                       :volatile,
      marginal_costs:            19.999791,
      load_profile_key:          :industry_chp,
      output_capacity_per_unit:  0.1,
      availability:              0.95,
      number_of_units:           1,
      fixed_costs_per_unit:      222.9245208,
      fixed_om_costs_per_unit:   35.775,
      full_load_hours:           1000
    }}

    let(:vol_2_attrs) {{
      key:                       :volatile_two,
      marginal_costs:            21.21,
      load_profile_key:          :solar_pv,
      output_capacity_per_unit:  0.1,
      availability:              0.95,
      number_of_units:           1,
      fixed_costs_per_unit:      222.9245208,
      fixed_om_costs_per_unit:   35.775,
      full_load_hours:           1000
    }}

    let(:order) do
      Order.new.tap do |order|
        order.add(dispatchable)
        order.add(dispatchable_two)

        order.add(volatile)
        order.add(volatile_two)

        order.add(user)
      end
    end

    let(:volatile)         { VolatileProducer.new(vol_1_attrs) }
    let(:volatile_two)     { VolatileProducer.new(vol_2_attrs) }
    let(:dispatchable)     { DispatchableProducer.new(disp_1_attrs) }
    let(:dispatchable_two) { DispatchableProducer.new(disp_2_attrs) }

    let(:user) { User.create(key: :total_demand, total_consumption: 6.4e6) }

    context 'with an excess of demand' do
      before { Convergence::Calculator.new.calculate(order) }

      it 'sets the load profile values of the first producer' do
        load_value = dispatchable.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(dispatchable.max_load_at(0))
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile_two.max_load_at(0))
      end

      it 'assigns the price setting producer with nothing' do
        expect(order.price_setting_producers[0]).to be_nil
      end
    end # with an excess of demand

    context 'with an excess of supply' do
      let(:disp_1_attrs) { super().merge(number_of_units: 2) }
      before { order.calculate(Calculator.new) }

      it 'sets the load profile values of the first dispatchable' do
        load_value = dispatchable.load_curve.get(0)

        demand = order.participants.users.first.load_at(0)
        demand -= volatile.max_load_at(0)
        demand -= volatile_two.max_load_at(0)

        expect(load_value).to_not be_nil
        expect(load_value).to be_within(0.01).of(demand)
      end

      it 'sets the load profile values of the second dispatchable' do
        load_value = dispatchable.load_curve.get(0)

        demand = order.participants.users.first.load_at(0)
        demand -= volatile.max_load_at(0)
        demand -= volatile_two.max_load_at(0)

        expect(load_value).to_not be_nil
        expect(load_value).to be_within(0.01).of(demand)
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile_two.max_load_at(0))
      end

      it 'assigns the price setting producer with the next dispatchable' do
        expect(order.price_setting_producers[0]).to eql(dispatchable_two)
      end

      context 'and the dispatchable is a cost-function producer' do
        let(:disp_1_attrs) do
          super().merge(cost_spread: 0.02, number_of_units: 2)
        end

        context 'with no remaining capacity' do
          it 'assigns the next dispatchable as price-setting' do
            expect(order.price_setting_producers[0]).to eql(dispatchable_two)
          end
        end # with no remaining capacity

        context 'with > 1 unit of remaining capacity' do
          let(:disp_1_attrs) do
            super().merge(cost_spread: 0.02, number_of_units: 3)
          end

          it 'assigns the current dispatchable as price-setting' do
            expect(order.price_setting_producers[0]).to eql(dispatchable)
          end
        end # with no remaining capacity
      end # and the dispatchable is a cost-function producer
    end # with an excess of supply

    context 'with a huge excess of supply' do
      before { volatile.instance_variable_set(:@number_of_units, 10**9) }
      before { order.calculate(Calculator.new) }

      it 'sets the load profile values of the first producer' do
        load_value = dispatchable.load_curve.get(0)

        expect(load_value).to eql 0.0
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to be_within(0.001).of(0.0)
      end

      it 'assigns the price setting producer with nothing' do
        expect(order.price_setting_producers).to eql \
          Array.new(POINTS, dispatchable)
      end
    end # with a huge excess of supply

    context 'with highly-competitive dispatchers' do
      before { order.calculate(Convergence::Calculator.new) }

      let(:order) do
        Order.new.tap do |order|
          order.add(dispatchable)
          order.add(dispatchable_two)
          order.add(user)
        end
      end

      let(:user) do
        User.create(
          key: :curve_demand,
          load_curve: Curve.new([1.0] * Merit::POINTS)
        )
      end

      let(:disp_1_attrs) { super().merge(
        cost_spread: 0.4, marginal_costs: 20.0,
        output_capacity_per_unit: 0.1, number_of_units: 10
      ) }

      let(:disp_2_attrs) { super().merge(
        marginal_costs: 20.1,
        output_capacity_per_unit: 0.02, number_of_units: 1
      ) }

      it 'assigns load to the first dispatchable' do
        expect(dispatchable.load_curve.get(0)).to be_within(1e-5).of(0.98)
      end

      it 'assigns load to the second dispatchable' do
        expect(dispatchable_two.load_curve.get(0)).to eq(0.02)
      end
    end

    describe 'with a variable-marginal-cost producer' do
      let(:curve) do
        Curve.new([[12.0] * 24, [24.0] * 24, [12.0] * 120].flatten * 52)
      end

      let(:ic_attrs) {{
        key:                       :interconnect,
        cost_curve:                curve,
        output_capacity_per_unit:  1.0,
        availability:              1.0,
        fixed_costs_per_unit:      1.0,
        fixed_om_costs_per_unit:   1.0
      }}

      let(:ic) do
        SupplyInterconnect.new(ic_attrs)
      end

      # We need "dispatchable" to take all of the remaining demand when it is
      # competitive, so that none is assigned to the interconnector
      before { dispatchable.instance_variable_set(:@number_of_units, 30) }

      before { order.add(ic) }
      before { order.calculate(Calculator.new) }

      context 'when the producer is competitive' do
        let(:ic_attrs) { super().merge(output_capacity_per_unit: 0.1) }

        it 'should be active' do
          expect(ic.load_curve.get(0)).to_not be_zero
        end

        it 'is price-setting' do
          expect(order.price_setting_producers[0]).to_not eq(ic)
        end
      end # when the producer is competitive

      context 'when the producer is the final producer' do
        it 'should be active' do
          expect(ic.load_curve.get(0)).to_not be_zero
        end

        it 'is price-setting' do
          expect(order.price_setting_producers[0]).to eq(ic)
        end
      end # when the producer is competitive

      context 'when the producer is uncompetitive' do
        it 'should be inactive' do
          expect(ic.load_curve.get(24)).to be_zero
        end

        it 'is not price-setting' do
          expect(order.price_setting_producers[24]).to_not eq(ic)
        end
      end # when the producer is uncompetitive
    end # with a variable-marginal-cost producer
  end # Convergence::Calculator
end # Merit
