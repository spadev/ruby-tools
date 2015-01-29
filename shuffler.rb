#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'

ESCAPE_SEQUENCE = "\r\033[K"

# Splits input file into randomly distributed ordered chunks,
# then shuffles each of chunks in memory
#
# Relies on `shuf` for doing the in-memory shuffle
# Relies on `bzcat` and `zcat` for reading compressed input files
#
# Example
#   input file with lines -> [1, 2, 3, 4, 5, 6, 7, 8]
#   split into 2 chunks   -> [1, 4, 5, 8], [2, 3, 6, 7]
#   shuffled in memor     -> [4, 1, 8, 5], [6, 3, 7, 2]
class Shuffler
  DEFAULT_COUNT = 128

  def initialize(input_file:, count: DEFAULT_COUNT, output_directory: File.dirname(__FILE__))
    @input_file       = File.absolute_path(input_file)
    @count            = count
    @output_directory = File.absolute_path(output_directory)
  end

  def run
    start_time = Time.now
    print_run_details
    create_output_files

    puts "\n*** Splitting input file: #{@input_file}"
    split_input_file

    puts "\n*** In-memory shuffle of #{output_paths.count} files"
    in_memory_shuffle_output_files
    puts "\nTotal duration: #{Formatting.seconds_to_time(Time.now - start_time)}"
  end

  private

  def in_memory_shuffle_output_files
    output_paths.each.with_index(1) do |path, index|
      IO.popen(['shuf', '-o', path, path]) do
        print "#{ESCAPE_SEQUENCE}shuffling #{File.basename(path)} [#{index}/#{output_paths.count}]"
      end
    end
  end

  def split_input_file
    io_object = io_object_for_file(@input_file)
    stats     = Stats.new(io_object, start: true)

    io_object.each_line do |line|
      @output_files.sample.write(line)
      stats.increment(line.size)
    end

    stats.finish!
    io_object.close
    @output_files.each(&:close)
  end

  def print_run_details
    puts "Input file:       #{@input_file}"
    puts "Output directory: #{@output_directory}"
    puts "Parts:            #{@count}"
  end

  def output_paths
    suffix = '0' * @count.to_s.size
    @output_paths ||= @count.times.map do
      ext      = File.extname(@input_file)
      basename = File.basename(@input_file, ext)
      if %w(.gz .bz2).include?(ext)
        ext      = File.extname(basename)
        basename = File.basename(basename, ext)
      end
      File.join(@output_directory, "#{basename}.#{suffix.next!}#{ext}")
    end
  end

  def create_output_files
    FileUtils.mkdir_p(@output_directory) unless File.exist?(@output_directory)
    @output_files = output_paths.map { |path| File.open(path, 'w') }
  end

  def io_object_for_file(file)
    case File.extname(file)
    when '.bz2'
      IO.popen(['bzcat', file])
    when '.gz'
      IO.popen(['zcat', file])
    else
      File.open(file, 'r')
    end
  end
end

# Convenince methods for pretty formatting
module Formatting
  SIZE_UNITS = %w(B KiB MiB GiB TiB)
  WEEK       = 604_800

  def seconds_to_time(seconds)
    return '??:??:??' unless seconds.to_f.finite?

    seconds = seconds.to_i
    return '> 2 weeks' if seconds > 2 * WEEK

    [seconds / 3600, seconds / 60 % 60, seconds % 60]
      .map { |t| t.to_s.rjust(2, '0') }.join(':')
  end
  module_function :seconds_to_time

  def percentage(numerator, denominator, round = 2)
    ((numerator / denominator.to_f) * 100).round(round)
  end
  module_function :percentage

  def pretty_number(number)
    parts = number.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
    parts.join('.')
  end
  module_function :pretty_number

  def humanize_bytes(bytes, round = 1)
    e = bytes == 0 ? 0 : (Math.log(bytes) / Math.log(1024)).floor
    s = format("%.#{round}f", bytes.to_f / 1024**e)

    "#{s} #{SIZE_UNITS[e]}"
  end
  module_function :humanize_bytes
end

# Stats for shuffler, prints at most once per specified update interval
class Stats
  include Formatting

  attr_reader :lines_count,
              :bytes_count

  def initialize(io_object, start: false, update_interval: 1)
    @bytes_count     = 0
    @lines_count     = 0
    @update_interval = update_interval
    @io_object       = io_object

    start! if start
  end

  def start!
    @start_time = Time.now
    @stats_thread = Thread.new do
      loop do
        print
        sleep @update_interval
      end
    end
  end

  def finish!
    @stats_thread.kill if @stats_thread
    print("\n")
  end

  def print(ending = '')
    message = [
      "#{seconds_to_time(elapsed_time)}",
      "#{humanize_bytes(bytes_count)} [#{humanize_bytes(bytes_per_second.round(1))}/s]",
      "#{pretty_number(lines_count)} lines [#{pretty_number(lines_per_second.round)} lines/s]",
      "#{percentage_string}%",
    ].join(' | ')
    STDERR.print "#{ESCAPE_SEQUENCE}#{message}#{ending}"
  end

  def percentage_string
    percentage(@io_object.pos, @io_object.size, 2).to_s
  rescue NoMethodError, Errno::ESPIPE
    '??'
  end

  def elapsed_time
    Time.now - @start_time
  end

  def increment(bytes)
    @lines_count += 1
    @bytes_count += bytes
  end

  def lines_per_second
    lines_count / elapsed_time
  end

  def bytes_per_second
    bytes_count / elapsed_time
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  parser = OptionParser.new do |optparse|
    optparse.on('-c', '--count N', Integer, "Split into N files")   { |n| options[:count] = n }
    optparse.on('-i', '--input-file FILE', "The file to read from") { |f| options[:input_file] = f }
    optparse.on('-o', '--output-directory PATH', "The output directory for shuffled files") do |directory|
      options[:output_directory] = directory
    end
  end
  parser.parse!

  abort("Missing input file\n#{parser}") unless options[:input_file]

  begin
    Shuffler.new(options).run
  rescue Interrupt
    abort("INTERRUPTED")
  end
end
