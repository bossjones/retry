require 'optparse'


class RetryIt

  attr_accessor :max_retries, :min_sleep, :max_sleep, :constant_sleep

  def initialize()
    @max_tries = 10
    @min_sleep = 0.3
    @max_sleep = 60.0
    @constant_sleep = nil
  end

  def load_options(args)
    return if args.size < 1

    optparser = OptionParser.new do |opts|
      opts.banner = "Usage: retry [options] [-f fail_script +commands] -e execute command"

      opts.on("-h", "-?", "--help") do |v|
        puts opts
        exit
      end

      opts.on("-t#", "--tries=#", Integer, "Set max retries: Default 10") do |v|
        @max_tries = v
      end

      opts.on("-s#", "--sleep=secs", Float, "Constant sleep amount (seconds)") do |v|
        @constant_sleep = v
      end

      opts.on("-m#", "--min=secs", Float, "Exponenetial Backoff: minimum sleep amount (seconds): Default 0.3") do |v|
        @min_sleep = v
      end

      opts.on("-x#", "--max=secs", Float, "Exponenetial Backoff: maximum sleep amount (seconds): Default 60") do |v|
        @max_sleep = v
      end

    end

    optparser.parse(*args)
  end

  def sleep_amount(attempts)
    @constant_sleep || [@min_sleep * (2 ** (attempts - 1)), @max_sleep].min
  end

  def log_out(message)
    STDERR.puts(message)
  end

  def run(args)

    if (args.size < 1 || ["-h", "-?", "--help"].include?(args[0]))
      load_options(["-?"])
    end

    fail_command = nil

    idx = args.find_index("-f") || args.find_index("-e")
    if !idx.nil?
      load_options(args[0...idx])
      if (args[idx] == "-f")
        e_idx = args.find_index("-e")
        raise "fail script (-f) must be combined with execution script (-e)" if e_idx.nil?
        raise "fail script not defined" if idx == e_idx
        fail_command = args[(idx+1)..(e_idx-1)]
        idx = e_idx
      end
      args = args[(idx+1)..-1]
    end

    #log_out("Run script #{args[0]} #{args[1..-1]}")
    #log_out("Fail script #{fail_command[0]} #{fail_command[1..-1]}") unless fail_command.nil?

    raise "max_tries must be greater than 0" unless @max_tries > 0
    raise "minimum sleep cannot be greater than maximum sleep" unless @max_sleep >= @min_sleep
    raise "unknown execute command" unless args.size > 0

    process = nil
    attempts = 0
    success = false
    while (success == false && attempts <= @max_tries)
      if (attempts > 0)
        sleep_time = sleep_amount(attempts)
        log_out("Before retry ##{attempts}: sleeping #{sleep_time} seconds")
        sleep sleep_time
      end
      success = system(args[0], *args[1..-1])
      process = $?
      attempts += 1
    end

    if success.nil?
      log_out("Command Failed: #{args[0]}")
    elsif attempts > @max_tries
      if !fail_command.nil?
        log_out("Retries exhausted, running fail script")
        system(fail_command[0], *fail_command[1..-1])
      else
        log_out("Retries exhausted")
      end
    end
    exit process.exitstatus
  end

end
