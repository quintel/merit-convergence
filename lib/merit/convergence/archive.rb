module Merit
  module Convergence
    # Given a path to an export from ETEngine, reads the data into a form which
    # can be loaded and used by Merit.
    class Archive
      # Public: Path to the archive directory.
      attr_reader :path

      # Public: Creates a new Archive to be read from the given +directory+.
      def initialize(directory, profiles_dir)
        @path     = Pathname.new(directory)
        @profiles = Pathname.new(profiles_dir)
      end

      # Public: The name of the area whose data is archived.
      #
      # Returns a String.
      def area
        info[:area].to_sym
      end

      # Public: Creates a new Merit::Order with the data contained in the
      # archive.
      #
      # Returns a Merit::Order.
      def merit_order
        order = Merit::Order.new

        producers.each do |producer|
          order.add(producer) unless producer.marginal_costs == Float::NAN
        end

        order.add(local_demand_user)

        order
      end

      # Public: All the producers defined in the archive.
      #
      # Returns an array of Producers.
      def producers
        Pathname.glob(@path.join('producers/*.yml')).map do |file|
          producer(YAML.load_file(file))
        end.compact
      end

      # Public: The total amount of energy consumed in the archive region.
      #
      # Returns a Float.
      def total_demand
        info[:total_demand]
      end

      # Public: Returns the price curve contained in the archive.
      #
      # Returns a Curve.
      def price_curve
        load_curve('price.csv')
      end

      # Public: Returns the demand curve contained in the archive.
      #
      # Returns a Curve.
      def demand_curve
        load_curve('demand.csv')
      end

      #######
      private
      #######

      def load_curve(file)
        values = @path.join(file).read.strip.split("\n").map(&:to_f)
        Curve.new(values, Merit::POINTS)
      end

      def producer(data)
        return nil if data[:marginal_costs] && data[:marginal_costs].nan?

        if data[:load_profile_key]
          profile = @profiles.join("#{ data.delete(:load_profile_key) }.csv")
          data = data.merge(load_profile: LoadProfile.load(profile))
        end

        Merit.const_get(data.delete(:type)).new(data)
      end

      def local_demand_user
        profile = Merit::LoadProfile.load(@profiles.join('total_demand.csv'))

        Merit::User.create(
          key:               :local_demand,
          total_consumption:  total_demand,
          load_profile:       profile
        )
      end

      def info
        @info ||= YAML.load_file(@path.join('archive-info.yml'))
      end
    end # Archive
  end # Convergence
end # Merit
