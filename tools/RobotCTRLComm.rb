#!/usr/bin/ruby1.9.3

=begin
@author: vincent.sercu@ugent.be
@created: may-2013
@updated: jan-2019

last changelog:
15/07/15: added safereturn option -> pass "start_drive_safereturn" on STDIN
01/01/19: fixed ruby-version + modified the howto


+++++++ DESCRIPTION +++++++++
This script acts as RobotDashboard to automate requests to RobotControl, from a framework such as OMF.
Call the script in the beginning of the experiment, and when needed, put commands to its STDIN.
Using OML, the script can capture location data of robots.
Every action forwarded to RobotControl is via REST.

+++++++    HOWTO    +++++++++
---------
 method 1:
---------
if this file is executed, it acts as Ruby-like interface to talk to robotcontrol (via HTTP-requests)
it basically does the same as a user on the RobotDashboard, but you can automate it much easier.

- a coordinate file for robots is always requested at startup (unless you only want to preform actions (e.g. autoundock / autodock) for robots)
- forward actions to robot by writing 'robotid;actionname' to STDIN (e.g. '1;autoundock')
- start driving of robot by writing 'START_DRIVE' to STDIN of this script
- optionally: log the robot's position to the OML DB of your experiment


--------------------
method 2 (advanced):
--------------------
example, if this file is included into an external ruby script written by you :)
require 'RobotCTRLComm'

