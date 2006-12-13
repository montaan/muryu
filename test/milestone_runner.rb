milestone_name = ARGV[0]
exit unless milestone_name
milestone_log = File.open(milestone_name + ".log", "w")
STDOUT.reopen milestone_log
$stdout = STDOUT
STDERR.reopen milestone_log
$stderr = STDERR
load milestone_name
