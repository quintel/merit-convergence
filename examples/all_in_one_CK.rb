require_relative '../lib/merit/convergence'

# Path to the directory containing data exported from ETEngine.
DATA_DIR     = Pathname.new(__FILE__).join('../../data').expand_path
PROFILES_DIR = Pathname.new(Merit.root)

DE_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('/Users/kruip/Projects/etengine/tmp/convergence/DE_2014-08-18_16-02-11'),                   # Path to the DE data.
  PROFILES_DIR.join('load_profiles/de')  # Path to the DE load profiles.
)

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('/Users/kruip/Projects/etengine/tmp/convergence/NL_2014-08-18_16-02-46'),                   # Path to the NL data.
  PROFILES_DIR.join('load_profiles/nl')  # Path to the NL load profiles.
)

# ------------------------------------------------------------------------------

# Create a Runner with data for the local country.
runner = Merit::Convergence::Runner.new(NL_ARCHIVE)

# Add an interconnect with a foreign nation. Import and export loads will be
# calculated depending on the price of each region.
runner.add_interconnect(DE_ARCHIVE, 2449.0)

# Presently the Runner supports only one "real" interconnect. For the moment,
# you may add export loads to other nations if you have those in a Curve.
#
# runner.add_export(:be, Merit::Curve.load_file('/path/to/file'))

runner.add_export(:be, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/be.csv'))
runner.add_export(:gbr, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/gbr.csv'))
runner.add_export(:nor, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/nor.csv'))
#runner.add_export(:den, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/den.csv'))


# Do the two-step run, and get the final merit order back.
merit_order = runner.run
hour        = 1040
time        = Time.at(hour * 60 * 60).utc.strftime('%d %b @ %H:00')

puts "Before including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.first_order).table_for(hour)
puts

# See what the German merit order looks like by uncommenting:
#
# puts "German Merit Order (not including import from NL) @ #{ time }"
# puts "-------------------------------------------------#{ '-' * time.length }"
# puts
# puts Merit::PointTable.new(runner.other_orders[:de]).table_for(hour)
# puts

puts "After including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(merit_order).table_for(hour)

# Get the price curve for NL:
#
merit_order.price_curve

columns = merit_order.participants.producers.map do |producer|
  [ producer.key,
    producer.class,
    producer.output_capacity_per_unit,
    producer.number_of_units,
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

# Get the price curve for DE (the "runner" object which is responsible for
# calculating NL twice to account for import/export retains a copy of the
# calculated DE merit order):
#
# runner.other_orders[:de].price_curve

# Produce a Curve which combines import and export to Germany. Exports are
# positive numbers, imports are negative:
#
# runner.interconnect_flow(:de)

de_order = runner.other_orders[:de]

columns = de_order.participants.producers.map do |producer|
  [ producer.key,
    producer.class,
    producer.output_capacity_per_unit,
    producer.number_of_units,
    producer.marginal_costs,
    producer.load_curve.to_a
  ].flatten
end.transpose

csv_content = CSV.generate do |csv|
  columns.each { |column| csv << column }
end

#puts csv_content
File.write('de_load_curve.csv', csv_content)

csv_content = CSV.generate do |csv|
  de_order.price_curve.each { |v| csv << [v] }
end

File.write('de_price_curve.csv', csv_content)

# Produce a Curve which combines import and export to Germany. Exports are
# positive numbers, imports are negative:
#
csv_content = CSV.generate do |csv|
  de_order.interconnect_flow(:de).each { |v| csv << [v] }
end

File.write('interconnector_curve.csv', csv_content)