RobotControlCommunicator.get_location() # get the location of *all* known robots in a YAML-format

	returns -> { 2=>{ :timestamp=>1369931033, :hrstate=>:docked, :time=>"2013-05-30 18:23:53", 
                      :x=>45, :y=>253, :artnd=>:not_ready, :reliableness=>5, :angle=>154, :id=>2, :state=>4},
                 3=>{ robot3's state }, 
                 
                 ...  
               }

RobotControlCommunicator.get_location(2) # gets the location of *one* robotid

 returns -> {2=>{:timestamp=>1369931033, :hrstate=>:docked, :time=>"2013-05-30 18:23:53", 
                 :x=>45, :y=>253, :artnd=>:not_ready, :reliableness=>5, :angle=>154, :id=>2, :state=>4}}


=end

# SET this variable to true if you want OML-logging of the robots position. (OMF/OML is discontinued, this option is deprecated)
$oml_init = false
################################# leave code after this unchanged ###########################################
if (RUBY_VERSION.to_i == 1 and RUBY_VERSION.split('.')[1].to_i < 9 and RUBY_VERSION.split('.')[2].to_i < 1)
  raise "Ruby version must be at least 1.9.1, 1.9.3 recommended. It is now: #{RUBY_VERSION.inspect}"
end

require "uri"
require "net/http"
require "yaml"
require 'logger'

require 'rubygems'
require "json" # >= 1.8.2 (else https://ibcn-jira.intec.ugent.be/browse/WILAB-555)

$SERVICE_HOST = 'robotcontrol.wilab2.ilabt.iminds.be'
$SERVICE_PORT = 5056
$Max_robots = 20
$Allowed_actions = [
  :openlefteye, :openrighteye, :closelefteye, :closerighteye, :zotac_on, :zotac_off, :autodock, :autoundock
]

# gets overwritten by ARGV's
$auth = 'null'

# include the modified oml4r file
begin
  if $oml_init
      require "/var/lib/gems/1.8/gems/oml4r-2.9.1/lib/oml4r.rb"
  
      class RobotLocation < OML4R::MPBase
        name :RobotLocation
        param :robotid
        param :x
        param :y
        param :alpha
      end
  end
rescue Exception => e
  $stderr.puts "Include of oml4r failed: #{e}"
  $oml_init = false
end

# logging:
Timeformat_str = "%Y-%m-%d %H:%M:%S "
class Log
  @@prefix = "RobotComm"
  @@Logfile = Logger.new('communicator.log', 2, 1024000)
  @@Logfile.datetime_format=Timeformat_str
  def self.info(str)
    t = Time.new.strftime(Timeformat_str)
    puts "#{t} #{@@prefix} INFO #{str}"
    @@Logfile.info(str)
  end
  def self.error(str)
    t = Time.new.strftime(Timeformat_str)
    $stderr.puts "#{t} #{@@prefix} ERROR #{str}"
    @@Logfile.error(str)
  end
  def self.warn(str)
    t = Time.new.strftime(Timeformat_str)
    $stderr.puts "#{t} #{@@prefix} WARN #{str}"
    @@Logfile.warn(str)
  end
end

# main functionality
class RobotControlCommunicator
  @@coordinates = nil
 
  ##############################################################################
  # forwards a drive-csv string to the robotcontrol API
  def self.forward_drives(str = nil, sr_after=nil)
    if str.nil? and @@coordinates.nil?
      raise "No coordinates have been loaded, can't continue." 
    end
       
    params = {'coordinates' => str, 'auth' => $auth }
    params['sr_n_dock'] = true unless sr_after.nil?
    
    x = Net::HTTP.post_form(URI.parse("http://#{$SERVICE_HOST}:#{$SERVICE_PORT}/Robot/Run"), params)
    #x.body.gsub!(/(<{1}\/?([^>]+)>{1})/, "")
    if x.body.start_with?("ROBOT_SCENARIO_ERROR")
      Log.error "Unsuccesfull: #{x.body.inspect}"
    else
      Log.info "Succesfull: #{x.body.inspect}"
    end
  end

  ##############################################################################
  # forwards a drive-csv string to the robotcontrol API, in order to set robots at initial positions
  def self.initialize_bots(str)
    raise "CSV file was empty or non-existent." if str.nil?
    params = {'coordinates' => str, 'auth' => $auth }
    x = Net::HTTP.post_form(URI.parse("http://#{$SERVICE_HOST}:#{$SERVICE_PORT}/Robot/ResetScenario"), params)
    #x.body.gsub!(/(<{1}\/?([^>]+)>{1})/, "")
    if x.body.start_with?("OK_RESET_TO_SCENARIOSTART")
      Log.info "Succesfull: #{x.body.inspect}"
    else
      Log.error "Unsuccesfull: #{x.body.inspect}"
    end
  end

  ##############################################################################
  # forwards an action to robotcontrol API
  def self.forward_action(str)
    params = {'actions' => str, 'auth' => $auth }
    x = Net::HTTP.post_form(URI.parse("http://#{$SERVICE_HOST}:#{$SERVICE_PORT}/Robot/Action"), params)
    #x.body.gsub!(/(<([^>]+)>)/, "")
    if x.body.start_with?("ACTION_OK")
      Log.info "Succesfull: req '#{str}' returned: #{x.body.inspect}"
    else
      Log.error "Unsuccesfull: #{x.body.inspect}"
    end
  end

  ##############################################################################
  # gets the location of a robot
  def self.get_location(only_robot = nil)
    params = {}
    params['filter'] = only_robot if only_robot != nil && ! only_robot.empty?
    x = Net::HTTP.post_form(URI.parse("http://#{$SERVICE_HOST}:#{$SERVICE_PORT}/Robot/LocationsYaml"), params)
    obj = YAML::load(x.body)
    return obj
  end

  ##############################################################################
  # reads the csv file
  def self.read_file(filename)
    begin # read robotcoord file
      file = File.new(filename, "r")
      lines = ""
      while (line = file.gets)
        lines += line
      end
      file.close
      @@coordinates = lines
      
    rescue Exception=>e
      Log.error "Exception while trying to read #{filename.inspect}: #{e}"
    end
  end

  ##############################################################################
  # reads the csv file
  def self.set_auth(usr, date, token)
    begin # read robotcoord file
        $auth = { 'user' => usr, 'generated_on' => date, 'auth_hash' => token}.to_json
        Log.info("Authentication token is: #{$auth}")
    rescue Exception=>e
      Log.error "Exception while trying to read #{filename.inspect}: #{e}"
    end
  end

  ##############################################################################
  # handles STDIN text input
  def self.handle_stdin()
    while line=STDIN.gets()
      begin
        Log.info "Read: #{line.inspect} from stdin."
        line.strip!
        line = line.downcase
        
        exit(0) if line.match(/^exit$/) || line.match(/^bye$/)

        if line.match(/^start_drive$/) or line.match(/^drive$/) or line.match(/^start$/)
          Log.info "Starting drive"
          forward_drives(@@coordinates)
        elsif line.match(/^start_drive_safereturn$/)
          Log.info "Starting drive + safe returning when scenario ends"
          forward_drives(@@coordinates, :safe_return)
        elsif line.match(/^init$/) or line.match(/^initialize$/)
          Log.info "Initializing scenario"
          initialize_bots(@@coordinates)

        elsif cap = line.match(/^read_csv (.*)$/)
          if ! cap[1].empty?
            Log.info "Attempting to read file #{cap[1]}"
            read_file(cap[1])
          else
            Log.error("Supply a valid csv file.")
          end

        elsif cap = line.match(/^log_positions\(?(.*?)\)?$/)
          robots = []
          if !cap[1].empty?
            cap[1].split(/,\s?/).each { |robotid|
              robots.push robotid.to_i
            }
          end
          Log.info "Logging positions for all robots"         if robots.empty?
          Log.info "Logging positions for: #{robots.inspect}" if ! robots.empty?
          positions2oml(robots)
        else
          next if line.empty?
          
          # maybe another command
          res = line.match(/^([0-9]+);(\w+)$/)

          if (res.nil?)
            raise "Unparsable line: #{line}"
          else
            robotid = Integer(res[1]) #1st match
            action = res[2].downcase.to_sym #2nd match

            # basic validation, using other actions will result in fail by robotctrl anyway
            raise "robotid '#{robotid}' not allowed." if robotid < 0 or robotid > $Max_robots
            raise "action '#{action}' not allowed. (allowed actions: #{$Allowed_actions.join('|')})" unless $Allowed_actions.include?(action)

            forward_action("#{robotid};#{action}")
          end #if action
        end #if startdrive
      rescue SystemExit => e
        # silently exit
      rescue Exception => e
        Log.error "While reading STDIN: #{line.inspect} resulted in: #{e}"
      end
    end #while
  end

  ##############################################################################
  ################################# OML ########################################
  # inits oml and logs positions of the array robotids (can be empty) to the current users db
  def self.positions2oml(robotids)
    unless $oml_init
      OML4R::init(nil,
        { :appName => 'robotcommunicator',
          #:domain => 'wilab2-mobility', # is mapped to expID by OMF Resource Controller via bash ENV variables
          :collect =>  "tcp:am.wilab2.ilabt.iminds.be:3004",
          # for debugging, log to a file
          #:nodeID => `hostname`,        # for debugging
          #:collect => 'file:/tmp/test.db'
        }
      )
    end

#    RobotLocation.inject(0, 100, 101, 102); RobotLocation.inject(0, 100, 101, 103); RobotLocation.inject(0, 100, 102, 104)

    Thread.new {
      loop {
        loc = get_location(robotids)
        if ! loc.nil?
          loc.each { |rid, status|
            RobotLocation.inject(rid, status[:x], status[:y], status[:angle])
          }
        end
        sleep 1
      }
    }
  end
end

if $0 == __FILE__
  Thread.abort_on_exception = true
  Log.info("******* STARTING *******")
  Log.info("Arguments: #{ARGV.inspect}")
  #Log.info "ENV is:: #{ENV.inspect}"

  if (ARGV[0] == '?' or ARGV[0] == 'help' or ARGV[0] == '-h' or ARGV[0] == '--help')
    $stdout.puts "Usage: #{$0} <coordinatefile> <username> <date> <token> to startup the app."
    $stdout.puts "    where: coordinatefile: the filename of a CSV file with coordinates"
    $stdout.puts "           username: the username corresponding with the security token  (optional)"
    $stdout.puts "           date    : the date-string the security token was generated on (optional)"
    $stdout.puts "           token   : the hash-string that signs the token                (optional)"
    $stdout.puts "After startop, you can enter the following on STDIN:"
    $stdout.puts "> 'robotid;desiredAction<enter>'"
    $stdout.puts "DesiredAction can be either one of: #{$Allowed_actions.join(' ')}"
    $stdout.puts "> 'start_drive' will forward the coordinates in CSV file to RobotControl"
    $stdout.puts "After startup you can forward the coordinates in the CSV by sending 'start_drive' to STDIN."
    exit
  else
    if (! ARGV[0].nil?)
      Log.info "Reading CSV file '#{ARGV[0]}'"
      RobotControlCommunicator.read_file(ARGV[0])

      if (! ARGV[1].nil? and ! ARGV[2].nil? and ! ARGV[3].nil?)
        usr   = ARGV[1]
        date  = ARGV[2]
        token = ARGV[3]
        $auth = { 'user' => usr, 'generated_on' => date, 'auth_hash' => token}.to_json
        Log.info("Authentication token is: #{$auth}")
      else
        if ARGV[1].nil?
          Log.warn "No authentication token supplied."
        else
          Log.warn "Incomplete authentication token."
        end
      end
    else
      Log.warn "No CSV coordinates passed -- 'start_drive' wont work."
    end
  end
  Log.info "Starting STDIN-handler"
  RobotControlCommunicator.handle_stdin # blocks
end


