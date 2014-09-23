require_relative '../lib/merit/convergence'

# The merit-convergence directory.
CONVERGENCE_DIR = Pathname.new(__FILE__).join('../..').expand_path

# Path to the directory containing data exported from ETEngine.
DATA_DIR = CONVERGENCE_DIR.join('data')

# Path to the ETSource datasets/ directory. The default value assumes that
# ETSource and Merit::Convergence have a common parent directory.
#
#   └ Projects/
#     ├ etsource/
#     │ ├ datasets/
#     │ └ ...
#     └ merit-convergence/
#       ├ data/
#       ├ examples/
#       └ ...
#
DATASETS_DIR = CONVERGENCE_DIR.join('../etsource/datasets')

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('/Users/kruip/Projects/etengine/tmp/convergence/20140923_1502/NL_373837_2014-09-23_15-01-42'),                   # Path to the NL data.
  DATASETS_DIR.join('nl/load_profiles')  # Path to the NL load profiles.
)

# ------------------------------------------------------------------------------

# Create a Runner with data for the local country.
runner = Merit::Convergence::Runner.new(NL_ARCHIVE)

# Add an interconnect with a foreign nation. Import and export loads will be
# calculated depending on the price of each region.
#runner.add_interconnect(DE_ARCHIVE, 2449.0)

# Presently the Runner supports only one "real" interconnect. For the moment,
# you may add export loads to other nations if you have those in a Curve.
#
# runner.add_export(:be, Merit::Curve.load_file('/path/to/file'))

# These curves represent IMPORT from BE, GBR, NOR (and in the future DEN)
# The numbers need to be NEGATIVE
# Export is included in the load curve by a scaling
runner.add_export(:be, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/BE_NL_2013.csv'))
runner.add_export(:gbr, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/GBR_NL.csv'))
runner.add_export(:nor, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/NOR_NL_2013.csv'))
#runner.add_export(:den, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/DEN_NL.csv'))


# Do the run, and get the final merit order back.
merit_order = runner.run
hour        = 4153
time        = Time.at(hour * 60 * 60).utc.strftime('%d %b @ %H:00')

puts "Before including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.first_order).table_for(hour)
puts


# Get the price curve for NL:
#
merit_order.price_curve

columns = merit_order.participants.producers.map do |producer|
  [ producer.key,
    producer.class,
    producer.output_capacity_per_unit,
    producer.number_of_units,
    #producer.availability,
    producer.marginal_costs,
    producer.load_curve.to_a
  ].flatten
end.transpose

csv_content = CSV.generate do |csv|
  columns.each { |column| csv << column }
end

#puts csv_content
File.write('nl_load_curve.csv', csv_content)

csv_content = CSV.generate do |csv|
  merit_order.price_curve.each { |v| csv << [v] }
end

File.write('nl_price_curve.csv', csv_content)

