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

DE_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('/Users/kruip/Projects/etengine/tmp/convergence/run_2a/DE_403119_2015-02-25_17-56-14'),
  DATASETS_DIR.join('de/load_profiles')  # Path to the DE load profiles.
)

NL_ARCHIVE = Merit::Convergence::Archive.new(
  DATA_DIR.join('/Users/kruip/Projects/etengine/tmp/convergence/run_2a/NL_403102_2015-02-25_17-55-50'),                   # Path to the NL data.
  DATASETS_DIR.join('nl/load_profiles')  # Path to the NL load profiles.
)

# ------------------------------------------------------------------------------

# Create a Runner with data for the local country.
runner = Merit::Convergence::Runner.new(NL_ARCHIVE)

# These curves represent IMPORT from BE, GBR, NOR (and in the future DEN)
# The numbers need to be NEGATIVE
# Export is included in the load curve by a scaling
runner.add_export(:be, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/BE_NL_2023.csv'))
runner.add_export(:gbr, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/GBR_NL.csv'))
runner.add_export(:nor, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/NOR_NL_2023.csv'))
runner.add_export(:den, Merit::Curve.load_file('/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/DEN_NL.csv'))

standalone = runner.standalone(:be, :gbr, :nor, :den)

csv_content = CSV.generate do |csv|
    standalone.price_curve.each { |v| csv << [v] }
end

File.write('nl_original_price_curve.csv', csv_content)


# Add an interconnect with a foreign nation. Import and export loads will be
# calculated depending on the price of each region.
runner.add_interconnect(DE_ARCHIVE, 5049.0)


# Presently the Runner supports only one "real" interconnect. For the moment,
# you may add export loads to other nations if you have those in a Curve.
#
# runner.add_export(:be, Merit::Curve.load_file('/path/to/file'))

# Do the two-step run, and get the final merit order back.
merit_order = runner.run
hour        = 4153
time        = Time.at(hour * 60 * 60).utc.strftime('%d %b @ %H:00')

puts "Before including export to Germany @ #{ time }"
puts "------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.first_order).table_for(hour)
puts

# See what the German merit order looks like by uncommenting:
#
puts "German Merit Order (not including import from NL) @ #{ time }"
puts "-------------------------------------------------#{ '-' * time.length }"
puts
puts Merit::PointTable.new(runner.other_orders[:de]).table_for(hour)
puts

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

# Get the price curve for DE (the "runner" object which is responsible for
# calculating NL twice to account for import/export retains a copy of the
# calculated DE merit order):
#
runner.other_orders[:de].price_curve

# Produce a Curve which combines import and export to Germany. Exports are
# positive numbers, imports are negative:
#
runner.interconnect_flow(:de)

de_order = runner.other_orders[:de]

columns = de_order.participants.producers.map do |producer|
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
File.write('de_load_curve.csv', csv_content)

csv_content = CSV.generate do |csv|
  de_order.price_curve.each { |v| csv << [v] }
end

File.write('de_price_curve.csv', csv_content)

# Produce a Curve which combines import and export to Germany. Exports are
# positive numbers, imports are negative:
#
csv_content = CSV.generate do |csv|
  runner.interconnect_flow(:de).each { |v| csv << [v] }
end

File.write('interconnector_curve.csv', csv_content)


################### Statistics on "% of time of being price-setting" ##########################
# Build a hash counting the number of times each producer is price-setting.
 
price_setting_stats = Hash.new(0)
 
merit_order.price_setting_producers.each do |producer|
  price_setting_stats[producer] += 1
end
 
# Produce a CSV containing the producer keys, marginal costs, capacity, and the
# percentage of the year in which they are price-setting.
 
headers = ['Key', 'Marginal_Cost_(EUR/MWh)', 'Capacity_(MW)', '%_Price-setting']
 
price_content = CSV.generate(headers: headers, write_headers: true) do |csv|
  producers = merit_order.participants.producers.sort_by do |producer|
    # Sort the most-price setting producers at the top, and then by key.
    [-price_setting_stats[producer], producer.key]
  end
 
  producers.each do |producer|
    csv << [
      producer.key,
      producer.marginal_costs,
      producer.available_output_capacity,
      (price_setting_stats[producer].to_f / Merit::POINTS) * 100
    ]
  end
 
  # Hours in which there is no price-setting converter, the "emergency price"
  # (the most expensive producer * 7.22) is used.
 
  csv << [
    'emergency_price', '', '',
    (price_setting_stats[nil].to_f / Merit::POINTS) * 100
  ]
end
 
File.write('price_setting_producers.csv', price_content)