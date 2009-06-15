#!/usr/bin/ruby
require 'rubygems'
require 'Logger'
require 'benchmark'
require 'ping'
require 'FileUtils'
require 'open3'

#============================= OPTIONS ==============================#
# == Options for local machine.
SSH_APP       = 'ssh'
RSYNC_APP     = 'rsync'

EXCLUDE_FILE  = '/Users/madnashua/.rsyncignore'
DIR_TO_BACKUP = '/Users/madnashua/'
LOG_FILE      = '/Users/madnashua/.log/rrsync/backup_home.log'
LOG_AGE       = 'daily'

EMPTY_DIR     = '/tmp/empty_rsync_dir/' #NEEDS TRAILING SLASH.
# == Options for the remote machine.
SSH_USER      = 'madnashua'
SSH_SERVER    = '192.168.0.2'
SSH_PORT      = '' #Leave blank for default (port 22).
BACKUP_ROOT   = '/share/backup/hubris'
BACKUP_DIR    = BACKUP_ROOT + '/' + Time.now.strftime('%A').downcase
RSYNC_VERBOSE = '-v'
RSYNC_OPTS    = "--force --ignore-errors --delete-excluded --exclude-from=#{EXCLUDE_FILE} --delete --backup --backup-dir=#{BACKUP_DIR} -a"
# == Options to control output
DEBUG         = true #If true output to screen else output is sent to log file.
SILENT        = false #Total silent = no log or screen output.
#========================== END OF OPTIONS ==========================#

if DEBUG && !SILENT
  logger = Logger.new(STDOUT, LOG_AGE)
elsif LOG_FILE != '' && !SILENT
  logger = Logger.new(LOG_FILE, LOG_AGE)
else
  logger = Logger.new(nil)
end
ssh_port = SSH_PORT.empty? ? '' : "-e 'ssh -p #{SSH_PORT}'"
rsync_cleanout_cmd = "#{RSYNC_APP} #{RSYNC_VERBOSE} #{ssh_port} --delete -a #{EMPTY_DIR} #{SSH_USER}@#{SSH_SERVER}:#{BACKUP_DIR}"
rsync_cmd = "#{RSYNC_APP} #{RSYNC_VERBOSE} #{ssh_port} #{RSYNC_OPTS} #{DIR_TO_BACKUP} #{SSH_USER}@#{SSH_SERVER}:#{BACKUP_ROOT}/current"

logger.info("Started running at: #{Time.now}")
`growlnotify -t RRsync --image icons/pending.png -m 'Started running at: #{Time.now}'`
run_time = Benchmark.realtime do
  begin
    raise Exception, "Unable to find remote host (#{SSH_SERVER})" unless Ping.pingecho(SSH_SERVER)
       
    FileUtils.mkdir_p("#{EMPTY_DIR}")
    Open3::popen3("#{rsync_cleanout_cmd}") { |stdin, stdout, stderr|
      tmp_stdout = stdout.read.strip
      tmp_stderr = stderr.read.strip
      logger.info("#{rsync_cleanout_cmd}\n#{tmp_stdout}") unless tmp_stdout.empty?
      unless tmp_stderr.empty?
        logger.error("#{rsync_cleanout_cmd}\n#{tmp_stderr}")
        `growlnotify -t RRsync --image icons/fail.png -m 'An error occurred: #{tmp_stderr}'`
      end
    }
    Open3::popen3("#{rsync_cmd}") { |stdin, stdout, stderr|
      tmp_stdout = stdout.read.strip
      tmp_stderr = stderr.read.strip
      logger.info("#{rsync_cmd}\n#{tmp_stdout}") unless tmp_stdout.empty?
      unless tmp_stderr.empty?
        logger.error("#{rsync_cmd}\n#{tmp_stderr}")
        `growlnotify -t RRsync --image icons/fail.png -m 'An error occurred: #{tmp_stderr}'`
      end
    }
    FileUtils.rmdir("#{EMPTY_DIR}")
  rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTEMPTY, Exception => e
    logger.fatal(e.to_s)
    `growlnotify -t RRsync --image icons/fail.png -m 'An error occurred: #{e.to_s}'`
  end
end
logger.info("Finished running at: #{Time.now} - Execution time: #{run_time.to_s[0, 5]}")
`growlnotify -t RRsync --image icons/pass.png -m 'Finished running at: #{Time.now} - Execution time: #{run_time.to_s[0, 5]}'`
